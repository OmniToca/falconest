import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Sjednocená hlavička úkolu podle vzoru Check-in/Check-out.
///
/// PROČ: Jednotný vizuální hierarchie napříč všemi Task Detail screens – nadpis,
/// datum/čas s ikonou hodin. Zamezí rozházeným layoutům (např. Cleaning vs. Check-in).
///
/// [title] – hlavní nadpis (např. "Petr Sokol", "Úklid bytu 3A").
/// [scheduledStart] – plánovaný začátek úkolu; při null se řádek s hodinami nezobrazí.
class TaskHeaderWidget extends StatelessWidget {
  const TaskHeaderWidget({
    super.key,
    required this.title,
    this.scheduledStart,
  });

  final String title;
  final DateTime? scheduledStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildScheduledTimeRow(scheduledStart),
      ],
    );
  }

  /// Řádek s ikonou hodin a formátovaným datumem/časem.
  Widget _buildScheduledTimeRow(DateTime? scheduledStart) {
    if (scheduledStart == null) return const SizedBox.shrink();
    final formatted = DateFormat('dd.MM.yyyy HH:mm').format(scheduledStart);
    return Row(
      children: [
        Icon(Icons.access_time, size: 22, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Text(
          formatted,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
