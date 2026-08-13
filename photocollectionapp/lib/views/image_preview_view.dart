import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photocollectionapp/models/photo_resolution.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../models/photo_abstract.dart';
import '../models/photo_local.dart';
import '../models/photo_remote.dart';
import '../services/exif_service.dart';
import '../utils/bounding_box_painter.dart';
import '../viewmodels/image_preview_viewmodel.dart';

//TODO: Progressive loading (mini → full swap).
//TODO: Pre-cache images for smooth scrolling.
//TODO: Eliminate the last FutureBuilder (micro-optimization).

class ImagePreviewView extends StatefulWidget {
  final Photo photo;
  const ImagePreviewView({super.key, required this.photo});

  @override
  State<ImagePreviewView> createState() => _ImagePreviewViewState();
}

class _ImagePreviewViewState extends State<ImagePreviewView> {
  Uint8List? _bytes; //Only used for metadata and decoding, not for viewing.
  //dep. bool _isDownloading = false;

  @override
  void initState() {
    super.initState();

    // We must guard clearResults against repeated unwanted resets and call before widget is initialized.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImagePreviewViewModel>().clearResults();
    });
  }

  /* Better practise than addPostFrameCallback:
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      context.read<ImagePreviewViewModel>().clearResults();
      _initialized = true;
    }
  }
  */

  Future<Uint8List?> _ensureBytesLoaded() async {
    if (_bytes != null) return _bytes;

    try {
      /*
      if (widget.photo.path.startsWith('http')) {
        final response = await http.get(Uri.parse(widget.photo.url!));
        if (response.statusCode == 200) {
          _cachedBytes = response.bodyBytes;
        }
      } else {
        final file = File(widget.photo.path);
        if (await file.exists()) {
          _cachedBytes = await file.readAsBytes();
        }
      }*/
      // Local or remote Photo is now abstracted.
      _bytes = await widget.photo.loadBytes(PhotoResolution.full);
      if (mounted) setState(() {});
      //widget.photo.getFull();
    } catch (e) {
      debugPrint('Error loading image bytes: $e');
    }
    return _bytes;
  }

  Future<Map<String, dynamic>> _getImageDetails() async {
    await _ensureBytesLoaded();
    if (_bytes == null) return {};

    final decoded = img.decodeImage(_bytes!);
    final gps = await _readGpsCoordinates();

    return {
      'title': widget.photo.title,
      'sizeKB': (_bytes!.length) ~/ 1024,
      'width': decoded?.width,
      'height': decoded?.height,
      'latitude': gps?['latitude'],
      'longitude': gps?['longitude'],
    };
  }

  Future<Map<String, double?>?> _readGpsCoordinates() async {
    if (widget.photo is RemotePhoto) {
      final remotePhoto = widget.photo as RemotePhoto;
      return {
        'latitude': remotePhoto.latitude,
        'longitude': remotePhoto.longitude,
      };
    }

    if (widget.photo is! LocalPhoto) return null;

    final localPhoto = widget.photo as LocalPhoto;
    final exifService = ExifService();
    final gps = await exifService.getGpsFromPhoto(localPhoto.fullPath);

    if (gps == null) return null;

    return {
      'latitude': gps['latitude'],
      'longitude': gps['longitude'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ImagePreviewViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Image Preview')),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.loading ? null : () => vm.detectFromPhoto(widget.photo),
        child:
            vm.loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.search),
      ),
      body: Stack(
        children: [
          // Layer 1: The Image (Always present in a Positioned.fill to stabilize layout)
          // Always use ImageProvider (auto caching)
          Positioned.fill(
            child: Image(
              image: widget.photo.getFull(),
              fit: BoxFit.contain,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      frame != null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                );
                //Alternative to frameBuilder:
                //loadingBuilder: (context, child, progress) {
                //  if (progress == null) return child;
                //  return const Center(child: CircularProgressIndicator());
                // },
              },
            ),
          ),

          // Layer 2: Bounding Boxes (only when detected)
          if (vm.detected)
            Positioned.fill(
              child: FutureBuilder<Uint8List?>(
                future: _ensureBytesLoaded(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final decoded = img.decodeImage(snapshot.data!);

                  return CustomPaint(
                    painter: BoundingBoxPainter(
                      vm.detectionResults.boxes.toList(),
                      vm.detectionResults.scores.toList(),
                      vm.detectionResults.classes.toList(),
                      decoded?.width.toDouble() ?? 0,
                      decoded?.height.toDouble() ?? 0,
                    ),
                  );
                },
              ),
            ),

          // Layer 3: Loading indicator overlay
          if (vm.loading)
            // Using Positioned.fill to avoid layout jumps.
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // Layer 4: Metadata overlay (only when available)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildMetadataWidget(),
          ),
        ],
      ),
    );
  }

  /* dep. 
  Widget _buildImageContent() {
    if (_cachedBytes != null) {
      return GestureDetector(
        onLongPress: () async {
          await _ensureBytesLoaded();
          if (mounted) setState(() {});
        },
        child: Image.memory(_cachedBytes!, fit: BoxFit.contain),
      );
    } else if (widget.photo.url != null) {
      return Image.network(
        widget.photo.url!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder:
            (context, error, stackTrace) =>
                const Center(child: Text('Error loading image')),
      );
    } else {
      return const Center(child: Text('Image not found'));
    }
  }
  */

  String formatCoordinatesText(double? lat, double? lon, {int decimals = 3}) {
    return (lat != null && lon != null)
      ? '📍 ${lat.toStringAsFixed(decimals)}, ${lon.toStringAsFixed(decimals)}'
      : '📍 -';
  }

  Widget _buildMetadataWidget() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getImageDetails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;

        return Container(
          color: Colors.black54,
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${data['title']}'),
                Text('${data['width']} x ${data['height']} px, ${data['sizeKB']} KB'),
                Text(formatCoordinatesText(data['latitude'] as double?, data['longitude'] as double?)),
                Text(' '), // Force empty line to push up from bottom edge.
              ],
            ),
          ),
        );
      },
    );
  }
}
