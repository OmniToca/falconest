import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/worker/providers/worker_absences_provider.dart';
import 'package:falconest/features/worker/widgets/add_absence_dialog.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Obrazovka „Moje nepřítomnost“ – přehled vlastních dovolených a nemocí.
///
/// Worker si může prohlédnout své budoucí i minulé záznamy a přidat novou
/// žádost (dovolená, nemoc). Offline: zápis prochází přes MutationQueueService.
class WorkerAbsencesScreen extends ConsumerWidget {
  const WorkerAbsencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absencesAsync = ref.watch(workerAbsencesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('worker.drawer_my_absences'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAbsenceDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text('worker.absence_add_button'.tr()),
        backgroundColor: _primaryBlue,
      ),
      body: absencesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(onAddTap: () => _showAddAbsenceDialog(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workerAbsencesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                return _AbsenceCard(absence: a);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'common.error_with_message'.tr(namedArgs: {'message': '$e'}),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(workerAbsencesProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAbsenceDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AddAbsenceDialog(
        onSaved: () {
          ref.invalidate(workerAbsencesProvider);
        },
      ),
    );
  }
}

/// Karta jedné nepřítomnosti – datumy a důvod.
class _AbsenceCard extends StatelessWidget {
  const _AbsenceCard({required this.absence});

  final StaffAbsence absence;

  @override
  Widget build(BuildContext context) {
    final from = absence.startDate != null ? formatAbsenceDate(absence.startDate!) : '—';
    final to = absence.endDate != null ? formatAbsenceDate(absence.endDate!) : '—';
    // Důvod: buď lokalizovaný klíč (vacation, sick, other) nebo volný text z Adminu.
    final String reason;
    switch (absence.reason?.toLowerCase()) {
      case 'vacation':
        reason = 'worker.absence_reason_vacation'.tr();
        break;
      case 'sick':
        reason = 'worker.absence_reason_sick'.tr();
        break;
      case 'other':
        reason = 'worker.absence_reason_other'.tr();
        break;
      default:
        reason = absence.reason?.trim().isNotEmpty == true ? absence.reason! : 'worker.absence_reason_other'.tr();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: _primaryBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$from – $to',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Prázdný stav – žádné nepřítomnosti.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.event_available,
            size: 80,
            color: Colors.green.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 24),
          Text(
            'worker.absences_empty'.tr(),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'worker.absences_empty_hint'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.add),
            label: Text('worker.absence_add_button'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
