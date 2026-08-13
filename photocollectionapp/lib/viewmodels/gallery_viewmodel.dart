import 'dart:async';

import '../models/group.dart';
import '../models/photo_abstract.dart';
import '../models/photo_local.dart';
import '../models/gallery_sync_events.dart';
import '../models/photo_remote.dart';
import '../services/gallery_sync_service.dart';
import '../utils/logger.dart';
import 'photos_viewmodel.dart';

class GalleryViewModel extends PhotosViewModel {
  final GallerySyncService _gallerySyncService;
  StreamSubscription<GallerySyncEvent>? _gallerySyncSubscription;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  List<Group> _availableGroups = [];
  List<Group> get availableGroups => _availableGroups;

  String? _selectedGroupId;
  String? get selectedGroupId => _selectedGroupId;

  Group? get selectedGroup {
    if (_selectedGroupId == null) {
      return null;
    }

    for (final group in _availableGroups) {
      if (group.id == _selectedGroupId) {
        return group;
      }
    }

    return null;
  }

  GalleryViewModel(
    super.userId,
    super.localPhotoService,
    super.storageService,
    this._gallerySyncService,
  ) : super(
        filterMode: FilterMode.group,
        preferenceKey: 'gallery_group_by_date',
      ) {
    _gallerySyncSubscription = _gallerySyncService.events.listen((event) {
      logger.d('Gallery VM: received sync event ${event.runtimeType}');
      unawaited(applySyncEvent(event));
    });
    unawaited(_gallerySyncService.start());
    _initializeGroupSelection();
  }

  Future<void> _initializeGroupSelection() async {
    if (userId.isEmpty) {
      _availableGroups = [];
      _selectedGroupId = null;
      notifyListeners();
      return;
    }

    final groups = await storageService.groupService.getGroupsForUser(userId);
    _availableGroups = groups;

    if (groups.isEmpty) {
      _selectedGroupId = null;
    } else if (_selectedGroupId == null ||
        !groups.any((group) => group.id == _selectedGroupId)) {
      _selectedGroupId = groups.first.id;
    }

    notifyListeners();
    await loadPhotos();
  }

  Future<void> _refreshAvailableGroups({bool reloadPhotos = true}) async {
    final groups = await storageService.groupService.getGroupsForUser(userId);
    _availableGroups = groups;

    final selectedStillExists =
        _selectedGroupId != null &&
        groups.any((group) => group.id == _selectedGroupId);

    if (!selectedStillExists) {
      _selectedGroupId = null;
      items.clear();
      selectedItems.clear();
      logger.i('Gallery VM: selected group no longer available; cleared gallery');
      notifyListeners();
      return;
    }

    notifyListeners();
    if (reloadPhotos) {
      await loadPhotos();
    }
  }

  Future<void> selectGroup(String? groupId) async {
    if (groupId != null && _availableGroups.any((group) => group.id == groupId)) {
      if (_selectedGroupId == groupId) {
        logger.d('Gallery VM: selectGroup ignored; already selected $groupId');
        return;
      }

      _selectedGroupId = groupId;
      logger.i('Gallery VM: selected group changed to $groupId');
      notifyListeners();
      await loadPhotos();
    } else {
      // Invalid or no group, then clear the view.
      _selectedGroupId = null;
      items.clear();
      selectedItems.clear();
      logger.i('Gallery VM: Selected group set to none.');
      notifyListeners();
    }
  }

  //TODO: loadPhotos is mostly duplicated from PhotosViewModel, but we need to filter by groupId. Consider refactor to avoid code duplication.
  @override
  Future<void> loadPhotos() async {
    _isLoading = true;
    notifyListeners();

    try {
      final local = localPhotoService.getAllPhotos();
      logger.i("loadPhotos found ${local.length} photos stored locally.");

      final remote = await storageService.getSharedPhotos(
        userId,
        groupId: _selectedGroupId,
      );
      logger.i("loadPhotos found ${remote.length} photos in backend.");

      final visibleLocal = <LocalPhoto>[];
      final visibleRemote = remote.where((photo) => true).toList();

      final List<PhotoItem> loaded;
      final remoteIds = visibleRemote.map((photo) => photo.id).toSet();
      final merged = <String, Photo>{};

      for (final photo in visibleRemote) {
        merged[photo.id] = photo;
      }
      for (final photo in visibleLocal) {
        merged[photo.id] = photo;
      }

      loaded =
          merged.entries.map((entry) {
            final photo = entry.value;
            return PhotoItem(
              photo: photo,
              isUploaded: remoteIds.contains(entry.key),
              isLocal: photo is LocalPhoto,
              isMine: photo.userid == userId,
            );
          }).toList();

      loaded.sort((a, b) => b.photo.capturedAt.compareTo(a.photo.capturedAt));
      items
        ..clear()
        ..addAll(loaded);
      selectedItems.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static List<PhotoDateSection> groupPhotosByDate(List<PhotoItem> items) {
    return PhotosViewModel.groupPhotosByDate(items);
  }

  Future<void> applySyncEvent(GallerySyncEvent event) async {
    logger.d('Gallery VM: applying sync event ${event.runtimeType}');

    if (event is MembershipAdded) {
      await _applyMembershipAdded(event);
      return;
    }
    if (event is MembershipRemoved) {
      await _applyMembershipRemoved(event);
      return;
    }
    if (event is PhotoAdded) {
      await _applyPhotoAdded(event);
      return;
    }
    if (event is PhotoRemoved) {
      _applyPhotoRemoved(event);
      return;
    }
    if (event is GallerySyncInvalidate) {
      logger.i(
        'Gallery VM: processing invalidate reason=${event.reason}; refreshing groups and selection',
      );
      await _refreshAvailableGroups();
    }
  }

  Future<void> _applyMembershipAdded(MembershipAdded event) async {
    if (event.membership.userid != userId) {
      logger.d(
        'Gallery VM: ignoring MembershipAdded for other user ${event.membership.userid}',
      );
      return;
    }
    if (_availableGroups.any((group) => group.id == event.membership.groupid)) {
      logger.d(
        'Gallery VM: MembershipAdded ignored; group already present ${event.membership.groupid}',
      );
      return;
    }

    final group = await storageService.groupService.getGroup(
      event.membership.groupid,
    );
    if (group == null) return;

    _availableGroups = [..._availableGroups, group];

    // Immediately select the new group if no group is currently selected.
    if (_selectedGroupId == null) {
      selectGroup(group.id);
      logger.i(
        'Gallery VM: selected initial group ${group.id} after membership add',
      );
    }
    notifyListeners();
  }

  Future<void> _applyMembershipRemoved(MembershipRemoved event) async {
    if (event.membership.userid != userId) {
      logger.d(
        'Gallery VM: ignoring MembershipRemoved for other user ${event.membership.userid}',
      );
      return;
    }

    // Remove the group from the available groups list.
    _availableGroups =
        _availableGroups
            .where((group) => group.id != event.membership.groupid)
            .toList();

    // If the removed group was selected, clear the active selection and gallery.
    if (event.membership.groupid == _selectedGroupId) {
      logger.i(
        'Gallery VM: selected group ${event.membership.groupid} removed; clearing active gallery selection',
      );
      await selectGroup(null);
      return;
    }

    notifyListeners();
  }

  Future<void> _applyPhotoAdded(PhotoAdded event) async {
    if (_selectedGroupId != event.photoMetadata.groupid) {
      logger.d(
        'Gallery VM: ignoring PhotoAdded for non-selected group ${event.photoMetadata.groupid}',
      );
      return;
    }
    final remotePhoto = await storageService.toRemotePhoto(event.photoMetadata);
    logger.d('Gallery VM: applying PhotoAdded ${event.photoMetadata.photoId}');
    _upsertPhotoItem(remotePhoto);
  }

  Future<void> _applyPhotoRemoved(PhotoRemoved event) async {
    final pmd = event.photoMetadata;
    if (_selectedGroupId != pmd.groupid) {
      logger.d(
        'Gallery VM: ignoring PhotoRemoved for non-selected group ${pmd.groupid}',
      );
      return;
    }
    final index = items.indexWhere((item) => item.photo.id == pmd.photoId);
    if (index < 0) {
      logger.d(
        'Gallery VM: PhotoRemoved ignored; photo not present ${pmd.photoId}',
      );
      return;
    }

    logger.d('Gallery VM: applying PhotoRemoved ${pmd.photoId}');
    items.removeAt(index);
    notifyListeners();
  }

  void _upsertPhotoItem(RemotePhoto remotePhoto) {
    final photoItem = PhotoItem(
      photo: remotePhoto,
      isUploaded: true,
      isLocal: false,
      isMine: remotePhoto.userid == userId,
    );

    final existingIndex = items.indexWhere(
      (item) => item.photo.id == remotePhoto.id,
    );
    if (existingIndex >= 0) {
      items.removeAt(existingIndex);
    }

    final insertIndex = items.indexWhere(
      (item) => item.photo.capturedAt.isBefore(remotePhoto.capturedAt),
    );
    if (insertIndex < 0) {
      items.add(photoItem);
    } else {
      items.insert(insertIndex, photoItem);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _gallerySyncSubscription?.cancel();
    super.dispose();
  }
}
