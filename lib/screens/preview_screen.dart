import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/filter_model.dart';
import '../painters/face_filter_painter.dart';
import '../services/face_detector_service.dart';
import '../widgets/filter_carousel.dart';

class PreviewScreen extends StatefulWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final FaceDetectorService _faceDetector = FaceDetectorService();
  final GlobalKey _repaintKey = GlobalKey();
  List<Face> _faces = [];
  bool _isDetecting = true;
  bool _isSaving = false;
  ui.Image? _uiImage;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageAndDetect();
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _loadImageAndDetect() async {
    try {
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      setState(() {
        _uiImage = img;
        _imageSize = Size(img.width.toDouble(), img.height.toDouble());
      });

      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final faces = await _faceDetector.detectFaces(inputImage);

      if (mounted) {
        setState(() {
          _faces = faces;
          _isDetecting = false;
        });
      }
    } catch (e) {
      debugPrint('Detection error: $e');
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureWidget();
      if (bytes == null) throw Exception('Failed to capture widget');
      await Gal.putImageBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to gallery!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _share() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureWidget();
      if (bytes == null) throw Exception('Failed to capture widget');
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/face_filter_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out my face filter! 🎭',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List?> _captureWidget() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          if (!_isDetecting)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              onPressed: _saveToGallery,
              tooltip: 'Save to Gallery',
            ),
          if (!_isDetecting)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _share,
              tooltip: 'Share',
            ),
        ],
      ),
      body: Column(
        children: [
          // Image + filter overlay (captured area)
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background
                  const ColoredBox(color: Colors.black),
                  // Image
                  if (_uiImage != null)
                    Builder(
                      builder: (context) {
                        final photoFilter =
                            context.watch<FilterModel>().photoFilter;
                        final colorFilter =
                            FilterModel.colorFilterFor(photoFilter);
                        final img = Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                        );
                        if (colorFilter != null) {
                          return ColorFiltered(
                              colorFilter: colorFilter, child: img);
                        }
                        return img;
                      },
                    ),
                  // Filter overlay
                  if (!_isDetecting && _faces.isNotEmpty && _imageSize != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final filterType =
                            context.watch<FilterModel>().selectedFilter;
                        return CustomPaint(
                          size: Size(
                              constraints.maxWidth, constraints.maxHeight),
                          painter: ImageFaceFilterPainter(
                            faces: _faces,
                            imageSize: _imageSize!,
                            filterType: filterType,
                          ),
                        );
                      },
                    ),
                  // Loading indicator
                  if (_isDetecting)
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Detecting faces...',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // No face warning
          if (!_isDetecting && _faces.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.withOpacity(0.2),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No faces detected. Filters will not appear.',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Filter carousel
          const FilterCarousel(),

          // Save / Share action bar
          if (!_isDetecting)
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.download_rounded,
                        label: 'Save',
                        color: const Color(0xFF6C63FF),
                        onTap: _saveToGallery,
                        isLoading: _isSaving,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        color: const Color(0xFF00BFA5),
                        onTap: _share,
                        isLoading: _isSaving,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else
              Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
