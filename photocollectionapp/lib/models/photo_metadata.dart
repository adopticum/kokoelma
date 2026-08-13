import 'package:meta/meta.dart'; //required for @nonVirtual
import '../models/photo_abstract.dart';

class PhotoMetadata {
  final String groupid;
  final String userid;
  final String filename;
  final String basename; //dep.
  final DateTime capturedAt;
  final DateTime? uploadedAt;
  final double? latitude;
  final double? longitude;

  // Resolve the URLs as a separate step.
  String? originalUrl; //Resolved URL. Depends on backend call.
  String? thumbnailUrl; //Resolved URL. Depends on backend call.

  PhotoMetadata({
    required this.groupid,
    required this.userid,
    required this.filename,
    required this.basename, //dep.
    required this.capturedAt,
    this.uploadedAt,
    this.latitude,
    this.longitude,
    this.originalUrl,
    this.thumbnailUrl,
  });

  @nonVirtual //This method must NOT be overridden
  String get photoId => Photo.getPhotoId(userid, capturedAt);

  String getPath({bool original = false}) {
    final resolution = original ? 'original' : 'thumbnail';
    final path = '$groupid/$userid/$resolution/$filename';
    return path;
  }

  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    // These are the fields in the JSON data:
    // .select('groupid, userid, filename, captured_at, latitude, longitude')
    return PhotoMetadata(
      groupid: json['groupid'],
      userid: json['userid'],
      filename: json['filename'],
      basename: '', //dep.
      capturedAt: DateTime.parse(json['captured_at'] as String),
      uploadedAt:
          ((json['uploaded_at'] == null)
              ? null
              : DateTime.parse(json['created_at'] as String)),
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  // Fill in the URLs when they are resolved.
  PhotoMetadata copyWith({String? originalUrl, String? thumbnailUrl}) {
    return PhotoMetadata(
      groupid: groupid,
      userid: userid,
      filename: filename,
      basename: basename, //dep.
      capturedAt: capturedAt,
      uploadedAt: uploadedAt,
      latitude: latitude,
      longitude: longitude,
      //
      originalUrl: originalUrl ?? this.originalUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
