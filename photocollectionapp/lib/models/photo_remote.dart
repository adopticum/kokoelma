import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photocollectionapp/models/photo_abstract.dart';
import 'package:photocollectionapp/models/photo_resolution.dart';
import 'package:http/http.dart' as http;

class RemotePhoto extends Photo {
  /// Contract:
  /// - Full image MUST exist (error if missing)
  /// - Thumbnail MAY exist but optionel (value = "" not null).
  
  final String fullUrl;  // Full resolution image.
  final String miniUrl;  // Thumbnail version.
  final double? latitude;
  final double? longitude;

  RemotePhoto({
    required super.userid,
    required super.capturedAt,
    required this.fullUrl,
    required this.miniUrl,
    this.latitude,
    this.longitude,
  });

  // Flutter already downloads, caches (in memory), decodes, so  prefer NetworkImage over loadBytes.
  @override
  ImageProvider getMini() {
    return NetworkImage(miniUrl);
  }

  @override
  ImageProvider getFull() {
    return NetworkImage(fullUrl);
  }

  @override
  Future<Uint8List> loadBytes(PhotoResolution value) async {
    // Only call this when you need raw data, image processing or manual caching.
    // Flutter already downloads, caches (in memory), decodes, so  prefer NetworkImage over loadBytes.
    final url = value == PhotoResolution.mini ? miniUrl : fullUrl;
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to load remote image: ${response.statusCode}');
    }

    return response.bodyBytes;
  }
}
