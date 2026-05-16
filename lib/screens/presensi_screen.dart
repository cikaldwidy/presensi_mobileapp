import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/presensi_model.dart';
import '../services/api_service.dart';
import '../services/face_detection_service.dart';
import 'face_camera_screen.dart';

class PresensiScreen extends StatefulWidget {
  const PresensiScreen({
    super.key,
    required this.apiService,
    required this.type,
  });

  final ApiService apiService;
  final String type;

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  bool _isLoading = false;
  bool _isCapturing = false;
  Position? _position;
  XFile? _faceImage;
  int _faceCount = 0;
  String? _message;

  bool get _isMasuk => widget.type == 'masuk';

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final response = await widget.apiService.get('/user/dashboard');
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> _submit() async {
    if (_faceImage == null || _faceCount < 1) {
      setState(() {
        _message = 'Ambil foto wajah terlebih dahulu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final position = await _getLocation();
      final endpoint =
          _isMasuk ? '/user/presensi/masuk' : '/user/presensi/pulang';

      final response = await widget.apiService.post(
        endpoint,
        body: {
          'lat': position.latitude,
          'lng': position.longitude,
          'image': await _imageToDataUri(_faceImage!),
          'face_detected': true,
        },
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _message = response['message'] as String? ?? 'Presensi berhasil.';
        _dashboardFuture = _loadDashboard();
      });
    } on ApiException catch (error) {
      setState(() => _message = error.message);
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takeFacePhoto() async {
    setState(() {
      _isCapturing = true;
      _message = null;
    });

    try {
      final photo = await _openFaceCamera();

      if (photo == null) {
        return;
      }

      final faceCount = await detectFaceCount(photo);

      if (faceCount < 1) {
        setState(() {
          _faceImage = null;
          _faceCount = 0;
          _message =
              'Wajah tidak terdeteksi. Ulangi foto dengan wajah terlihat jelas.';
        });
        return;
      }

      setState(() {
        _faceImage = photo;
        _faceCount = faceCount;
        _message = supportsLocalFaceDetection
            ? 'Wajah terdeteksi. Silakan kirim presensi.'
            : 'Foto wajah dipilih. Silakan kirim presensi.';
      });
    } catch (error) {
      setState(() {
        _message = 'Kamera/validasi wajah gagal: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<XFile?> _openFaceCamera() {
    return Navigator.of(context).push<XFile>(
      MaterialPageRoute(builder: (_) => const FaceCameraScreen()),
    );
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

  Future<Position> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi belum aktif.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Buka pengaturan aplikasi.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFDFFBFA),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? <String, dynamic>{};
            final shift = data['shift'] as Map<String, dynamic>? ?? {};
            final activeShift = shift['active'] as Map<String, dynamic>?;
            final scheduledShift = shift['scheduled'] as Map<String, dynamic>?;
            final shiftData = activeShift ?? scheduledShift;
            final presensiJson = data['presensi_hari_ini'];
            final presensi = presensiJson is Map<String, dynamic>
                ? PresensiModel.fromJson(presensiJson)
                : null;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
              children: [
                _VerificationCameraCard(
                  image: _faceImage,
                  date: _formatCompactDate(now),
                  time: DateFormat('HH.mm.ss').format(now),
                  isCapturing: _isCapturing,
                  onTap: _takeFacePhoto,
                ),
                const SizedBox(height: 22),
                _MapPreview(position: _position),
                const SizedBox(height: 16),
                _ShiftNotice(shiftData: shiftData),
                const SizedBox(height: 14),
                _StatusTiles(
                  presensi: presensi,
                  shiftData: shiftData,
                ),
                const SizedBox(height: 18),
                _VerifyButton(
                  isMasuk: _isMasuk,
                  isLoading: _isLoading,
                  canSubmit: _faceImage != null && _faceCount > 0,
                  onPressed: _submit,
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  _MessagePanel(message: _message!),
                ],
                if (snapshot.connectionState == ConnectionState.waiting) ...[
                  const SizedBox(height: 14),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (snapshot.hasError) ...[
                  const SizedBox(height: 14),
                  _MessagePanel(message: snapshot.error.toString()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatCompactDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

class _VerificationCameraCard extends StatelessWidget {
  const _VerificationCameraCard({
    required this.image,
    required this.date,
    required this.time,
    required this.isCapturing,
    required this.onTap,
  });

  final XFile? image;
  final String date;
  final String time;
  final bool isCapturing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF060C1A),
      borderRadius: BorderRadius.circular(11),
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      child: InkWell(
        onTap: isCapturing ? null : onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          height: 232,
          child: Stack(
            children: [
              if (image != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _XFilePreviewImage(
                      image: image!,
                      height: 232,
                      width: double.infinity,
                    ),
                  ),
                ),
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(13),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: Color(0xFF6ADFC2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 11,
                child: _FloatingLabel(text: date),
              ),
              Positioned(
                right: 12,
                top: 11,
                child: _FloatingLabel(text: time),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    isCapturing
                        ? 'Membuka kamera verifikasi wajah...'
                        : image == null
                            ? 'Tekan Masuk/Verifikasi untuk menyalakan kamera'
                            : 'Foto wajah siap diverifikasi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 13,
                right: 13,
                bottom: 8,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Kamera verifikasi wajah',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4D5565),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.position});

  final Position? position;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: const Color(0xFF07101E),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapPainter()),
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF48B797).withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF237E6C),
                    width: 2,
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.location_on_rounded,
                color: Color(0xFF2F9BCB),
                size: 52,
              ),
            ),
            Positioned(
              right: 66,
              bottom: 20,
              child: Text(
                position == null ? 'RS Otopedi' : 'Lokasi kamu',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 2,
              child: Container(
                color: Colors.white.withValues(alpha: 0.76),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: const Text(
                  'Leaflet | (c) OpenStreetMap',
                  style: TextStyle(
                    color: Color(0xFF30445C),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftNotice extends StatelessWidget {
  const _ShiftNotice({required this.shiftData});

  final Map<String, dynamic>? shiftData;

  @override
  Widget build(BuildContext context) {
    final hasShift = shiftData != null;
    final text = hasShift
        ? 'Shift hari ini ${shiftData!['jam_masuk'] ?? '-'} - ${shiftData!['jam_pulang'] ?? '-'}.'
        : 'Shift kamu belum diatur oleh admin. Hubungi admin untuk assign jadwal shift terlebih dulu.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFFFD975)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFAA6840),
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusTiles extends StatelessWidget {
  const _StatusTiles({
    required this.presensi,
    required this.shiftData,
  });

  final PresensiModel? presensi;
  final Map<String, dynamic>? shiftData;

  @override
  Widget build(BuildContext context) {
    final hasShift = shiftData != null;
    final shiftValue = hasShift ? 'Terjadwal' : 'Belum\nDijadwalkan';

    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            icon: Icons.group_rounded,
            label: 'Shift',
            value: shiftValue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusTile(
            icon: Icons.login_rounded,
            label: 'Jam Masuk',
            value: presensi?.jamMasuk ?? '--:--',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusTile(
            icon: Icons.logout_rounded,
            label: 'Jam Pulang',
            value: presensi?.jamKeluar ?? '--:--',
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF07896F),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF045C4D).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.isMasuk,
    required this.isLoading,
    required this.canSubmit,
    required this.onPressed,
  });

  final bool isMasuk;
  final bool isLoading;
  final bool canSubmit;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isLoading || !canSubmit ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fingerprint_rounded),
        label: Text(isMasuk ? 'Verifikasi Masuk' : 'Verifikasi Pulang'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF07896F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF30445C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _XFilePreviewImage extends StatelessWidget {
  const _XFilePreviewImage({
    required this.image,
    required this.height,
    required this.width,
  });

  final XFile image;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: height,
            width: width,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Image.memory(
          snapshot.data!,
          height: height,
          width: width,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(7),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF2EEDC);
    canvas.drawRect(Offset.zero & size, background);

    final parkPaint = Paint()..color = const Color(0xFFD5F1C7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, 10, size.width * 0.23, 36),
        const Radius.circular(4),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.58, 20, size.width * 0.26, 42),
        const Radius.circular(4),
      ),
      parkPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final roadLine = Paint()
      ..color = const Color(0xFFC7BCA8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void drawRoad(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas
        ..drawPath(path, roadPaint)
        ..drawPath(path, roadLine);
    }

    drawRoad([
      Offset(0, size.height * 0.30),
      Offset(size.width * 0.36, size.height * 0.43),
      Offset(size.width, size.height * 0.20),
    ]);
    drawRoad([
      Offset(size.width * 0.10, size.height),
      Offset(size.width * 0.20, size.height * 0.52),
      Offset(size.width * 0.26, 0),
    ]);
    drawRoad([
      Offset(size.width * 0.42, size.height),
      Offset(size.width * 0.56, size.height * 0.46),
      Offset(size.width * 0.74, 0),
    ]);
    drawRoad([
      Offset(0, size.height * 0.73),
      Offset(size.width * 0.48, size.height * 0.66),
      Offset(size.width, size.height * 0.82),
    ]);

    final routePaint = Paint()
      ..color = const Color(0xFFE58B82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final route = Path()
      ..moveTo(size.width * 0.76, 0)
      ..lineTo(size.width * 0.72, size.height * 0.38)
      ..lineTo(size.width * 0.78, size.height);
    canvas.drawPath(route, routePaint);

    final blockPaint = Paint()..color = const Color(0xFFE7DCC1);
    for (final rect in [
      const Rect.fromLTWH(8, 8, 46, 20),
      const Rect.fromLTWH(58, 52, 42, 18),
      Rect.fromLTWH(size.width - 68, 8, 52, 18),
      Rect.fromLTWH(size.width - 84, 62, 64, 20),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        blockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
