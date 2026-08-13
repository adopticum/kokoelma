import 'dart:async';

import '../models/photo_abstract.dart';
import '../models/photo_local.dart';
import '../utils/logger.dart';
import 'photos_viewmodel.dart';

class CameraRollViewModel extends PhotosViewModel {
  late final StreamSubscription<void> _photoChangesSubscription;
  bool _isReloadingPhotos = false;

  CameraRollViewModel(super.userId,super.localPhotoService, super.storageService)
    : super(
        filterMode: FilterMode.mine,
        preferenceKey: 'camera_roll_group_by_date',
      ) {
    _photoChangesSubscription = localPhotoService.photoChanges.listen((_) {
      _reloadPhotosFromLocalChange();
    });
  }

  static List<PhotoDateSection> groupPhotosByDate(List<PhotoItem> items) {
    return PhotosViewModel.groupPhotosByDate(items);
  }

  // Load remote photos taken by the current user regardless of group.
  // Load all local photos. Merge the two lists and sort by capturedAt descending.
  @override
  Future<void> loadPhotos() async {
    final local = localPhotoService.getAllPhotos();
    logger.i("loadPhotos found ${local.length} photos stored locally.");

    // Filter remote photos to include only those taken by the current user.
    final visibleLocal =
        local.where((photo) => photo.userid == userId).toList();

    // Get all remote photos taken by the current user, but from all groups.
    final remote = await storageService.getAllMySharedPhotos(userId);
    logger.i("loadPhotos found ${remote.length} photos in backend.");
    final visibleRemote =
        remote.where((photo) => photo.userid == userId).toList();
    final remoteIds = visibleRemote.map((photo) => photo.id).toSet();

    final merged = <String, Photo>{};

    for (final photo in visibleRemote) {
      merged[photo.id] = photo;
    }
    for (final photo in visibleLocal) {
      merged[photo.id] = photo;
    }

    final List<PhotoItem> loaded =
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
    notifyListeners();
  }

  Future<void> _reloadPhotosFromLocalChange() async {
    if (_isReloadingPhotos) {
      return;
    }

    _isReloadingPhotos = true;
    try {
      await loadPhotos();
    } finally {
      _isReloadingPhotos = false;
    }
  }

  @override
  void dispose() {
    _photoChangesSubscription.cancel();
    super.dispose();
  }
}
