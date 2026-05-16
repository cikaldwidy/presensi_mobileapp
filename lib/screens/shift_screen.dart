import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _monthFormat = DateFormat('yyyy-MM');
  late DateTime _month;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await widget.apiService.get(
      '/user/jadwal-shift?month=${_monthFormat.format(_month)}',
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List<dynamic>? ?? [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  void _changeMonth(int value) {
    setState(() {
      _month = DateTime(_month.year, _month.month + value);
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Shift')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _MessageList(
                      message: 'Gagal memuat jadwal: ${snapshot.error}');
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _MessageList(
                      message: 'Belum ada jadwal shift bulan ini.');
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8FAF4),
                          child: Icon(
                            item['status'] == 'libur'
                                ? Icons.free_breakfast
                                : Icons.schedule,
                            color: const Color(0xFF07896F),
                          ),
                        ),
                        title: Text(item['tanggal'] as String? ?? '-'),
                        subtitle: Text(item['nama_shift'] as String? ?? '-'),
                        trailing: Text(
                          item['status'] as String? ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [Text(message)],
    );
  }
}
