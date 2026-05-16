import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/presensi_model.dart';
import '../services/api_service.dart';
import '../widgets/attendance_card.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  late Future<List<PresensiModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PresensiModel>> _load() async {
    final response = await widget.apiService.get('/user/presensi/riwayat');
    final data = response['data'] as List<dynamic>? ?? [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(PresensiModel.fromJson)
        .toList();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  String _formatDate(String? value) {
    if (value == null) return '-';

    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Presensi'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<PresensiModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Gagal memuat riwayat: ${snapshot.error}'),
                ],
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  Text('Belum ada riwayat presensi.'),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = items[index];
                return AttendanceCard(
                  presensi: PresensiModel(
                    id: item.id,
                    tanggal: _formatDate(item.tanggal),
                    jamMasuk: item.jamMasuk,
                    jamKeluar: item.jamKeluar,
                    status: item.status,
                    statusPulang: item.statusPulang,
                    keterangan: item.keterangan,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }
}
