import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/worker/providers/worker_absences_provider.dart';
import 'package:falconest/features/worker/widgets/add_absence_dialog.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Lokální filtr seznamu absencí – pouze UI; provider a Drift data zůstávají beze změny.
enum _WorkerAbsenceListFilter {
  all,
  approved,
  pendingOrRejected,
}

/// Obrazovka „Moje nepřítomnost“ – přehled vlastních dovolených a nemocí.
///
/// Worker si může prohlédnout své budoucí i minulé záznamy a přidat novou
/// žádost (dovolená, nemoc). Offline: zápis prochází přes MutationQueueService.
class WorkerAbsencesScreen extends ConsumerStatefulWidget {
  const WorkerAbsencesScreen({super.key});

  @override
  ConsumerState<WorkerAbsencesScreen> createState() =>
      _WorkerAbsencesScreenState();
}

class _WorkerAbsencesScreenState extends ConsumerState<WorkerAbsencesScreen> {
  _WorkerAbsenceListFilter _filter = _WorkerAbsenceListFilter.all;

  /// Aplikuje výběr filtru na již načtený seznam – bez dotazu do repozitáře.
  List<StaffAbsence> _applyFilter(
    List<StaffAbsence> list,
    _WorkerAbsenceListFilter f,
  ) {
    switch (f) {
      case _WorkerAbsenceListFilter.all:
        return list;
      case _WorkerAbsenceListFilter.approved:
        return list.where((a) => a.isApproved).toList();
      case _WorkerAbsenceListFilter.pendingOrRejected:
        return list
            .where(
              (a) =>
                  a.isPending ||
                  (a.status != null &&
                      a.status == staffAbsenceStatusRejected),
            )
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onPressed: _showAddAbsenceDialog,
        icon: const Icon(Icons.add),
        label: Text('worker.absence_add_button'.tr()),
        backgroundColor: _primaryBlue,
      ),
      body: absencesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(onAddTap: _showAddAbsenceDialog);
          }
          final filtered = _applyFilter(list, _filter);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SegmentedButton<_WorkerAbsenceListFilter>(
                  segments: [
                    ButtonSegment<_WorkerAbsenceListFilter>(
                      value: _WorkerAbsenceListFilter.all,
                      label: Text('worker.absences_filter_all'.tr()),
                      icon: const Icon(Icons.list_alt, size: 18),
                    ),
                    ButtonSegment<_WorkerAbsenceListFilter>(
                      value: _WorkerAbsenceListFilter.approved,
                      label: Text('worker.absences_filter_approved'.tr()),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                    ),
                    ButtonSegment<_WorkerAbsenceListFilter>(
                      value: _WorkerAbsenceListFilter.pendingOrRejected,
                      label: Text(
                        'worker.absences_filter_pending_rejected'.tr(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                      icon: const Icon(Icons.hourglass_top_outlined, size: 18),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() => _filter = s.first);
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'worker.absences_filter_empty'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(workerAbsencesProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final a = filtered[i];
                            return _AbsenceCard(absence: a);
                          },
                        ),
                      ),
              ),
            ],
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
                  'common.generic_error_user_friendly'.tr(),
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

  void _showAddAbsenceDialog() {
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
    final from = absence.startDate != null ? formatAbsenceDate(absence.startDate!) : 'common.placeholder_dash'.tr();
    final to = absence.endDate != null ? formatAbsenceDate(absence.endDate!) : 'common.placeholder_dash'.tr();
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
