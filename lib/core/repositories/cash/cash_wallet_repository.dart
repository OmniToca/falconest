import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/services/supabase_service.dart';

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
  Future<void> recordCashCollection({
    required String taskId,
    required double amount,
    required String tenantId,
    required String profileId,
  }) async {
    if (amount <= 0) return;

    try {
      final client = SupabaseService.client;

      // (a) Nalezení nebo vytvoření peněženky pro (tenant_id, profile_id)
      final existing = await client
          .from('employee_cash_wallets')
          .select('id, balance')
          .eq('tenant_id', tenantId)
          .eq('profile_id', profileId)
          .maybeSingle();

      String walletId;
      double currentBalance;

      if (existing == null) {
        final insertRes = await client.from('employee_cash_wallets').insert({
          'tenant_id': tenantId,
          'profile_id': profileId,
          'balance': 0,
        }).select('id').single();
        walletId = insertRes['id'] as String;
        currentBalance = 0;
      } else {
        walletId = existing['id'] as String;
        currentBalance = (_toDouble(existing['balance']) ?? 0);
      }

      // (b) Vložení transakce do účetní knihy
      await client.from('employee_cash_transactions').insert({
        'tenant_id': tenantId,
        'wallet_id': walletId,
        'task_id': taskId,
        'amount': amount,
        'transaction_type': 'COLLECTED_FROM_GUEST',
        'created_by': profileId,
      });

      // (c) Zvýšení balance v peněžence
      final newBalance = currentBalance + amount;
      await client
          .from('employee_cash_wallets')
          .update({'balance': newBalance, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', walletId);
    } catch (e) {
      if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
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
          },
        );
        return;
      }
      rethrow;
    }
  }

  /// Vynulování kapsy zaměstnance po odevzdání hotovosti na centrále.
  /// Vkládá se záporná transakce HANDED_TO_AGENCY a balance se odečte na 0.
  ///
  /// [adminProfileId] – profiles.id administrátora, který hotovost fyzicky převzal.
  Future<void> receiveCashFromWorker({
    required String walletId,
    required String workerProfileId,
    required double amountToClear,
    required String adminProfileId,
    required String tenantId,
  }) async {
    if (amountToClear <= 0) return;

    final client = SupabaseService.client;

    // (a) Vložení záporné transakce HANDED_TO_AGENCY
    await client.from('employee_cash_transactions').insert({
      'tenant_id': tenantId,
      'wallet_id': walletId,
      'task_id': null,
      'amount': -amountToClear,
      'transaction_type': 'HANDED_TO_AGENCY',
      'created_by': adminProfileId,
    });

    // (b) Odečtení balance na 0
    await client
        .from('employee_cash_wallets')
        .update({'balance': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', walletId);
  }

  /// Načte seznam peněženek zaměstnanců s join na profiles pro jména.
  /// Vrací mapu: walletId -> {id, profileId, balance, workerName}.
  Future<List<EmployeeCashWalletRow>> fetchWalletsForTenant(String tenantId) async {
    final client = SupabaseService.client;
    final res = await client
        .from('employee_cash_wallets')
        .select('id, profile_id, balance, profiles(name, first_name, last_name)')
        .eq('tenant_id', tenantId);

    final list = List<dynamic>.from(res as List);
    final rows = <EmployeeCashWalletRow>[];
    for (final e in list) {
      final map = Map<String, dynamic>.from(e as Map);
      final id = map['id']?.toString().trim();
      final profileId = map['profile_id']?.toString().trim();
      if (id == null || id.isEmpty || profileId == null || profileId.isEmpty) continue;

      final balance = _toDouble(map['balance']) ?? 0;
      final profilesData = map['profiles'];
      String workerName = '—';
      if (profilesData != null && profilesData is Map) {
        final p = Map<String, dynamic>.from(profilesData);
        final name = (p['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          workerName = name;
        } else {
          final first = (p['first_name'] as String?)?.trim() ?? '';
          final last = (p['last_name'] as String?)?.trim() ?? '';
          workerName = '$first $last'.trim().isEmpty ? '—' : '$first $last'.trim();
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

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
