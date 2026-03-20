import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  FaceDetector? _faceDetector;
  bool _isProcessing = false;

  FaceDetector get _detector {
    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    return _faceDetector!;
  }

  bool get isProcessing => _isProcessing;

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (_isProcessing) return [];
    _isProcessing = true;
    try {
      return await _detector.processImage(inputImage);
    } catch (e) {
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> close() async {
    await _faceDetector?.close();
    _faceDetector = null;
  }
}
