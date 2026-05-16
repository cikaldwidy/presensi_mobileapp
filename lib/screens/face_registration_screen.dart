import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/face_detection_service.dart';
import 'face_camera_screen.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({
    super.key,
    required this.authService,
    required this.onFinished,
  });

  final AuthService authService;
  final VoidCallback onFinished;

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  static const _requiredSamples = 3;

  final List<XFile> _samples = [];
  bool _isCapturing = false;
  bool _isSaving = false;
  bool _isSuccess = false;
  bool _blinkVerified = false;
  String _message =
      'Kedipkan mata saat sampel pertama diambil untuk verifikasi liveness.';

  double get _progress => _samples.length / _requiredSamples;

  Future<void> _captureSample() async {
    if (_samples.length >= _requiredSamples || _isCapturing || _isSaving) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _message = 'Membuka kamera...';
    });

    try {
      final photo = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => const FaceCameraScreen()),
      );

      if (photo == null) {
        setState(() => _message = 'Pengambilan sampel dibatalkan.');
        return;
      }

      final liveness = await detectFaceLiveness(photo);
      if (liveness.faceCount < 1) {
        setState(() {
          _message =
              'Wajah tidak terdeteksi. Ulangi foto dengan wajah terlihat jelas.';
        });
        return;
      }

      if (!_blinkVerified &&
          supportsBlinkDetection &&
          !liveness.blinkDetected) {
        setState(() {
          _message = liveness.message ??
              'Kedipan belum terdeteksi. Kedipkan mata saat mengambil sampel pertama.';
        });
        return;
      }

      if (!_blinkVerified && !supportsBlinkDetection) {
        setState(() {
          _message = liveness.message ??
              'Deteksi kedipan otomatis belum tersedia di mode ini.';
        });
        return;
      }

      setState(() {
        _blinkVerified = _blinkVerified || liveness.blinkDetected;
        _samples.add(photo);
        _message = _samples.length >= _requiredSamples
            ? 'Semua sampel lengkap. Menyimpan data wajah...'
            : _blinkVerified && _samples.length == 1
                ? 'Kedipan terverifikasi. Ambil sampel wajah berikutnya.'
                : 'Sampel ${_samples.length} tersimpan. Ambil sampel berikutnya.';
      });

      if (_samples.length >= _requiredSamples) {
        await _submit();
      }
    } catch (error) {
      setState(() => _message = 'Kamera/validasi wajah gagal: $error');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_samples.length < _requiredSamples || _isSaving) return;

    setState(() {
      _isSaving = true;
      _message = 'Menyimpan pendaftaran wajah...';
    });

    try {
      final images = <String>[];
      for (final sample in _samples) {
        images.add(await _imageToDataUri(sample));
      }

      final response = await widget.authService.enrollFace(
        images: images,
        blinkVerified: _blinkVerified,
      );
      if (!mounted) return;

      setState(() {
        _isSuccess = true;
        _message =
            response['message'] as String? ?? 'Pendaftaran wajah berhasil.';
      });
    } on ApiException catch (error) {
      setState(() => _message = error.message);
    } catch (error) {
      setState(() => _message = 'Pendaftaran wajah gagal: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String> _imageToDataUri(XFile image) async {
    final bytes = await image.readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();
    final mime = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  void _resetSamples() {
    if (_isSaving) return;

    setState(() {
      _samples.clear();
      _isSuccess = false;
      _blinkVerified = false;
      _message =
          'Kedipkan mata saat sampel pertama diambil untuk verifikasi liveness.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      appBar: AppBar(
        title: const Text('Pendaftaran Wajah'),
        backgroundColor: const Color(0xFFF1F3F7),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                _RegistrationStepper(currentStep: _isSuccess ? 4 : 2),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isSuccess
                      ? _SuccessPanel(
                          message: _message,
                          onContinue: widget.onFinished,
                        )
                      : Column(
                          key: const ValueKey('form'),
                          children: [
                            const _GuidePanel(),
                            const SizedBox(height: 16),
                            _CameraPanel(
                              samples: _samples,
                              isCapturing: _isCapturing,
                              isSaving: _isSaving,
                              blinkVerified: _blinkVerified,
                              message: _message,
                              onCapture: _captureSample,
                              onReset: _resetSamples,
                            ),
                            const SizedBox(height: 18),
                            _ProgressPanel(
                              count: _samples.length,
                              total: _requiredSamples,
                              progress: _progress,
                              blinkVerified: _blinkVerified,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationStepper extends StatelessWidget {
  const _RegistrationStepper({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('1', 'LOGIN'),
      ('2', 'PENDAFTARAN WAJAH'),
      ('3', 'VERIFIKASI'),
      ('4', 'BERHASIL'),
    ];

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          left: 28,
          right: 28,
          top: 17,
          child: Container(height: 2, color: const Color(0xFFD8DEE8)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            final step = index + 1;
            final active = step <= currentStep;
            final item = items[index];

            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFD7DDE6),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF8B95A6),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.$2,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF9AA3B5),
                      fontSize: 9,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 680;

          const illustration = _RegistrationIllustration();
          const content = _GuideContent();

          if (isWide) {
            return const Row(
              children: [
                SizedBox(width: 240, child: illustration),
                SizedBox(width: 24),
                Expanded(child: content),
              ],
            );
          }

          return const Column(
            children: [
              _RegistrationIllustration(),
              SizedBox(height: 20),
              _GuideContent(),
            ],
          );
        },
      ),
    );
  }
}

class _GuideContent extends StatelessWidget {
  const _GuideContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PANDUAN PENDAFTARAN WAJAH',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        SizedBox(height: 16),
        _GuideItem(
          icon: Icons.sentiment_satisfied_alt_rounded,
          text:
              'Kedipkan mata saat sampel pertama diambil untuk verifikasi liveness.',
        ),
        SizedBox(height: 12),
        _GuideItem(
          icon: Icons.lightbulb_outline_rounded,
          text:
              'Gunakan pencahayaan cukup agar sistem dapat membaca wajah dengan stabil.',
        ),
        SizedBox(height: 12),
        _GuideItem(
          icon: Icons.sync_rounded,
          text:
              'Setelah kedipan lolos, ambil 2 sampel tambahan dengan wajah tetap jelas.',
        ),
      ],
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5ECF8)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF5FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF687386),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.samples,
    required this.isCapturing,
    required this.isSaving,
    required this.blinkVerified,
    required this.message,
    required this.onCapture,
    required this.onReset,
  });

  final List<XFile> samples;
  final bool isCapturing;
  final bool isSaving;
  final bool blinkVerified;
  final String message;
  final VoidCallback onCapture;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final hasSamples = samples.isNotEmpty;
    final isComplete = samples.length >= 3;
    final disabled = isCapturing || isSaving || isComplete;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;

              const title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AREA KAMERA',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ambil sampel pertama sambil berkedip. Sampel tidak dihitung sebelum kedipan valid.',
                    style: TextStyle(
                      color: Color(0xFF7B8497),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );

              final actions = _CameraActions(
                isActive: hasSamples || isCapturing || isSaving,
                isCapturing: isCapturing,
                isSaving: isSaving,
                blinkVerified: blinkVerified,
                disabled: disabled,
                onCapture: onCapture,
                onReset: onReset,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: title),
                    const SizedBox(width: 18),
                    SizedBox(width: 280, child: actions),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 14),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            height: 310,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFFD7E6FF)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasSamples)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _SamplePreview(image: samples.last),
                  ),
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6EA0FF),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 46,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!hasSamples)
                  const Center(
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Color(0xFFE1E7F2),
                      size: 74,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8B95A6),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraActions extends StatelessWidget {
  const _CameraActions({
    required this.isActive,
    required this.isCapturing,
    required this.isSaving,
    required this.blinkVerified,
    required this.disabled,
    required this.onCapture,
    required this.onReset,
  });

  final bool isActive;
  final bool isCapturing;
  final bool isSaving;
  final bool blinkVerified;
  final bool disabled;
  final VoidCallback onCapture;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isActive ? const Color(0xFFE9F8EF) : const Color(0xFFF1F3F7),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFB9E4C7)
                    : const Color(0xFFE0E5EE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  blinkVerified
                      ? Icons.visibility_rounded
                      : isActive
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                  color: isActive
                      ? const Color(0xFF16834E)
                      : const Color(0xFF7B8497),
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  isActive ? 'Kamera aktif' : 'Kamera mati',
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF16834E)
                        : const Color(0xFF7B8497),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: disabled ? null : onCapture,
            icon: isCapturing || isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.camera_alt_rounded, size: 17),
            label: Text(
              isSaving
                  ? 'MENYIMPAN...'
                  : blinkVerified
                      ? 'AMBIL SAMPEL'
                      : 'KEDIP & AMBIL',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: isSaving ? null : onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFF4B4B4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            child: const Text('RESET'),
          ),
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.count,
    required this.total,
    required this.progress,
    required this.blinkVerified,
  });

  final int count;
  final int total;
  final double progress;
  final bool blinkVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Wajah Disimpan',
                  style: TextStyle(
                    color: Color(0xFF4B5565),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$count / $total',
                style: const TextStyle(
                  color: Color(0xFF4B5565),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              color: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFFDCEAFF),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              !blinkVerified
                  ? 'Langkah 1: Kedipkan mata saat mengambil sampel pertama.'
                  : count >= total
                      ? 'Semua langkah selesai. Menyimpan data wajah...'
                      : 'Langkah ${count + 1}: Ambil sampel wajah.',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.message,
    required this.onContinue,
  });

  final String message;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('success'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: Color(0xFFE9F8EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF16834E),
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Pendaftaran Berhasil',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF253246),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7B8497),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('LANJUT KE DASHBOARD'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SamplePreview extends StatelessWidget {
  const _SamplePreview({required this.image});

  final XFile image;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}

class _RegistrationIllustration extends StatelessWidget {
  const _RegistrationIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8FA),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFB7CFDA), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDFF7F7), Color(0xFFFFF7D7)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 48,
            child: Container(
              width: 72,
              height: 122,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7FB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF31546A), width: 4),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_retouching_natural, color: Color(0xFF2563EB)),
                  SizedBox(height: 14),
                  Icon(Icons.fingerprint_rounded, color: Color(0xFF16834E)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 24,
            child: Container(
              width: 78,
              height: 112,
              decoration: const BoxDecoration(
                color: Color(0xFF2B7BAA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFFFC69F),
                    child: Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: Color(0xFF6A3B2D),
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 88,
            bottom: 70,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                width: 70,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF31546A), width: 3),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: Color(0xFF2B7BAA),
                  size: 25,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 50,
            bottom: 58,
            child: Icon(
              Icons.local_hospital_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: const Color(0xFFDDE7F8)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
