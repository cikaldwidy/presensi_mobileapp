import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await widget.apiService.get('/user/pengumuman');
    final items = response['data'] as List<dynamic>? ?? [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageList(
                message: 'Gagal memuat pengumuman: ${snapshot.error}');
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _MessageList(message: 'Belum ada pengumuman aktif.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['judul'] as String? ?? '-',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item['tanggal_mulai'] ?? '-'} - ${item['tanggal_berakhir'] ?? '-'}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(item['isi'] as String? ?? '-'),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
