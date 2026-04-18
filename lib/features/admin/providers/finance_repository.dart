import 'package:falconest/core/services/supabase_service.dart';

/// Řádek „sirotčí“ hotovosti v trezoru: HANDED_TO_AGENCY bez vazby na owner settlement.
///
/// PROČ: Umožní dispečinku dohledat převzetí hotovosti, které se nepárovalo – párování
/// je přes text v `owner_cash_transit_settlements.note` (`auto_handoff: … (tx: …)`), ne přes FK sloupec.
class UnpairedVaultCashRow {
  const UnpairedVaultCashRow({
    required this.transactionId,
    required this.walletId,
    required this.reservationId,
    required this.workerProfileId,
    required this.amount,
    this.createdAt,
  });

  final String transactionId;
  final String walletId;
  final String reservationId;
  final String workerProfileId;
  final double amount;
  final DateTime? createdAt;
}

/// Repozitář pro operace modulu Fakturace – označování úkolů jako vyfakturované.
class FinanceRepository {
  FinanceRepository._();
  static final FinanceRepository instance = FinanceRepository._();

  /// Označí dané úkoly jako vyfakturované – nastaví invoiced_at = now().
  ///
  /// PROČ: Soft-archivace. Úkoly s invoiced_at != null se již nezobrazují
  /// na Nástěnce/Plachtě ani v podkladech pro fakturaci. Fakturace je idempotentní
  /// – opakované volání na stejná ID nic nepokazí.
  Future<void> invoiceTasks(String tenantId, List<String> taskIds) async {
    if (tenantId.isEmpty || taskIds.isEmpty) return;
    final ids = taskIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    await SupabaseService.safeFrom(
      'tasks',
      tenantId,
    ).update({'invoiced_at': now}).inFilter('id', ids);
  }

  /// Vrátí HANDED_TO_AGENCY transakce, které nejsou spárované v owner settlement tabulce.
  ///
  /// PROČ: Bez sloupce `employee_cash_transaction_id` na settlementech načteme settlementy s `note`
  /// obsahujícím `HANDED_TO_AGENCY`, v Dartu z textu `(tx: <uuid>)` složíme množinu již spárovaných
  /// transakcí a odfiltrujeme je od seznamu HANDED z pokladny.
  Future<List<UnpairedVaultCashRow>> getUnpairedVaultCash(
    String tenantId,
  ) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return [];

    final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tid);
    final safeSet = SupabaseService.safeFrom(
      'owner_cash_transit_settlements',
      tid,
    );

    final txRows = await safeTx
        .select('id, wallet_id, reservation_id, profile_id, amount, created_at')
        .eq('transaction_type', 'HANDED_TO_AGENCY')
        .not('reservation_id', 'is', null)
        .order('created_at', ascending: false);
    final setRows = await safeSet
        .select('note')
        .ilike('note', '%HANDED_TO_AGENCY%');

    final paired = _handedTransactionIdsPairedInSettlementNotes(
      setRows is List ? setRows : const <dynamic>[],
    );

    final out = <UnpairedVaultCashRow>[];
    for (final r in (txRows is List ? txRows : const <dynamic>[])) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final id = m['id']?.toString().trim() ?? '';
      if (id.isEmpty || paired.contains(id)) continue;
      final reservationId = m['reservation_id']?.toString().trim() ?? '';
      if (reservationId.isEmpty) continue;
      final walletId = m['wallet_id']?.toString().trim() ?? '';
      final workerId = m['profile_id']?.toString().trim() ?? '';
      final amountRaw = m['amount'];
      final amount = (amountRaw is num)
          ? amountRaw.toDouble().abs()
          : (double.tryParse(amountRaw?.toString() ?? '') ?? 0).abs();
      if (walletId.isEmpty || workerId.isEmpty || amount <= 0) continue;
      final createdRaw = m['created_at'];
      DateTime? createdAt;
      if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);
      if (createdRaw is DateTime) createdAt = createdRaw;

      out.add(
        UnpairedVaultCashRow(
          transactionId: id,
          walletId: walletId,
          reservationId: reservationId,
          workerProfileId: workerId,
          amount: amount,
          createdAt: createdAt,
        ),
      );
    }
    return out;
  }

  /// Z odpovědi Supabase (řádky settlementů s vyplněným [note]) vytáhne množinu ID transakcí HANDED,
  /// které už mají řádek v `owner_cash_transit_settlements` (text `… (tx: <id>)`).
  static Set<String> _handedTransactionIdsPairedInSettlementNotes(
    List<dynamic> rows,
  ) {
    const marker = '(tx: ';
    final out = <String>{};
    for (final r in rows) {
      if (r is! Map) continue;
      final raw = r['note']?.toString();
      if (raw == null || raw.isEmpty) continue;
      final i = raw.indexOf(marker);
      if (i < 0) continue;
      final rest = raw.substring(i + marker.length);
      final end = rest.indexOf(')');
      if (end < 0) continue;
      final id = rest.substring(0, end).trim();
      if (id.isNotEmpty) out.add(id);
    }
    return out;
  }

  /// Aktualizuje stav úhrady zmraženého vyúčtování (`billing_snapshots.payment_status`).
  ///
  /// PROČ: Dispečer v Adminu označí fakturu jako uhrazenou / částečně / zápočet; majitel
  /// vidí stejný stav v Klientském portálu. Při [newStatus] == `paid` nastavíme [paid_at]
  /// na aktuální čas UTC; jinak [paid_at] vymažeme, aby UI neukazovalo zastaralé datum.
  Future<void> updateSnapshotPaymentStatus(
    String tenantId,
    String snapshotId,
    String newStatus,
  ) async {
    final tid = tenantId.trim();
    final sid = snapshotId.trim();
    final status = newStatus.trim().toLowerCase();
    const allowed = {'unpaid', 'paid', 'partially_paid', 'cash_offset'};
    if (tid.isEmpty || sid.isEmpty || !allowed.contains(status)) {
      throw ArgumentError(
        'Neplatné parametry pro updateSnapshotPaymentStatus',
      );
    }
    final payload = <String, dynamic>{
      'payment_status': status,
      if (status == 'paid')
        'paid_at': DateTime.now().toUtc().toIso8601String()
      else
        'paid_at': null,
    };
    await SupabaseService.safeFrom('billing_snapshots', tid)
        .update(payload)
        .eq('id', sid);
  }

  /// Uloží nebo vymaže odkaz na PDF faktury u snapshotu (`billing_snapshots.invoice_pdf_url`).
  ///
  /// PROČ: Agentura může nahrát fakturu do úložiště a sem vložit veřejnou URL; prázdný
  /// řetězec sloupec vyčistí (majitel už tlačítko PDF neuvidí).
  Future<void> updateSnapshotInvoicePdfUrl(
    String tenantId,
    String snapshotId,
    String pdfUrl,
  ) async {
    final tid = tenantId.trim();
    final sid = snapshotId.trim();
    if (tid.isEmpty || sid.isEmpty) {
      throw ArgumentError(
        'Neplatné parametry pro updateSnapshotInvoicePdfUrl',
      );
    }
    final trimmed = pdfUrl.trim();
    await SupabaseService.safeFrom('billing_snapshots', tid).update({
      'invoice_pdf_url': trimmed.isEmpty ? null : trimmed,
    }).eq('id', sid);
  }
}
