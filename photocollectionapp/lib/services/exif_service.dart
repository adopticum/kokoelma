import 'package:native_exif/native_exif.dart';

class ExifService {
  Future<void> embedGpsToPhoto(String path, double lat, double lon) async {
    final exif = await Exif.fromPath(path);

    try {
      await exif.writeAttributes({
        'GPSLatitude': lat,
        'GPSLatitudeRef': lat >= 0 ? 'N' : 'S',
        'GPSLongitude': lon,
        'GPSLongitudeRef': lon >= 0 ? 'E' : 'W',
      });
    } finally {
      await exif.close();
    }
  }

  Future<void> writeGpsToPhoto(String path, double lat, double lon) async {
    await embedGpsToPhoto(path, lat, lon);
  }

  Future<bool> hasGps(String filePath) async {
    final exif = await Exif.fromPath(filePath);

    try {
      final lat = await exif.getAttribute('GPSLatitude');
      final lon = await exif.getAttribute('GPSLongitude');
      return lat != null && lon != null;
    } finally {
      await exif.close();
    }
  }

  Future<Map<String, double>?> getGpsFromPhoto(String filePath) async {
    final exif = await Exif.fromPath(filePath);

    try {
      final lat = await exif.getAttribute('GPSLatitude');
      final lon = await exif.getAttribute('GPSLongitude');
      if (lat != null && lon != null) {
        return {
          'latitude': lat,
          'longitude': lon,
        };
      }

      return null;
    } finally {
      await exif.close();
    }
  }
}