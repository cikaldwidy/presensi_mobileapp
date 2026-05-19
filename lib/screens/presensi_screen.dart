import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import 'auto_face_attendance_view.dart';

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
  bool _isSubmitting = false;
  bool _isFinished = false;
  DateTime? _lastSubmitAt;
  String? _message;
  Map<String, dynamic>? _dashboardData;

  bool get _isMasuk => widget.type == 'masuk';

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final response = await widget.apiService.get('/user/dashboard');
    final data = response['data'] as Map<String, dynamic>;
    _dashboardData = data;
    return data;
  }

  Future<void> _submitAutomaticAttendance(FaceAttendancePayload payload) async {
    final now = DateTime.now();
    final lastSubmitAt = _lastSubmitAt;
    if (_isSubmitting ||
        _isFinished ||
        (lastSubmitAt != null && now.difference(lastSubmitAt).inSeconds < 4)) {
      return;
    }

    _lastSubmitAt = now;
    setState(() {
      _isSubmitting = true;
      _message = 'Memproses absensi...';
    });

    try {
      final position = await _getOptionalLocation();
      final user = _dashboardData?['user'] as Map<String, dynamic>? ?? {};
      final response = await widget.apiService.post(
        '/absensi/face',
        body: {
          'user_id': user['id'],
          'type': widget.type,
          'embedding': payload.embedding,
          'timestamp': payload.timestamp.toIso8601String(),
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
        },
      );

      if (!mounted) return;
      setState(() {
        _isFinished = true;
        _message = response['message'] as String? ?? 'Absensi berhasil disimpan';
      });

      unawaited(_closeAfterSuccess());
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Absensi gagal diproses: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _closeAfterSuccess() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<Position?> _getOptionalLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (snapshot.hasError) {
            return _BlockedView(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final data = snapshot.data ?? <String, dynamic>{};
          final availabilityMessage = _attendanceAvailabilityMessage(data);
          if (availabilityMessage != null) {
            return _BlockedView(
              message: availabilityMessage,
              onBack: () => Navigator.of(context).pop(),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              AutoFaceAttendanceView(
                enabled: !_isSubmitting && !_isFinished,
                isSubmitting: _isSubmitting,
                externalMessage: _message,
                onFaceReady: _submitAutomaticAttendance,
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton.filledTonal(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Kembali',
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _ModeChip(
                      text: _isMasuk ? 'Absensi Masuk' : 'Absensi Pulang',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _attendanceAvailabilityMessage(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final status = data['status_presensi'] as Map<String, dynamic>? ?? {};
    final hasFaceEnrollment = user['has_face_enrollment'] as bool? ?? false;
    final hasApprovedLeave = status['has_approved_leave'] as bool? ?? false;
    final activeShiftAvailable =
        status['active_shift_available'] as bool? ?? false;
    final canMasuk = status['can_masuk'] as bool? ?? false;
    final canPulang = status['can_pulang'] as bool? ?? false;

    if (!hasFaceEnrollment) {
      return 'Wajah belum terdaftar. Selesaikan enrollment terlebih dulu.';
    }

    if (hasApprovedLeave) {
      return 'Kamu memiliki izin yang sudah disetujui pada tanggal presensi ini.';
    }

    if (!activeShiftAvailable) {
      return 'Shift belum aktif atau kamu berada di luar jam presensi.';
    }

    if (_isMasuk && !canMasuk) {
      return 'Anda sudah melakukan presensi masuk.';
    }

    if (!_isMasuk && !canPulang) {
      return 'Presensi pulang belum tersedia.';
    }

    return null;
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_rounded,
                color: Colors.white,
                size: 46,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
