import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';

// =============================================================================
// DATOVÉ TŘÍDY (DTOs) PRO UI
// =============================================================================

/// Položka jednoho úkolu v podkladech pro fakturaci.
///
/// [taskId] = UUID úkolu z tabulky tasks.
/// [title] = název úkolu (tasks.title nebo custom_title).
/// [scheduledStart] = naplánovaný čas zahájení – kdy měl úkol začít (UTC→lokální při mapování).
/// [completedAt] = datum dokončení – kdy byl úkol skutečně vykonán.
/// [chargedPrice] = vypočítaná cena k fakturaci v EUR (viz pravidla výpočtu níže).
/// [payerType] = kdo platí: 'owner' (majitel bytu), 'guest' (host), 'client' (externí klient).
/// [reservationId] = UUID rezervace – pro vizuální seskupení úkolů pod rezervace v UI.
/// [guestName] = jméno hosta z reservations.guest_name – pro profesionální zobrazení místo surového ID.
/// [reservationStart]/[reservationEnd] = termín pobytu z reservations.start_date/end_date – majitelům
/// pomáhá rychle identifikovat, k jaké události se úklid váže.
/// [mediaUrls] = URL fotek z tasks.media_urls – pro indikaci fotodokumentace v UI.
class BillingTaskItem {
  const BillingTaskItem({
    required this.taskId,
    required this.title,
    this.scheduledStart,
    this.completedAt,
    required this.chargedPrice,
    required this.payerType,
    this.reservationId,
    this.guestName,
    this.reservationStart,
    this.reservationEnd,
    this.mediaUrls = const [],
  });

  final String taskId;
  final String title;
  /// Naplánovaný čas zahájení – převedeno z UTC na lokální při mapování.
  final DateTime? scheduledStart;
  final DateTime? completedAt;
  final double chargedPrice;
  final String payerType;
  final String? reservationId;
  final String? guestName;
  final DateTime? reservationStart;
  final DateTime? reservationEnd;
  final List<String> mediaUrls;
}

/// Položka firemního výdaje (materiál, nákup) – agentura platila za majitele.
///
/// [id] = UUID transakce z employee_cash_transactions.
/// [date] = datum nákupu (created_at transakce).
/// [description] = poznámka (note) nebo výchozí text.
/// [amount] = kladná částka k proplacení majitelem.
/// [mediaUrls] = URL účtenky (receipt_image_url) – fotodokumentace pro majitele.
class BillingExpenseItem {
  const BillingExpenseItem({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    this.mediaUrls = const [],
  });

  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final List<String> mediaUrls;
}

/// Agregační skupina úkolů – seskupeno striktně podle klienta (majitele).
///
/// [groupKey] = client_id (determinuje, kdo dostane fakturu). Jeden klient s více byty
/// má všechny úkoly v jedné skupině – jedna souhrnná faktura.
/// [groupName] = lidsky čitelný název klienta.
/// [tasks] = seznam úkolů v této skupině.
/// [totalToInvoice] = celkový obrat za služby (součet chargedPrice VŠECH úkolů).
/// [totalPaidByGuest] = částka uhrazená hosty (hotovost) – odečítáme od faktury majitele.
/// [totalExpenses] = součet firemních výdajů (materiál do bytu) – PŘIČÍTÁME k faktuře, majitel proplácí agentuře.
/// [expenses] = detailní seznam výdajů pro rozpis v PDF/Excel/UI.
class BillingGroup {
  const BillingGroup({
    required this.groupKey,
    required this.groupName,
    required this.tasks,
    required this.totalToInvoice,
    this.totalExpenses = 0.0,
    this.expenses = const [],
  });

  final String groupKey;
  final String groupName;
  final List<BillingTaskItem> tasks;
  final double totalToInvoice;
  /// Firemní výdaje (paragony na materiál) – PŘIČÍTÁME, majitel proplácí agentuře.
  final double totalExpenses;
  /// Detailní seznam výdajů – datum, popis, částka, fotka účtenky.
  final List<BillingExpenseItem> expenses;

  /// Částka uhravená hosty (hotovost) – úkoly s payerType='guest'.
  /// Odečítáme od finální faktury majitele.
  double get totalPaidByGuest =>
      tasks.where((t) => t.payerType == 'guest').fold<double>(0, (s, t) => s + t.chargedPrice);

  /// Finální částka k úhradě majitelem = obrat - uhraveno hosty + náklady (proplacení agentuře).
  double get finalToInvoice =>
      (totalToInvoice - totalPaidByGuest) + totalExpenses;

  /// Rekonstruuje BillingGroup ze zmraženého snapshot_data (JSONB z billing_snapshots).
  ///
  /// PROČ: Majitel v Klientské zóně stahuje PDF z historických snapshotů. Existující
  /// BillingPdfService očekává BillingGroup – tato factory převádí uložený stav
  /// zpět do živého modelu pro účely generátoru PDF.
  /// [currentClientName] – pokud předán, použije se jako groupName (aktuální jméno z DB);
  /// jinak fallback na zmražené jméno ze snapshotu (kompatibilita s Klientskou zónou bez dotazu na clients).
  factory BillingGroup.fromSnapshot(
    Map<String, dynamic> snapshotData,
    String clientId, {
    String? currentClientName,
  }) {
    final snapshotName = (snapshotData['client_name'] as String?)?.trim() ?? '';
    final clientName = (currentClientName != null && currentClientName.trim().isNotEmpty)
        ? currentClientName.trim()
        : (snapshotName.isNotEmpty ? snapshotName : '');
    final expenses = _parseExpensesFromSnapshot(snapshotData['expenses']);
    final totalExpenses = expenses.isNotEmpty
        ? expenses.fold<double>(0, (s, e) => s + e.amount)
        : (_toDouble(snapshotData['total_expenses']) ?? 0.0);

    final itemsRaw = snapshotData['items'];
    final tasks = <BillingTaskItem>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final itemMap = Map<String, dynamic>.from(item);
        final taskId = (itemMap['task_id'] as String?)?.trim() ?? '';
        final title = (itemMap['title'] as String?)?.trim() ?? '';
        final chargedPrice = _toDouble(itemMap['charged_price']) ?? 0.0;
        final payerType = (itemMap['payer_type'] as String?)?.trim() ?? 'guest';
        final reservationId = (itemMap['reservation_id'] as String?)?.trim();
        final guestName = (itemMap['guest_name'] as String?)?.trim();
        DateTime? reservationStart;
        final rs = itemMap['reservation_start'];
        if (rs is String) reservationStart = DateTime.tryParse(rs)?.toLocal();
        DateTime? reservationEnd;
        final re = itemMap['reservation_end'];
        if (re is String) reservationEnd = DateTime.tryParse(re)?.toLocal();
        final mediaUrlsRaw = itemMap['media_urls'];
        final mediaUrls = mediaUrlsRaw is List
            ? mediaUrlsRaw
                .map((e) => e?.toString().trim())
                .where((s) => s != null && s.isNotEmpty)
                .cast<String>()
                .toList()
            : <String>[];

        DateTime? scheduledStart;
        final ss = itemMap['scheduled_start'];
        if (ss is String) scheduledStart = DateTime.tryParse(ss);
        DateTime? completedAt;
        final ca = itemMap['completed_at'];
        if (ca is String) completedAt = DateTime.tryParse(ca);

        tasks.add(BillingTaskItem(
          taskId: taskId,
          title: title,
          scheduledStart: scheduledStart,
          completedAt: completedAt,
          chargedPrice: chargedPrice,
          payerType: payerType,
          reservationId: reservationId?.isNotEmpty == true ? reservationId : null,
          guestName: guestName?.isNotEmpty == true ? guestName : null,
          reservationStart: reservationStart,
          reservationEnd: reservationEnd,
          mediaUrls: mediaUrls,
        ));
      }
    }

    // Obrat = součet všech chargedPrice (kompatibilita se živým výpočtem).
    final totalToInvoice = tasks.fold<double>(0, (s, t) => s + t.chargedPrice);
    tasks.sort((a, b) => _taskSortDate(a).compareTo(_taskSortDate(b)));

    return BillingGroup(
      groupKey: clientId,
      groupName: clientName,
      tasks: tasks,
      totalToInvoice: totalToInvoice,
      totalExpenses: totalExpenses,
      expenses: expenses,
    );
  }
}

List<BillingExpenseItem> _parseExpensesFromSnapshot(dynamic raw) {
  if (raw == null || raw is! List) return [];
  final result = <BillingExpenseItem>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final id = (m['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) continue;
    final dateRaw = m['date'];
    DateTime? date;
    if (dateRaw is String) date = DateTime.tryParse(dateRaw)?.toLocal();
    if (date == null) continue;
    final description = (m['description'] as String?)?.trim() ?? '';
    final amount = _toDouble(m['amount']) ?? 0.0;
    final urlsRaw = m['media_urls'];
    final mediaUrls = urlsRaw is List
        ? urlsRaw
            .map((e) => e?.toString().trim())
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList()
        : <String>[];
    result.add(BillingExpenseItem(
      id: id,
      date: date,
      description: description.isEmpty ? '-' : description,
      amount: amount,
      mediaUrls: mediaUrls,
    ));
  }
  return result;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Stav měsíce fakturace – živá data nebo zmražená historie.
///
/// [groups] = seskupené úkoly podle klienta.
/// [isLocked] = true znamená, že měsíc je uzamčen; data pocházejí z billing_snapshots.
class BillingMonthState {
  const BillingMonthState({
    required this.groups,
    this.isLocked = false,
  });

  final List<BillingGroup> groups;
  final bool isLocked;
}

/// Parametr pro výběr období – měsíc/rok.
///
/// KRITICKÉ: Přepis [==] a [hashCode] je nutný pro správnou funkci Riverpod
/// FutureProvider.family – bez něj by stejné parametry (rok, měsíc) vedly k nekonečné
/// smyčce kvůli _didChangeDependency (instance se porovnávají reference-placeholder).
class BillingMonthParam {
  const BillingMonthParam({required this.year, required this.month});

  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingMonthParam &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

/// Položka fakturace pro záložku Finance v detailu klienta – jeden úkol k úhradě / vyfakturovaný.
///
/// [taskId], [title], [date] (scheduledStart nebo completedAt), [chargedPrice] v EUR,
/// [isInvoiced] = true pokud byl úkol již vyfakturován (invoiced_at IS NOT NULL).
class ClientBillingItem {
  const ClientBillingItem({
    required this.taskId,
    required this.title,
    this.date,
    required this.chargedPrice,
    required this.isInvoiced,
  });

  final String taskId;
  final String title;
  final DateTime? date;
  final double chargedPrice;
  final bool isInvoiced;
}

// =============================================================================
// PROVIDER
// =============================================================================

/// Načte podklady pro fakturaci – živá data nebo zmražená historie.
///
/// Nejprve dotazuje billing_snapshots – pokud existují snapshoty pro měsíc,
/// vrací rekonstruované BillingGroup s isLocked = true. Jinak načte živé úkoly
/// (invoiced_at IS NULL) a vrátí isLocked = false.
final billingReportProvider =
    FutureProvider.autoDispose.family<BillingMonthState, BillingMonthParam>((ref, param) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return const BillingMonthState(groups: [], isLocked: false);
  }

  final billingPeriodStr =
      '${param.year}-${param.month.toString().padLeft(2, '0')}-01';

  try {
    // Krok 0: Zkontroluj, zda měsíc má zmražené snapshoty (uzamčen).
    final snapshotsRes = await SupabaseService.client
        .from('billing_snapshots')
        .select('client_id, snapshot_data')
        .eq('tenant_id', tenantId)
        .eq('billing_period', billingPeriodStr);

    final snapshotsList = (snapshotsRes as List).cast<Map<String, dynamic>>();
    if (snapshotsList.isNotEmpty) {
      // Měsíc je uzamčen – načti aktuální jména klientů z DB a rekonstruuj groups ze snapshot_data.
      final clientIdsFromSnapshots = snapshotsList
          .map((row) => (row['client_id'] as String?)?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final clientIdToName = <String, String>{};
      if (clientIdsFromSnapshots.isNotEmpty) {
        final clientsRes = await SupabaseService.client
            .from('clients')
            .select('id, name')
            .eq('tenant_id', tenantId)
            .inFilter('id', clientIdsFromSnapshots)
            .isFilter('deleted_at', null);
        for (final row in (clientsRes as List)) {
          final m = row as Map<String, dynamic>;
          final id = (m['id'] as String?)?.trim();
          final name = (m['name'] as String?)?.trim();
          if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
            clientIdToName[id] = name;
          }
        }
      }
      final reconstructedGroups = <BillingGroup>[];
      for (final row in snapshotsList) {
        final clientId = (row['client_id'] as String?)?.trim() ?? '';
        final snapshotData = row['snapshot_data'];
        if (clientId.isEmpty || snapshotData is! Map<String, dynamic>) continue;
        final currentName = clientIdToName[clientId];
        reconstructedGroups.add(BillingGroup.fromSnapshot(
          snapshotData,
          clientId,
          currentClientName: currentName,
        ));
      }
      reconstructedGroups.sort((a, b) => a.groupName.compareTo(b.groupName));
      return BillingMonthState(groups: reconstructedGroups, isLocked: true);
    }

    // Živá data – načti dokončené nevyfakturované úkoly POUZE pro vybraný měsíc (časové okno v DB).
    final startOfMonth = DateTime.utc(param.year, param.month, 1);
    final startOfNextMonth = DateTime.utc(param.year, param.month + 1, 1);
    final startIso = startOfMonth.toIso8601String();
    final endIso = startOfNextMonth.toIso8601String();

    // Krok 1: Načti dokončené nevyfakturované úkoly tenantu pro daný měsíc (filtr v DB).
    // PROČ: Výkon – bez filtru by se stahovala celá historie (OOM při 10 000+ úkolech).
    final tasksRes = await SupabaseService.client
        .from('tasks')
        .select(
          'id, title, custom_title, task_type, apartment_id, reservation_id, service_id, client_id, '
          'completed_at, due_date, scheduled_start, metadata, media_urls, '
          'reservations(guest_name, start_date, end_date)',
        )
        .eq('tenant_id', tenantId)
        .eq('status', 'completed')
        .isFilter('invoiced_at', null)
        .isFilter('deleted_at', null)
        .gte('completed_at', startIso)
        .lt('completed_at', endIso)
        .limit(2000);

    final tasksList = (tasksRes as List).cast<Map<String, dynamic>>();
    if (tasksList.isEmpty) {
      return const BillingMonthState(groups: [], isLocked: false);
    }

    // Úkoly jsou již vyfiltrované podle měsíce v DB; použijeme je přímo.
    final tasksInMonth = tasksList;

    // Krok 2: Ceny z reservation_services (úkoly napojené na rezervaci).
    final reservationIds = tasksInMonth
        .map((t) => (t['reservation_id'] as String?)?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final priceByResService = <String, double>{};
    final payerTypeByResService = <String, String>{};
    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (reservationIds.isNotEmpty) {
      final servicesByRes = await fetchByReservationIds(reservationIds, tenantId);
      final apartmentServiceIds = <String>{};
      for (final list in servicesByRes.values) {
        for (final rs in list) {
          final id = rs.apartmentServiceId.trim();
          if (id.isNotEmpty) apartmentServiceIds.add(id);
        }
      }
      final aptServiceToServiceId = <String, String>{};
      // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
      if (apartmentServiceIds.isNotEmpty) {
        final aptRes = await SupabaseService.client
            .from('apartment_services')
            .select('id, service_id')
            .eq('tenant_id', tenantId)
            .inFilter('id', apartmentServiceIds.toList());
        for (final row in (aptRes as List)) {
          final m = row as Map<String, dynamic>;
          final id = (m['id'] as String?)?.trim();
          final sid = (m['service_id'] as String?)?.trim();
          if (id != null && id.isNotEmpty && sid != null && sid.isNotEmpty) {
            aptServiceToServiceId[id] = sid;
          }
        }
      }
      for (final entry in servicesByRes.entries) {
        for (final rs in entry.value) {
          final sid = aptServiceToServiceId[rs.apartmentServiceId];
          if (sid == null) continue;
          final key = '${entry.key}|$sid';
          priceByResService[key] = (rs.chargedPrice ?? 0).toDouble();
          payerTypeByResService[key] = rs.payerType ?? 'guest';
        }
      }
    }

    // Krok 3: Mapování byt → majitel (profile) → klient. Vazba: apartment_owners.owner_id
    // = profiles.id, clients.profile_id = profiles.id. Klíčem pro fakturaci je vždy client_id.
    final apartmentIdsFromTasks = tasksInMonth
        .map((t) => (t['apartment_id'] as String?)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final clientIdsFromTasks = tasksInMonth
        .map((t) => (t['client_id'] as String?)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final apartmentToOwnerId = <String, String>{};
    final ownerIdToClientId = <String, String>{};
    final clientIdToName = <String, String>{};

    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (apartmentIdsFromTasks.isNotEmpty) {
      final ownersRes = await SupabaseService.client
          .from('apartment_owners')
          .select('apartment_id, owner_id')
          .inFilter('apartment_id', apartmentIdsFromTasks)
          .isFilter('deleted_at', null);
      for (final row in (ownersRes as List)) {
        final m = row as Map<String, dynamic>;
        final aptId = (m['apartment_id'] as String?)?.trim();
        final ownerId = (m['owner_id'] as String?)?.trim();
        if (aptId != null && aptId.isNotEmpty && ownerId != null && ownerId.isNotEmpty) {
          apartmentToOwnerId.putIfAbsent(aptId, () => ownerId);
        }
      }
    }

    final profileIdsToFetch = apartmentToOwnerId.values.toSet().toList();
    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (profileIdsToFetch.isNotEmpty) {
      final clientsByProfileRes = await SupabaseService.client
          .from('clients')
          .select('id, name, profile_id')
          .eq('tenant_id', tenantId)
          .inFilter('profile_id', profileIdsToFetch)
          .isFilter('deleted_at', null);
      for (final row in (clientsByProfileRes as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] as String?)?.trim();
        final name = (m['name'] as String?)?.trim();
        final profileId = (m['profile_id'] as String?)?.trim();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          clientIdToName[id] = name;
        }
        if (id != null && id.isNotEmpty && profileId != null && profileId.isNotEmpty) {
          ownerIdToClientId[profileId] = id;
        }
      }
    }

    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (clientIdsFromTasks.isNotEmpty) {
      final clientsDirectRes = await SupabaseService.client
          .from('clients')
          .select('id, name')
          .eq('tenant_id', tenantId)
          .inFilter('id', clientIdsFromTasks)
          .isFilter('deleted_at', null);
      for (final row in (clientsDirectRes as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] as String?)?.trim();
        final name = (m['name'] as String?)?.trim();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          clientIdToName[id] = name;
        }
      }
    }

    final apartmentToClientId = <String, String>{};
    for (final e in apartmentToOwnerId.entries) {
      final cid = ownerIdToClientId[e.value];
      if (cid != null) apartmentToClientId[e.key] = cid;
    }

    // Krok 3b: Firemní výdaje s apartment_id – PŘIČÍTÁME k faktuře, majitel proplácí agentuře.
    // Načti transakce COMPANY_EXPENSE v daném měsíci včetně detailů (note, receipt_image_url).
    final expensesByClientId = <String, List<BillingExpenseItem>>{};
    final expensesRes = await SupabaseService.client
        .from('employee_cash_transactions')
        .select('id, apartment_id, amount, note, receipt_image_url, created_at')
        .eq('tenant_id', tenantId)
        .eq('transaction_type', 'COMPANY_EXPENSE')
        .not('apartment_id', 'is', null)
        .gte('created_at', startOfMonth.toIso8601String())
        .lt('created_at', startOfNextMonth.toIso8601String());

    for (final row in (expensesRes as List)) {
      final m = row as Map<String, dynamic>;
      final aptId = (m['apartment_id'] as String?)?.trim();
      if (aptId == null || aptId.isEmpty) continue;
      final clientId = apartmentToClientId[aptId];
      if (clientId == null || clientId.isEmpty) continue;
      final id = (m['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;
      final amountRaw = m['amount'];
      final amount = (amountRaw is num)
          ? amountRaw.toDouble().abs()
          : (amountRaw != null ? double.tryParse(amountRaw.toString())?.abs() : null) ?? 0.0;
      if (amount <= 0) continue;
      final note = (m['note'] as String?)?.trim() ?? '';
      final receiptUrl = (m['receipt_image_url'] as String?)?.trim();
      final mediaUrls = receiptUrl != null && receiptUrl.isNotEmpty
          ? [receiptUrl]
          : <String>[];
      final createdAtRaw = m['created_at'];
      DateTime? date;
      if (createdAtRaw != null) {
        if (createdAtRaw is DateTime) {
          date = createdAtRaw.toLocal();
        } else if (createdAtRaw is String) {
          date = DateTime.tryParse(createdAtRaw)?.toLocal();
        }
      }
      date ??= DateTime.now().toLocal();
      expensesByClientId.putIfAbsent(clientId, () => []).add(BillingExpenseItem(
        id: id,
        date: date,
        description: note.isEmpty ? '-' : note,
        amount: amount,
        mediaUrls: mediaUrls,
      ));
    }

    // Krok 4: Převedení úkolů na BillingTaskItem s výpočtem ceny a plátce.
    final items = <BillingTaskItem>[];
    for (final t in tasksInMonth) {
      final taskId = (t['id'] as String?)?.trim() ?? '';
      if (taskId.isEmpty) continue;

      final title = (t['title'] as String?)?.trim().isNotEmpty == true
          ? (t['title'] as String).trim()
          : (t['custom_title'] as String?)?.trim() ?? taskId;
      final completedAtRaw = _parseDateTime(t['completed_at']);
      final completedAt = completedAtRaw != null ? completedAtRaw.toLocal() : null;
      final scheduledStartRaw = _parseDateTime(t['scheduled_start']);
      final scheduledStart = scheduledStartRaw != null ? scheduledStartRaw.toLocal() : null;
      final clientId = (t['client_id'] as String?)?.trim() ?? '';
      final resId = (t['reservation_id'] as String?)?.trim() ?? '';
      final svcId = (t['service_id'] as String?)?.trim() ?? '';
      final resSvcKey = '$resId|$svcId';

      double chargedPrice;
      String payerType;

      if (resId.isNotEmpty && svcId.isNotEmpty) {
        // PRAVIDLO A: Úkol napojen na rezervaci – cena z reservation_services.
        chargedPrice = priceByResService[resSvcKey] ?? 0.0;
        payerType = payerTypeByResService[resSvcKey] ?? 'guest';
      } else {
        // PRAVIDLO B: Manuální/externí úkol bez rezervace – fallback na metadata.
        // Historický bug: starý modul tyto úkoly přeskakoval. service_price = zamražená
        // cena; amount_to_collect = hotovost vybraná od hosta. Plátce: owner u bytu, client u externího.
        final meta = t['metadata'];
        double? servicePrice;
        double? amountToCollect;
        if (meta is Map) {
          servicePrice = double.tryParse((meta['service_price']?.toString() ?? '').trim());
          amountToCollect = double.tryParse((meta['amount_to_collect']?.toString() ?? '').trim());
        }
        chargedPrice = servicePrice ?? amountToCollect ?? 0.0;
        payerType = clientId.isNotEmpty ? 'client' : 'owner';
      }

      final reservationId = (t['reservation_id'] as String?)?.trim().isNotEmpty == true
          ? (t['reservation_id'] as String).trim()
          : null;
      final guestName = _parseGuestName(t['reservations']);
      final (resStart, resEnd) = _parseReservationDates(t['reservations']);
      final mediaUrls = _parseMediaUrls(t['media_urls']);

      items.add(BillingTaskItem(
        taskId: taskId,
        title: title,
        scheduledStart: scheduledStart,
        completedAt: completedAt,
        chargedPrice: chargedPrice,
        payerType: payerType,
        reservationId: reservationId,
        guestName: guestName,
        reservationStart: resStart,
        reservationEnd: resEnd,
        mediaUrls: mediaUrls,
      ));
    }

    // Krok 5: Agregace do BillingGroup – striktně podle klienta (majitele).
    //
    // PROČ: Fakturujeme lidem/firmám (Klientům), ne budovám (Apartmánům). Klient s více
    // byty má všechny úkoly – včetně těch napojených na byty i volných transferů –
    // seskupené pod sebou v jedné BillingGroup, aby mu šla vystavit jedna souhrnná faktura.
    //
    // A) Úkol má přímé client_id (externí transfer) → použij ho.
    // B) Úkol má apartment_id → dotáhni majitele přes apartment_owners a clients.profile_id.
    // C) Nemá ani klienta, ani apartmán (nebo se majitele nepodařilo dohledat) → 'external'.
    final byGroupKey = <String, List<BillingTaskItem>>{};
    for (final item in items) {
      final t = tasksInMonth.firstWhere((x) => (x['id'] as String?)?.trim() == item.taskId);
      final aptId = (t['apartment_id'] as String?)?.trim() ?? '';
      final clientIdDirect = (t['client_id'] as String?)?.trim() ?? '';

      String groupKey;
      if (clientIdDirect.isNotEmpty) {
        groupKey = clientIdDirect;
      } else if (aptId.isNotEmpty) {
        groupKey = apartmentToClientId[aptId] ?? 'external';
      } else {
        groupKey = 'external';
      }

      byGroupKey.putIfAbsent(groupKey, () => []).add(item);
    }

    final groups = <BillingGroup>[];
    for (final entry in byGroupKey.entries) {
      final list = entry.value;
      // Chronologické řazení úkolů – scheduledStart, fallback completedAt.
      final sortedList = List<BillingTaskItem>.from(list)
        ..sort((a, b) => _taskSortDate(a).compareTo(_taskSortDate(b)));
      // Celkový obrat = součet VŠECH služeb (majitel + host + klient).
      final totalToInvoice = sortedList.fold<double>(0, (s, i) => s + i.chargedPrice);
      final groupExpenses = expensesByClientId[entry.key] ?? [];
      final totalExpenses = groupExpenses.fold<double>(0, (s, e) => s + e.amount);
      groups.add(BillingGroup(
        groupKey: entry.key,
        groupName: _resolveGroupName(entry.key, clientIdToName),
        tasks: sortedList,
        totalToInvoice: totalToInvoice,
        totalExpenses: totalExpenses,
        expenses: groupExpenses,
      ));
    }

    // Seřazení podle názvu klienta.
    groups.sort((a, b) => a.groupName.compareTo(b.groupName));
    return BillingMonthState(groups: groups, isLocked: false);
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('FinanceBillingProvider error: $e');
      // ignore: avoid_print
      print(st);
    }
    rethrow;
  }
});

/// Načte položky k fakturaci pro daného klienta – úkoly s cenou > 0, status completed,
/// které patří klientovi (client_id) nebo jeho apartmánům (apartment_owners).
/// Stejná logika výpočtu ceny jako v Podkladech pro fakturaci (reservation_services / metadata).
/// Vrací i již vyfakturované úkoly (invoiced_at IS NOT NULL) pro zobrazení statusu.
final clientBillingProvider =
    FutureProvider.autoDispose.family<List<ClientBillingItem>, String>((ref, clientId) async {
  if (clientId.trim().isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  try {
    // Krok 1: Klientův profile_id a seznam apartment_id (majitel bytů).
    final clientRes = await SupabaseService.client
        .from('clients')
        .select('id, profile_id')
        .eq('tenant_id', tenantId)
        .eq('id', clientId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (clientRes == null) return [];

    final profileId = (clientRes['profile_id'] as String?)?.trim();

    final apartmentIds = <String>[];
    if (profileId != null && profileId.isNotEmpty) {
      final ownersRes = await SupabaseService.client
          .from('apartment_owners')
          .select('apartment_id')
          .eq('owner_id', profileId)
          .isFilter('deleted_at', null);
      for (final row in (ownersRes as List)) {
        final m = row as Map<String, dynamic>;
        final aptId = (m['apartment_id'] as String?)?.trim();
        if (aptId != null && aptId.isNotEmpty) apartmentIds.add(aptId);
      }
    }

    // Krok 2: Dokončené úkoly – buď přímo client_id, nebo apartment_id v seznamu majitele.
    const selectCols =
        'id, title, custom_title, apartment_id, client_id, reservation_id, service_id, '
        'completed_at, due_date, scheduled_start, invoiced_at, metadata, '
        'reservations(guest_name, start_date, end_date)';

    final tasksForClient = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    final byClientRes = await SupabaseService.client
        .from('tasks')
        .select(selectCols)
        .eq('tenant_id', tenantId)
        .eq('status', 'completed')
        .eq('client_id', clientId)
        .isFilter('deleted_at', null);
    for (final row in (byClientRes as List)) {
      final m = Map<String, dynamic>.from(row as Map<String, dynamic>);
      final id = (m['id'] as String?)?.trim() ?? '';
      if (id.isNotEmpty && seenIds.add(id)) tasksForClient.add(m);
    }

    if (apartmentIds.isNotEmpty) {
      final byAptRes = await SupabaseService.client
          .from('tasks')
          .select(selectCols)
          .eq('tenant_id', tenantId)
          .eq('status', 'completed')
          .inFilter('apartment_id', apartmentIds)
          .isFilter('deleted_at', null);
      for (final row in (byAptRes as List)) {
        final m = Map<String, dynamic>.from(row as Map<String, dynamic>);
        final id = (m['id'] as String?)?.trim() ?? '';
        if (id.isNotEmpty && seenIds.add(id)) tasksForClient.add(m);
      }
    }
    if (tasksForClient.isEmpty) return [];

    // Krok 3: Ceny z reservation_services (stejná logika jako billingReportProvider).
    final reservationIds = tasksForClient
        .map((t) => (t['reservation_id'] as String?)?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final priceByResService = <String, double>{};
    final payerTypeByResService = <String, String>{};
    if (reservationIds.isNotEmpty) {
      final servicesByRes = await fetchByReservationIds(reservationIds, tenantId);
      final apartmentServiceIds = <String>{};
      for (final list in servicesByRes.values) {
        for (final rs in list) {
          final id = rs.apartmentServiceId.trim();
          if (id.isNotEmpty) apartmentServiceIds.add(id);
        }
      }
      final aptServiceToServiceId = <String, String>{};
      if (apartmentServiceIds.isNotEmpty) {
        final aptRes = await SupabaseService.client
            .from('apartment_services')
            .select('id, service_id')
            .eq('tenant_id', tenantId)
            .inFilter('id', apartmentServiceIds.toList());
        for (final row in (aptRes as List)) {
          final m = row as Map<String, dynamic>;
          final id = (m['id'] as String?)?.trim();
          final sid = (m['service_id'] as String?)?.trim();
          if (id != null && id.isNotEmpty && sid != null && sid.isNotEmpty) {
            aptServiceToServiceId[id] = sid;
          }
        }
      }
      for (final entry in servicesByRes.entries) {
        for (final rs in entry.value) {
          final sid = aptServiceToServiceId[rs.apartmentServiceId];
          if (sid == null) continue;
          final key = '${entry.key}|$sid';
          priceByResService[key] = (rs.chargedPrice ?? 0).toDouble();
          payerTypeByResService[key] = rs.payerType ?? 'guest';
        }
      }
    }

    // Krok 4: Převedení na ClientBillingItem s výpočtem ceny (stejná pravidla jako v reportu).
    final items = <ClientBillingItem>[];
    for (final t in tasksForClient) {
      final taskId = (t['id'] as String?)?.trim() ?? '';
      if (taskId.isEmpty) continue;

      final title = (t['title'] as String?)?.trim().isNotEmpty == true
          ? (t['title'] as String).trim()
          : (t['custom_title'] as String?)?.trim() ?? taskId;
      final resId = (t['reservation_id'] as String?)?.trim() ?? '';
      final svcId = (t['service_id'] as String?)?.trim() ?? '';
      final resSvcKey = '$resId|$svcId';

      double chargedPrice;
      if (resId.isNotEmpty && svcId.isNotEmpty) {
        chargedPrice = priceByResService[resSvcKey] ?? 0.0;
      } else {
        final meta = t['metadata'];
        double? servicePrice;
        double? amountToCollect;
        if (meta is Map) {
          servicePrice = double.tryParse((meta['service_price']?.toString() ?? '').trim());
          amountToCollect = double.tryParse((meta['amount_to_collect']?.toString() ?? '').trim());
        }
        chargedPrice = servicePrice ?? amountToCollect ?? 0.0;
      }
      if (chargedPrice <= 0) continue;

      final scheduledStartRaw = _parseDateTime(t['scheduled_start']);
      final completedAtRaw = _parseDateTime(t['completed_at']);
      final date = (scheduledStartRaw ?? completedAtRaw)?.toLocal();
      final invoicedAtRaw = t['invoiced_at'];
      final isInvoiced = invoicedAtRaw != null &&
          ((invoicedAtRaw is String && invoicedAtRaw.trim().isNotEmpty) ||
              invoicedAtRaw is DateTime);

      items.add(ClientBillingItem(
        taskId: taskId,
        title: title,
        date: date,
        chargedPrice: chargedPrice,
        isInvoiced: isInvoiced,
      ));
    }

    items.sort((a, b) {
      final da = a.date ?? DateTime.utc(1970);
      final db = b.date ?? DateTime.utc(1970);
      return db.compareTo(da);
    });
    return items;
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('clientBillingProvider error: $e');
      // ignore: avoid_print
      print(st);
    }
    rethrow;
  }
});

/// Vrací datum pro chronologické řazení úkolu – scheduledStart, fallback completedAt.
DateTime _taskSortDate(BillingTaskItem t) {
  return t.scheduledStart ?? t.completedAt ?? DateTime.utc(1970);
}

/// Připojí k základnímu titulku bloku rezervace termín pobytu (dd.MM.yyyy - dd.MM.yyyy).
///
/// Termín pobytu pomáhá majitelům apartmánů snáze identifikovat, k jaké události
/// (pobytu hosta) se úklid váže. [baseTitle] = "Host: X" nebo "Rezervace: id" (i18n v UI).
String formatReservationBlockWithDates({
  required String baseTitle,
  required DateTime? reservationStart,
  required DateTime? reservationEnd,
  required String Function(DateTime) formatDate,
}) {
  if (reservationStart != null && reservationEnd != null) {
    return '$baseTitle (${formatDate(reservationStart)} - ${formatDate(reservationEnd)})';
  }
  return baseTitle;
}

/// Vrací zobrazovací název skupiny. Pro 'external' vrací klíč pro i18n –
/// UI má zobrazit 'admin.finance.billing_group_external'.tr().
String _resolveGroupName(String groupKey, Map<String, String> clientIdToName) {
  if (groupKey == 'external') return 'admin.finance.billing_group_external';
  return clientIdToName[groupKey] ?? groupKey;
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Parsuje guest_name z vnořeného objektu reservations (Supabase relation).
String? _parseGuestName(dynamic raw) {
  if (raw == null) return null;
  if (raw is! Map) return null;
  final name = (raw['guest_name'] as String?)?.trim();
  return name != null && name.isNotEmpty ? name : null;
}

/// Parsuje start_date a end_date z vnořeného objektu reservations.
/// Vrací (start, end) jako lokální DateTime – termín pobytu pomáhá majitelům
/// apartmánů snáze identifikovat, k jaké události (pobytu hosta) se úklid váže.
(DateTime?, DateTime?) _parseReservationDates(dynamic raw) {
  if (raw == null || raw is! Map) return (null, null);
  final startRaw = raw['start_date'];
  final endRaw = raw['end_date'];
  DateTime? start;
  if (startRaw != null) {
    if (startRaw is DateTime) {
      start = startRaw.toLocal();
    } else if (startRaw is String) {
      final parsed = DateTime.tryParse(startRaw);
      start = parsed?.toLocal();
    }
  }
  DateTime? end;
  if (endRaw != null) {
    if (endRaw is DateTime) {
      end = endRaw.toLocal();
    } else if (endRaw is String) {
      final parsed = DateTime.tryParse(endRaw);
      end = parsed?.toLocal();
    }
  }
  return (start, end);
}

/// Parsuje media_urls (text[]) z PostgreSQL – vrací List<String>.
/// Null a prázdné hodnoty jsou vynechány.
List<String> _parseMediaUrls(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    final list = <String>[];
    for (final e in raw) {
      final s = e?.toString().trim();
      if (s != null && s.isNotEmpty) list.add(s);
    }
    return list;
  }
  return [];
}
