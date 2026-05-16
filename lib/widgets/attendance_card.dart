import 'package:flutter/material.dart';

import '../models/presensi_model.dart';

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({
    super.key,
    required this.presensi,
  });

  final PresensiModel presensi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    presensi.tanggal ?? '-',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _StatusChip(label: presensi.status ?? '-'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _TimeItem(label: 'Masuk', value: presensi.jamMasuk)),
                Expanded(
                    child:
                        _TimeItem(label: 'Pulang', value: presensi.jamKeluar)),
              ],
            ),
            if ((presensi.statusPulang ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Status pulang: ${presensi.statusPulang}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeItem extends StatelessWidget {
  const _TimeItem({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value ?? '-',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = normalized.contains('terlambat')
        ? Colors.orange
        : normalized.contains('izin')
            ? Colors.blueGrey
            : Colors.green;

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}
