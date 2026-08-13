import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photocollectionapp/models/photo_abstract.dart';
import 'package:photocollectionapp/models/photo_resolution.dart';

class LocalPhoto extends Photo {
  final String fullPath;  // Full resolution image.
  final String miniPath;  // Thumbnail version.

  LocalPhoto({
    required super.userid,
    required super.capturedAt,
    required this.fullPath,
    required this.miniPath,
  });


  @override
  ImageProvider getMini() {
    return FileImage(File(miniPath));
  }

  @override
  ImageProvider getFull() {
    return FileImage(File(fullPath));
  }

  @override
  Future<Uint8List> loadBytes(PhotoResolution value) {
    final path = value == PhotoResolution.mini ? miniPath : fullPath;
    return File(path).readAsBytes();
  }
}
