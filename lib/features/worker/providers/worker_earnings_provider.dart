import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/settlements/settlement_repository.dart';

/// Jeden řádek výdělku pro Worker pohled – výplata nebo provize z úkolu s názvem a datem.
///
/// PROČ: Read-only přehled pro zaměstnance – kolik si vydělal (výplaty i provize)
/// a jaké úkoly má zaplacené.
class WorkerEarningsRow {
  const WorkerEarningsRow({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.completedAt,
    required this.amount,
    required this.status,
    required this.isCommission,
  });

  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime? completedAt;
  final double amount;
  /// pending | approved | paid
  final String status;
  /// true = provize (profile_id), false = výplata (task_payouts)
  final bool isCommission;

  bool get isPaid => status.toLowerCase() == 'paid';
}

/// Souhrn výdělků – sumy pro pending a paid, plus seznam řádků.
///
/// PROČ: UI zobrazí dvě karty (Čeká na vyplacení / Již vyplaceno) a historii.
class WorkerEarningsSummary {
  const WorkerEarningsSummary({
    required this.pendingTotal,
    required this.paidTotal,
    required this.rows,
  });

  final double pendingTotal;
  final double paidTotal;
  final List<WorkerEarningsRow> rows;
}

/// Provider: výdělky aktuálně přihlášeného zaměstnance z task_payouts a task_commissions.
///
/// Načítá výplaty (task_payouts) i provize (task_commissions, profile_id) a sloučí je
/// do jednoho seznamu seřazeného podle data. Pracovník vidí jen své záznamy – RLS je filtruje.
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
    String taskTitle = (map['task_title'] as String?) ?? '—';
    if (isCommission && taskTitle != '—') {
      taskTitle = '${'worker.earnings.commission_prefix'.tr()}$taskTitle';
    }
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
