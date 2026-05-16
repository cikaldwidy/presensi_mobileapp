import 'package:image_picker/image_picker.dart';

const bool supportsLocalFaceDetection = false;
const bool supportsBlinkDetection = false;

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

Future<int> detectFaceCount(XFile image) async => 1;

Future<FaceLivenessResult> detectFaceLiveness(XFile image) async {
  return const FaceLivenessResult(
    faceCount: 1,
    blinkDetected: false,
    message:
        'Deteksi kedipan otomatis belum tersedia di mode web. Gunakan aplikasi mobile untuk validasi kedipan sungguhan.',
  );
}
