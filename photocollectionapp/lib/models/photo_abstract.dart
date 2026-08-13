import 'dart:typed_data';
import 'package:meta/meta.dart'; //required for @nonVirtual
import 'package:flutter/material.dart';
import 'package:photocollectionapp/models/photo_resolution.dart';
import '../utils/datetime_utils.dart';

abstract class Photo {
  // The user id + timestamp of capture will uniquely identify any photo.
  final String userid;
  final DateTime capturedAt;

  Photo({required this.userid, required this.capturedAt});

  // Globally uniquely identifies a photo.
  @nonVirtual //This method must NOT be overridden
  late final String id = getPhotoId(userid, capturedAt);

  // Single source of truth for generating photo ids. Do not duplicate this code. 
  static String getPhotoId(String userid, DateTime capturedAt) {
    return "$userid/${DateTimeUtils.filenameFormat(capturedAt)}";
  }

  @nonVirtual //This method must NOT be overridden
  late final String title =
    DateTimeUtils.filenameFormat(capturedAt);

  @override @nonVirtual
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Photo && other.id == id;

  @override @nonVirtual
  int get hashCode => id.hashCode;

  // Prefer using the image providers because Flutter already
  //downloads, caches (in memory), decodes, so prefer these over loadBytes.
  ImageProvider getMini();
  ImageProvider getFull();

  // Only call this when you need raw data, image processing or manual caching.
  Future<Uint8List> loadBytes(PhotoResolution resolution);
}
