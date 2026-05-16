import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/presensi_model.dart';
import '../screens/announcement_screen.dart';
import '../screens/izin_screen.dart';
import '../screens/presensi_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/riwayat_screen.dart';
import '../screens/shift_screen.dart';
import '../screens/shift_swap_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class _AppColors {
  static const background = Color(0xFFF4F8F8);
  static const surface = Colors.white;
  static const primary = Color(0xFF087B68);
  static const primaryDark = Color(0xFF075E59);
  static const primarySoft = Color(0xFFE8FAF4);
  static const ink = Color(0xFF243746);
  static const muted = Color(0xFF728294);
  static const line = Color(0xFFE2ECEB);
  static const warning = Color(0xFFB7791F);
  static const warningSoft = Color(0xFFFFF5DB);
  static const blue = Color(0xFF2B6CB0);
  static const blueSoft = Color(0xFFE8F1FF);
  static const red = Color(0xFFE05252);
  static const redSoft = Color(0xFFFFE9E9);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.apiService,
    required this.authService,
    required this.onLogout,
  });

  final ApiService apiService;
  final AuthService authService;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final response = await widget.apiService.get('/user/dashboard');
    return response['data'] as Map<String, dynamic>;
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardTab(
        apiService: widget.apiService,
        future: _dashboardFuture,
        onRefresh: _refreshDashboard,
        onOpenPresensi: _openPresensi,
        onOpenMenu: (index) => setState(() => _selectedIndex = index),
        onLogout: _logout,
      ),
      RiwayatScreen(apiService: widget.apiService),
      IzinScreen(apiService: widget.apiService),
      ProfileScreen(
        authService: widget.authService,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_selectedIndex],
      bottomNavigationBar: _MockBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
        onCenterTap: () => _openPresensi('masuk'),
      ),
    );
  }

  Future<void> _openPresensi(String type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresensiScreen(
          apiService: widget.apiService,
          type: type,
        ),
      ),
    );
    _refreshDashboard();
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({
    required this.apiService,
    required this.future,
    required this.onRefresh,
    required this.onOpenPresensi,
    required this.onOpenMenu,
    required this.onLogout,
  });

  final ApiService apiService;
  final Future<Map<String, dynamic>> future;
  final VoidCallback onRefresh;
  final ValueChanged<String> onOpenPresensi;
  final ValueChanged<int> onOpenMenu;
  final VoidCallback onLogout;

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const _DashboardBackground(),
            RefreshIndicator(
              color: _AppColors.primary,
              onRefresh: () async => widget.onRefresh(),
              child: FutureBuilder<Map<String, dynamic>>(
                future: widget.future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 118),
                      children: const [_LoadingPanel()],
                    );
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 118),
                      children: [
                        _InfoPanel(
                          icon: Icons.cloud_off_rounded,
                          title: 'Data belum bisa dimuat',
                          subtitle: snapshot.error.toString(),
                        ),
                      ],
                    );
                  }

                  final data = snapshot.data ?? <String, dynamic>{};
                  final user = data['user'] as Map<String, dynamic>? ?? {};
                  final status =
                      data['status_presensi'] as Map<String, dynamic>? ?? {};
                  final presensiJson = data['presensi_hari_ini'];
                  final presensi = presensiJson is Map<String, dynamic>
                      ? PresensiModel.fromJson(presensiJson)
                      : null;
                  final rekap =
                      data['rekap_30_hari'] as Map<String, dynamic>? ?? {};
                  final shift = data['shift'] as Map<String, dynamic>? ?? {};
                  final announcements =
                      (data['pengumuman'] as List<dynamic>? ?? [])
                          .whereType<Map<String, dynamic>>()
                          .toList();
                  final activeShift = shift['active'] as Map<String, dynamic>?;
                  final scheduledShift =
                      shift['scheduled'] as Map<String, dynamic>?;
                  final shiftData = activeShift ?? scheduledShift;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
                    children: [
                      _Header(
                        name: user['name'] as String? ?? 'Akun User',
                        now: _now,
                        onLogout: widget.onLogout,
                      ),
                      const SizedBox(height: 16),
                      _ShiftNotice(shiftData: shiftData),
                      const SizedBox(height: 14),
                      _AttendanceStatusCard(presensi: presensi),
                      const SizedBox(height: 16),
                      const _SectionTitle(
                        title: 'Akses Cepat',
                        subtitle: 'Pilih kebutuhan presensi kamu',
                      ),
                      const SizedBox(height: 10),
                      _FeatureGrid(
                        onHadir: () => _openAttendance(user, status),
                        onIzin: () => widget.onOpenMenu(2),
                        onInfo: () => widget.onOpenMenu(3),
                        onJadwal: () => _openPage(
                          ShiftScreen(apiService: widget.apiService),
                        ),
                        onSwapShift: () => _openPage(
                          ShiftSwapScreen(apiService: widget.apiService),
                        ),
                        onComingSoon: _showComingSoon,
                      ),
                      const SizedBox(height: 16),
                      _MonthlySummary(rekap: rekap),
                      const SizedBox(height: 16),
                      _AnnouncementPreview(
                        items: announcements,
                        onViewAll: () => _openPage(
                          AnnouncementScreen(apiService: widget.apiService),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label belum tersedia di aplikasi mobile.')),
    );
  }

  void _openAttendance(
    Map<String, dynamic> user,
    Map<String, dynamic> status,
  ) {
    final hasFaceEnrollment = user['has_face_enrollment'] as bool? ?? false;
    final hasApprovedLeave = status['has_approved_leave'] as bool? ?? false;
    final activeShiftAvailable =
        status['active_shift_available'] as bool? ?? false;
    final canMasuk = status['can_masuk'] as bool? ?? false;
    final canPulang = status['can_pulang'] as bool? ?? false;

    if (!hasFaceEnrollment) {
      _showMessage(
        'Wajah belum terdaftar. Selesaikan enrollment melalui web terlebih dulu.',
      );
      return;
    }

    if (hasApprovedLeave) {
      _showMessage('Kamu memiliki izin yang sudah disetujui hari ini.');
      return;
    }

    if (!activeShiftAvailable) {
      _showMessage('Shift belum aktif atau kamu berada di luar jam presensi.');
      return;
    }

    if (canPulang) {
      widget.onOpenPresensi('pulang');
      return;
    }

    if (canMasuk) {
      widget.onOpenPresensi('masuk');
      return;
    }

    _showMessage('Presensi hari ini sudah lengkap.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    widget.onRefresh();
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 235,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_AppColors.primaryDark, _AppColors.primary],
            ),
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const CircularProgressIndicator(color: _AppColors.primary),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.now,
    required this.onLogout,
  });

  final String name;
  final DateTime now;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH.mm.ss').format(now);
    final date = _formatIndonesianDate(now);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AppColors.line),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat bertugas',
                      style: TextStyle(
                        color: _AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: _AppColors.redSoft,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onLogout,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.logout_rounded,
                      color: _AppColors.red,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: _AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _AppColors.line),
            ),
            child: Column(
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: _AppColors.primaryDark,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: _AppColors.primary,
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        date,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatIndonesianDate(DateTime value) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
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

    return '${days[value.weekday - 1]}, ${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
  }
}

class _ShiftNotice extends StatelessWidget {
  const _ShiftNotice({required this.shiftData});

  final Map<String, dynamic>? shiftData;

  @override
  Widget build(BuildContext context) {
    final hasShift = shiftData != null;
    final title = hasShift ? 'Shift Hari Ini' : 'Belum Ada Shift';
    final text = hasShift
        ? 'Shift hari ini ${shiftData!['jam_masuk'] ?? '-'} - ${shiftData!['jam_pulang'] ?? '-'}.'
        : 'Shift kamu belum diatur oleh admin untuk hari ini. Absen hanya bisa dilakukan setelah ada jadwal shift.';
    final icon =
        hasShift ? Icons.schedule_rounded : Icons.warning_amber_rounded;
    final tint = hasShift ? _AppColors.blue : _AppColors.warning;
    final soft = hasShift ? _AppColors.blueSoft : _AppColors.warningSoft;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tint,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: _AppColors.ink,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatusCard extends StatelessWidget {
  const _AttendanceStatusCard({required this.presensi});

  final PresensiModel? presensi;

  @override
  Widget build(BuildContext context) {
    final hasMasuk = (presensi?.jamMasuk ?? '').isNotEmpty;
    final hasPulang = (presensi?.jamKeluar ?? '').isNotEmpty;
    final statusText = hasPulang
        ? 'Selesai'
        : hasMasuk
            ? 'Sedang Bertugas'
            : 'Belum Presensi';
    final statusColor = hasPulang
        ? _AppColors.blue
        : hasMasuk
            ? _AppColors.primary
            : _AppColors.warning;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Presensi Hari Ini',
                  style: TextStyle(
                    color: _AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AttendanceStatusItem(
                  icon: Icons.login_rounded,
                  label: 'Jam Masuk',
                  value: presensi?.jamMasuk ?? '--:--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AttendanceStatusItem(
                  icon: Icons.logout_rounded,
                  label: 'Jam Pulang',
                  value: presensi?.jamKeluar ?? '--:--',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatusItem extends StatelessWidget {
  const _AttendanceStatusItem({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _AppColors.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.onHadir,
    required this.onIzin,
    required this.onInfo,
    required this.onJadwal,
    required this.onSwapShift,
    required this.onComingSoon,
  });

  final VoidCallback onHadir;
  final VoidCallback onIzin;
  final VoidCallback onInfo;
  final VoidCallback onJadwal;
  final VoidCallback onSwapShift;
  final ValueChanged<String> onComingSoon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 340 ? 3 : 4;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: crossAxisCount == 3 ? 1 : 0.88,
          children: [
            _FeatureTile(
              icon: Icons.how_to_reg_rounded,
              label: 'Hadir',
              accent: _AppColors.primary,
              soft: _AppColors.primarySoft,
              onTap: onHadir,
            ),
            _FeatureTile(
              icon: Icons.health_and_safety_rounded,
              label: 'Sakit',
              accent: _AppColors.red,
              soft: _AppColors.redSoft,
              onTap: onIzin,
            ),
            _FeatureTile(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Izin',
              accent: _AppColors.blue,
              soft: _AppColors.blueSoft,
              onTap: onIzin,
            ),
            _FeatureTile(
              icon: Icons.flight_takeoff_rounded,
              label: 'Cuti',
              accent: _AppColors.warning,
              soft: _AppColors.warningSoft,
              onTap: onIzin,
            ),
            _FeatureTile(
              icon: Icons.badge_rounded,
              label: 'ID Card',
              accent: const Color(0xFF5965D8),
              soft: const Color(0xFFEDEEFF),
              onTap: onInfo,
            ),
            _FeatureTile(
              icon: Icons.access_time_filled_rounded,
              label: 'Lembur',
              accent: const Color(0xFF59697A),
              soft: const Color(0xFFE9ECF3),
              onTap: () => onComingSoon('Lembur'),
            ),
            _FeatureTile(
              icon: Icons.calendar_month_rounded,
              label: 'Jadwal',
              accent: const Color(0xFF0E7490),
              soft: const Color(0xFFE2F6FB),
              onTap: onJadwal,
            ),
            _FeatureTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Swap Shift',
              accent: const Color(0xFF8B5CF6),
              soft: const Color(0xFFF0EAFF),
              onTap: onSwapShift,
            ),
          ],
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.soft,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _AppColors.ink,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementPreview extends StatelessWidget {
  const _AnnouncementPreview({
    required this.items,
    required this.onViewAll,
  });

  final List<Map<String, dynamic>> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengumuman Aktif',
                      style: TextStyle(
                        color: _AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Info terbaru untuk user',
                      style: TextStyle(
                        color: _AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('Lihat'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const _EmptyLine(
              icon: Icons.campaign_outlined,
              text: 'Belum ada pengumuman aktif.',
            )
          else
            ...items.take(3).map(
                  (item) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['judul'] as String? ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['isi'] as String? ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.rekap});

  final Map<String, dynamic> rekap;

  @override
  Widget build(BuildContext context) {
    final hadir = _asInt(rekap['hadir']);
    final izin = _asInt(rekap['izin']) + _asInt(rekap['sakit']);
    final terlambat = _asInt(rekap['terlambat']);
    final total = _asInt(rekap['total']);
    final belumAbsen = total > 0
        ? (total - hadir - izin).clamp(0, total).toInt()
        : _asInt(rekap['belum_absen']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '30 Hari terakhir',
            style: TextStyle(
              color: _AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Ringkasan absensi',
            style: TextStyle(
              color: _AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryPill(
                label: 'Hadir',
                value: hadir,
                color: _AppColors.primarySoft,
                textColor: _AppColors.primary,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                label: 'Sakit/Izin',
                value: izin,
                color: _AppColors.warningSoft,
                textColor: _AppColors.warning,
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                label: terlambat > 0 ? 'Terlambat' : 'Belum',
                value: terlambat > 0 ? terlambat : belumAbsen,
                color: terlambat > 0 ? _AppColors.redSoft : _AppColors.blueSoft,
                textColor: terlambat > 0 ? _AppColors.red : _AppColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final String label;
  final int value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.78),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockBottomNav extends StatelessWidget {
  const _MockBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.onCenterTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 82,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.11),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BottomItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _BottomItem(
                    icon: Icons.description_rounded,
                    label: 'Histori',
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  const SizedBox(width: 56),
                  _BottomItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Izin',
                    selected: selectedIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                  _BottomItem(
                    icon: Icons.info_rounded,
                    label: 'Info',
                    selected: selectedIndex == 3,
                    onTap: () => onSelected(3),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -22,
              child: Material(
                color: _AppColors.primary,
                shape: const CircleBorder(),
                elevation: 8,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCenterTap,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 5),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
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

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _AppColors.primary : const Color(0xFF9AA4B2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: selected ? 23 : 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: _AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _AppColors.muted, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
