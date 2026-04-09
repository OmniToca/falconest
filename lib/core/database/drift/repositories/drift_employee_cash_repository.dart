import 'package:drift/drift.dart';

import 'package:falconest_drift/app_database.dart' as drift_db;

/// Lokální čtení a zápis zaměstnanecké hotovosti (`employee_cash_*`) pro Worker.
///
/// PROČ: Obrazovka „Peněženka“ a související dialogy nesmí záviset na Supabase streamu;
/// data přijdou při worker sync a optimistické výdaje/výběry zapisujeme sem před frontou mutací.
class DriftEmployeeCashRepository {
  DriftEmployeeCashRepository(this._db);

  final drift_db.AppDatabase _db;

  /// Sleduje peněženku daného pracovníka v tenantu (max. jeden řádek).
  Stream<drift_db.DriftEmployeeCashWallet?> watchWalletForProfile(String tenantId, String profileId) {
    if (tenantId.isEmpty || profileId.isEmpty) {
      return Stream.value(null);
    }
    return (_db.select(_db.employeeCashWallets)
          ..where((w) => w.tenantId.equals(tenantId) & w.profileId.equals(profileId))
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Transakce peněženky podle UUID peněženky na serveru, od nejnovějších.
  Stream<List<drift_db.DriftEmployeeCashTransaction>> watchTransactionsForWallet(
    String tenantId,
    String walletSupabaseId,
  ) {
    if (tenantId.isEmpty || walletSupabaseId.isEmpty) {
      return Stream.value(const []);
    }
    return (_db.select(_db.employeeCashTransactions)
          ..where((t) => t.tenantId.equals(tenantId) & t.walletId.equals(walletSupabaseId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Kombinovaný stream: změna peněženky přepne poslech transakcí (správné [walletId]).
  ///
  /// PROČ: Riverpod nemusí skládat dva providery ručně; jedna větev streamu = konzistentní snapshot.
  Stream<({drift_db.DriftEmployeeCashWallet? wallet, List<drift_db.DriftEmployeeCashTransaction> txs})>
      watchWalletBundleForProfile(String tenantId, String profileId) {
    if (tenantId.isEmpty || profileId.isEmpty) {
      return Stream.value((wallet: null, txs: <drift_db.DriftEmployeeCashTransaction>[]));
    }
    return watchWalletForProfile(tenantId, profileId).asyncExpand((w) {
      if (w == null) {
        return Stream.value((wallet: null, txs: <drift_db.DriftEmployeeCashTransaction>[]));
      }
      return watchTransactionsForWallet(tenantId, w.supabaseId)
          .map((txs) => (wallet: w, txs: txs));
    });
  }

  /// Přepíše lokální peněženku a transakce podle odpovědi Supabase (full replace pro tenant+profile).
  ///
  /// PROČ: Stejný vzor jako výplaty/absence – po synci nemergeujeme složitě event stream z realtime.
  Future<void> replaceFromSupabaseForProfile({
    required String tenantId,
    required String profileId,
    required Map<String, dynamic>? walletRow,
    required List<dynamic> transactionRows,
    String? currencyCode,
  }) async {
    if (tenantId.isEmpty || profileId.isEmpty) return;

    await (_db.delete(_db.employeeCashTransactions)
          ..where((t) => t.tenantId.equals(tenantId) & t.profileId.equals(profileId)))
        .go();
    await (_db.delete(_db.employeeCashWallets)
          ..where((w) => w.tenantId.equals(tenantId) & w.profileId.equals(profileId)))
        .go();

    if (walletRow == null || walletRow.isEmpty) return;

    final wMap = Map<String, dynamic>.from(walletRow);
    final wid = wMap['id']?.toString().trim();
    if (wid == null || wid.isEmpty) return;
    final wTid = wMap['tenant_id']?.toString().trim() ?? tenantId;
    final wPid = wMap['profile_id']?.toString().trim() ?? profileId;
    if (wTid != tenantId || wPid != profileId) return;

    final bal = _toDouble(wMap['balance']) ?? 0;
    final upd = _parseDateTime(wMap['updated_at']) ?? DateTime.now().toUtc();
    final curr = currencyCode?.trim();
    await _db.into(_db.employeeCashWallets).insert(
          drift_db.EmployeeCashWalletsCompanion.insert(
            supabaseId: wid,
            tenantId: wTid,
            profileId: wPid,
            balance: bal,
            currencyCode: Value(curr != null && curr.isNotEmpty ? curr : null),
            updatedAt: upd,
          ),
        );

    for (final raw in transactionRows) {
      final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final tid = map['id']?.toString().trim();
      if (tid == null || tid.isEmpty) continue;
      final tTenant = map['tenant_id']?.toString().trim() ?? tenantId;
      final wId = map['wallet_id']?.toString().trim();
      if (wId == null || wId.isEmpty || wId != wid) continue;
      if (tTenant != tenantId) continue;

      final amount = _toDouble(map['amount']);
      if (amount == null) continue;
      final type = (map['transaction_type']?.toString() ?? '').trim();
      if (type.isEmpty) continue;

      await _db.into(_db.employeeCashTransactions).insert(
            drift_db.EmployeeCashTransactionsCompanion.insert(
              supabaseId: tid,
              tenantId: tTenant,
              walletId: wId,
              profileId: profileId,
              amount: amount,
              transactionType: type,
              note: Value(_optString(map['note'])),
              createdAt: _parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
              taskId: Value(_optString(map['task_id'])),
              createdBy: Value(_optString(map['created_by'])),
              receiptImageUrl: Value(_optString(map['receipt_image_url'])),
              expectedAmount: Value(_toDouble(map['expected_amount'])),
              apartmentId: Value(_optString(map['apartment_id'])),
              clientId: Value(_optString(map['client_id'])),
              isShortfallResolved: Value(map['is_shortfall_resolved'] == true),
              shortfallResolutionType: Value(_optString(map['shortfall_resolution_type'])),
              shortfallResolutionNote: Value(_optString(map['shortfall_resolution_note'])),
            ),
          );
    }
  }

  /// Optimalistický zápis firemního výdaje – snížení [balance] a nový řádek transakce (záporná částka).
  ///
  /// PROČ: UI se okamžitě překreslí; server doplní stejné UUID při zpracování [OFFLINE_COMPANY_EXPENSE].
  Future<void> applyCompanyExpenseLocal({
    required String tenantId,
    required String profileId,
    required String walletSupabaseId,
    required String transactionId,
    required double amountPositive,
    required String note,
    String? receiptImageUrl,
    String? apartmentId,
    String? clientId,
  }) async {
    if (tenantId.isEmpty ||
        profileId.isEmpty ||
        walletSupabaseId.isEmpty ||
        transactionId.isEmpty ||
        amountPositive <= 0) {
      return;
    }
    final noteTrimmed = note.trim();
    if (noteTrimmed.isEmpty) return;

    final wallets = await (_db.select(_db.employeeCashWallets)
          ..where((w) =>
              w.tenantId.equals(tenantId) &
              w.profileId.equals(profileId) &
              w.supabaseId.equals(walletSupabaseId)))
        .get();
    if (wallets.isEmpty) return;
    final w = wallets.first;
    final current = w.balance;
    if (current < amountPositive) return;

    final now = DateTime.now().toUtc();
    final newBal = current - amountPositive;
    await (_db.update(_db.employeeCashWallets)..where((x) => x.id.equals(w.id))).write(
          drift_db.EmployeeCashWalletsCompanion(
            balance: Value(newBal),
            updatedAt: Value(now),
          ),
        );

    await _db.into(_db.employeeCashTransactions).insert(
          drift_db.EmployeeCashTransactionsCompanion.insert(
            supabaseId: transactionId,
            tenantId: tenantId,
            walletId: walletSupabaseId,
            profileId: profileId,
            amount: -amountPositive,
            transactionType: 'COMPANY_EXPENSE',
            note: Value(noteTrimmed),
            createdAt: now,
            createdBy: Value(profileId),
            receiptImageUrl: Value(_nonEmpty(receiptImageUrl)),
            apartmentId: Value(_nonEmpty(apartmentId)),
            clientId: Value(_nonEmpty(clientId)),
            isShortfallResolved: const Value(false),
            shortfallResolutionType: const Value.absent(),
            shortfallResolutionNote: const Value.absent(),
          ),
        );
  }

  /// Optimalistický zápis výběru od hosta – navýšení zůstatku a transakce [COLLECTED_FROM_GUEST].
  ///
  /// PROČ: Stejné UUID na serveru při [processOfflineCashCollection] zabrání duplicitám po synci.
  Future<void> applyCashCollectionLocal({
    required String tenantId,
    required String profileId,
    required String walletSupabaseId,
    required String taskId,
    required double amount,
    required String transactionId,
    double? expectedAmount,
    String? note,
  }) async {
    if (tenantId.isEmpty ||
        profileId.isEmpty ||
        walletSupabaseId.isEmpty ||
        taskId.isEmpty ||
        transactionId.isEmpty ||
        amount <= 0) {
      return;
    }

    final wallets = await (_db.select(_db.employeeCashWallets)
          ..where((w) =>
              w.tenantId.equals(tenantId) &
              w.profileId.equals(profileId) &
              w.supabaseId.equals(walletSupabaseId)))
        .get();
    if (wallets.isEmpty) return;
    final w = wallets.first;
    final now = DateTime.now().toUtc();
    final newBal = w.balance + amount;
    await (_db.update(_db.employeeCashWallets)..where((x) => x.id.equals(w.id))).write(
          drift_db.EmployeeCashWalletsCompanion(
            balance: Value(newBal),
            updatedAt: Value(now),
          ),
        );

    await _db.into(_db.employeeCashTransactions).insert(
          drift_db.EmployeeCashTransactionsCompanion.insert(
            supabaseId: transactionId,
            tenantId: tenantId,
            walletId: walletSupabaseId,
            profileId: profileId,
            amount: amount,
            transactionType: 'COLLECTED_FROM_GUEST',
            note: Value(_nonEmpty(note)),
            createdAt: now,
            taskId: Value(taskId),
            createdBy: Value(profileId),
            receiptImageUrl: const Value.absent(),
            expectedAmount: expectedAmount != null && expectedAmount > 0
                ? Value(expectedAmount)
                : const Value.absent(),
            apartmentId: const Value.absent(),
            clientId: const Value.absent(),
            isShortfallResolved: const Value(false),
            shortfallResolutionType: const Value.absent(),
            shortfallResolutionNote: const Value.absent(),
          ),
        );
  }

  /// Mapa pro [CashTransactionUIModel.raw] – musí odpovídat klíčům z Supabase.
  static Map<String, dynamic> transactionToRawMap(drift_db.DriftEmployeeCashTransaction t) {
    return {
      'id': t.supabaseId,
      'tenant_id': t.tenantId,
      'wallet_id': t.walletId,
      'task_id': t.taskId,
      'amount': t.amount,
      'transaction_type': t.transactionType,
      'created_by': t.createdBy,
      'created_at': t.createdAt.toUtc().toIso8601String(),
      'note': t.note,
      'receipt_image_url': t.receiptImageUrl,
      'expected_amount': t.expectedAmount,
      'apartment_id': t.apartmentId,
      'client_id': t.clientId,
      'is_shortfall_resolved': t.isShortfallResolved,
      'shortfall_resolution_type': t.shortfallResolutionType,
      'shortfall_resolution_note': t.shortfallResolutionNote,
    };
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  static String? _optString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
