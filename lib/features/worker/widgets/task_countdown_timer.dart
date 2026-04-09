import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Parsuje odhad času v minutách z description nebo metadata.
///
/// PROČ: Jednotná logika pro všechny Task Detail screens. Description často obsahuje
/// "Odhad: 180 min" (AUDIT_TASK_GENERATOR). Metadata může mít estimated_minutes.
int parseTaskEstimateMinutes(String description, Map<String, dynamic>? metadata) {
  // Priorita 1: metadata.estimated_minutes nebo metadata.estimate_minutes
  if (metadata != null) {
    final fromMeta = metadata['estimated_minutes'] ?? metadata['estimate_minutes'];
    if (fromMeta != null) {
      final m = fromMeta is int ? fromMeta : int.tryParse(fromMeta.toString());
      if (m != null && m > 0) return m;
    }
  }
  // Priorita 2: regex v description (Odhad: 180 min, 180 min, atd.)
  if (description.trim().isEmpty) return 0;
  final match = RegExp(r'(?:Odhad|Estimate|Estimación)[:\s]*(\d+)\s*min|(\d+)\s*min')
      .firstMatch(description.trim());
  final minutes = match != null
      ? (int.tryParse(match.group(1) ?? '') ?? int.tryParse(match.group(2) ?? ''))
      : null;
  return minutes ?? 0;
}

/// Live countdown timer pro úkol v průběhu (in_progress).
///
/// PROČ: Pracovník vidí zbývající čas nebo zpoždění bez nutnosti manuálně počítat.
/// Používá Timer.periodic – pouze tento widget se přebuduje každou sekundu, ne celá obrazovka.
///
/// [startedAt] – UTC čas zahájení práce (z WorkerTaskDetail).
/// [completedAt] – při dokončení nezobrazujeme odpočet.
/// [estimatedMinutes] – odhad v minutách (parsováno z description či metadata).
/// Zobrazí se pouze když startedAt != null, completedAt == null a estimatedMinutes > 0.
class TaskCountdownTimer extends StatefulWidget {
  const TaskCountdownTimer({
    super.key,
    required this.startedAt,
    this.completedAt,
    required this.estimatedMinutes,
    /// PROČ: V master detailu je odpočet v sticky liště pod AppBar – bez vnějšího spodního okraje,
    /// aby vizuálně seděl do kompaktního panelu.
    this.embedInSticky = false,
  });

  final DateTime? startedAt;
  final DateTime? completedAt;
  final int estimatedMinutes;
  final bool embedInSticky;

  @override
  State<TaskCountdownTimer> createState() => _TaskCountdownTimerState();
}

class _TaskCountdownTimerState extends State<TaskCountdownTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant TaskCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.completedAt != widget.completedAt ||
        oldWidget.estimatedMinutes != widget.estimatedMinutes ||
        oldWidget.embedInSticky != widget.embedInSticky) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.startedAt == null || widget.estimatedMinutes <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startedAt == null ||
        widget.completedAt != null ||
        widget.estimatedMinutes <= 0) {
      return const SizedBox.shrink();
    }

    final sticky = widget.embedInSticky;

    final target = widget.startedAt!.add(Duration(minutes: widget.estimatedMinutes));
    final now = DateTime.now().toUtc();
    final difference = target.difference(now);

    final isOverdue = difference.isNegative;
    final duration = difference.abs();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final timeStr = '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    final displayStr = isOverdue ? '-$timeStr' : timeStr;

    final label = isOverdue
        ? 'worker.task_countdown_overdue'.tr()
        : 'worker.task_countdown_remaining'.tr();
    final color = isOverdue ? Colors.red.shade700 : Colors.green.shade700;
    final bgColor = isOverdue ? Colors.red.shade50 : Colors.green.shade50;

    return Container(
      padding: EdgeInsets.all(sticky ? 10 : 14),
      margin: sticky ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(sticky ? 12 : 8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, size: sticky ? 28 : 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: sticky ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayStr,
                  style: TextStyle(
                    fontSize: sticky ? 26 : 20,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: color,
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
