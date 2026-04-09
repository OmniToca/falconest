import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/task_commission_model.dart';
import 'package:falconest/core/models/task_payout_model.dart';
import 'package:falconest/core/repositories/settlements/settlement_repository.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// Jedna položka v rozbaleném seznamu „K výplatě“ / výplatní páska – úkol, časy, částka.
///
/// PROČ: Rozbalovací karta a PDF výplatní pásky potřebují datum, časy od–do, trvání
/// a volitelné spropitné. Data se ukládají do payout_snapshots.items_data (JSONB).
class PayoutLineItem {
  const PayoutLineItem({
    required this.taskId,
    required this.taskTitle,
    this.date,
    required this.amount,
    this.scheduledStart,
    this.scheduledEnd,
    this.durationMinutes = 0,
    this.tipAmount = 0.0,
  });

  final String taskId;
  final String taskTitle;
  /// Datum úkolu (completed_at nebo scheduled_start) – pro řazení a zobrazení.
  final DateTime? date;
  final double amount;
  /// Začátek úkolu (tasks.scheduled_start) – pro PDF sloupec Od.
  final DateTime? scheduledStart;
  /// Konec úkolu (tasks.completed_at jako konec práce) – pro PDF sloupec Do.
  final DateTime? scheduledEnd;
  /// Trvání v minutách – z rozdílu časů nebo metadata; pro výpočet hodinové mzdy.
  final int durationMinutes;
  /// Spropitné (pro budoucí rozšíření; v DB zatím nemáme, ukládáme 0).
  final double tipAmount;
}

/// Jedna skupina k výplatě – buď Zaměstnanec (payouts) nebo Partner (commissions).
///
/// PROČ: Admin vidí přehled „komu dlužíme kolik“ – seskupeno podle příjemce a MĚSÍCE ÚKOLU.
/// [taskMonth] = první den měsíce, ve kterém byly úkoly odvedeny (pro účetní správný payout_period).
/// [items] = rozpad po úkolech pro rozbalovací seznam (název úkolu, datum, částka).
class PayoutGroup {
  const PayoutGroup({
    required this.isEmployee,
    required this.recipientId,
    required this.recipientName,
    required this.totalAmount,
    required this.payoutIds,
    required this.commissionIds,
    required this.taskMonth,
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
  /// Měsíc, ve kterém byly úkoly odvedeny (1. den měsíce) – pro zápis do payout_snapshots a zobrazení v UI.
  final DateTime taskMonth;
  /// Rozpad po úkolech – pro rozbalovací kartu (název, datum, částka).
  final List<PayoutLineItem> items;
}

/// Jeden řádek rozpadu marže – naúčtováno a náklady za konkrétní úkol.
class TaskMarginDetail {
  const TaskMarginDetail({
    required this.taskId,
    required this.taskTitle,
    required this.invoiced,
    required this.costs,
    this.date,
  });

  final String taskId;
  final String taskTitle;
  /// Hodnota úkolu (z metadata) – naúčtováno klientům.
  final double invoiced;
  /// Součet výplat/provizí za tento úkol (náklady na personál).
  final double costs;
  /// Datum úkolu – pro řazení a zobrazení.
  final DateTime? date;

  double get margin => invoiced - costs;
}

/// Data pro záložku „K výplatě“ – skupiny příjemců + celkový zisk agentury (marže).
///
/// PROČ: Jedna struktura vracená providerem – skupiny i souhrnná marže po schválení výplat.
/// totalTaskValue / totalPayouts umožňují v UI zobrazit rozpad (naúčtováno vs. náklady).
/// taskMargins = drill-down po jednotlivých úkolech (Naúčtováno − Náklady = Marže úkolu).
class PayrollTabData {
  const PayrollTabData({
    required this.groups,
    required this.agencyMarginTotal,
    required this.totalTaskValue,
    required this.totalPayouts,
    this.taskMargins = const [],
  });

  final List<PayoutGroup> groups;
  /// Součet (hodnota úkolů − výplaty − provize) za všechny pending záznamy.
  final double agencyMarginTotal;
  /// Hodnota úkolů (z metadata) – naúčtováno klientům. Každý úkol jen jednou.
  final double totalTaskValue;
  /// Součet všech výplat a provizí (náklady na personál).
  final double totalPayouts;
  /// Rozpad marže po úkolech – pro drill-down v kartě celkové marže.
  final List<TaskMarginDetail> taskMargins;
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
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return const TaskSettlements(payouts: [], commissions: []);
  }
  return SettlementRepository.instance.getSettlementsForTask(tenantId, taskId);
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

/// Začátek úkolu (tasks.scheduled_start) – pro výplatní pásky PDF.
DateTime? _taskScheduledStartFromRow(Map<String, dynamic> row) {
  final tasks = row['tasks'];
  if (tasks is! Map) return null;
  final t = Map<String, dynamic>.from(tasks);
  final v = t['scheduled_start'];
  if (v == null) return null;
  return v is DateTime ? v : DateTime.tryParse(v.toString());
}

/// Konec úkolu (tasks.completed_at) – pro výplatní pásky PDF (sloupec Do).
DateTime? _taskScheduledEndFromRow(Map<String, dynamic> row) {
  final tasks = row['tasks'];
  if (tasks is! Map) return null;
  final t = Map<String, dynamic>.from(tasks);
  final v = t['completed_at'];
  if (v == null) return null;
  return v is DateTime ? v : DateTime.tryParse(v.toString());
}

/// Trvání v minutách – z rozdílu completed_at − scheduled_start, nebo z metadata.
int _taskDurationMinutesFromRow(Map<String, dynamic> row) {
  final tasks = row['tasks'];
  if (tasks is! Map) return 0;
  final t = Map<String, dynamic>.from(tasks);
  final start = _taskScheduledStartFromRow(row);
  final end = _taskScheduledEndFromRow(row);
  if (start != null && end != null && end.isAfter(start)) {
    return end.difference(start).inMinutes;
  }
  final meta = t['metadata'];
  if (meta is Map) {
    final m = Map<String, dynamic>.from(meta);
    final d = m['duration_minutes'];
    if (d != null) return (d is num) ? d.toInt() : (int.tryParse(d.toString()) ?? 0);
  }
  return 0;
}

/// Vrátí první den měsíce úkolu (pro seskupení a payout_period). Fallback na aktuální měsíc.
DateTime _taskMonthFromRow(Map<String, dynamic> row) {
  final d = _taskDateFromRow(row);
  if (d != null) return DateTime(d.year, d.month, 1);
  return DateTime(DateTime.now().year, DateTime.now().month, 1);
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
/// Seskupuje podle PŘÍJEMCE + MĚSÍCE ÚKOLU (rok a měsíc z task_date), aby účetní viděl,
/// za jaký měsíc dané peníze schvaluje. [taskMonth] = první den měsíce odvedené práce.
final groupedPendingPayoutsProvider =
    FutureProvider<PayrollTabData>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return const PayrollTabData(
      groups: [],
      agencyMarginTotal: 0,
      totalTaskValue: 0,
      totalPayouts: 0,
      taskMargins: [],
    );
  }

  final repo = SettlementRepository.instance;
  final payoutsRaw = await repo.getPendingPayoutsWithProfile(tenantId);
  final commissionsClientRaw = await repo.getPendingCommissionsWithClient(tenantId);
  final commissionsProfileRaw = await repo.getPendingCommissionsWithProfile(tenantId);

  // Hodnota úkolu (z metadata) – každý task jen jednou pro součet marže.
  final taskValueByTaskId = <String, double>{};

  final groups = <PayoutGroup>[];
  // Klíč = příjemce + měsíc úkolu (profileId_year_month), aby se seskupovalo po měsíci.
  final employeeData = <String, ({
    String recipientId,
    String name,
    DateTime taskMonth,
    List<String> payoutIds,
    List<String> commissionIds,
    double total,
    List<PayoutLineItem> items,
  })>{};

  String employeeKey(String profileId, DateTime taskMonth) =>
      '${profileId}_${taskMonth.year}_${taskMonth.month}';

  // 1. Výplaty podle profile_id + měsíc úkolu
  for (final p in payoutsRaw) {
    final profileId = (p['profile_id'] as String?)?.trim() ?? '';
    if (profileId.isEmpty) continue;
    final id = (p['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) continue;
    final amount = ((p['amount'] as num?) ?? 0).toDouble();
    final taskId = (p['task_id'] as String?)?.trim() ?? '';
    final profiles = p['profiles'] as Map<String, dynamic>?;
    final name = _profileDisplayName(profiles);
    final taskMonth = _taskMonthFromRow(p);
    if (taskId.isNotEmpty) taskValueByTaskId.putIfAbsent(taskId, () => _taskValueFromRow(p));

    final line = PayoutLineItem(
      taskId: taskId,
      taskTitle: _taskTitleFromRow(p),
      date: _taskDateFromRow(p),
      amount: amount,
      scheduledStart: _taskScheduledStartFromRow(p),
      scheduledEnd: _taskScheduledEndFromRow(p),
      durationMinutes: _taskDurationMinutesFromRow(p),
    );

    final key = employeeKey(profileId, taskMonth);
    final existing = employeeData[key];
    if (existing != null) {
      employeeData[key] = (
        recipientId: existing.recipientId,
        name: existing.name,
        taskMonth: existing.taskMonth,
        payoutIds: [...existing.payoutIds, id],
        commissionIds: existing.commissionIds,
        total: existing.total + amount,
        items: [...existing.items, line],
      );
    } else {
      employeeData[key] = (
        recipientId: profileId,
        name: name.isEmpty ? 'common.removed_user'.tr() : name,
        taskMonth: taskMonth,
        payoutIds: [id],
        commissionIds: [],
        total: amount,
        items: [line],
      );
    }
  }

  // 2. Provize pro zaměstnance (profile_id) – sloučit do stejného klíče příjemce + měsíc
  for (final c in commissionsProfileRaw) {
    final profileId = (c['profile_id'] as String?)?.trim() ?? '';
    if (profileId.isEmpty) continue;
    final id = (c['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) continue;
    final amount = ((c['amount'] as num?) ?? 0).toDouble();
    final taskId = (c['task_id'] as String?)?.trim() ?? '';
    final profiles = c['profiles'] as Map<String, dynamic>?;
    final name = _profileDisplayName(profiles);
    final taskMonth = _taskMonthFromRow(c);
    if (taskId.isNotEmpty) taskValueByTaskId.putIfAbsent(taskId, () => _taskValueFromRow(c));

    final line = PayoutLineItem(
      taskId: taskId,
      taskTitle: _taskTitleFromRow(c),
      date: _taskDateFromRow(c),
      amount: amount,
      scheduledStart: _taskScheduledStartFromRow(c),
      scheduledEnd: _taskScheduledEndFromRow(c),
      durationMinutes: _taskDurationMinutesFromRow(c),
    );

    final key = employeeKey(profileId, taskMonth);
    final existing = employeeData[key];
    if (existing != null) {
      employeeData[key] = (
        recipientId: existing.recipientId,
        name: existing.name,
        taskMonth: existing.taskMonth,
        payoutIds: existing.payoutIds,
        commissionIds: [...existing.commissionIds, id],
        total: existing.total + amount,
        items: [...existing.items, line],
      );
    } else {
      employeeData[key] = (
        recipientId: profileId,
        name: name.isEmpty ? 'common.removed_user'.tr() : name,
        taskMonth: taskMonth,
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
      recipientId: d.recipientId,
      recipientName: d.name,
      totalAmount: d.total,
      payoutIds: d.payoutIds,
      commissionIds: d.commissionIds,
      taskMonth: d.taskMonth,
      items: d.items,
    ));
  }

  // 3. Provize pro partnery (client_id) – seskupit podle client_id + měsíc úkolu
  final partnerData = <String, ({
    String recipientId,
    String name,
    DateTime taskMonth,
    List<String> commissionIds,
    double total,
    List<PayoutLineItem> items,
  })>{};

  String partnerKey(String clientId, DateTime taskMonth) =>
      '${clientId}_${taskMonth.year}_${taskMonth.month}';

  for (final c in commissionsClientRaw) {
    final clientId = (c['client_id'] as String?)?.trim() ?? '';
    if (clientId.isEmpty) continue;
    final taskId = (c['task_id'] as String?)?.trim() ?? '';
    final taskMonth = _taskMonthFromRow(c);
    if (taskId.isNotEmpty) taskValueByTaskId.putIfAbsent(taskId, () => _taskValueFromRow(c));
    final key = partnerKey(clientId, taskMonth);
    final clients = c['clients'] as Map<String, dynamic>?;
    final name = (clients?['name'] as String?)?.trim() ?? '';
    final id = (c['id'] as String?)?.trim() ?? '';
    final amount = ((c['amount'] as num?) ?? 0).toDouble();
    final line = PayoutLineItem(
      taskId: taskId,
      taskTitle: _taskTitleFromRow(c),
      date: _taskDateFromRow(c),
      amount: amount,
      scheduledStart: _taskScheduledStartFromRow(c),
      scheduledEnd: _taskScheduledEndFromRow(c),
      durationMinutes: _taskDurationMinutesFromRow(c),
    );
    final existing = partnerData[key];
    if (existing != null) {
      partnerData[key] = (
        recipientId: existing.recipientId,
        name: existing.name,
        taskMonth: existing.taskMonth,
        commissionIds: [...existing.commissionIds, id],
        total: existing.total + amount,
        items: [...existing.items, line],
      );
    } else {
      partnerData[key] = (
        recipientId: clientId,
        name: name.isEmpty ? 'common.placeholder_dash'.tr() : name,
        taskMonth: taskMonth,
        commissionIds: [id],
        total: amount,
        items: [line],
      );
    }
  }
  for (final entry in partnerData.entries) {
    final d = entry.value;
    groups.add(PayoutGroup(
      isEmployee: false,
      recipientId: d.recipientId,
      recipientName: d.name,
      totalAmount: d.total,
      payoutIds: const [],
      commissionIds: d.commissionIds,
      taskMonth: d.taskMonth,
      items: d.items,
    ));
  }

  // Celkový zisk agentury = součet hodnot úkolů (každý jednou) − součet všech výplat
  final totalTaskValue = taskValueByTaskId.values.fold<double>(0, (a, b) => a + b);
  final totalPayouts = groups.fold<double>(0, (s, g) => s + g.totalAmount);
  final agencyMarginTotal = (totalTaskValue - totalPayouts).clamp(0.0, double.infinity);

  // Rozpad marže po úkolech: náklady seskupené podle taskId z items ve všech skupinách
  final costsByTaskId = <String, double>{};
  final titleByTaskId = <String, String>{};
  final dateByTaskId = <String, DateTime?>{};
  for (final g in groups) {
    for (final item in g.items) {
      if (item.taskId.isEmpty) continue;
      costsByTaskId[item.taskId] = (costsByTaskId[item.taskId] ?? 0) + item.amount;
      titleByTaskId.putIfAbsent(item.taskId, () => item.taskTitle);
      dateByTaskId.putIfAbsent(item.taskId, () => item.date);
    }
  }
  final allTaskIds = <String>{...taskValueByTaskId.keys, ...costsByTaskId.keys};
  final taskMargins = allTaskIds.map((taskId) {
    final invoiced = taskValueByTaskId[taskId] ?? 0.0;
    final costs = costsByTaskId[taskId] ?? 0.0;
    final taskTitle = titleByTaskId[taskId]?.trim().isNotEmpty == true
        ? titleByTaskId[taskId]!
        : 'admin.task_no_title'.tr();
    return TaskMarginDetail(
      taskId: taskId,
      taskTitle: taskTitle,
      invoiced: invoiced,
      costs: costs,
      date: dateByTaskId[taskId],
    );
  }).toList();
  taskMargins.sort((a, b) {
    final byMargin = b.margin.compareTo(a.margin);
    if (byMargin != 0) return byMargin;
    final aDate = a.date ?? DateTime(0);
    final bDate = b.date ?? DateTime(0);
    return bDate.compareTo(aDate);
  });

  return PayrollTabData(
    groups: groups,
    agencyMarginTotal: agencyMarginTotal,
    totalTaskValue: totalTaskValue,
    totalPayouts: totalPayouts,
    taskMargins: taskMargins,
  );
});

/// Parametr pro výběr měsíce historie výplat – rok a měsíc.
///
/// KRITICKÉ: Přepis [==] a [hashCode] je nutný pro správnou funkci Riverpod
/// FutureProvider.family – stejný vzor jako BillingMonthParam v Podkladech pro fakturaci.
/// Bez něj by stejné (rok, měsíc) vedly k nekonečné smyčce kvůli porovnávání instancí.
class PayoutMonthParam {
  const PayoutMonthParam({required this.year, required this.month});

  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayoutMonthParam &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

/// Z jednoho řádku payout_snapshots (items_data = JSONB) sestaví seznam [PayoutLineItem].
List<PayoutLineItem> _itemsFromSnapshotRow(Map<String, dynamic> row) {
  final raw = row['items_data'];
  if (raw == null) return [];
  if (raw is! List) return [];
  final items = <PayoutLineItem>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final taskId = (m['task_id'] as String?)?.trim() ?? '';
    final taskTitle = (m['task_title'] as String?)?.trim() ?? 'common.placeholder_dash'.tr();
    final amount = (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0;
    DateTime? date;
    final d = m['date'];
    if (d != null) date = DateTime.tryParse(d.toString());
    DateTime? scheduledStart;
    final s1 = m['scheduled_start'];
    if (s1 != null) scheduledStart = DateTime.tryParse(s1.toString());
    DateTime? scheduledEnd;
    final s2 = m['scheduled_end'];
    if (s2 != null) scheduledEnd = DateTime.tryParse(s2.toString());
    final durationMinutes = (m['duration_minutes'] is num)
        ? (m['duration_minutes'] as num).toInt()
        : (int.tryParse(m['duration_minutes']?.toString() ?? '') ?? 0);
    final tipAmount = (m['tip_amount'] is num) ? (m['tip_amount'] as num).toDouble() : 0.0;
    items.add(PayoutLineItem(
      taskId: taskId,
      taskTitle: taskTitle,
      date: date,
      amount: amount,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      durationMinutes: durationMinutes,
      tipAmount: tipAmount,
    ));
  }
  return items;
}

/// Provider: historie výplat pro daný měsíc – čte VÝHRADNĚ z tabulky [payout_snapshots].
///
/// Žádné dynamické joinování task_payouts/task_commissions. Data pochází z uzamčených
/// snapshotů (stejný princip jako billing_snapshots u fakturace).
final payoutHistoryReportProvider =
    FutureProvider.autoDispose.family<List<PayoutGroup>, PayoutMonthParam>((ref, param) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final monthDate = DateTime.utc(param.year, param.month, 1);
  final repo = SettlementRepository.instance;
  final rows = await repo.getPayoutSnapshotsByMonth(tenantId, monthDate);

  final groups = rows.map((row) {
    final isEmployee = row['is_employee'] as bool? ?? true;
    final profileId = (row['profile_id'] as String?)?.trim();
    final clientId = (row['client_id'] as String?)?.trim();
    final recipientId = (profileId ?? clientId ?? '').trim();
    final recipientName = (row['recipient_name'] as String?)?.trim() ?? 'common.placeholder_dash'.tr();
    final totalAmount = (row['total_amount'] is num)
        ? (row['total_amount'] as num).toDouble()
        : 0.0;
    final items = _itemsFromSnapshotRow(row);
    // Snapshot řádky jsou vždy pro daný měsíc (param); taskMonth = první den toho měsíce.
    return PayoutGroup(
      isEmployee: isEmployee,
      recipientId: recipientId.isEmpty ? 'unknown' : recipientId,
      recipientName: recipientName,
      totalAmount: totalAmount,
      payoutIds: const [],
      commissionIds: const [],
      taskMonth: monthDate,
      items: items,
    );
  }).toList();

  groups.sort((a, b) => a.recipientName.compareTo(b.recipientName));
  return groups;
});

/// Označí skupinu jako vyplacenou, zapíše snapshot do [payout_snapshots] a invaliduje providery.
///
/// KROK A: Označí task_payouts a task_commissions jako 'paid'.
/// KROK B: Vloží (nebo sloučí) záznam do payout_snapshots, aby Historie výplat měla data.
/// Invalidace [groupedPendingPayoutsProvider] odstraní vyplacenou skupinu z záložky K výplatě.
/// Invalidace [payoutHistoryReportProvider] obnoví záložku Historie výplat.
Future<void> markPayoutGroupAsPaid({required dynamic ref, required PayoutGroup group}) async {
  final repo = SettlementRepository.instance;
  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    throw StateError('Nelze označit výplatu bez tenant ID.');
  }

  // KROK A: Označit výplaty a provize jako vyplacené.
  if (group.payoutIds.isNotEmpty) {
    await repo.markPayoutsAsPaid(tenantId, group.payoutIds);
  }
  if (group.commissionIds.isNotEmpty) {
    await repo.markCommissionsAsPaid(tenantId, group.commissionIds);
  }

  // KROK B: Zápis do payout_snapshots – měsíc ÚKOLU (group.taskMonth), ne datum vyplacení!
  // PROČ: Účetní proplácí únorové úkoly 10. března → snapshot musí patřit do ÚNORA.
  final lockedByProfileId = ref.read(authNotifierProvider).state.profileId;
  if (lockedByProfileId != null && lockedByProfileId.trim().isNotEmpty) {
    final periodFirstDay = DateTime(group.taskMonth.year, group.taskMonth.month, 1);
    final itemsData = group.items.map((item) {
      return <String, dynamic>{
        'task_id': item.taskId,
        'task_title': item.taskTitle,
        'date': item.date?.toUtc().toIso8601String(),
        'amount': item.amount,
        'scheduled_start': item.scheduledStart?.toUtc().toIso8601String(),
        'scheduled_end': item.scheduledEnd?.toUtc().toIso8601String(),
        'duration_minutes': item.durationMinutes,
        'tip_amount': item.tipAmount,
      };
    }).toList();

    await repo.upsertPayoutSnapshot(
      tenantId: tenantId,
      payoutPeriodFirstDay: periodFirstDay,
      isEmployee: group.isEmployee,
      profileId: group.isEmployee ? group.recipientId : null,
      clientId: group.isEmployee ? null : group.recipientId,
      recipientName: group.recipientName,
      totalAmount: group.totalAmount,
      itemsData: itemsData,
      lockedByProfileId: lockedByProfileId,
    );
  }

  ref.invalidate(groupedPendingPayoutsProvider);
  ref.invalidate(payoutHistoryReportProvider);
}
