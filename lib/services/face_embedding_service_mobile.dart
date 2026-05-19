import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceEmbeddingService {
  const FaceEmbeddingService();

  Future<List<double>> createEmbedding({
    required CameraImage image,
    required Face face,
  }) async {
    // Replace this deterministic fallback with a TFLite FaceNet/MobileFaceNet
    // interpreter when the model asset is added to the project.
    final signature = _buildFrameSignature(image, face);
    final values = List<double>.filled(128, 0);

    for (var i = 0; i < values.length; i++) {
      final source = signature[i % signature.length];
      final mixed = (source + (i * 37) + signature[(i * 7) % signature.length]);
      values[i] = double.parse(((mixed % 256) / 255).toStringAsFixed(6));
    }

    return values;
  }

  Uint8List _buildFrameSignature(CameraImage image, Face face) {
    final signature = Uint8List(256);
    var offset = 0;

    void addNumber(num value) {
      final scaled = (value * 1000).round();
      signature[offset++ % signature.length] = scaled & 0xff;
      signature[offset++ % signature.length] = (scaled >> 8) & 0xff;
    }

    addNumber(image.width);
    addNumber(image.height);
    addNumber(face.boundingBox.left);
    addNumber(face.boundingBox.top);
    addNumber(face.boundingBox.width);
    addNumber(face.boundingBox.height);
    addNumber(face.headEulerAngleX ?? 0);
    addNumber(face.headEulerAngleY ?? 0);
    addNumber(face.headEulerAngleZ ?? 0);

    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) {
      return signature;
    }

    final step = (bytes.length / 220).floor().clamp(1, bytes.length);
    for (var index = 0;
        index < bytes.length && offset < signature.length;
        index += step) {
      signature[offset++] = bytes[index];
    }

    return signature;
  }
}
