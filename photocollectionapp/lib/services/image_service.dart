import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
//import 'exif_service.dart';
//import 'local_photo_service.dart';
import '../utils/logger.dart';

class ImageService {
  
  ImageService();

/* dep. 
  int? extractTimestampFromFilename(String path) {
    final regex = RegExp(r'photo_(\d+)\.jpg$');
    final match = regex.firstMatch(path);
    if (match != null) {
      final millis = int.tryParse(match.group(1)!);
      if (millis != null) {
        return millis;
      }
    }
    return null;
  }
*/

  Future<Uint8List?> generateThumbnail(File imageFile) async {
    try {
      final data = await imageFile.readAsBytes();
      final image = img.decodeImage(data);
      if (image == null) return null;

      final thumbnail = img.copyResize(image, width: 300);
      return Uint8List.fromList(img.encodeJpg(thumbnail));
    } catch (e) {
      logger.e('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Read the image file and return a JPEG byte stream that fits within
  /// [maxSizeKb] kilobytes. Returns the original bytes if they are already
  /// a valid JPEG and fit the size. Returns null if the image cannot be decoded.
  Future<Uint8List?> jpegBytesWithinLimit(
    File file, {
    required int maxSizeKb,
  }) async {
    final data = await file.readAsBytes();
    final decoded = img.decodeImage(data);
    if (decoded == null || !img.JpegDecoder().isValidFile(data)) {
      return null;
    }

    final maxBytes = maxSizeKb * 1024;
    // If original is already a valid JPEG and within size, return original bytes.
    if ((data.lengthInBytes <= maxBytes) || (maxSizeKb < 1)) {
      return data;
    }

    // Helper to encode image to JPEG bytes with given quality.
    //    Uint8List encodeJpeg(img.Image image, int quality) =>
    //        Uint8List.fromList(img.encodeJpg(image, quality: quality));

    // Strategy:
    // 1) Keep quality fixed at 80 and progressively downscale until the
    //    encoded size at quality 80 is <= 2.0 * maxBytes (target window).
    // 2) For that downscaled image, binary-search the quality to get
    //    an encoded JPEG <= maxBytes (as close as possible).

    double byteRatio = data.lengthInBytes / maxBytes;
    int wMin = 16;
    int wMax = decoded.width;
    int width = 0;
    int q = 80;
    img.Image resizedImg;
    Uint8List resizedJpg;

    // Resize the image until the encoded size is within 1.0 to 1.25 times the allowed max.
    do {
      width = (wMin + wMax) ~/ 2;
      resizedImg = img.copyResize(decoded, width: width);
      resizedJpg = img.encodeJpg(resizedImg, quality: q);
      byteRatio = resizedJpg.lengthInBytes / maxBytes;

      if (resizedJpg.lengthInBytes > maxBytes) {
        wMax = width;
      } else {
        wMin = width;
      }
    } while ((byteRatio < 1.0 || byteRatio > 1.25) && (wMax - wMin > 16));

    // We are now within an acceptable downscale factor, proceed with quality tuning.
    int qMin = 25;
    int qMax = 80;
    do {
      q = (qMin + qMax) ~/ 2;
      resizedJpg = img.encodeJpg(resizedImg, quality: q);
      byteRatio = resizedJpg.lengthInBytes / maxBytes;

      if (resizedJpg.lengthInBytes > maxBytes) {
        qMax = q;
      } else {
        qMin = q;
      }
    } while ((byteRatio < 0.75 || byteRatio > 1.0) && (qMax - qMin > 2));

    if (resizedJpg.lengthInBytes < maxBytes) {
      // Successfully downscaled the size and quality to meet target.
      return resizedJpg;
    }

    // If we couldn't meet the target, produce a small fallback image.
    return img.encodeJpg(img.copyResize(decoded, width: 64), quality: 30);
    //final img.Image tiny = img.copyResize(decoded, width: 64);
    //return Uint8List.fromList(img.encodeJpg(tiny, quality: 30));
  }


/* dep. 
  Future<PhotoMetadata?> parseLocalPhoto(File file) async {
    // Ensure the file is a valid JPEG.
    final bytes = await file.readAsBytes();
    if (!img.JpegDecoder().isValidFile(bytes)) {
      logger.w('File ${file.path} is not a valid JPEG image.');
      return null;
    }

    // Ensure timestamp can be extracted from filename.
    final timestamp = extractTimestampFromFilename(file.path);
    if (timestamp == null) {
      logger.w('Could not extract timestamp from filename: ${file.path}');
      return null;
    }

    final position = await _exifService.getGpsFromPhoto(file.path);
    final parsed = _localPhotoService.parseFilePath(file.path);

    final metadata = PhotoMetadata(
      // Use the original filename from local storage, but ensure extension is .jpg.
      groupid: groupid,
      userid: parsed.userId,
      filename: p.basename(file.path), //with extension
      //dep.  basename: p.basenameWithoutExtension(file.path),
      capturedAt: parsed.capturedAt,
      latitude: position?['latitude'],
      longitude: position?['longitude'],

    );

    return metadata;
  }
  */
}
