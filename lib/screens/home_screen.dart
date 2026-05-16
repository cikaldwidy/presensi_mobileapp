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
      backgroundColor: const Color(0xFFDFFBFA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: FutureBuilder<Map<String, dynamic>>(
            future: widget.future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  children: [
                    _InfoPanel(
                      icon: Icons.cloud_off,
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
              final announcements = (data['pengumuman'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
              final activeShift = shift['active'] as Map<String, dynamic>?;
              final scheduledShift =
                  shift['scheduled'] as Map<String, dynamic>?;
              final shiftData = activeShift ?? scheduledShift;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
                children: [
                  _Header(
                    name: user['name'] as String? ?? 'Akun User',
                    now: _now,
                    onLogout: widget.onLogout,
                  ),
                  const SizedBox(height: 18),
                  _ShiftNotice(shiftData: shiftData),
                  const SizedBox(height: 14),
                  _AttendanceStatusCard(presensi: presensi),
                  const SizedBox(height: 16),
                  _FeatureGrid(
                    onHadir: () {
                      final canPulang = status['can_pulang'] as bool? ?? false;
                      widget.onOpenPresensi(canPulang ? 'pulang' : 'masuk');
                    },
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
      ),
    );
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label belum tersedia di aplikasi mobile.')),
    );
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    widget.onRefresh();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF536878),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Akun User',
                    style: TextStyle(
                      color: Color(0xFF7B8D9A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF536878),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: Column(
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF087B68),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFF7B8D9A),
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
    final text = hasShift
        ? 'Shift hari ini ${shiftData!['jam_masuk'] ?? '-'} - ${shiftData!['jam_pulang'] ?? '-'}.'
        : 'Shift kamu belum diatur oleh admin untuk hari ini. Absen hanya bisa dilakukan setelah ada jadwal shift.';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2CB55)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9B6331),
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AttendanceStatusCard extends StatelessWidget {
  const _AttendanceStatusCard({required this.presensi});

  final PresensiModel? presensi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AttendanceStatusItem(
              icon: Icons.login_rounded,
              label: 'Jam Masuk',
              value: presensi?.jamMasuk ?? '--:--',
            ),
          ),
          Container(width: 1, height: 44, color: const Color(0xFFE8F0EF)),
          Expanded(
            child: _AttendanceStatusItem(
              icon: Icons.work_rounded,
              label: 'Jam Pulang',
              value: presensi?.jamKeluar ?? 'Belum\nDijadwalkan',
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8FAF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF07896F), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8290A3),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF30445C),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.86,
      children: [
        _FeatureTile(
          icon: Icons.how_to_reg_rounded,
          label: 'Hadir',
          onTap: onHadir,
        ),
        _FeatureTile(
          icon: Icons.health_and_safety_rounded,
          label: 'Sakit',
          onTap: onIzin,
        ),
        _FeatureTile(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Izin',
          onTap: onIzin,
        ),
        _FeatureTile(
          icon: Icons.flight_takeoff_rounded,
          label: 'Cuti',
          onTap: onIzin,
        ),
        _FeatureTile(
          icon: Icons.badge_rounded,
          label: 'ID Card',
          onTap: onInfo,
        ),
        _FeatureTile(
          icon: Icons.access_time_filled_rounded,
          label: 'Lembur',
          onTap: () => onComingSoon('Lembur'),
        ),
        _FeatureTile(
          icon: Icons.calendar_month_rounded,
          label: 'Jadwal',
          onTap: onJadwal,
        ),
        _FeatureTile(
          icon: Icons.swap_horiz_rounded,
          label: 'Swap Shift',
          onTap: onSwapShift,
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: const Color(0xFFE9FBF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF07896F), size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF536878),
                fontSize: 11,
                fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
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
                        color: Color(0xFF536878),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Info terbaru untuk user',
                      style: TextStyle(
                        color: Color(0xFF8A98A8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                  onPressed: onViewAll, child: const Text('Lihat semua')),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('Belum ada pengumuman aktif.')
          else
            ...items.take(3).map(
                  (item) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FAFA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['judul'] as String? ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['isi'] as String? ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '30 Hari terakhir',
            style: TextStyle(
              color: Color(0xFF536878),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Ringkasan absensi',
            style: TextStyle(
              color: Color(0xFF8A98A8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryPill(
                label: 'Hadir',
                value: rekap['hadir'],
                color: const Color(0xFFBFEFDF),
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                label: 'Sakit/Izin',
                value: (rekap['izin'] as int? ?? 0),
                color: const Color(0xFFF4E4B1),
              ),
              const SizedBox(width: 8),
              _SummaryPill(
                label: 'Belum Absen',
                value: rekap['total'] == null ? 0 : null,
                color: const Color(0xFFE9ECF3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final dynamic value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          value == null ? label : '$label ${value ?? 0}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF59697A),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
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
        height: 78,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
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
                color: const Color(0xFF07896F),
                shape: const CircleBorder(),
                elevation: 7,
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
    final color = selected ? const Color(0xFF07896F) : const Color(0xFF9AA4B2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF07896F)),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
