import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/task_commission_model.dart';
import 'package:falconest/core/models/task_payout_model.dart';
import 'package:falconest/core/repositories/settlements/settlement_repository.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// Jedna položka v rozbaleném seznamu „K výplatě“ – úkol, datum, částka pro daného příjemce.
///
/// PROČ: Rozbalovací karta zobrazuje historii – z jakých úkolů se celková suma skládá.
class PayoutLineItem {
  const PayoutLineItem({
    required this.taskId,
    required this.taskTitle,
    this.date,
    required this.amount,
  });

  final String taskId;
  final String taskTitle;
  final DateTime? date;
  final double amount;
}

/// Jedna skupina k výplatě – buď Zaměstnanec (payouts) nebo Partner (commissions).
///
/// PROČ: Admin vidí přehled „komu dlužíme kolik“ – seskupeno podle příjemce.
/// [items] = rozpad po úkolech pro rozbalovací seznam (název úkolu, datum, částka).
class PayoutGroup {
  const PayoutGroup({
    required this.isEmployee,
    required this.recipientId,
    required this.recipientName,
    required this.totalAmount,
    required this.payoutIds,
    required this.commissionIds,
    this.items = const [],
  });

  /// true = Zaměstnanec (task_payouts), false = Partner (task_commissions).
  final bool isEmployee;
  /// profile_id nebo client_id.
  final String recipientId;
  /// Zobrazené jméno (z profiles nebo clients).
  final String recipientName;
  /// Součet částek všech záznamů ve skupině.
  final double totalAmount;
  /// ID výplat z task_payouts – neprázdné jen když isEmployee.
  final List<String> payoutIds;
  /// ID provizí z task_commissions – u zaměstnanců (profile_id) i partnerů (client_id).
  final List<String> commissionIds;
  /// Rozpad po úkolech – pro rozbalovací kartu (název, datum, částka).
  final List<PayoutLineItem> items;
}

/// Data pro záložku „K výplatě“ – skupiny příjemců + celkový zisk agentury (marže).
///
/// PROČ: Jedna struktura vracená providerem – skupiny i souhrnná marže po schválení výplat.
class PayrollTabData {
  const PayrollTabData({
    required this.groups,
    required this.agencyMarginTotal,
  });

  final List<PayoutGroup> groups;
  /// Součet (hodnota úkolů − výplaty − provize) za všechny pending záznamy.
  final double agencyMarginTotal;
}

/// Provider: množina ID úkolů, které už mají záznam v task_payouts.
///
/// PROČ: Fronta "Ke schválení" vylučuje tyto úkoly – Admin u nich již rozdělil peníze.
/// Invalidace po approveSettlement zajistí, že schválený úkol okamžitě zmizí z fronty.
final taskIdsWithPayoutsProvider =
    FutureProvider<Set<String>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return {};

  return SettlementRepository.instance.getTaskIdsWithPayouts(tenantId);
});

/// Provider: množina ID úkolů, které už mají záznam v task_commissions.
///
/// PROČ: Finanční zámek – úkoly s provizemi nelze upravovat (ochrana účetnictví).
/// Spolu s taskIdsWithPayoutsProvider slouží pro sestavení úplné množiny uzamčených úkolů.
final taskIdsWithCommissionsProvider =
    FutureProvider<Set<String>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return {};

  return SettlementRepository.instance.getTaskIdsWithCommissions(tenantId);
});

/// Provider: sjednocení úkolů s výplatami a s provizemi – úkoly finančně uzamčené.
///
/// PROČ: Jediný zdroj pravdy pro „nelze upravovat“ v UI (dialog úkolu, Kanban drag/delete).
/// Jakmile úkol má záznam v task_payouts NEBO task_commissions, je uzamčen natrvalo.
final lockedFinancialTaskIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  final payouts = await ref.watch(taskIdsWithPayoutsProvider.future);
  final commissions = await ref.watch(taskIdsWithCommissionsProvider.future);
  return payouts.union(commissions);
});

/// Provider: fronta úkolů "Ke schválení" – globální INBOX dokončených úkolů bez vyúčtování.
///
/// LOGIKA: Načte data přímo z [SettlementRepository.getAllPendingSettlementTasks] – dokončené
/// úkoly (status completed/done/hotovo/dokončeno) bez záznamu v task_payouts. Žádná závislost
/// na [selectedTaskMonthProvider] ani [adminTasksStreamProvider].
///
/// PROČ: Fronta byla odpojena od měsíčního filtru kalendáře – při přepnutí měsíce v záložce Úkoly
/// by jinak zmizely nevyúčtované úkoly z jiných měsíců a hrozilo by riziko nevyplacení mzdy.
/// Finance tak mají vlastní nezávislý zdroj dat; záložka Úkoly dál používá watchTasksRawForMonth.
final pendingSettlementsProvider =
    FutureProvider<List<TaskRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final rawList = await SettlementRepository.instance.getAllPendingSettlementTasks(tenantId);
  if (rawList.isEmpty) return [];

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  return rawList
      .map((raw) => TaskRow.fromSupabaseRow(
            Map<String, dynamic>.from(raw),
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          ))
      .toList();
});

/// Načte již uložené výplaty a provize pro konkrétní úkol.
///
/// PROČ: UI může zobrazit historii vyúčtování nebo předvyplnit formulář.
final taskSettlementsProvider =
    FutureProvider.autoDispose.family<TaskSettlements, String>((ref, taskId) async {
  if (taskId.trim().isEmpty) {
    return const TaskSettlements(payouts: [], commissions: []);
  }
  return SettlementRepository.instance.getSettlementsForTask(taskId);
});

/// Uloží schválené vyúčtování (výplaty + provize) a invaliduje frontu.
///
/// PROČ: Jediná akce pro Admin – po zadání výplat a provizí v UI se data uloží
/// do Supabase a úkol zmizí z fronty "Ke schválení".
///
/// [ref] – Riverpod Ref (WidgetRef nebo Ref z provideru) pro invalidaci.
/// [taskId] – úkol, ke kterému se vyúčtování váže.
/// [payouts] – výplaty pracovníkům (profile_id, amount; status bude 'pending' nebo 'approved').
/// [commissions] – provize partnerům (client_id, amount; status stejně).
///
/// Vyhazuje [Exception] při chybě Supabase. Volající má obalit v try-catch
/// a zobrazit uživateli chybovou hlášku.
Future<void> approveSettlement({
  required dynamic ref,
  required String taskId,
  required List<TaskPayoutModel> payouts,
  required List<TaskCommissionModel> commissions,
}) async {
  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    throw StateError('Nelze schválit vyúčtování bez tenant ID.');
  }

  await SettlementRepository.instance.saveSettlement(
    tenantId: tenantId,
    taskId: taskId.trim(),
    payouts: payouts,
    commissions: commissions,
  );

  // PROČ: Schválený úkol má nyní záznam v task_payouts – musí zmizet z fronty.
  // Invalidace taskIdsWithPayoutsProvider způsobí refetch; pendingSettlementsProvider
  // na ní závisí a přepočítá se s novou množinou.
  ref.invalidate(taskIdsWithPayoutsProvider);
  ref.invalidate(taskIdsWithCommissionsProvider);
  ref.invalidate(lockedFinancialTaskIdsProvider);
  ref.invalidate(pendingSettlementsProvider);
}

/// Extrahuje jméno z profiles objektu (first_name + last_name nebo name).
String _profileDisplayName(Map<String, dynamic>? profiles) {
  if (profiles == null) return '';
  final name = (profiles['name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;
  final first = (profiles['first_name'] as String?)?.trim() ?? '';
  final last = (profiles['last_name'] as String?)?.trim() ?? '';
  return '$first $last'.trim().isEmpty ? '' : '$first $last'.trim();
}

/// Z raw řádku (payout/commission) s joinem na tasks vrátí název úkolu.
String _taskTitleFromRow(Map<String, dynamic> row) {
  final tasks = row['tasks'];
  if (tasks is! Map) return '';
  final t = Map<String, dynamic>.from(tasks);
  final custom = (t['custom_title'] as String?)?.trim();
  final title = (t['title'] as String?)?.trim();
  return (custom != null && custom.isNotEmpty) ? custom : (title ?? '');
}

/// Z raw řádku vrátí datum úkolu (completed_at nebo scheduled_start).
DateTime? _taskDateFromRow(Map<String, dynamic> row) {
  final tasks = row['tasks'];
  if (tasks is! Map) return null;
  final t = Map<String, dynamic>.from(tasks);
  final completed = t['completed_at'];
  if (completed != null) {
    final d = completed is DateTime ? completed : DateTime.tryParse(completed.toString());
    if (d != null) return d;
  }
  final scheduled = t['scheduled_start'];
  if (scheduled != null) {
    final d = scheduled is DateTime ? scheduled : DateTime.tryParse(scheduled.toString());
    if (d != null) return d;
  }
  return null;
}

/// Z raw řádku (tasks.metadata) vrátí celkovou hodnotu úkolu pro výpočet marže.
double _taskValueFromRow(Map<String, dynamic> row) {
  final tasks = row['tasks'];
  if (tasks is! Map) return 0;
  final t = Map<String, dynamic>.from(tasks);
  final meta = t['metadata'];
  if (meta is! Map) return 0;
  final m = Map<String, dynamic>.from(meta);
  final amt = m['amount_to_collect'];
  if (amt != null) {
    final v = amt is num ? amt.toDouble() : double.tryParse(amt.toString());
    return v ?? 0;
  }
  final svc = m['service_price'];
  if (svc != null) {
    final v = svc is num ? svc.toDouble() : double.tryParse(svc.toString());
    return v ?? 0;
  }
  return 0;
}

/// Provider: seskupené pending výplaty a provize + celkový zisk agentury – pro pohled "K výplatě".
///
/// Seskupuje podle příjemce, přidává rozpad po úkolech (items) a dopočítá [PayrollTabData.agencyMarginTotal].
final groupedPendingPayoutsProvider =
    FutureProvider<PayrollTabData>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return const PayrollTabData(groups: [], agencyMarginTotal: 0);
  }

  final repo = SettlementRepository.instance;
  final payoutsRaw = await repo.getPendingPayoutsWithProfile(tenantId);
  final commissionsClientRaw = await repo.getPendingCommissionsWithClient(tenantId);
  final commissionsProfileRaw = await repo.getPendingCommissionsWithProfile(tenantId);

  // Hodnota úkolu (z metadata) – každý task jen jednou pro součet marže.
  final taskValueByTaskId = <String, double>{};

  final groups = <PayoutGroup>[];
  final employeeData = <String, ({
    String name,
    List<String> payoutIds,
    List<String> commissionIds,
    double total,
    List<PayoutLineItem> items,
  })>{};

  // 1. Výplaty podle profile_id včetně položek pro rozbalovací seznam
  for (final p in payoutsRaw) {
    final profileId = (p['profile_id'] as String?)?.trim() ?? '';
    if (profileId.isEmpty) continue;
    final id = (p['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) continue;
    final amount = ((p['amount'] as num?) ?? 0).toDouble();
    final taskId = (p['task_id'] as String?)?.trim() ?? '';
    final profiles = p['profiles'] as Map<String, dynamic>?;
    final name = _profileDisplayName(profiles);
    if (taskId.isNotEmpty) taskValueByTaskId.putIfAbsent(taskId, () => _taskValueFromRow(p));

    final line = PayoutLineItem(
      taskId: taskId,
      taskTitle: _taskTitleFromRow(p),
      date: _taskDateFromRow(p),
      amount: amount,
    );

    final existing = employeeData[profileId];
    if (existing != null) {
      employeeData[profileId] = (
        name: existing.name,
        payoutIds: [...existing.payoutIds, id],
        commissionIds: existing.commissionIds,
        total: existing.total + amount,
        items: [...existing.items, line],
      );
    } else {
      employeeData[profileId] = (
        name: name.isEmpty ? 'common.removed_user'.tr() : name,
        payoutIds: [id],
        commissionIds: [],
        total: amount,
        items: [line],
      );
    }
  }

  // 2. Provize pro zaměstnance (profile_id) – sloučit včetně items
  for (final c in commissionsProfileRaw) {
    final profileId = (c['profile_id'] as String?)?.trim() ?? '';
    if (profileId.isEmpty) continue;
    final id = (c['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) continue;
    final amount = ((c['amount'] as num?) ?? 0).toDouble();
    final taskId = (c['task_id'] as String?)?.trim() ?? '';
    final profiles = c['profiles'] as Map<String, dynamic>?;
    final name = _profileDisplayName(profiles);
    if (taskId.isNotEmpty) taskValueByTaskId.putIfAbsent(taskId, () => _taskValueFromRow(c));

    final line = PayoutLineItem(
      taskId: taskId,
      taskTitle: _taskTitleFromRow(c),
      date: _taskDateFromRow(c),
      amount: amount,
    );

    final existing = employeeData[profileId];
    if (existing != null) {
      employeeData[profileId] = (
        name: existing.name,
        payoutIds: existing.payoutIds,
        commissionIds: [...existing.commissionIds, id],
        total: existing.total + amount,
        items: [...existing.items, line],
      );
    } else {
      employeeData[profileId] = (
        name: name.isEmpty ? 'common.removed_user'.tr() : name,
        payoutIds: [],
        commissionIds: [id],
        total: amount,
        items: [line],
      );
    }
  }

  for (final entry in employeeData.entries) {
    final d = entry.value;
    if (d.payoutIds.isEmpty && d.commissionIds.isEmpty) continue;
    groups.add(PayoutGroup(
      isEmployee: true,
      recipientId: entry.key,
      recipientName: d.name,
      totalAmount: d.total,
      payoutIds: d.payoutIds,
      commissionIds: d.commissionIds,
      items: d.items,
    ));
  }

  // 3. Provize pro partnery (client_id) včetně items a taskValue
  final commissionByClient = <String, List<Map<String, dynamic>>>{};
  for (final c in commissionsClientRaw) {
    final clientId = (c['client_id'] as String?)?.trim() ?? '';
    if (clientId.isEmpty) continue;
    final taskId = (c['task_id'] as String?)?.trim() ?? '';
    if (taskId.isNotEmpty) taskValueByTaskId.putIfAbsent(taskId, () => _taskValueFromRow(c));
    commissionByClient.putIfAbsent(clientId, () => []).add(c);
  }
  for (final entry in commissionByClient.entries) {
    final list = entry.value;
    final ids = list.map((c) => (c['id'] as String?) ?? '').where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) continue;
    final total = list.fold<double>(0, (s, c) => s + ((c['amount'] as num?) ?? 0).toDouble());
    final clients = list.first['clients'] as Map<String, dynamic>?;
    final name = (clients?['name'] as String?)?.trim() ?? '';
    final items = list.map((c) => PayoutLineItem(
      taskId: (c['task_id'] as String?)?.trim() ?? '',
      taskTitle: _taskTitleFromRow(c),
      date: _taskDateFromRow(c),
      amount: ((c['amount'] as num?) ?? 0).toDouble(),
    )).toList();
    groups.add(PayoutGroup(
      isEmployee: false,
      recipientId: entry.key,
      recipientName: name.isEmpty ? '—' : name,
      totalAmount: total,
      payoutIds: const [],
      commissionIds: ids,
      items: items,
    ));
  }

  // Celkový zisk agentury = součet hodnot úkolů (každý jednou) − součet všech výplat
  final totalTaskValue = taskValueByTaskId.values.fold<double>(0, (a, b) => a + b);
  final totalPayouts = groups.fold<double>(0, (s, g) => s + g.totalAmount);
  final agencyMarginTotal = (totalTaskValue - totalPayouts).clamp(0.0, double.infinity);

  return PayrollTabData(groups: groups, agencyMarginTotal: agencyMarginTotal);
});

/// Provider: historie vyplacených výplat a provizí pro daný měsíc.
///
/// PROČ: Dialog "Historie výplat" seskupuje záznamy podle příjemce (zaměstnanec vs partner)
/// stejným způsobem jako groupedPendingPayoutsProvider – jen pro status 'paid'.
/// Měsíc určuje rozsah podle updated_at (kdy bylo označeno jako vyplaceno).
final paidSettlementsByMonthProvider =
    FutureProvider.autoDispose.family<List<PayoutGroup>, DateTime>((ref, month) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final repo = SettlementRepository.instance;
  final data = await repo.getPaidSettlementsByMonth(tenantId, month);

  final groups = <PayoutGroup>[];
  final employeeData = <String, ({String name, double total})>{};

  // 1. Výplaty podle profile_id (zaměstnanci)
  for (final p in data.payouts) {
    final profileId = (p['profile_id'] as String?)?.trim() ?? '';
    if (profileId.isEmpty) continue;
    final amount = ((p['amount'] as num?) ?? 0).toDouble();
    final profiles = p['profiles'] as Map<String, dynamic>?;
    final name = _profileDisplayName(profiles);

    final existing = employeeData[profileId];
    if (existing != null) {
      employeeData[profileId] = (name: existing.name, total: existing.total + amount);
    } else {
      employeeData[profileId] = (name: name.isEmpty ? 'common.removed_user'.tr() : name, total: amount);
    }
  }

  // 2. Provize pro zaměstnance (profile_id)
  for (final c in data.commissionsProfile) {
    final profileId = (c['profile_id'] as String?)?.trim() ?? '';
    if (profileId.isEmpty) continue;
    final amount = ((c['amount'] as num?) ?? 0).toDouble();
    final profiles = c['profiles'] as Map<String, dynamic>?;
    final name = _profileDisplayName(profiles);

    final existing = employeeData[profileId];
    if (existing != null) {
      employeeData[profileId] = (name: existing.name, total: existing.total + amount);
    } else {
      employeeData[profileId] = (name: name.isEmpty ? 'common.removed_user'.tr() : name, total: amount);
    }
  }

  for (final entry in employeeData.entries) {
    groups.add(PayoutGroup(
      isEmployee: true,
      recipientId: entry.key,
      recipientName: entry.value.name,
      totalAmount: entry.value.total,
      payoutIds: const [],
      commissionIds: const [],
    ));
  }

  // 3. Provize pro partnery (client_id)
  final partnerByClient = <String, ({String name, double total})>{};
  for (final c in data.commissionsClient) {
    final clientId = (c['client_id'] as String?)?.trim() ?? '';
    if (clientId.isEmpty) continue;
    final amount = ((c['amount'] as num?) ?? 0).toDouble();
    final clients = c['clients'] as Map<String, dynamic>?;
    final name = (clients?['name'] as String?)?.trim() ?? '';

    final existing = partnerByClient[clientId];
    if (existing != null) {
      partnerByClient[clientId] = (name: existing.name, total: existing.total + amount);
    } else {
      partnerByClient[clientId] = (name: name.isEmpty ? '—' : name, total: amount);
    }
  }

  for (final entry in partnerByClient.entries) {
    groups.add(PayoutGroup(
      isEmployee: false,
      recipientId: entry.key,
      recipientName: entry.value.name,
      totalAmount: entry.value.total,
      payoutIds: const [],
      commissionIds: const [],
    ));
  }

  groups.sort((a, b) => a.recipientName.compareTo(b.recipientName));
  return groups;
});

/// Označí skupinu jako vyplacenou a invaliduje providery.
///
/// PROČ: Jedna akce pro Admin – po kliknutí „Označit jako vyplaceno“ updatují
/// se záznamy v DB (status → 'paid') a skupina zmizí z přehledu "K výplatě".
/// Invalidace [groupedPendingPayoutsProvider] odstraní vyplacenou skupinu z listu.
/// Invalidace [paidSettlementsByMonthProvider] (celá family) zajistí, že dialog
/// "Historie výplat" se při příštím zobrazení nebo už při otevřeném okně znovu
/// načte ze serveru a zobrazí aktuální vyplacené záznamy (.eq('status', 'paid')).
Future<void> markPayoutGroupAsPaid({required dynamic ref, required PayoutGroup group}) async {
  final repo = SettlementRepository.instance;
  if (group.payoutIds.isNotEmpty) {
    await repo.markPayoutsAsPaid(group.payoutIds);
  }
  if (group.commissionIds.isNotEmpty) {
    await repo.markCommissionsAsPaid(group.commissionIds);
  }
  ref.invalidate(groupedPendingPayoutsProvider);
  ref.invalidate(paidSettlementsByMonthProvider);
}
