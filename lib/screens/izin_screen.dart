import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  final _keteranganController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  String _jenisIzin = 'izin';
  DateTime _tanggalMulai = DateTime.now();
  DateTime _tanggalSelesai = DateTime.now();
  bool _isLoading = false;
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _loadRequests();
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _tanggalMulai : _tanggalSelesai;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _tanggalMulai = picked;
        if (_tanggalSelesai.isBefore(_tanggalMulai)) {
          _tanggalSelesai = picked;
        }
      } else {
        _tanggalSelesai = picked;
      }
    });
  }

  Future<void> _submit() async {
    final keterangan = _keteranganController.text.trim();
    if (keterangan.isEmpty) {
      _showMessage('Keterangan wajib diisi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await widget.apiService.post(
        '/user/izin',
        body: {
          'jenis_izin': _jenisIzin,
          'tanggal_mulai': _dateFormat.format(_tanggalMulai),
          'tanggal_selesai': _dateFormat.format(_tanggalSelesai),
          'keterangan': keterangan,
        },
      );

      _keteranganController.clear();
      if (!mounted) return;
      setState(() => _requestsFuture = _loadRequests());
      _showMessage(
          response['message'] as String? ?? 'Pengajuan izin terkirim.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Pengajuan izin gagal dikirim.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final response = await widget.apiService.get('/user/izin');
    final items = response['data'] as List<dynamic>? ?? [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izin/Sakit')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form Pengajuan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _jenisIzin,
                    decoration: InputDecoration(
                      labelText: 'Jenis izin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'izin', child: Text('Izin')),
                      DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                      DropdownMenuItem(value: 'cuti', child: Text('Cuti')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _jenisIzin = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: 'Mulai',
                          date: _dateFormat.format(_tanggalMulai),
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateButton(
                          label: 'Selesai',
                          date: _dateFormat.format(_tanggalSelesai),
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _keteranganController,
                    label: 'Keterangan',
                    icon: Icons.notes,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 18),
                  CustomButton(
                    label: 'Kirim Pengajuan',
                    icon: Icons.send,
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Riwayat Pengajuan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _requestsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('Gagal memuat izin: ${snapshot.error}');
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Text('Belum ada pengajuan izin.');
              }

              return Column(
                children:
                    items.map((item) => _LeaveRequestCard(item: item)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? '-';
    final color = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (item['jenis_izin'] as String? ?? '-').toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor: color.withValues(alpha: 0.12),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
              ],
            ),
            Text(
                '${item['tanggal_mulai'] ?? '-'} - ${item['tanggal_selesai'] ?? '-'}'),
            const SizedBox(height: 8),
            Text(item['keterangan'] as String? ?? '-'),
            if ((item['catatan_admin'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Catatan admin: ${item['catatan_admin']}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(date, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
