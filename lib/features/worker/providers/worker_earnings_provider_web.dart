import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/settlements/settlement_repository.dart';
import 'package:falconest/features/worker/models/worker_earnings_models.dart';

/// Web: Drift není k dispozici – výdělky zůstávají u [SettlementRepository] (Supabase + RLS).
final myEarningsProvider = FutureProvider<WorkerEarningsSummary>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).state.profileId;

  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    return const WorkerEarningsSummary(pendingTotal: 0, paidTotal: 0, rows: []);
  }

  final payoutsFuture = SettlementRepository.instance.getMyPayouts(tenantId, profileId);
  final commissionsFuture = SettlementRepository.instance.getMyCommissions(tenantId, profileId);
  final results = await Future.wait([payoutsFuture, commissionsFuture]);
  final payoutsRaw = results[0];
  final commissionsRaw = results[1];

  double pendingTotal = 0;
  double paidTotal = 0;
  final rows = <WorkerEarningsRow>[];

  WorkerEarningsRow rowFromMap(Map<String, dynamic> map, bool isCommission) {
    final amount = ((map['amount'] as num?) ?? 0).toDouble();
    final status = ((map['status'] as String?) ?? 'pending').trim().toLowerCase();
    DateTime? completedAt;
    final ca = map['completed_at'];
    if (ca != null) completedAt = DateTime.tryParse(ca.toString());
    // PROČ: Stejně jako mobil – typ řádku řeší UI (task_payout_for_task / commission_for_task).
    final taskTitle = (map['task_title'] as String?) ?? 'common.placeholder_dash'.tr();
    return WorkerEarningsRow(
      id: (map['id'] as String?) ?? '',
      taskId: (map['task_id'] as String?) ?? '',
      taskTitle: taskTitle,
      completedAt: completedAt,
      amount: amount,
      status: status,
      isCommission: isCommission,
    );
  }

  for (final map in payoutsRaw) {
    final amount = ((map['amount'] as num?) ?? 0).toDouble();
    final status = ((map['status'] as String?) ?? 'pending').trim().toLowerCase();
    if (status == 'paid') {
      paidTotal += amount;
    } else {
      pendingTotal += amount;
    }
    rows.add(rowFromMap(map, false));
  }

  for (final map in commissionsRaw) {
    final amount = ((map['amount'] as num?) ?? 0).toDouble();
    final status = ((map['status'] as String?) ?? 'pending').trim().toLowerCase();
    if (status == 'paid') {
      paidTotal += amount;
    } else {
      pendingTotal += amount;
    }
    rows.add(rowFromMap(map, true));
  }

  rows.sort((a, b) {
    final da = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });

  return WorkerEarningsSummary(
    pendingTotal: pendingTotal,
    paidTotal: paidTotal,
    rows: rows,
  );
});
