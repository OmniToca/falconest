import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/repositories/cash/reservation_cash_transit_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_enrich_supabase.dart';

export 'finance_cash_worker_wallet.dart';

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
    yield await enrichCashTransactionsWithSupabase(tenantId, rows);
  }
});

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

      final title = (map['title'] as String?)?.trim() ?? 'common.placeholder_dash'.tr();
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
  } catch (e, st) {
    AppLogger.error('failedCashCollectionsProvider: načtení nevybrané hotovosti selhalo', e, st);
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

/// Průtoková hotovost za ubytování – lidský stav pro jednu rezervaci (ledger + settlement).
final reservationCashTransitProvider =
    FutureProvider.autoDispose.family<ReservationCashTransitSnapshot, String>((ref, reservationId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || reservationId.trim().isEmpty) {
    return const ReservationCashTransitSnapshot(phase: ReservationCashTransitPhase.notApplicable);
  }
  return ReservationCashTransitRepository.resolve(
    tenantId: tenantId,
    reservationId: reservationId.trim(),
  );
});

extension ReservationCashTransitPhaseX on ReservationCashTransitPhase {
  /// Klíč pro EasyLocalization (`finance.cash_transit_phase_*`).
  String get labelTranslationKey => switch (this) {
        ReservationCashTransitPhase.notApplicable => 'finance.cash_transit_phase_not_applicable',
        ReservationCashTransitPhase.awaitingCollection => 'finance.cash_transit_phase_awaiting_collection',
        ReservationCashTransitPhase.withWorker => 'finance.cash_transit_phase_with_worker',
        ReservationCashTransitPhase.atAgencyVault => 'finance.cash_transit_phase_at_agency',
        ReservationCashTransitPhase.settledToOwner => 'finance.cash_transit_phase_settled',
      };
}
