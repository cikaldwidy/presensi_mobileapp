import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

const bool supportsLocalFaceDetection = true;
const bool supportsBlinkDetection = true;

class FaceLivenessResult {
  const FaceLivenessResult({
    required this.faceCount,
    required this.blinkDetected,
    this.message,
  });

  final int faceCount;
  final bool blinkDetected;
  final String? message;
}

Future<int> detectFaceCount(XFile image) async {
  final result = await detectFaceLiveness(image);
  return result.faceCount;
}

Future<FaceLivenessResult> detectFaceLiveness(XFile image) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  try {
    final faces = await detector.processImage(
      InputImage.fromFilePath(image.path),
    );
    if (faces.isEmpty) {
      return const FaceLivenessResult(
        faceCount: 0,
        blinkDetected: false,
        message: 'Wajah tidak terdeteksi.',
      );
    }

    final face = faces.first;
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) {
      return FaceLivenessResult(
        faceCount: faces.length,
        blinkDetected: false,
        message: 'Probabilitas mata belum terbaca. Ambil foto lebih dekat.',
      );
    }

    final averageEyeOpen = (leftEye + rightEye) / 2;
    final blinkDetected =
        (leftEye < 0.35 && rightEye < 0.35) || averageEyeOpen < 0.32;

    return FaceLivenessResult(
      faceCount: faces.length,
      blinkDetected: blinkDetected,
      message: blinkDetected
          ? 'Kedipan terverifikasi.'
          : 'Kedipan belum terdeteksi. Kedipkan mata saat mengambil sampel pertama.',
    );
  } finally {
    await detector.close();
  }
}
