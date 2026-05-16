import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

const bool supportsLocalFaceDetection = true;

Future<int> detectFaceCount(XFile image) async {
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
    return faces.length;
  } finally {
    await detector.close();
  }
}
