import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraScreen extends StatefulWidget {
  const FaceCameraScreen({super.key});

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _isInitializing = true;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    await _controller?.dispose();
    _controller = null;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _error = 'Kamera tidak tersedia di perangkat ini.';
        });
        return;
      }

      final orderedCameras = [
        ...cameras.where(
          (item) => item.lensDirection == CameraLensDirection.front,
        ),
        ...cameras.where(
          (item) => item.lensDirection != CameraLensDirection.front,
        ),
      ];

      Object? lastError;
      for (final camera in orderedCameras) {
        for (final preset in [ResolutionPreset.medium, ResolutionPreset.low]) {
          final controller = CameraController(
            camera,
            preset,
            enableAudio: false,
          );

          try {
            await controller.initialize();
            if (!mounted) {
              await controller.dispose();
              return;
            }

            setState(() {
              _controller = controller;
              _isInitializing = false;
            });
            return;
          } catch (error) {
            lastError = error;
            await controller.dispose();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _error = _cameraErrorMessage(lastError);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _error = _cameraErrorMessage(error);
      });
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(image);
    } catch (error) {
      setState(() => _error = 'Foto gagal diambil: $error');
    } finally {
      if (mounted) {
        setState(() => _isTakingPicture = false);
      }
    }
  }

  String _cameraErrorMessage(Object? error) {
    if (error is CameraException) {
      switch (error.code) {
        case 'cameraAccessDenied':
        case 'CameraAccessDenied':
          return 'Izin kamera ditolak. Izinkan kamera di Chrome, lalu coba lagi.';
        case 'cameraNotReadable':
        case 'CameraNotReadable':
          return 'Kamera terdeteksi, tapi belum bisa dibaca. Tutup aplikasi lain yang memakai kamera, cek izin kamera Windows/Chrome, lalu coba lagi.';
      }
    }

    return 'Kamera gagal dibuka. Pastikan kamera tidak sedang dipakai aplikasi lain dan izin kamera sudah aktif.';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ambil Foto Wajah'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _initCamera,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : _isInitializing ||
                    controller == null ||
                    !controller.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.previewSize!.height,
                            height: controller.value.previewSize!.width,
                            child: CameraPreview(controller),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 28,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Posisikan wajah di tengah kamera',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FloatingActionButton.large(
                              onPressed: _isTakingPicture ? null : _takePicture,
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF07896F),
                              child: _isTakingPicture
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.camera_alt_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
