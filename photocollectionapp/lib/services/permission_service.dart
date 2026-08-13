
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';

class PermissionService {
    final GlobalKey<NavigatorState> navigatorKey;

  PermissionService(this.navigatorKey);

  Future<bool> _requestAndNag(Permission permission) async {
    var status = await permission.request();
    if (status.isGranted) return true;

    logger.w('${permission.toString()} denied. Asking user to open app settings.');

    while (!status.isGranted && !status.isPermanentlyDenied) {
      final confirmed = await _showPermissionDialog(permission);
      if (!confirmed) return false;

      await openAppSettings();
      await Future.delayed(const Duration(seconds: 2));
      status = await permission.status;
    }

    return status.isGranted;
  }

  Future<bool> _showPermissionDialog(Permission permission) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Permission Required'),
            content: Text(
              'The app needs ${permission.toString().split(".").last} permission to function properly. Please grant it in settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> requestCamera() => _requestAndNag(Permission.camera);

  Future<bool> requestLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      logger.w('Location services are disabled. Prompting user to enable.');

      final context = navigatorKey.currentContext;
      if (context != null) {
        if (context.mounted){
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Enable Location Services'),
              content: const Text('Location services are turned off. Please enable them in system settings.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
      return false;
    }

    return _requestAndNag(Permission.locationWhenInUse);
  }
  
  Future<bool> requestAllRequired() async {
    final cameraGranted = await requestCamera();
    final locationGranted = await requestLocation();

    final allGranted = cameraGranted && locationGranted;
    logger.i('All required permissions granted: $allGranted');
    return allGranted;
  }

  Future<bool> isAllGranted() async {
    final camera = await Permission.camera.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;

    logger.d('Camera granted: $camera');
    logger.d('Location granted: $location');
 
    return camera && location;
  }
}
