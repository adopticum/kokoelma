import 'package:flutter/material.dart';
import 'package:photocollectionapp/services/local_photo_service.dart';
import 'package:photocollectionapp/services/location_service.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

class CameraViewModel extends ChangeNotifier {
  final LocalPhotoService localPhotoService;
  final PhotoLocationService photoLocationService;

  CameraViewModel(this.localPhotoService, this.photoLocationService);

  final List<String> _pendingPhotoPaths = [];

  String getNewPhotoPath() {
    return localPhotoService.getNewPhotoPath();
  }

  void notifyPhotoCaptured() {
    localPhotoService.notifyPhotoChanged();
  }

  Future<void> startLocationTracking() async {
    await photoLocationService.startTracking();
  }

  void stopLocationTracking() {
    photoLocationService.stop();
  }

  void enqueueCapturedPhoto(String path) {
    photoLocationService.enqueuePhoto(path);
  }

  String insertSuffix(String path, String suffix) {
    int dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0) {
      return path;
    }

    final String base = path.substring(0, dotIndex);
    final String ext = path.substring(dotIndex);
    return base + suffix + ext;
  }

  List<String> consumePendingPhotoPaths() {
    final pending = List<String>.from(_pendingPhotoPaths);
    _pendingPhotoPaths.clear();
    return pending;
  }

  // How and where we save photos
  SaveConfig createSaveConfig() {
    return SaveConfig.photo(
      mirrorFrontCamera: false,
      exifPreferences: ExifPreferences(saveGPSLocation: true),
      pathBuilder: (sensors) async {
        final newPhotoPath = getNewPhotoPath();

        if (sensors.length == 1) {
          _pendingPhotoPaths.add(newPhotoPath);
          return SingleCaptureRequest(newPhotoPath, sensors.first);
        } else {
          // Separate pictures taken with front and back camera
          final paths = {
            for (final sensor in sensors)
              sensor:
                  (sensor.position == SensorPosition.front)
                      ? insertSuffix(newPhotoPath, "_front")
                      : insertSuffix(newPhotoPath, "_back"),
          };

          _pendingPhotoPaths.addAll(paths.values);
          return MultipleCaptureRequest(paths);
        }
      },
    );
  }
}
