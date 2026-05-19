import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/face_embedding_service_mobile.dart';

class FaceAttendancePayload {
  const FaceAttendancePayload({
    required this.embedding,
    required this.timestamp,
  });

  final List<double> embedding;
  final DateTime timestamp;
}

class AutoFaceAttendanceView extends StatefulWidget {
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
  State<AutoFaceAttendanceView> createState() => _AutoFaceAttendanceViewState();
}

class _AutoFaceAttendanceViewState extends State<AutoFaceAttendanceView> {
  static const _validHoldDuration = Duration(milliseconds: 1300);
  static const _scanInterval = Duration(milliseconds: 220);
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final _embeddingService = const FaceEmbeddingService();
  late final FaceDetector _faceDetector;
  CameraController? _controller;
  CameraDescription? _camera;
  DateTime? _validSince;
  DateTime? _lastScanAt;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isCapturingFrame = false;
  String _status = 'Wajah belum terdeteksi';
  String? _error;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant AutoFaceAttendanceView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enabled && !widget.enabled) {
      _stopImageStream();
    } else if (!oldWidget.enabled && widget.enabled) {
      _startImageStream();
    }
  }

  @override
  void dispose() {
    _stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Kamera tidak tersedia di perangkat ini.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _camera = camera;
      _controller = controller;
      setState(() => _isInitializing = false);
      await _startImageStream();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _error = _cameraErrorMessage(error);
      });
    }
  }

  Future<void> _startImageStream() async {
    final controller = _controller;
    if (!widget.enabled ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream(_processCameraImage);
  }

  Future<void> _stopImageStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.stopImageStream();
    } catch (_) {
      // The camera plugin may already be stopping during route disposal.
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!mounted ||
        !widget.enabled ||
        widget.isSubmitting ||
        _isProcessingFrame ||
        _isCapturingFrame) {
      return;
    }

    final now = DateTime.now();
    final lastScanAt = _lastScanAt;
    if (lastScanAt != null && now.difference(lastScanAt) < _scanInterval) {
      return;
    }

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _setStatus('Wajah belum terdeteksi');
      return;
    }

    _lastScanAt = now;
    _isProcessingFrame = true;
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted || !widget.enabled || widget.isSubmitting) return;

      final validation = _validateFaces(faces, image);
      _setStatus(validation.message);

      if (!validation.isValid || faces.length != 1) {
        _validSince = null;
        return;
      }

      _validSince ??= now;
      if (now.difference(_validSince!) < _validHoldDuration) {
        return;
      }

      await _captureValidFrame(image, faces.first);
    } catch (error) {
      _validSince = null;
      _setStatus('Deteksi wajah gagal diproses.');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _captureValidFrame(CameraImage image, Face face) async {
    if (_isCapturingFrame) return;

    _isCapturingFrame = true;
    _setStatus('Memproses absensi...');
    try {
      final embedding = await _embeddingService.createEmbedding(
        image: image,
        face: face,
      );

      if (!mounted) return;
      widget.onFaceReady(
        FaceAttendancePayload(
          embedding: embedding,
          timestamp: DateTime.now(),
        ),
      );
      _validSince = null;
    } finally {
      _isCapturingFrame = false;
    }
  }

  _FaceValidation _validateFaces(List<Face> faces, CameraImage image) {
    if (faces.isEmpty) {
      return const _FaceValidation(false, 'Wajah belum terdeteksi');
    }

    if (faces.length != 1) {
      return const _FaceValidation(false, 'Posisikan wajah di tengah kamera');
    }

    final face = faces.first;
    final box = face.boundingBox;
    final frameWidth = image.width.toDouble();
    final frameHeight = image.height.toDouble();
    final faceCenterX = box.center.dx;
    final faceCenterY = box.center.dy;
    final frameCenterX = frameWidth / 2;
    final frameCenterY = frameHeight / 2;
    final maxOffsetX = frameWidth * 0.18;
    final maxOffsetY = frameHeight * 0.20;
    final minFaceWidth = frameWidth * 0.24;
    final minFaceHeight = frameHeight * 0.24;
    final angleX = (face.headEulerAngleX ?? 0).abs();
    final angleY = (face.headEulerAngleY ?? 0).abs();
    final angleZ = (face.headEulerAngleZ ?? 0).abs();
    final eyesReadable = face.leftEyeOpenProbability != null &&
        face.rightEyeOpenProbability != null;

    final isCentered = (faceCenterX - frameCenterX).abs() <= maxOffsetX &&
        (faceCenterY - frameCenterY).abs() <= maxOffsetY;
    final isLargeEnough =
        box.width >= minFaceWidth && box.height >= minFaceHeight;
    final isStraight = angleX <= 18 && angleY <= 18 && angleZ <= 14;
    final isInsideFrame = box.left >= 0 &&
        box.top >= 0 &&
        box.right <= frameWidth &&
        box.bottom <= frameHeight;

    if (!isCentered ||
        !isLargeEnough ||
        !isStraight ||
        !isInsideFrame ||
        !eyesReadable) {
      return const _FaceValidation(false, 'Posisikan wajah di tengah kamera');
    }

    return const _FaceValidation(true, 'Wajah valid. Tahan posisi...');
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    final rotation = _resolveImageRotation(camera, controller);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _resolveImageRotation(
    CameraDescription camera,
    CameraController controller,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    final orientation = _orientations[controller.value.deviceOrientation];
    if (orientation == null) return null;

    final rotationCompensation = camera.lensDirection == CameraLensDirection.front
        ? (sensorOrientation + orientation) % 360
        : (sensorOrientation - orientation + 360) % 360;

    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  void _setStatus(String status) {
    if (!mounted || _status == status) return;
    setState(() => _status = status);
  }

  String _cameraErrorMessage(Object error) {
    if (error is CameraException) {
      switch (error.code) {
        case 'cameraAccessDenied':
        case 'CameraAccessDenied':
          return 'Izin kamera ditolak. Aktifkan izin kamera, lalu coba lagi.';
        case 'cameraNotReadable':
        case 'CameraNotReadable':
          return 'Kamera sedang dipakai aplikasi lain atau belum bisa dibaca.';
      }
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final message = widget.externalMessage ?? _status;

    return ColoredBox(
      color: Colors.black,
      child: _error != null
          ? _CameraErrorView(message: _error!, onRetry: _initCamera)
          : _isInitializing || controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize!.height,
                        height: controller.value.previewSize!.width,
                        child: CameraPreview(controller),
                      ),
                    ),
                    const _FaceGuideOverlay(),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 36,
                      child: _StatusPanel(
                        message: message,
                        isLoading: widget.isSubmitting || _isCapturingFrame,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _FaceValidation {
  const _FaceValidation(this.isValid, this.message);

  final bool isValid;
  final String message;
}

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 230,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(150),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.86),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.message,
    required this.isLoading,
  });

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white,
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
