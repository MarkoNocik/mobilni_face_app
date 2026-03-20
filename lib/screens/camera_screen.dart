import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/filter_model.dart';
import '../painters/face_filter_painter.dart';
import '../services/face_detector_service.dart';
import '../widgets/filter_carousel.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 1; // default front camera
  final FaceDetectorService _faceDetector = FaceDetectorService();
  List<Face> _faces = [];
  bool _isDetecting = false;
  bool _isInitialized = false;
  bool _isCapturing = false;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  // Device orientation for rotation compensation
  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer until first frame so the Activity is fully resumed/foreground
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCameras());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.stopImageStream().catchError((_) {});
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty) {
        _initCamera(_cameras[_selectedCameraIndex]);
      } else {
        _initCameras();
      }
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      // Prefer front camera
      _selectedCameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front);
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;
      await _initCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    setState(() => _isInitialized = false);
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
      _rotation = _getRotation(camera);
      if (!mounted) return;
      controller.startImageStream(_processCameraImage);
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera initialize error: $e');
    }
  }

  InputImageRotation _getRotation(CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }
    // Android: compensate for device orientation
    final deviceOrientation =
        WidgetsBinding.instance.platformDispatcher.implicitView?.physicalSize !=
                null
            ? DeviceOrientation.portraitUp
            : DeviceOrientation.portraitUp;
    var rotationCompensation =
        _orientations[deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  void _processCameraImage(CameraImage image) {
    if (_isDetecting) return;
    _isDetecting = true;
    _detectFaces(image).then((_) => _isDetecting = false);
  }

  Future<void> _detectFaces(CameraImage image) async {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return;
    if (image.planes.isEmpty) return;

    final plane = image.planes.first;
    final inputImage = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );

    final faces = await _faceDetector.detectFaces(inputImage);
    if (mounted) {
      setState(() => _faces = faces);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _controller?.stopImageStream();
    await _controller?.dispose();
    _faces = [];
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(_cameras[_selectedCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isCapturing = true);
    try {
      _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(imagePath: xFile.path),
        ),
      );
      // Resume stream after returning
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(imagePath: xFile.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            if (_isInitialized && _controller != null)
              _buildCameraPreview()
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Face filter overlay
            if (_isInitialized && _controller != null)
              _buildFaceOverlay(),

            // Top controls
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildTopBar(),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FilterCarousel(),
                  _buildBottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final photoFilter = context.watch<FilterModel>().photoFilter;
        final colorFilter = FilterModel.colorFilterFor(photoFilter);
        Widget preview = ClipRect(
          child: OverflowBox(
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
            child: CameraPreview(_controller!),
          ),
        );
        if (colorFilter != null) {
          preview = ColorFiltered(colorFilter: colorFilter, child: preview);
        }
        return preview;
      },
    );
  }

  Widget _buildFaceOverlay() {
    final filterType =
        context.watch<FilterModel>().selectedFilter;
    if (filterType == FilterType.none || _faces.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: FaceFilterPainter(
            faces: _faces,
            imageSize: Size(
              _controller!.value.previewSize!.height,
              _controller!.value.previewSize!.width,
            ),
            rotation: _rotation,
            cameraLensDirection:
                _cameras[_selectedCameraIndex].lensDirection,
            filterType: filterType,
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Face Filters',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
        if (_cameras.length > 1)
          _iconButton(
            Icons.flip_camera_ios,
            _switchCamera,
            tooltip: 'Switch Camera',
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          _iconButton(
            Icons.photo_library_outlined,
            _pickFromGallery,
            tooltip: 'Pick from Gallery',
            size: 32,
          ),
          // Capture button
          GestureDetector(
            onTap: _capturePhoto,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isCapturing ? 68 : 74,
              height: _isCapturing ? 68 : 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: Colors.white70,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.black, size: 36),
            ),
          ),
          // Placeholder for symmetry
          const SizedBox(width: 32, height: 32),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap,
      {String? tooltip, double size = 28}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
