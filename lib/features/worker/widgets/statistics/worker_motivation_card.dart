import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/features/worker/providers/worker_motivation_stats_provider.dart';

const Color _workerMotivationAccent = Color(0xFF1565C0);
const Color _workerMotivationGold = Color(0xFFE65100);

String _formatMotivationHours(double h) {
  if (h <= 0) return '0';
  if (h == h.truncateToDouble()) return h.toInt().toString();
  return h.toStringAsFixed(1);
}

/// Karta „úspěchů“ na dashboardu pracovníka – měsíční dokončení, cíl a spolehlivost / hodiny.
///
/// PROČ: Pozitivní, povzbudivý tón; data z [workerMotivationStatsProvider] (Drift nebo Supabase).
class WorkerMotivationDashboardCard extends ConsumerWidget {
  const WorkerMotivationDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workerMotivationStatsProvider);

    return async.when(
      data: (stats) => _WorkerMotivationCardBody(stats: stats),
      loading: () => _WorkerMotivationLoadingPlaceholder(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _WorkerMotivationLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _workerMotivationAccent.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const SizedBox(
        height: 4,
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _WorkerMotivationCardBody extends StatelessWidget {
  const _WorkerMotivationCardBody({required this.stats});

  final WorkerMonthMotivationStats stats;

  @override
  Widget build(BuildContext context) {
    final goal = kWorkerMonthlyGoalCompletedTasks;
    final progress = goal > 0
        ? (stats.completedCount / goal).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final pct = stats.onTimePercent;
    final showReliability = stats.onTimeEligibleCount > 0 && pct != null;
    final reliabilityPct = pct ?? 0.0;
    final showHours = stats.workedHours >= 0.15;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _workerMotivationAccent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _workerMotivationGold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _workerMotivationAccent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _workerMotivationGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events_rounded, color: _workerMotivationGold, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'worker.stats.motivation_title'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Colors.grey.shade900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'worker.stats.motivation_subtitle'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: _workerMotivationAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'worker.stats.motivation_completed'.tr(namedArgs: {
                    'count': '${stats.completedCount}',
                  }),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (showReliability) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'worker.stats.motivation_reliability'.tr(namedArgs: {
                      'percent': reliabilityPct.toStringAsFixed(0),
                    }),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.35),
                  ),
                ),
              ],
            ),
          ] else if (showHours) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, color: _workerMotivationAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'worker.stats.motivation_hours'.tr(namedArgs: {
                      'hours': _formatMotivationHours(stats.workedHours),
                    }),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'worker.stats.motivation_goal_label'.tr(namedArgs: {
              'current': '${stats.completedCount}',
              'goal': '$goal',
            }),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: _workerMotivationAccent.withValues(alpha: 0.12),
              color: _workerMotivationAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'worker.stats.motivation_goal_hint'.tr(),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
          ),
        ],
      ),
    );
  }
}
