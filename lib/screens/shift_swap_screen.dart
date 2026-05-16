import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ShiftSwapScreen extends StatefulWidget {
  const ShiftSwapScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ShiftSwapScreen> createState() => _ShiftSwapScreenState();
}

class _ShiftSwapScreenState extends State<ShiftSwapScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await widget.apiService.get('/user/tukar-shift');
    final items = response['data'] as List<dynamic>? ?? [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _openCreate() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateShiftSwapScreen(apiService: widget.apiService),
      ),
    );
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _respond(int id, String action) async {
    try {
      final response =
          await widget.apiService.post('/user/tukar-shift/$id/$action');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] as String? ?? 'Berhasil')),
      );
      _refresh();
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swap Shift'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Request'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageList(
                message: 'Gagal memuat swap shift: ${snapshot.error}');
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _MessageList(
                message: 'Belum ada request tukar shift.');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final requester =
                  item['requester'] as Map<String, dynamic>? ?? {};
              final target = item['target_user'] as Map<String, dynamic>? ?? {};
              final shift = item['shift'] as Map<String, dynamic>? ?? {};
              final targetShift =
                  item['target_shift'] as Map<String, dynamic>? ?? {};
              final canRespond = item['can_respond'] as bool? ?? false;

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
                              '${requester['name'] ?? '-'} -> ${target['name'] ?? '-'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Chip(label: Text(item['status'] as String? ?? '-')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Shift saya: ${shift['tanggal'] ?? '-'} ${shift['jam_masuk'] ?? '-'}-${shift['jam_pulang'] ?? '-'}'),
                      Text(
                          'Shift target: ${targetShift['tanggal'] ?? '-'} ${targetShift['jam_masuk'] ?? '-'}-${targetShift['jam_pulang'] ?? '-'}'),
                      if ((item['note'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(item['note'] as String),
                      ],
                      if (canRespond) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    _respond(item['id'] as int, 'accept'),
                                child: const Text('Terima'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _respond(item['id'] as int, 'reject'),
                                child: const Text('Tolak'),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _CreateShiftSwapScreen extends StatefulWidget {
  const _CreateShiftSwapScreen({required this.apiService});

  final ApiService apiService;

  @override
  State<_CreateShiftSwapScreen> createState() => _CreateShiftSwapScreenState();
}

class _CreateShiftSwapScreenState extends State<_CreateShiftSwapScreen> {
  final _noteController = TextEditingController();
  late Future<Map<String, dynamic>> _optionsFuture;
  List<Map<String, dynamic>> _targetShifts = [];
  int? _shiftId;
  int? _targetUserId;
  int? _targetShiftId;
  bool _isLoadingTargets = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _loadOptions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadOptions() async {
    final response = await widget.apiService.get('/user/tukar-shift/options');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> _loadTargetShifts() async {
    if (_shiftId == null || _targetUserId == null) return;

    setState(() {
      _isLoadingTargets = true;
      _targetShiftId = null;
      _targetShifts = [];
    });

    try {
      final response = await widget.apiService.get(
        '/user/tukar-shift/target-shifts?target_user_id=$_targetUserId&shift_id=$_shiftId',
      );
      final items = response['data'] as List<dynamic>? ?? [];
      setState(() =>
          _targetShifts = items.whereType<Map<String, dynamic>>().toList());
    } finally {
      if (mounted) {
        setState(() => _isLoadingTargets = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_shiftId == null || _targetUserId == null || _targetShiftId == null) {
      _showMessage('Lengkapi shift, user target, dan shift target.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await widget.apiService.post(
        '/user/tukar-shift',
        body: {
          'shift_id': _shiftId,
          'target_user_id': _targetUserId,
          'target_shift_id': _targetShiftId,
          'note': _noteController.text.trim(),
        },
      );
      if (!mounted) return;
      _showMessage(response['message'] as String? ?? 'Request terkirim.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Swap Shift')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _optionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final myShifts = (data['my_shifts'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          final users = (data['users'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DropdownCard(
                label: 'Shift saya',
                value: _shiftId,
                items: myShifts,
                labelBuilder: (item) =>
                    '${item['tanggal']} ${item['jam_masuk']}-${item['jam_pulang']}',
                onChanged: (value) {
                  setState(() => _shiftId = value);
                  _loadTargetShifts();
                },
              ),
              const SizedBox(height: 12),
              _DropdownCard(
                label: 'User target',
                value: _targetUserId,
                items: users,
                labelBuilder: (item) => item['name'] as String? ?? '-',
                onChanged: (value) {
                  setState(() => _targetUserId = value);
                  _loadTargetShifts();
                },
              ),
              const SizedBox(height: 12),
              if (_isLoadingTargets)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ))
              else
                _DropdownCard(
                  label: 'Shift target',
                  value: _targetShiftId,
                  items: _targetShifts,
                  labelBuilder: (item) =>
                      '${item['tanggal']} ${item['jam_masuk']}-${item['jam_pulang']}',
                  onChanged: (value) => setState(() => _targetShiftId = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.send),
                label: const Text('Kirim Request'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DropdownCard extends StatelessWidget {
  const _DropdownCard({
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) labelBuilder;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(labelBuilder(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
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
