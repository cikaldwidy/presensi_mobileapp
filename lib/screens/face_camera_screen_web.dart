// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FaceCameraScreen extends StatefulWidget {
  const FaceCameraScreen({super.key});

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen> {
  late final String _viewType;
  late final html.VideoElement _video;
  html.MediaStream? _stream;
  String? _error;
  bool _isInitializing = true;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'face-camera-${DateTime.now().microsecondsSinceEpoch}';
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.setProperty('object-fit', 'cover')
      ..style.backgroundColor = '#000';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );

    _initCamera();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });
    _stopStream();

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        setState(() {
          _isInitializing = false;
          _error = 'Browser ini tidak mendukung akses kamera langsung.';
        });
        return;
      }

      html.MediaStream? stream;
      Object? lastError;
      final constraints = [
        {
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
        },
        {
          'audio': false,
          'video': {
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
        },
        {'audio': false, 'video': true},
      ];

      for (final constraint in constraints) {
        try {
          stream = await mediaDevices.getUserMedia(constraint);
          break;
        } catch (error) {
          lastError = error;
        }
      }

      if (stream == null) {
        throw lastError ?? StateError('Kamera tidak bisa dibuka.');
      }

      _stream = stream;
      _video.srcObject = stream;
      await _video.play();
      await _waitUntilReadable();

      if (!mounted) return;
      setState(() => _isInitializing = false);
    } catch (error) {
      if (!mounted) return;
      _stopStream();
      setState(() {
        _isInitializing = false;
        _error = _cameraErrorMessage(error);
      });
    }
  }

  Future<void> _waitUntilReadable() async {
    if (_video.videoWidth > 0 && _video.videoHeight > 0) {
      return;
    }

    await _video.onLoadedMetadata.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Camera metadata timeout'),
    );
  }

  Future<void> _takePicture() async {
    if (_video.videoWidth == 0 || _video.videoHeight == 0) {
      setState(() {
        _error = 'Preview kamera belum siap. Coba lagi beberapa detik lagi.';
      });
      return;
    }

    setState(() => _isTakingPicture = true);
    try {
      final canvas = html.CanvasElement(
        width: _video.videoWidth,
        height: _video.videoHeight,
      );
      canvas.context2D.drawImageScaled(
        _video,
        0,
        0,
        _video.videoWidth,
        _video.videoHeight,
      );

      final blob = await canvas.toBlob('image/jpeg', 0.9);
      final bytes = await _blobToBytes(blob);
      final image = XFile.fromData(
        bytes,
        mimeType: 'image/jpeg',
        name: 'face-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

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

  Future<Uint8List> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;

    final result = reader.result;
    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }
    if (result is Uint8List) {
      return result;
    }

    throw StateError('Foto kamera gagal dibaca.');
  }

  void _stopStream() {
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _video.srcObject = null;
  }

  String _cameraErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('NotAllowedError') ||
        text.contains('PermissionDeniedError')) {
      return 'Izin kamera ditolak. Izinkan kamera di Chrome, lalu coba lagi.';
    }
    if (text.contains('NotReadableError')) {
      return 'Kamera terdeteksi, tapi belum bisa dibaca. Tutup aplikasi lain yang memakai kamera, cek izin kamera Windows/Chrome, lalu coba lagi.';
    }
    if (text.contains('NotFoundError') || text.contains('DevicesNotFound')) {
      return 'Kamera tidak ditemukan di perangkat ini.';
    }

    return 'Kamera gagal dibuka. Pastikan kamera tidak sedang dipakai aplikasi lain dan izin kamera sudah aktif.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ambil Foto Wajah'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _error != null
            ? _CameraErrorView(
                message: _error!,
                onRetry: _initCamera,
              )
            : _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(
                        child: HtmlElementView(viewType: _viewType),
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
              size: 44,
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
