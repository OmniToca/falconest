import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// Realtime stream peněženek zaměstnanců (Zaměstnanecká pokladna) pro aktuální tenanta.
///
/// PROČ: Výběr hotovosti uklízečkou v terénu se v administraci projeví okamžitě bez F5.
/// Supabase WebSockets zajišťují push aktualizaci stavu balance.
final employeeCashWalletsProvider =
    StreamProvider<List<EmployeeCashWalletRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final team = await ref.watch(teamFullListProvider.future);
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final pid = m.profileId ?? m.id;
    if (pid.isNotEmpty) nameByProfileId[pid] = m.name;
  }

  await for (final rawList
      in CashWalletRepository.instance.watchWalletsRaw(tenantId)) {
    final rows = rawList.map((raw) {
      final id = (raw['id'] as String?)?.trim() ?? '';
      final profileId = (raw['profile_id'] as String?)?.trim() ?? '';
      final balance = _toDouble(raw['balance']) ?? 0;
      final workerName = nameByProfileId[profileId] ?? 'common.removed_user'.tr();
      return EmployeeCashWalletRow(
        id: id,
        profileId: profileId,
        balance: balance,
        workerName: workerName,
      );
    }).toList();
    yield rows;
  }
});

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Peněženka aktuálně přihlášeného pracovníka (Worker UI).
///
/// BEZPEČNOST: Filtrujeme striktně podle profile_id přihlášeného uživatele.
/// Pracovník nikdy nevidí peněženky ostatních.
final myCashWalletProvider =
    StreamProvider<EmployeeCashWalletRow?>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    yield null;
    return;
  }

  await for (final rawList
      in CashWalletRepository.instance.watchWalletsRaw(tenantId)) {
    final match = rawList.cast<Map<String, dynamic>>().where((raw) {
      final pid = (raw['profile_id'] as String?)?.trim() ?? '';
      return pid == profileId;
    }).toList();
    if (match.isEmpty) {
      yield null;
      continue;
    }
    final raw = match.first;
    yield EmployeeCashWalletRow(
      id: (raw['id'] as String?)?.trim() ?? '',
      profileId: (raw['profile_id'] as String?)?.trim() ?? '',
      balance: _toDouble(raw['balance']) ?? 0,
      workerName: '', // Worker vidí vlastní peněženku – jméno není potřeba
    );
  }
});

/// Transakce aktuálně přihlášeného pracovníka (Worker UI) – obohacené o kontext z úkolů.
///
/// BEZPEČNOST: Pouze transakce vlastní peněženky (wallet_id z myCashWalletProvider).
/// Seřazeno od nejnovějších. Načítá apartmentName a guestName z tasks pro COLLECTED_FROM_GUEST.
final myCashTransactionsProvider =
    StreamProvider<List<CashTransactionUIModel>>((ref) async* {
  final walletAsync = ref.watch(myCashWalletProvider);
  final wallet = walletAsync.valueOrNull;
  if (wallet == null || wallet.id.isEmpty) {
    yield [];
    return;
  }

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  await for (final rows
      in CashWalletRepository.instance.watchTransactionsRawForWallet(
    tenantId,
    wallet.id,
  )) {
    yield await _enrichTransactions(tenantId, rows);
  }
});

/// Realtime stream transakcí pro konkrétní peněženku zaměstnance – obohacené o kontext z úkolů.
///
/// PROČ: Detail peněženky v Admin UI – historie výběrů, odevzdání, firemních výdajů.
/// Nové transakce z terénu se zobrazí okamžitě bez refreshe.
/// Načítá apartmentName a guestName z tasks pro COLLECTED_FROM_GUEST.
final walletTransactionsProvider =
    StreamProvider.autoDispose.family<List<CashTransactionUIModel>, String>((ref, walletId) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || walletId.isEmpty) {
    yield [];
    return;
  }

  await for (final rows
      in CashWalletRepository.instance.watchTransactionsRawForWallet(
    tenantId,
    walletId,
  )) {
    yield await _enrichTransactions(tenantId, rows);
  }
});

/// Obohací syrové transakce o kontext z úkolů (apartmán, host) a klientů (jméno, typ).
///
/// PROČ: Supabase stream neumožňuje join v realtime. Po obdržení transakcí
/// načteme tasks s apartments(name) a reservations(guest_name) jedním dotazem,
/// a clients (name, client_type) pro transakce s client_id.
Future<List<CashTransactionUIModel>> _enrichTransactions(
  String tenantId,
  List<Map<String, dynamic>> rows,
) async {
  final taskIds = rows
      .map((r) => (r['task_id'] as String?)?.trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final taskInfo = <String, ({String? apartmentName, String? guestName, String? taskTitle})>{};

  if (taskIds.isNotEmpty) {
    try {
      final res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, title, apartments(name), reservations(guest_name)')
          .inFilter('id', taskIds)
          .isFilter('deleted_at', null);

      for (final t in res as List) {
        final m = Map<String, dynamic>.from(t);
        final id = (m['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;

        String? apartmentName;
        String? guestName;
        String? taskTitle;

        final title = (m['title'] as String?)?.trim();
        if (title != null && title.isNotEmpty) taskTitle = title;

        final apt = m['apartments'];
        if (apt != null && apt is Map) {
          apartmentName = (apt['name'] as String?)?.trim();
          if (apartmentName?.isEmpty == true) apartmentName = null;
        }
        final resData = m['reservations'];
        if (resData != null && resData is Map) {
          guestName = (resData['guest_name'] as String?)?.trim();
          if (guestName?.isEmpty == true) guestName = null;
        }

        taskInfo[id] = (apartmentName: apartmentName, guestName: guestName, taskTitle: taskTitle);
      }
    } catch (_) {
      // BACKWARD COMPATIBILITY: Selhání enrichementu nesmí rozbít UI – vrátíme transakce bez kontextu.
    }
  }

  // Načtení kontextu klientů – pro transakce s client_id (např. externí platba).
  final clientIds = rows
      .map((r) => (r['client_id'] as String?)?.trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final clientInfo = <String, ({String? name, String? clientType})>{};

  if (clientIds.isNotEmpty) {
    try {
      final res = await SupabaseService.safeFrom('clients', tenantId)
          .select('id, name, client_type')
          .inFilter('id', clientIds)
          .isFilter('deleted_at', null);

      for (final c in res as List) {
        final m = Map<String, dynamic>.from(c);
        final id = (m['id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;

        final name = (m['name'] as String?)?.trim();
        final clientType = (m['client_type'] as String?)?.trim();

        clientInfo[id] = (
          name: name != null && name.isNotEmpty ? name : null,
          clientType: clientType != null && clientType.isNotEmpty ? clientType : null,
        );
      }
    } catch (_) {
      // BACKWARD COMPATIBILITY: Selhání enrichementu klientů nesmí rozbít UI.
    }
  }

  return rows.map((r) {
    final taskId = (r['task_id'] as String?)?.trim();
    final clientId = (r['client_id'] as String?)?.trim();
    final taskCtx = taskId != null && taskId.isNotEmpty ? taskInfo[taskId] : null;
    final clientCtx = clientId != null && clientId.isNotEmpty ? clientInfo[clientId] : null;

    return CashTransactionUIModel(
      raw: Map<String, dynamic>.from(r),
      apartmentName: taskCtx?.apartmentName,
      guestName: taskCtx?.guestName,
      taskTitle: taskCtx?.taskTitle,
      clientName: clientCtx?.name,
      clientType: clientCtx?.clientType,
    );
  }).toList();
}

/// Řádek úkolu s nevybranou hotovostí – pro sekci alertů v Zaměstnanecké pokladně.
class FailedCashCollectionRow {
  const FailedCashCollectionRow({
    required this.taskId,
    required this.taskTitle,
    required this.workerName,
    required this.completedAt,
    required this.amountToCollect,
  });
  final String taskId;
  final String taskTitle;
  final String workerName;
  final DateTime? completedAt;
  final double amountToCollect;
}

/// Sekce kritických alertů: Zobrazuje úkoly, kde pracovník v terénu nepotvrdil výběr hotovosti.
/// Načte completed úkoly s metadata.cash_collection_failed == true (bez cash_collection_resolved).
final failedCashCollectionsProvider =
    FutureProvider<List<FailedCashCollectionRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    final res = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          'id, title, metadata, completed_at, assigned_to, profiles!tasks_assigned_to_fkey(name, first_name, last_name)',
        )
        .eq('status', 'completed')
        .isFilter('deleted_at', null)
        .filter('metadata', 'cs', '{"cash_collection_failed": true}');

    final list = List<dynamic>.from(res as List);
    final rows = <FailedCashCollectionRow>[];

    for (final e in list) {
      final map = Map<String, dynamic>.from(e);
      final id = map['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;

      final meta = map['metadata'];
      if (meta == null || meta is! Map) continue;
      final metaMap = Map<String, dynamic>.from(meta);
      if (metaMap['cash_collection_resolved'] == true) continue;

      final amountRaw = metaMap['amount_to_collect'];
      final amount = (amountRaw is num)
          ? amountRaw.toDouble()
          : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
      if (amount == null || amount <= 0) continue;

      final title = (map['title'] as String?)?.trim() ?? '—';
      String workerName = 'common.removed_user'.tr();
      // BUGFIX: PostgREST vrací pod profiles!tasks_assigned_to_fkey při explicitním FK.
      final profilesData = map['profiles'] ?? map['profiles!tasks_assigned_to_fkey'];
      if (profilesData != null && profilesData is Map) {
        final p = Map<String, dynamic>.from(profilesData);
        final name = (p['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          workerName = name;
        } else {
          final first = (p['first_name'] as String?)?.trim() ?? '';
          final last = (p['last_name'] as String?)?.trim() ?? '';
          workerName = '$first $last'.trim().isEmpty ? 'common.removed_user'.tr() : '$first $last'.trim();
        }
      }

      DateTime? completedAt;
      final raw = map['completed_at'];
      if (raw != null) {
        if (raw is DateTime) {
          completedAt = raw;
        } else if (raw is String) {
          completedAt = DateTime.tryParse(raw);
        }
      }

      rows.add(FailedCashCollectionRow(
        taskId: id,
        taskTitle: title,
        workerName: workerName,
        completedAt: completedAt,
        amountToCollect: amount,
      ));
    }
    return rows;
  } catch (_) {
    return [];
  }
});

/// Označí úkol s nevybranou hotovostí jako vyřešený.
/// Nastaví v metadata: cash_collection_failed: false, cash_collection_resolved: true.
Future<void> resolveFailedCashCollection(WidgetRef ref, String taskId) async {
  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return;

  final res = await SupabaseService.safeFrom('tasks', tenantId)
      .select('metadata')
      .eq('id', taskId)
      .maybeSingle();

  if (res == null) return;

  final resMap = res;
  final existing = resMap['metadata'];
  final meta = existing != null && existing is Map
      ? Map<String, dynamic>.from(existing)
      : <String, dynamic>{};
  meta['cash_collection_failed'] = false;
  meta['cash_collection_resolved'] = true;

  await SupabaseService.safeFrom('tasks', tenantId)
      .update({'metadata': meta})
      .eq('id', taskId);

  ref.invalidate(failedCashCollectionsProvider);
}

/// Počet transakcí s nedoplatkem (expected_amount != null a amount < expected_amount) za aktuálního tenanta.
///
/// PROČ: Nástěnka zobrazuje dlaždici „Nedoplatky v hotovosti“ a odkaz na Finance.
/// Filtrujeme transakce za posledních 14 dní, aby byl přehled relevantní a bez zbytečných rebuildů.
final cashShortfallsCountProvider = StreamProvider<int>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield 0;
    return;
  }

  final since = DateTime.now().toUtc().subtract(const Duration(days: 14));

  await for (final rows
      in CashWalletRepository.instance.watchTransactionsRaw(tenantId)) {
    int count = 0;
    for (final r in rows) {
      final amount = _toDouble(r['amount']);
      final expected = _toDouble(r['expected_amount']);
      if (expected == null || amount == null || amount >= expected) continue;
      if (r['is_shortfall_resolved'] == true) continue;
      final createdRaw = r['created_at'];
      DateTime? created;
      if (createdRaw != null) {
        if (createdRaw is DateTime) {
          created = createdRaw.toUtc();
        } else if (createdRaw is String) {
          created = DateTime.tryParse(createdRaw)?.toUtc();
        }
      }
      if (created != null && created.isAfter(since)) count++;
    }
    yield count;
  }
});
