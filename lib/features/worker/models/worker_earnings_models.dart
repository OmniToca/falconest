// Modely pro obrazovku „Moje výdělky“ (sdílené mezi web/mobil providery).

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
  /// Název úkolu z JOINu na `tasks` (mobil Drift) nebo z API (web). Prázdné / neznámé → UI použije placeholder.
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
