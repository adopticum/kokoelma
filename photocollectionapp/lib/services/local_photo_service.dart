import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:photocollectionapp/services/path_service.dart';
import '../models/photo_local.dart';
import '../utils/datetime_utils.dart';
import '../utils/logger.dart';

// The possible results when importing images.
enum ImportResult { success, cancelled, invalidFormat, error }

// Photos are stored locally on device like this:
// <root> is assigned from getApplicationDocumentsDirectory().
// <root>/<userId>/originals/yyyyMMdd-HHmmss-SSS.jpg
// The corresponding thumbnail miniature, if one exists, is stored as:
// <root>/<userId>/thumbnails/yyyyMMdd-HHmmss-SSS.jpg
// If for some reason we have no userId, then we use "anon"
// instead of an actual id, but this should never happen.
class LocalPhotoService {
  final PathService pathService;
  final String _userId;

  final StreamController<void> _photoChangesController =
      StreamController<void>.broadcast();

  LocalPhotoService(this.pathService, this._userId);

  static const String validExtensions = "(jpg|png)";
  //static const String anyExtension = r'\.[^.]+';
  static const String sizeFull = "originals";
  static const String sizeMini = "thumbnails";

  Stream<void> get photoChanges => _photoChangesController.stream;

  void notifyPhotoChanged() {
    if (!_photoChangesController.isClosed) {
      _photoChangesController.add(null);
    }
  }


  Directory getUserDirectory() {
    final Directory root = pathService.applicationDocumentsDirectory;
    final Directory dir = Directory(p.join(root.path, _userId));
    return dir;
  }

  bool ensureSubFolders(Directory userDir) {
    try {
      Directory(p.join(userDir.path, sizeFull))
        .createSync(recursive: true);
      Directory(p.join(userDir.path, sizeMini))
        .createSync(recursive: true);
      // No need to explicitly call exists()
      // createSync guarantees the dir exists if no exception is thrown.
      return true;
    } catch (e) {
      return false;
    }
  }

  String getNewPhotoPath() {
    final String timestampStr = DateTimeUtils.filenameFormat(DateTime.now());
    final userDir = getUserDirectory();
    ensureSubFolders(userDir);
    return p.join(userDir.path, sizeFull, "$timestampStr.jpg");
  }


  ({String userId, DateTime capturedAt}) parseFilePath(String path) {
    // Format: <root>/<userId>/originals/yyyyMMdd-HHmmss-SSS.jpg
    final userId = p.basename(p.dirname(p.dirname(path)));
    final filename = p.basenameWithoutExtension(path);
    final DateTime dt = DateTimeUtils.parseFilenameFormat(filename);
    return (userId: userId, capturedAt: dt);
  }

  // getAllPhotos must glob all files in the user's directory
  // and filter on the correct filname pattern,
  // then also parse out the timestamp from the filename.
  // It should populate the miniPath (thumbnail path) iff it exists.
  List<LocalPhoto> getAllPhotos() {
    final userDir = getUserDirectory();
    if (!ensureSubFolders(userDir)) {
      return [];
    }

    final fullDir = Directory(p.join(userDir.path, sizeFull));
    final miniDir = Directory(p.join(userDir.path, sizeMini));

    // Match both timestamp pattern and filename extension in one regular expression.
    final regex = RegExp(
      '^${DateTimeUtils.regExpPattern}\\.$validExtensions\$',
      caseSensitive: false,
    );

    final fullFiles =
        fullDir
            .listSync()
            .whereType<File>()
            .where((f) => regex.hasMatch(p.basename(f.path)))
            .toList();

    final miniFiles =
        miniDir
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .toSet();

    final List<LocalPhoto> photos = [];

    for (final file in fullFiles) {
      final filename = p.basename(file.path);
      final parsed = parseFilePath(file.path);
      final miniPath = p.join(miniDir.path, filename);

      photos.add(
        LocalPhoto(
          userid: parsed.userId,
          capturedAt: parsed.capturedAt,
          fullPath: file.path,
          miniPath:
              miniFiles.contains(filename) ? miniPath : file.path, // fallback
        ),
      );
    }

    // Sort newest first
    photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return photos;
  }

  // Import image using image picker as an alternative to using camera.
  Future<ImportResult> importImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) {
        // User cancelled.
        return ImportResult.cancelled;
      }

      final bytes = await pickedFile.readAsBytes();

      // Validate JPEG.
      if (!img.JpegDecoder().isValidFile(bytes)) {
        logger.i('Selected file is not a valid JPEG image.');
        return ImportResult.invalidFormat;
      }

      // Save photo to app directory.
      final filePath = getNewPhotoPath();
      final destination = File(filePath);
      await destination.writeAsBytes(bytes);
      notifyPhotoChanged();
      logger.i('Imported ${p.basename(destination.path)}');
      return ImportResult.success;
    } catch (e) {
      logger.i('Import failed: $e');
      return ImportResult.error;
    }
  }

  void dispose() {
    _photoChangesController.close();
  }
}
