import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/photo_abstract.dart';
import '../models/photo_local.dart';
import '../services/local_photo_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

// Photo representation for the list/grid in UI.
// Handle the fact that photos can exist both locally and remotely.
class PhotoItem {
  final Photo photo;

  // True if this photo exists in backend.
  final bool isUploaded;

  // True if we are using a local version (preferred).
  final bool isLocal;

  // True if this photo was captured by me.
  final bool isMine;

  PhotoItem({
    required this.photo,
    required this.isUploaded,
    required this.isLocal,
    required this.isMine,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PhotoItem && other.photo.id == photo.id);
  }

  @override
  int get hashCode => photo.id.hashCode;
}

enum FilterMode { mine, group }

enum SelectionAction {
  selectAll,
  selectNone,
  selectInvert,
  selectUploaded,
  selectNotUploaded,
}

class PhotoDateSection {
  final String title;
  final List<PhotoItem> items;

  const PhotoDateSection({required this.title, required this.items});
}

abstract class PhotosViewModel extends ChangeNotifier {
  final String userId;
  final LocalPhotoService _localPhotoService;
  final StorageService _storageService;
  final FilterMode _filterMode;

  final List<PhotoItem> _items = [];
  List<PhotoItem> get items => _items;

  LocalPhotoService get localPhotoService => _localPhotoService;
  StorageService get storageService => _storageService;

  final Set<PhotoItem> _selectedItems = {};
  Set<PhotoItem> get selectedItems => _selectedItems;

  String _titleText = 'Tap to preview, hold to select.';
  String get titleText => _titleText;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  bool _groupByDate = true;
  bool get groupByDate => _groupByDate;

  final String _preferenceKey;

  static const Map<String, String> titles = {
    'today': 'Today',
    'yesterday': 'Yesterday',
    'week': 'This week',
    'monthFormat': 'MMMM yyyy',
  };

  PhotosViewModel(
    this.userId,
    this._localPhotoService,
    this._storageService, {
    FilterMode filterMode = FilterMode.mine,
    required String preferenceKey,
    bool defaultGroupByDate = true,
  }) : _filterMode = filterMode,
    _preferenceKey = preferenceKey,
    _groupByDate = defaultGroupByDate {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadGroupByDatePreference();
    await loadPhotos();
  }

  Future<void> _loadGroupByDatePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _groupByDate = prefs.getBool(_preferenceKey) ?? _groupByDate;
    notifyListeners();
  }

  Future<void> setGroupByDate(bool value) async {
    _groupByDate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, value);
    notifyListeners();
  }

  Future<void> toggleGroupByDate() async {
    await setGroupByDate(!_groupByDate);
  }

  // Abstract method that must be implemented by subclasses to load the appropriate photos.
  Future<void> loadPhotos();

  static List<PhotoDateSection> groupPhotosByDate(List<PhotoItem> items) {
    if (items.isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final past7Days = today.subtract(const Duration(days: 7));

    final sections = <PhotoDateSection>[];
    final grouped = <String, List<PhotoItem>>{};

    for (final item in items) {
      final captured = item.photo.capturedAt;
      final dateOnly = DateTime(captured.year, captured.month, captured.day);

      String title;
      if (dateOnly == today) {
        title = titles['today']!;
      } else if (dateOnly == yesterday) {
        title = titles['yesterday']!;
      } else if (dateOnly.isAfter(past7Days) && dateOnly.isBefore(today)) {
        title = titles['week']!;
      } else {
        title = DateFormat(titles['monthFormat']!).format(captured);
      }

      grouped.putIfAbsent(title, () => []).add(item);
    }

    final orderedTitles =
        grouped.keys.toList()..sort((a, b) {
          final aDate = _dateForTitle(a, now);
          final bDate = _dateForTitle(b, now);
          if (aDate == null || bDate == null) {
            return a.compareTo(b);
          }
          return bDate.compareTo(aDate);
        });

    for (final title in orderedTitles) {
      sections.add(PhotoDateSection(title: title, items: grouped[title]!));
    }

    return sections;
  }

  static DateTime? _dateForTitle(String title, DateTime now) {
    if (title == titles['today']) {
      return DateTime(now.year, now.month, now.day);
    }
    if (title == titles['yesterday']) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
    }
    if (title == titles['week']) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
    }

    try {
      return DateFormat(titles['monthFormat']!).parse(title);
    } catch (_) {
      return null;
    }
  }

  void setTitleText(String text) {
    _titleText = text;
    notifyListeners();
  }

  Future<void> uploadSelectedPhotos({String? groupId}) async {
    if (_isUploading || _filterMode == FilterMode.group) return;

    final selectionSnapshot = List<PhotoItem>.from(_selectedItems);

    _isUploading = true;
    _isSelectionMode = false;
    notifyListeners();

    try {
      final toUpload =
          selectionSnapshot
              .where((item) => item.isLocal && !item.isUploaded)
              .map((item) => item.photo as LocalPhoto)
              .toList();

      for (final photo in toUpload) {
        await _storageService.uploadAndRecord(
          File(photo.fullPath),
          userId: userId,
          groupId: groupId,
        );
      }
      _selectedItems.clear();
    } finally {
      _isUploading = false;
      _selectedItems.clear();
      // Release UI state immediately even if refresh fails.
      notifyListeners();
      try {
        await loadPhotos();
      } catch (e, st) {
        logger.e(
          'Failed to refresh photos after upload: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> deleteSelectedPhotosLocally() async {
    final toDelete =
        _selectedItems
            .where((item) => item.photo is LocalPhoto)
            .map((item) => item.photo as LocalPhoto)
            .toList();

    for (final photo in toDelete) {
      await File(photo.fullPath).delete();

      if (photo.miniPath != photo.fullPath) {
        final f = File(photo.miniPath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    }

    clearSelection();
    await loadPhotos();
  }

  void enterSelectionMode() {
    if (_filterMode == FilterMode.group || _isSelectionMode) return;
    _isSelectionMode = true;
    notifyListeners();
  }

  void exitSelectionMode() {
    if (!_isSelectionMode) return;
    _isSelectionMode = false;
    _selectedItems.clear();
    notifyListeners();
  }

  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }

  void selectItem(PhotoItem item) {
    if (!_isSelectionMode) return;
    _selectedItems.add(item);
    notifyListeners();
  }

  void selectItems(List<PhotoItem> items) {
    if (!_isSelectionMode) return;
    _selectedItems.addAll(items);
    notifyListeners();
  }

  void deselectItem(PhotoItem item) {
    if (!_isSelectionMode) return;
    _selectedItems.remove(item);
    if (_selectedItems.isEmpty) {
      exitSelectionMode();
    }
    notifyListeners();
  }

  void deselectItems(List<PhotoItem> items) {
    if (!_isSelectionMode) return;
    _selectedItems.removeAll(items);
    if (_selectedItems.isEmpty) {
      exitSelectionMode();
    }
    notifyListeners();
  }

  bool isSelected(PhotoItem item) {
    return (_isSelectionMode && _selectedItems.contains(item));
  }

  void toggleSelected(PhotoItem item) {
    if (!_isSelectionMode) return;
    if (_selectedItems.contains(item)) {
      _selectedItems.remove(item);
    } else {
      _selectedItems.add(item);
    }

    if (_selectedItems.isEmpty) {
      exitSelectionMode();
    }
    notifyListeners();
  }

  void selectionAction(SelectionAction action) {
    if (!_isSelectionMode) return;
    switch (action) {
      case SelectionAction.selectAll:
        _selectedItems
          ..clear()
          ..addAll(_items);
        notifyListeners();
        break;
      case SelectionAction.selectNone:
        clearSelection();
        break;
      case SelectionAction.selectInvert:
        final inverted =
            _items.where((item) => !_selectedItems.contains(item)).toSet();
        _selectedItems
          ..clear()
          ..addAll(inverted);
        notifyListeners();
        break;
      case SelectionAction.selectUploaded:
        _selectedItems
          ..clear()
          ..addAll(_items.where((item) => item.isUploaded));
        notifyListeners();
        break;
      case SelectionAction.selectNotUploaded:
        _selectedItems
          ..clear()
          ..addAll(_items.where((item) => !item.isUploaded));
        notifyListeners();
        break;
    }
  }
}
