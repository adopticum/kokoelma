import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:photocollectionapp/models/photo_metadata.dart';
import '../models/photo_abstract.dart';
import '../models/photo_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'exif_service.dart';
import 'group_service.dart';
import 'image_service.dart';
import 'local_photo_service.dart';
import '../utils/logger.dart';
import '../utils/datetime_utils.dart';

class StorageService {
  final SupabaseClient _client;
  final ExifService _exifService;
  final GroupService _groupService;
  final ImageService _imageService;
  final LocalPhotoService _localPhotoService;

  StorageService(
    this._client,
    this._exifService,
    this._groupService,
    this._imageService,
    this._localPhotoService,
  ) { }

  static const String bucket = 'shared-files';
  static const String metadatatable = 'photometadata';
  static const String sizeMini = "thumbnails";
  static const String sizeFull = "originals";
  static const int signedUrlTimeout = 3600;  // One hour.
  static const int maxUploadSizeKb =
      900; // Max size for uploaded photos in KB, adjust as needed.

  GroupService get groupService => _groupService;

  bool _isStorageConflict(Object error) {
    if (error is! StorageException) return false;
    final status = error.statusCode?.toString() ?? '';
    final msg = error.message.toLowerCase();
    return status == '409' ||
        msg.contains('already exists') ||
        msg.contains('duplicate');
  }

  bool _isDuplicateMetadataError(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();
    final details = (error.details.toString()).toLowerCase();
    return code == '23505' ||
        msg.contains('duplicate key') ||
        details.contains('duplicate key');
  }

  // The auth token lets the RLS policy evaluate correctly and grant access.
  /* debug only
  Map<String, String> getAuthHeaders() {
    final session = _client.auth.currentSession;
    return {'Authorization': 'Bearer ${session?.accessToken}'};
  }
  */

  // Consistent filename handling.
  String getUploadName(File file) {
    final basename = p.basenameWithoutExtension(file.path);
    String ext = p.extension(file.path).toLowerCase();

    // Normalize all JPEG variants to .jpg
    //const jpegVariants = {'.jpeg', '.jpg', '.jpe', '.jfif'};
    //if (jpegVariants.contains(ext)) { ext = '.jpg'; }

    // Force everything to JPEG (since we re-encode anyway)
    ext = '.jpg';

    return "$basename$ext";
  }

  //TODO: Users should not be able to upload photos unless they are members of a group.

  /* Uploads the photo to Supabase Storage.
  Also generates and uploads a thumbnail size version of the image.
  Returns the public URL to the full size image and the thumbnail (if generated).
  Uses the filename as is from local storage.
  Ensure filename extension is .jpg when uploaded to Supabase Storage.
  */
  Future<bool> uploadPhotoToStorage(
    File file,
    String userId,
    String groupId,
  ) async {
    // Decode the local image and re-encode at lower resolution or JPEG quality, if necessary to meet size limits.
    final jpegBytes = await _imageService.jpegBytesWithinLimit(
      file,
      maxSizeKb: maxUploadSizeKb,
    );
    if (jpegBytes == null) {
      logger.w(
        'Failed to encode image ${p.basename(file.path)} to fit size restrictions for upload.',
      );
      return false;
    } else {
      logger.i(
        'Encoded image ${p.basename(file.path)} to ${jpegBytes.lengthInBytes} bytes for upload.',
      );
    }

    try {
      final uploadName = getUploadName(file);
      final gid = groupId;

      final photoName = "$gid/$userId/$sizeFull/$uploadName";
      final thumbName = "$gid/$userId/$sizeMini/$uploadName";

      // Upload high resolution JPEG to storage bucket.
      try {
        final storageResponse = await _client.storage
            .from(bucket)
            .uploadBinary(photoName, jpegBytes);

        if (storageResponse.isEmpty) {
          return false;
        }
      } catch (e) {
        if (_isStorageConflict(e)) {
          logger.i('Storage full image already exists, continuing: $photoName');
        } else {
          rethrow;
        }
      }

      // Generate and upload thumbnail.
      final Uint8List? thumbnailBytes = await _imageService.generateThumbnail(
        file,
      );
      //String? thumbUrl;
      if (thumbnailBytes != null) {
        try {
          await _client.storage
              .from(bucket)
              .uploadBinary(thumbName, thumbnailBytes);
        } catch (e) {
          if (_isStorageConflict(e)) {
            logger.i(
              'Storage thumbnail already exists, continuing: $thumbName',
            );
          } else {
            logger.w('Thumbnail upload failed for $thumbName: $e');
          }
        }
        //thumbUrl = _client.storage.from(bucket).getPublicUrl(thumbName);
      }

      logger.i(
        'Local image $uploadName successfully uploaded as $photoName (${jpegBytes.lengthInBytes} B).',
      );
      return true;
    } catch (e, st) {
      logger.e(
        'Storage upload failed for ${file.path}: $e',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /* Stores a record of the photo in the Supabase database.
  Rely on Supabase RLS to check permission and to assign 
  ownership of the record to the currently logged in user.
  */
  Future<void> insertMetadataRecord(File file, String groupId) async {
    //dep.
    //final metadata = await _imageService.parseLocalPhoto(file);
    //if (metadata == null) {
    //  logger.w(
    //    'Skipping database record insertion for ${file.path} due to metadata parsing issues.',
    //  );
    //  return;
    //}

    final parsed = _localPhotoService.parseFilePath(file.path);
    final position = await _exifService.getGpsFromPhoto(file.path);


    try {
      await _client.from(metadatatable).insert({
        //dep. 'user_id': user.id,
        'groupid': groupId,
        'filename': getUploadName(file),
        'captured_at': parsed.capturedAt.toIso8601String(),
        'latitude': position?['latitude'],
        'longitude': position?['longitude'],
      });
    } catch (e) {
      if (_isDuplicateMetadataError(e)) {
        logger.i(
          'Metadata row already exists for ${file.path}; treating as success.',
        );
        return;
      }
      rethrow;
    }
  }

  /// Perform both file upload and record metadata in a single operation.
  Future<void> uploadAndRecord(
    File file, {
    required String userId,
    String? groupId,
  }) async {
    if (userId.isEmpty) {
      logger.w('Upload skipped because userId is empty.');
      return;
    }

    // Resolve the default group ID if necessary.
    final gid =
      groupId?.trim().isNotEmpty == true
          ? groupId ?? ""
          : (await _groupService.getDefaultGroup(userId))?.id ?? "";

    try {
      if (!await uploadPhotoToStorage(file, userId, gid)) {
        logger.w(
          'Upload failed for ${file.path}; skipping metadata record insertion.',
        );
        return;
      }

      try {
        await insertMetadataRecord(file, gid);
      } catch (e, st) {
        logger.e(
          'Failed to insert photo record for ${file.path}: $e',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e, st) {
      logger.e(
        'UploadAndRecord failed for ${file.path}: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /* dep. 
  Future<Set<String>> getUploadedFileNames(String userId, String groupId) async {
    try {
      final response = await _client
          .from(metadatatable)
          .select('filename')
          .eq('userid', userId)
          .eq('groupid', groupId);

      final filenames =
          (response as List).map((e) => e['filename'].toString()).toSet();

      return filenames;
    } catch (e) {
      logger.i('Could not get uploaded filnames: $e');
      return {};
    }
  }
  */

  @Deprecated("Use either getallMySharedPhotos or getSharedPhotos instead.")
  Future<Set<String>> getIdsOfUploadedPhotos(
    String userId, {
    String? groupId,
  }) async {
    try {
      if (userId.isEmpty) return {};
      final gid =
          groupId?.trim().isNotEmpty == true
              ? groupId ?? ""
              : (await _groupService.getDefaultGroup(userId))?.id ?? "";

      final response = await _client
          .from(metadatatable)
          .select('captured_at, userid')
          .eq('groupid', gid);

      final ids =
          (response as List).map((e) {
            final ts = DateTime.parse(e['captured_at']);
            final user = e['userid'];
            return "$user/${DateTimeUtils.filenameFormat(ts)}";
          }).toSet();

      return ids;
    } catch (e) {
      logger.i('Could not get uploaded photo IDs: $e');
      return {};
    }
  }

  /* dep.
  // This method gets all photos for a user in a group, which is no longer relevant.
  Future<List<RemotePhoto>> getMyPhotos(String userId, String groupId) async {
    if (userId.isEmpty || groupId.isEmpty) return [];

    final response = await _client
        .from(metadatatable)
        .select('filename, captured_at, latitude, longitude')
        .eq('userid', userId)
        .eq('groupid', groupId)
        .order('created_at', ascending: false);

    return (response as List).map((data) {
      final filename = data['filename'] as String;
      final timestamp = data['captured_at'] as String;

      //TODO: This is a placeholder.
      final path = "$groupId/$userId/thumbnails/$filename";

      //final fileUrl = toUrl(groupId, userId, filename, original: true);
      //final thumbnailUrl = toUrl(groupId, userId, filename);

      return CapturedPhoto(
        path: path,
        timestamp: DateTime.tryParse(timestamp),
        lat: data['latitude'] as double?,
        lon: data['longitude'] as double?,
      );
    }).toList();
  }
  */

  // Get URLs that authenticated users can use to load images.
  Future<RemotePhoto> toRemotePhoto(PhotoMetadata obj) async {
    final basePath = "${obj.groupid}/${obj.userid}";
    final fullPath = "$basePath/$sizeFull/${obj.filename}";
    final miniPath = "$basePath/$sizeMini/${obj.filename}";

    try {
      // Full image SHOULD exist
      final fullUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(fullPath, signedUrlTimeout);

      String? miniUrl;

      try {
        // Thumbnail may or may not exist.
        miniUrl = await _client.storage
            .from(bucket)
            .createSignedUrl(miniPath, signedUrlTimeout);
      } on StorageException catch (e) {
        if (e.statusCode == '404') {
          logger.i("Thumbnail missing (expected): $miniPath");
          miniUrl = ""; // perfectly fine
        } else {
          rethrow;
        }
      }

      return RemotePhoto(
        userid: obj.userid,
        capturedAt: obj.capturedAt,
        fullUrl: fullUrl,
        miniUrl: miniUrl,
        latitude: obj.latitude,
        longitude: obj.longitude,
      );
    } catch (e, st) {
      logger.e(
        'Failed resolving full image (NOT expected): $fullPath',
        error: e,
        stackTrace: st,
      );
      rethrow; // this one SHOULD fail
    }
  }

  /// Fetches all photos shared to one specific group, uploaded by any user.
  Future<List<Photo>> getSharedPhotos(String userId, {String? groupId}) async {
    if (userId.isEmpty) return [];

    final resolvedGroupId =
        groupId ?? (await _groupService.getDefaultGroup(userId))?.id;
    if (resolvedGroupId == null) return [];

    logger.i(
      "Querying shared photos for group $resolvedGroupId.",
    );

    final response = await _client
        .from(metadatatable)
        .select('groupid, userid, filename, captured_at, latitude, longitude')
        .eq('groupid', resolvedGroupId)
        .order('captured_at', ascending: false);

    final items =
        (response as List).map((item) => PhotoMetadata.fromJson(item)).toList();

    // Resolve all URLs in parallel and construct Photo objects
    final photos = await Future.wait(items.map((item) => toRemotePhoto(item)));
    return photos;
  }

  /// Fetches all photos from one user uploaded/shared to any group.
  Future<List<Photo>> getAllMySharedPhotos(String userId) async {
    if (userId.isEmpty) return [];

    logger.i(
      "Querying all shared photos for user $userId.",
    );

    final response = await _client
        .from(metadatatable)
        .select('groupid, userid, filename, captured_at, latitude, longitude')
        .eq('userid', userId)
        .order('captured_at', ascending: false);

    final items =
        (response as List).map((item) => PhotoMetadata.fromJson(item)).toList();

    // Resolve all URLs in parallel and construct Photo objects
    final photos = await Future.wait(items.map((item) => toRemotePhoto(item)));
    return photos;
  }

}
