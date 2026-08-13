import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:photocollectionapp/services/exif_service.dart';
import 'package:photocollectionapp/utils/datetime_utils.dart';

class PendingPhotoLocation {
  PendingPhotoLocation({
    required this.path,
    required this.capturedAt,
    required this.filename,
  });

  final String path;
  final DateTime capturedAt;
  final String filename;
}

class PhotoLocationService {
  PhotoLocationService(this._exifService);

  static const Duration backfillWindow = Duration(seconds: 60);
  static const double maxAccuracyMeters = 30;
  static const double preferredAccuracyMeters = 10;

  final ExifService _exifService;

  final List<PendingPhotoLocation> _pending = [];
  Position? _bestPosition;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      if (!_isGoodPosition(position)) return;

      final shouldReplace = _bestPosition == null ||
          position.accuracy < _bestPosition!.accuracy &&
              position.accuracy <= preferredAccuracyMeters;

      if (!shouldReplace) return;

      _bestPosition = position;
      _processQueue();
    });
  }

  bool _isGoodPosition(Position position) {
    return position.latitude != 0.0 &&
        position.longitude != 0.0 &&
        position.accuracy <= maxAccuracyMeters;
  }

  void enqueuePhoto(String path) {
    final filename = File(path).uri.pathSegments.last;
    final capturedAt = DateTimeUtils.parseFilenameFormat(
      filename.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );

    _pending.add(PendingPhotoLocation(
      path: path,
      capturedAt: capturedAt,
      filename: filename,
    ));

    _pending.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_bestPosition == null) return;

    final now = DateTime.now();
    final pendingSnapshot = List<PendingPhotoLocation>.from(_pending);

    for (final item in pendingSnapshot) {
      final age = now.difference(item.capturedAt);
      final isStillWithinWindow = age <= backfillWindow;

      if (!isStillWithinWindow) {
        continue;
      }

      final alreadyHasGps = await _exifService.hasGps(item.path);
      if (alreadyHasGps) {
        continue;
      }

      await _exifService.writeGpsToPhoto(
        item.path,
        _bestPosition!.latitude,
        _bestPosition!.longitude,
      );

      _pending.remove(item);
    }

    _pending.removeWhere((item) {
      final age = now.difference(item.capturedAt);
      return age > backfillWindow;
    });
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }
}