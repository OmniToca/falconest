import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

/// Řádek peněženky zaměstnance – pro seznam v admin UI.
class EmployeeCashWalletRow {
  const EmployeeCashWalletRow({
    required this.id,
    required this.profileId,
    required this.balance,
    required this.workerName,
  });
  final String id;
  final String profileId;
  final double balance;
  final String workerName;
}

/// Repozitář pro Zaměstnaneckou pokladnu (employee_cash_wallets, employee_cash_transactions).
///
/// Slouží k evidování hotovosti vybrané od hostů při úkolech Check-in a Transfer.
/// Všechny operace jdou přímo do Supabase – při offline režimu na mobilu volání selže.
class CashWalletRepository {
  CashWalletRepository._();
  static final CashWalletRepository instance = CashWalletRepository._();

  /// Zaznamená výběr hotovosti od hosta při dokončení úkolu.
  ///
  /// Provede: (a) nalezení nebo vytvoření peněženky pro (tenantId, profileId),
  /// (b) vložení transakce COLLECTED_FROM_GUEST, (c) zvýšení balance.
  /// Při síťové chybě (offline) uloží do MutationQueueService a vrací bez výjimky –
  /// Sync Engine po návratu sítě provede celý flow.
  ///
  /// PROČ: Peníze se nesmí ztratit. Pokud jsme offline, uložíme výběr do fronty
  /// a o procesování peněženky se postará Sync Engine.
  ///
  /// [profileId] – profiles.id aktuálně přihlášeného zaměstnance (převzal hotovost).
  /// [expectedAmount] – očekávaná částka z metadata.amount_to_collect (pro výpočet spropitného).
  /// [note] – volitelná poznámka (např. důvod nedoplatku: „Host pošle na účet. Poznámka: …“).
  /// [reservationId] – volitelně z UI; pokud je null, doplní se z [tasks.reservation_id] podle [taskId].
  /// [presetTransactionId] – volitelné UUID transakce (shoda s Drift řádkem po offline zápisu).
  /// [deferOfflineQueue] – true na mobilu, pokud má volající vlastní Drift + enqueue (jinak repository zařadí frontu).
  Future<void> recordCashCollection({
    required String taskId,
    required double amount,
    required String tenantId,
    required String profileId,
    double? expectedAmount,
    String? note,
    String? presetTransactionId,
    String? reservationId,
    bool deferOfflineQueue = false,
  }) async {
    if (amount <= 0) return;

    try {
      // Frontend Firewall: [safeFrom] místo holého klienta (Super Admin bypass RLS).
      final safeWallets = SupabaseService.safeFrom('employee_cash_wallets', tenantId);
      final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tenantId);
      final safeTasks = SupabaseService.safeFrom('tasks', tenantId);

      String? resolvedReservationId = reservationId?.trim();
      Map<String, dynamic>? taskMeta;
      try {
        final taskRow = await safeTasks
            .select('reservation_id, metadata')
            .eq('id', taskId)
            .maybeSingle();
        if (taskRow != null) {
          final rid = taskRow['reservation_id']?.toString().trim();
          if (rid != null && rid.isNotEmpty) {
            resolvedReservationId ??= rid;
          }
          final rawMeta = taskRow['metadata'];
          if (rawMeta is Map<String, dynamic>) {
            taskMeta = rawMeta;
          } else if (rawMeta is Map) {
            taskMeta = Map<String, dynamic>.from(rawMeta);
          }
        }
      } catch (_) {
        // PROČ: Rezervace / metadata jsou vylepšení; výběr hotovosti nesmí spadnout jen kvůli SELECT úkolu.
      }

      final transitPortion = _transitPortionForCashCollection(amount, taskMeta);

      // (a) Nalezení nebo vytvoření peněženky pro (tenant_id, profile_id)
      final existing = await safeWallets
          .select('id, balance')
          .eq('profile_id', profileId)
          .maybeSingle();

      String walletId;
      double currentBalance;

      if (existing == null) {
        final insertRes = await safeWallets.insert({
          'profile_id': profileId,
          'balance': 0,
        }).select('id').single();
        walletId = insertRes['id'] as String;
        currentBalance = 0;
      } else {
        walletId = existing['id'] as String;
        currentBalance = (_toDouble(existing['balance']) ?? 0);
      }

      // (b) Vložení transakce do účetní knihy (expected_amount pro výpočet spropitného; note pro nedoplatek)
      final presetTid = presetTransactionId?.trim();
      await safeTx.insert({
        if (presetTid != null && presetTid.isNotEmpty) 'id': presetTid,
        'wallet_id': walletId,
        'task_id': taskId,
        if (resolvedReservationId != null && resolvedReservationId.isNotEmpty)
          'reservation_id': resolvedReservationId,
        'amount': amount,
        if (transitPortion != null && transitPortion > 0) 'transit_portion': transitPortion,
        if (expectedAmount != null && expectedAmount > 0) 'expected_amount': expectedAmount,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'transaction_type': 'COLLECTED_FROM_GUEST',
        'created_by': profileId,
      });

      // (c) Zvýšení balance v peněžence
      final newBalance = currentBalance + amount;
      await safeWallets.update({
        'balance': newBalance,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', walletId);

      // PROČ: Informujeme dispečink o pohybu hotovosti. Zabaleno v try-catch,
      // aby případný výpadek notifikací neshodil finanční transakci.
      // Nedoplatek (amount < expected_amount) → varovná notifikace s typem finance_shortfall.
      final isShortfall = expectedAmount != null && expectedAmount > 0 && amount < expectedAmount;
      if (isShortfall) {
        final diff = expectedAmount - amount;
        final notePart = (note != null && note.trim().isNotEmpty) ? note.trim() : '';
        await _sendAdminNotification(
          tenantId: tenantId,
          profileId: profileId,
          title: 'admin.notification_cash_shortfall_title',
          message: '${diff.toStringAsFixed(2)}|$notePart',
          type: 'finance_shortfall',
        );
      } else {
        await _sendAdminNotification(
          tenantId: tenantId,
          profileId: profileId,
          title: 'Nová hotovost',
          message: 'Pracovník právě zaznamenal příjem ${amount.toStringAsFixed(2)} EUR.',
        );
      }
    } catch (e) {
      if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
        if (deferOfflineQueue) rethrow;
        // PROČ: Peníze se nesmí ztratit. Pokud jsme offline, uložíme výběr do fronty
        // a o procesování peněženky se postará Sync Engine.
        await MutationQueueService.instance.enqueueMutation(
          table: 'employee_cash_transactions',
          action: 'OFFLINE_CASH_COLLECTION',
          payload: {
            'tenant_id': tenantId,
            'profile_id': profileId,
            'task_id': taskId,
            'amount': amount,
            if (expectedAmount != null && expectedAmount > 0) 'expected_amount': expectedAmount,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            if (presetTransactionId != null && presetTransactionId.trim().isNotEmpty)
              'transaction_id': presetTransactionId.trim(),
          },
        );
        return;
      }
      rethrow;
    }
  }

  /// Zaznamená firemní výdaj z hotovosti u zaměstnance (např. nákup materiálu).
  ///
  /// Provede: (a) nalezení peněženky pro (tenantId, profileId), (b) vložení transakce
  /// COMPANY_EXPENSE se zápornou částkou, (c) snížení balance.
  /// Při síťové chybě (offline) uloží do MutationQueueService a vrací bez výjimky.
  ///
  /// [profileId] – profiles.id zaměstnance, který výdaj provedl (utrácí z vlastní kapsy).
  /// [amount] – kladná částka výdaje (do DB se ukládá jako záporná).
  /// [note] – povinná poznámka (např. „Materiál na úklid“).
  /// [receiptImageUrl] – volitelná URL fotky účtenky.
  /// [apartmentId] – volitelná vazba na apartmán; pro automatické stržení nákladů ve faktuře majitele.
  /// [clientId] – volitelná vazba na klienta; pro výdaje vázané na konkrétního klienta (např. externí).
  /// [presetTransactionId] – volitelné UUID řádku transakce (offline-first Drift + fronta se stejným id).
  /// [deferOfflineQueue] – true na mobilu, pokud má volající vlastní Drift + enqueue.
  Future<void> recordCompanyExpense({
    required String tenantId,
    required String profileId,
    required double amount,
    required String note,
    String? receiptImageUrl,
    String? apartmentId,
    String? clientId,
    String? presetTransactionId,
    bool deferOfflineQueue = false,
  }) async {
    if (amount <= 0) return;
    final noteTrimmed = note.trim();
    if (noteTrimmed.isEmpty) return;

    try {
      final safeWallets = SupabaseService.safeFrom('employee_cash_wallets', tenantId);
      final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tenantId);

      // (a) Nalezení peněženky – u firemního výdaje musí existovat (utrácíme z kapsy)
      final existing = await safeWallets
          .select('id, balance')
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existing == null) return; // Bez peněženky nelze utrácet

      final walletId = existing['id'] as String;
      final currentBalance = _toDouble(existing['balance']) ?? 0;
      if (currentBalance < amount) return; // Nedostatečný zůstatek

      // PROČ: Částka výdaje musí být záporná, protože snižuje hotovost,
      // kterou má pracovník u sebe. V účetní knize záporné = odliv peněz.
      final negativeAmount = -amount;

      // (b) Vložení transakce COMPANY_EXPENSE do účetní knihy
      final presetTid = presetTransactionId?.trim();
      await safeTx.insert({
        if (presetTid != null && presetTid.isNotEmpty) 'id': presetTid,
        'wallet_id': walletId,
        'task_id': null,
        if (apartmentId != null && apartmentId.trim().isNotEmpty) 'apartment_id': apartmentId.trim(),
        if (clientId != null && clientId.trim().isNotEmpty) 'client_id': clientId.trim(),
        'amount': negativeAmount,
        'transaction_type': 'COMPANY_EXPENSE',
        'note': noteTrimmed,
        if (receiptImageUrl != null && receiptImageUrl.trim().isNotEmpty)
          'receipt_image_url': receiptImageUrl.trim(),
        'created_by': profileId,
      });

      // (c) Snížení balance v peněžence
      final newBalance = currentBalance - amount;
      await safeWallets.update({
        'balance': newBalance,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', walletId);

      // PROČ: Informujeme dispečink o pohybu hotovosti. Zabaleno v try-catch,
      // aby případný výpadek notifikací neshodil finanční transakci.
      await _sendAdminNotification(
        tenantId: tenantId,
        profileId: profileId,
        title: 'Nový firemní výdaj',
        message: 'Pracovník zadal výdaj ${amount.toStringAsFixed(2)} EUR. Poznámka: $noteTrimmed',
      );
    } catch (e) {
      if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
        if (deferOfflineQueue) rethrow;
        // PROČ: Firemní výdaj se nesmí ztratit. Pokud jsme offline, uložíme do fronty
        // a Sync Engine po návratu sítě provede celý flow.
        await MutationQueueService.instance.enqueueMutation(
          table: 'employee_cash_transactions',
          action: 'OFFLINE_COMPANY_EXPENSE',
          payload: {
            'tenant_id': tenantId,
            'profile_id': profileId,
            'amount': amount,
            'note': noteTrimmed,
            if (presetTransactionId != null && presetTransactionId.trim().isNotEmpty)
              'transaction_id': presetTransactionId.trim(),
            if (receiptImageUrl != null && receiptImageUrl.trim().isNotEmpty)
              'receipt_image_url': receiptImageUrl.trim(),
            if (apartmentId != null && apartmentId.trim().isNotEmpty)
              'apartment_id': apartmentId.trim(),
            if (clientId != null && clientId.trim().isNotEmpty)
              'client_id': clientId.trim(),
          },
        );
        return;
      }
      rethrow;
    }
  }

  /// Částečné nebo celkové převzetí hotovosti od zaměstnance na centrále.
  /// Vkládá se záporná transakce HANDED_TO_AGENCY a balance se sníží o [amountToClear].
  /// PROČ: Umožňuje částečný výběr (např. vybrat 359 EUR z 459 EUR, zůstane 100 EUR na vracení).
  ///
  /// [adminProfileId] – profiles.id administrátora, který hotovost fyzicky převzal.
  /// Vyhazuje výjimku, pokud peněženka neexistuje nebo amountToClear > aktuální balance.
  Future<void> receiveCashFromWorker({
    required String walletId,
    required String workerProfileId,
    required double amountToClear,
    required String adminProfileId,
    required String tenantId,
    /// Volitelná vazba na rezervaci – pro stav „v trezoru agentury“ v průtokové hotovosti.
    String? reservationId,
  }) async {
    if (amountToClear <= 0) return;

    final safeWallets = SupabaseService.safeFrom('employee_cash_wallets', tenantId);
    final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tenantId);

    // (a) Načtení aktuálního zůstatku a validace – částečný výběr nesmí překročit balance
    final walletRow = await safeWallets
        .select('balance')
        .eq('id', walletId)
        .maybeSingle();

    if (walletRow == null) {
      throw Exception('CashWalletRepository: wallet not found');
    }
    final currentBalance = _toDouble(walletRow['balance']) ?? 0;
    if (amountToClear > currentBalance) {
      throw Exception(
        'CashWalletRepository: amountToClear ($amountToClear) exceeds current balance ($currentBalance)',
      );
    }

    final rid = reservationId?.trim();
    // (b) Vložení záporné transakce HANDED_TO_AGENCY
    await safeTx.insert({
      'wallet_id': walletId,
      'task_id': null,
      if (rid != null && rid.isNotEmpty) 'reservation_id': rid,
      'amount': -amountToClear,
      'transaction_type': 'HANDED_TO_AGENCY',
      'created_by': adminProfileId,
    });

    // (c) Snížení balance o vybranou částku (částečný výběr: zůstane zbytek; celý výběr: 0)
    final newBalance = currentBalance - amountToClear;
    await safeWallets.update({
      'balance': newBalance,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', walletId);
  }

  /// Vklad základu (float / kasírtaška) – admin zaměstnanci vloží hotovost na začátek směny.
  /// PROČ: Zaměstnanec potřebuje např. 100 EUR na vracení zákazníkům nebo nákupy.
  /// Najde nebo vytvoří peněženku, vloží kladnou transakci FLOAT_ISSUED a zvýší balance.
  ///
  /// [adminProfileId] – profiles.id administrátora, který vklad provedl.
  Future<void> issueFloatToWorker({
    required String tenantId,
    required String profileId,
    required double amount,
    String? note,
    required String adminProfileId,
  }) async {
    if (amount <= 0) return;

    final safeWallets = SupabaseService.safeFrom('employee_cash_wallets', tenantId);
    final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tenantId);

    // (a) Nalezení nebo vytvoření peněženky pro (tenant_id, profile_id) – stejná logika jako recordCashCollection
    final existing = await safeWallets
        .select('id, balance')
        .eq('profile_id', profileId)
        .maybeSingle();

    String walletId;
    double currentBalance;

    if (existing == null) {
      final insertRes = await safeWallets.insert({
        'profile_id': profileId,
        'balance': 0,
      }).select('id').single();
      walletId = insertRes['id'] as String;
      currentBalance = 0;
    } else {
      walletId = existing['id'] as String;
      currentBalance = (_toDouble(existing['balance']) ?? 0);
    }

    // (b) Vložení kladné transakce FLOAT_ISSUED do účetní knihy
    await safeTx.insert({
      'wallet_id': walletId,
      'task_id': null,
      'amount': amount,
      'transaction_type': 'FLOAT_ISSUED',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'created_by': adminProfileId,
    });

    // (c) Zvýšení balance v peněžence
    final newBalance = currentBalance + amount;
    await safeWallets.update({
      'balance': newBalance,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', walletId);
  }

  /// Načte seznam peněženek zaměstnanců s join na profiles pro jména.
  /// Vrací mapu: walletId -> {id, profileId, balance, workerName}.
  Future<List<EmployeeCashWalletRow>> fetchWalletsForTenant(String tenantId) async {
    final res = await SupabaseService.safeFrom('employee_cash_wallets', tenantId)
        .select('id, profile_id, balance, profiles(name, first_name, last_name)');

    final list = List<dynamic>.from(res as List);
    final rows = <EmployeeCashWalletRow>[];
    for (final e in list) {
      final map = Map<String, dynamic>.from(e as Map);
      final id = map['id']?.toString().trim();
      final profileId = map['profile_id']?.toString().trim();
      if (id == null || id.isEmpty || profileId == null || profileId.isEmpty) continue;

      final balance = _toDouble(map['balance']) ?? 0;
      final profilesData = map['profiles'];
      String workerName = 'common.placeholder_dash'.tr();
      if (profilesData != null && profilesData is Map) {
        final p = Map<String, dynamic>.from(profilesData);
        final name = (p['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          workerName = name;
        } else {
          final first = (p['first_name'] as String?)?.trim() ?? '';
          final last = (p['last_name'] as String?)?.trim() ?? '';
          workerName = '$first $last'.trim().isEmpty ? 'common.placeholder_dash'.tr() : '$first $last'.trim();
        }
      }
      rows.add(EmployeeCashWalletRow(
        id: id,
        profileId: profileId,
        balance: balance,
        workerName: workerName,
      ));
    }
    return rows;
  }

  /// Realtime stream peněženek zaměstnanců pro daného tenanta.
  ///
  /// PROČ: Realtime stream pro okamžitou synchronizaci stavu peněženky mezi terénem
  /// a dispečinkem (Supabase WebSockets). Výběr hotovosti uklízečkou se v administraci
  /// projeví bez nutnosti F5.
  ///
  /// PROČ resilientSupabaseStream: Chyby WebSocketu (Code 1000) se nikdy nepropagují do
  /// Riverpodu – UI zůstane stabilní, reconnect proběhne tiše na pozadí.
  ///
  /// OMEZENÍ: Stream vrací surové řádky bez JOIN na profiles – obohacení o jméno
  /// provede provider (nameByProfileId z adminTeamProvider).
  /// PROČ: Bezpečnostní limit 500 záznamů, aby nedošlo k zahlcení paměti u velkých agentur.
  Stream<List<Map<String, dynamic>>> watchWalletsRaw(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);
    return resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.safeFrom('employee_cash_wallets', tenantId)
          .stream(primaryKey: ['id'])
          .order('updated_at', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) {
            rows.sort((a, b) {
              final aBal = _toDouble(a['balance']) ?? 0;
              final bBal = _toDouble(b['balance']) ?? 0;
              if (bBal > 0 && aBal <= 0) return 1;
              if (aBal > 0 && bBal <= 0) return -1;
              return (bBal - aBal).sign.toInt();
            });
            return rows;
          }),
      debugLabel: 'CashWalletRepository.watchWalletsRaw',
    );
  }

  /// Realtime stream transakcí (výběry, odevzdání) pro daného tenanta.
  ///
  /// PROČ: Realtime stream pro okamžitou synchronizaci stavu peněženky mezi terénem
  /// a dispečinkem (Supabase WebSockets). Pro historii transakcí v budoucím UI.
  /// PROČ resilientSupabaseStream: Chyby WebSocketu (Code 1000) se nikdy nepropagují do Riverpodu.
  /// PROČ: Bezpečnostní limit 500 záznamů, aby nedošlo k zahlcení paměti u velkých agentur.
  Stream<List<Map<String, dynamic>>> watchTransactionsRaw(String tenantId) {
    if (tenantId.isEmpty) return Stream.value([]);
    return resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.safeFrom('employee_cash_transactions', tenantId)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) {
            rows.sort((a, b) {
              final aT = a['created_at']?.toString() ?? '';
              final bT = b['created_at']?.toString() ?? '';
              return bT.compareTo(aT);
            });
            return rows;
          }),
      debugLabel: 'CashWalletRepository.watchTransactionsRaw',
    );
  }

  /// Realtime stream transakcí pro konkrétní peněženku zaměstnance.
  ///
  /// PROČ: Detail peněženky v Admin UI – historie výběrů, odevzdání a firemních výdajů.
  /// Nové transakce z terénu se zobrazí okamžitě bez refreshe.
  /// PROČ resilientSupabaseStream: Chyby WebSocketu (Code 1000) se nikdy nepropagují do Riverpodu.
  /// Filtrujeme podle wallet_id v map – stream API podporuje jen jeden inFilter.
  /// PROČ: Bezpečnostní limit 200 záznamů, aby nedošlo k zahlcení paměti u velkých agentur.
  Stream<List<Map<String, dynamic>>> watchTransactionsRawForWallet(
    String tenantId,
    String walletId,
  ) {
    if (tenantId.isEmpty || walletId.isEmpty) return Stream.value([]);
    return resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.safeFrom('employee_cash_transactions', tenantId)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(200)
          .map((List<Map<String, dynamic>> rows) {
            final filtered =
                rows.where((r) => (r['wallet_id']?.toString() ?? '') == walletId).toList();
            filtered.sort((a, b) {
              final aT = a['created_at']?.toString() ?? '';
              final bT = b['created_at']?.toString() ?? '';
              return bT.compareTo(aT);
            });
            return filtered;
          }),
      debugLabel: 'CashWalletRepository.watchTransactionsRawForWallet',
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Část [collectedAmount], která připadá na průtok majiteli (po alokaci `amount_to_collect` = agentura).
  static double? _transitPortionForCashCollection(
    double collectedAmount,
    Map<String, dynamic>? meta,
  ) {
    if (collectedAmount <= 0 || meta == null) return null;
    final rawT = meta['transit_amount_to_collect'];
    final transitPlan = (rawT is num)
        ? rawT.toDouble()
        : (rawT != null ? double.tryParse(rawT.toString()) : null);
    if (transitPlan == null || transitPlan <= 0) return null;

    final rawA = meta['amount_to_collect'];
    var agencyPlan = 0.0;
    if (rawA != null) {
      if (rawA is num) {
        agencyPlan = rawA.toDouble();
      } else {
        agencyPlan = double.tryParse(rawA.toString()) ?? 0.0;
      }
    }
    final afterAgency = collectedAmount > agencyPlan ? collectedAmount - agencyPlan : 0.0;
    final p = afterAgency < transitPlan ? afterAgency : transitPlan;
    if (p <= 0) return null;
    return p;
  }

  /// Odešle notifikaci všem adminům/manažerům dané agentury.
  ///
  /// PROČ: Informujeme dispečink o pohybu hotovosti (výběr od hosta, firemní výdaj).
  /// Zabaleno v try-catch – selhání notifikací nikdy nesmí zabránit uložení peněz.
  /// [type] – volitelný typ (finance, finance_shortfall); finance_shortfall zobrazí dispečer červeně.
  Future<void> _sendAdminNotification({
    required String tenantId,
    required String profileId,
    required String title,
    required String message,
    String type = 'finance',
  }) async {
    try {
      // Načtení IDs všech adminů a manažerů agentury (dispečerů s přístupem do administrace)
      final adminsRes = await SupabaseService.safeFrom('profiles', tenantId)
          .select('id')
          .inFilter('role', ['admin', 'manager'])
          .isFilter('deleted_at', null);

      final admins = List<dynamic>.from(adminsRes as List);
      if (admins.isEmpty) return;

      final payloads = <Map<String, dynamic>>[];
      for (final a in admins) {
        final m = Map<String, dynamic>.from(a as Map);
        final adminId = (m['id'] as String?)?.trim();
        if (adminId == null || adminId.isEmpty) continue;
        payloads.add({
          'profile_id': adminId,
          'title': title,
          'message': message,
          'type': type,
        });
      }
      if (payloads.isEmpty) return;

      // Batch insert neprojde přes [SafeTenantTable.insert] – každý řádek přes [safeInsertPayload].
      final safeRows = payloads
          .map((p) => SupabaseService.safeInsertPayload(tenantId, p))
          .toList();
      await SupabaseService.safeFrom('notifications', tenantId).insert(safeRows);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('CashWalletRepository: Nepodařilo se odeslat notifikaci adminům: $e');
      }
    }
  }
}
