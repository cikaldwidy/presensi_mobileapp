import 'package:flutter/material.dart';

class FaceAttendancePayload {
  const FaceAttendancePayload({
    required this.embedding,
    required this.timestamp,
  });

  final List<double> embedding;
  final DateTime timestamp;
}

class AutoFaceAttendanceView extends StatelessWidget {
  const AutoFaceAttendanceView({
    super.key,
    required this.enabled,
    required this.isSubmitting,
    required this.onFaceReady,
    this.externalMessage,
  });

  final bool enabled;
  final bool isSubmitting;
  final String? externalMessage;
  final ValueChanged<FaceAttendancePayload> onFaceReady;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Absensi wajah otomatis hanya tersedia di aplikasi mobile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
