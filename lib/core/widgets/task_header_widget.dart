import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Sjednocená hlavička úkolu podle vzoru Check-in/Check-out.
///
/// PROČ: Jednotný vizuální hierarchie napříč všemi Task Detail screens – nadpis,
/// datum/čas s ikonou hodin. Zamezí rozházeným layoutům (např. Cleaning vs. Check-in).
///
/// [title] – hlavní nadpis (např. "Petr Sokol", "Úklid bytu 3A").
/// [scheduledStart] – plánovaný začátek úkolu; při null se řádek s hodinami nezobrazí.
/// [showTitle] / [showScheduledRow] – PROČ: Master layout detailu úkolu přesunul nadpis a čas do AppBar
/// a sticky lišty; typové obrazovky pak mohou skrýt duplicitní velké nadpisy, ale ponechat kontext.
class TaskHeaderWidget extends StatelessWidget {
  const TaskHeaderWidget({
    super.key,
    required this.title,
    this.scheduledStart,
    this.showTitle = true,
    this.showScheduledRow = true,
  });

  final String title;
  final DateTime? scheduledStart;
  final bool showTitle;
  final bool showScheduledRow;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (showTitle) {
      children.add(
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
      if (showScheduledRow && scheduledStart != null) {
        children.add(const SizedBox(height: 12));
      }
    }
    if (showScheduledRow) {
      children.add(_buildScheduledTimeRow(scheduledStart));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
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
