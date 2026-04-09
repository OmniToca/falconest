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
/// [cashShortfall*] = nedoplatek z peněženky (amount < expected_amount) – pro zobrazení a vyřešení v Podkladech.
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
    this.cashShortfallTransactionId,
    this.cashShortfallMissingAmount,
    this.cashShortfallNote,
    this.isShortfallResolved = false,
    this.assignedTo,
    this.assignedUserIds = const [],
    this.requiresPhoto = false,
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

  /// UUID transakce v employee_cash_transactions s nedoplatkem.
  final String? cashShortfallTransactionId;

  /// Chybějící částka (expected_amount - amount) v EUR.
  final double? cashShortfallMissingAmount;

  /// Poznámka pracovníka (důvod nedoplatku).
  final String? cashShortfallNote;

  /// Zda dispečer nedoplatek již vyřešil (přenos na majitele / odpis / jinak).
  final bool isShortfallResolved;

  /// Primární přiřazení (`tasks.assigned_to`) – pro kontrolu před uzamčením fakturace.
  final String? assignedTo;

  /// Další přiřazení (`tasks.assigned_user_ids`).
  final List<String> assignedUserIds;

  /// Povinná fotodokumentace z `tasks.metadata.requires_photo`.
  final bool requiresPhoto;

  /// PROČ: Varování před uzamčením – nebezpečné uzavřít měsíc bez přiřazení nebo bez fotky u povinné služby.
  bool get hasLockBillingRisk {
    final noPrimary = assignedTo == null || assignedTo!.trim().isEmpty;
    final noSecondary = assignedUserIds.isEmpty;
    final unassigned = noPrimary && noSecondary;
    final photoMissing = requiresPhoto && mediaUrls.isEmpty;
    return unassigned || photoMissing;
  }
}

/// Položka „nedoplatek převedený na majitele“ – zobrazí se v Podkladech a na faktuře.
class BillingShortfallTransferItem {
  const BillingShortfallTransferItem({
    required this.id,
    required this.amount,
    this.description,
    this.taskId,
    required this.cashTransactionId,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String? description;
  final String? taskId;
  final String cashTransactionId;
  final DateTime? createdAt;
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
/// [shortfallTransfers] = nedoplatky z hotovosti převedené na fakturu majitele.
/// [monthlyManagementFee] = měsíční paušál za správu bytů – PŘIČÍTÁME k faktuře (i pro klienty bez úkolů v měsíci).
class BillingGroup {
  const BillingGroup({
    required this.groupKey,
    required this.groupName,
    required this.tasks,
    required this.totalToInvoice,
    this.totalExpenses = 0.0,
    this.expenses = const [],
    this.shortfallTransfers = const [],
    this.monthlyManagementFee = 0.0,
  });

  final String groupKey;
  final String groupName;
  final List<BillingTaskItem> tasks;
  final double totalToInvoice;

  /// Firemní výdaje (paragony na materiál) – PŘIČÍTÁME, majitel proplácí agentuře.
  final double totalExpenses;

  /// Detailní seznam výdajů – datum, popis, částka, fotka účtenky.
  final List<BillingExpenseItem> expenses;

  /// Nedoplatky z hotovosti převedené na majitele – PŘIČÍTÁME k faktuře.
  final List<BillingShortfallTransferItem> shortfallTransfers;

  /// Měsíční paušál za správu apartmánů – PŘIČÍTÁME k faktuře (součet za všechny byty klienta).
  final double monthlyManagementFee;

  /// Částka skutečně uhrazená hosty (hotovost) – úkoly s payerType='guest'.
  /// U úkolů s vyřešeným nedoplatkem převedeným na majitele se nepočítá celá chargedPrice,
  /// ale chargedPrice − cashShortfallMissingAmount (host skutečně zaplatil méně). Tím se
  /// nedoplatek neúčtuje dvojitě – rozdíl „obrat − skutečně uhrazeno“ už je doplatek k úhradě.
  double get totalPaidByGuest =>
      tasks.where((t) => t.payerType == 'guest').fold<double>(0, (s, t) {
        final price = t.chargedPrice;
        if (t.isShortfallResolved &&
            t.cashShortfallMissingAmount != null &&
            t.cashShortfallMissingAmount! > 0) {
          return s + (price - t.cashShortfallMissingAmount!);
        }
        return s + price;
      });

  double get totalShortfallTransfers =>
      shortfallTransfers.fold<double>(0, (s, t) => s + t.amount);

  /// Finální částka k úhradě majitelem = obrat − skutečně uhraveno hosty + náklady + měsíční paušál.
  /// Nedoplatky se již ne přičítají zvlášť – jsou zahrnuty v (obrat − totalPaidByGuest).
  double get finalToInvoice =>
      (totalToInvoice - totalPaidByGuest) +
      totalExpenses +
      monthlyManagementFee;

  /// True, pokud ve skupině existuje alespoň jeden úkol s nevyřešeným nedoplatkem (zobrazení ikony v záhlaví).
  bool get hasUnresolvedShortfalls => tasks.any(
    (t) =>
        t.cashShortfallMissingAmount != null &&
        t.cashShortfallMissingAmount! > 0 &&
        !t.isShortfallResolved,
  );

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
    final clientName =
        (currentClientName != null && currentClientName.trim().isNotEmpty)
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
        final cashShortfallMissing = _toDouble(
          itemMap['cash_shortfall_missing_amount'],
        );
        final isShortfallResolved = itemMap['is_shortfall_resolved'] == true;
        final assignedToSnap = (itemMap['assigned_to'] as String?)?.trim();
        final assignedTo = assignedToSnap != null && assignedToSnap.isNotEmpty
            ? assignedToSnap
            : null;
        final assignedUserIdsRaw = itemMap['assigned_user_ids'];
        final assignedUserIds = assignedUserIdsRaw is List
            ? assignedUserIdsRaw
                  .map((e) => e?.toString().trim())
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .toList()
            : <String>[];
        final requiresPhoto = itemMap['requires_photo'] == true;

        tasks.add(
          BillingTaskItem(
            taskId: taskId,
            title: title,
            scheduledStart: scheduledStart,
            completedAt: completedAt,
            chargedPrice: chargedPrice,
            payerType: payerType,
            reservationId: reservationId?.isNotEmpty == true
                ? reservationId
                : null,
            guestName: guestName?.isNotEmpty == true ? guestName : null,
            reservationStart: reservationStart,
            reservationEnd: reservationEnd,
            mediaUrls: mediaUrls,
            cashShortfallMissingAmount: cashShortfallMissing,
            isShortfallResolved: isShortfallResolved,
            assignedTo: assignedTo,
            assignedUserIds: assignedUserIds,
            requiresPhoto: requiresPhoto,
          ),
        );
      }
    }

    // Obrat = součet všech chargedPrice (kompatibilita se živým výpočtem).
    final totalToInvoice = tasks.fold<double>(0, (s, t) => s + t.chargedPrice);
    tasks.sort((a, b) => _taskSortDate(a).compareTo(_taskSortDate(b)));

    final monthlyFee = _toDouble(snapshotData['monthly_management_fee']) ?? 0.0;

    return BillingGroup(
      groupKey: clientId,
      groupName: clientName,
      tasks: tasks,
      totalToInvoice: totalToInvoice,
      totalExpenses: totalExpenses,
      expenses: expenses,
      shortfallTransfers: const [],
      monthlyManagementFee: monthlyFee >= 0 ? monthlyFee : 0.0,
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
    result.add(
      BillingExpenseItem(
        id: id,
        date: date,
        description: description.isEmpty ? '-' : description,
        amount: amount,
        mediaUrls: mediaUrls,
      ),
    );
  }
  return result;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Z řádků apartment_owners vybere pro každý apartment_id právě jednoho owner_id.
///
/// PROČ: U spoluvlastnictví (více majitelů na jeden byt) smí fakturace (paušál i úkoly)
/// jít jen jednomu klientovi. Pravidlo: přednost záznamu s is_primary_billing == true,
/// jinak první dostupný. Výsledná mapa je 1 apartmán = 1 majitel.
Map<String, String> _pickOneOwnerPerApartment(List<dynamic> rawRows) {
  final byApt = <String, List<({String ownerId, bool isPrimary})>>{};
  for (final row in rawRows) {
    final m = row as Map<String, dynamic>;
    final aptId = (m['apartment_id'] as String?)?.trim();
    final ownerId = (m['owner_id'] as String?)?.trim();
    if (aptId == null || aptId.isEmpty || ownerId == null || ownerId.isEmpty)
      continue;
    final isPrimary = m['is_primary_billing'] == true;
    byApt.putIfAbsent(aptId, () => []).add((
      ownerId: ownerId,
      isPrimary: isPrimary,
    ));
  }
  final result = <String, String>{};
  for (final e in byApt.entries) {
    final list = e.value;
    if (list.isEmpty) continue;
    final primary = list.where((x) => x.isPrimary).toList();
    if (primary.isNotEmpty) {
      result[e.key] = primary.first.ownerId;
    } else {
      result[e.key] = list.first.ownerId;
    }
  }
  return result;
}

/// Stav měsíce fakturace – živá data nebo zmražená historie.
///
/// [groups] = seskupené úkoly podle klienta.
/// [isLocked] = true znamená, že měsíc je uzamčen; data pocházejí z billing_snapshots.
class BillingMonthState {
  const BillingMonthState({required this.groups, this.isLocked = false});

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
final billingReportProvider = FutureProvider.autoDispose.family<BillingMonthState, BillingMonthParam>((
  ref,
  param,
) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return const BillingMonthState(groups: [], isLocked: false);
  }

  final billingPeriodStr =
      '${param.year}-${param.month.toString().padLeft(2, '0')}-01';

  try {
    // Krok 0: Zkontroluj, zda měsíc má zmražené snapshoty (uzamčen).
    final snapshotsRes = await SupabaseService.safeFrom(
      'billing_snapshots',
      tenantId,
    ).select('client_id, snapshot_data').eq('billing_period', billingPeriodStr);

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
        final clientsRes = await SupabaseService.safeFrom('clients', tenantId)
            .select('id, name')
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
        reconstructedGroups.add(
          BillingGroup.fromSnapshot(
            snapshotData,
            clientId,
            currentClientName: currentName,
          ),
        );
      }
      reconstructedGroups.sort((a, b) => a.groupName.compareTo(b.groupName));
      return BillingMonthState(groups: reconstructedGroups, isLocked: true);
    }

    // Živá data – nejprve založíme skupiny z aktivních apartmánů s měsíčním paušálem, pak načteme úkoly.
    final clientIdToName = <String, String>{};
    final monthlyFeeByGroupKey = <String, double>{};
    final byGroupKey = <String, List<BillingTaskItem>>{};
    final apartmentToClientId = <String, String>{};

    // Krok 0b: Aktivní apartmány s monthly_management_fee > 0 – založí BillingGroup pro každého majitele (i bez úkolů v měsíci).
    // Paušál se započte jen pokud je měsíc fakturace >= managed_from (nebo managed_from je null – zpětná kompatibilita).
    final startOfBillingMonth = DateTime.utc(param.year, param.month, 1);
    final apartmentsRes = await SupabaseService.safeFrom('apartments', tenantId)
        .select('id, monthly_management_fee, managed_from')
        .isFilter('deleted_at', null);
    final apartmentsList = (apartmentsRes as List).cast<Map<String, dynamic>>();
    final feeApartmentIds = <String>[];
    final feeByApartmentId = <String, double>{};
    for (final row in apartmentsList) {
      final aptId = (row['id'] as String?)?.trim();
      if (aptId == null || aptId.isEmpty) continue;
      final fee = _toDouble(row['monthly_management_fee']);
      if (fee == null || fee <= 0) continue;
      final managedFromRaw = row['managed_from'];
      if (managedFromRaw != null) {
        final managedFrom = DateTime.tryParse(managedFromRaw.toString());
        if (managedFrom != null) {
          final firstDayManaged = DateTime.utc(
            managedFrom.year,
            managedFrom.month,
            1,
          );
          if (startOfBillingMonth.isBefore(firstDayManaged)) continue;
        }
      }
      feeApartmentIds.add(aptId);
      feeByApartmentId[aptId] = fee;
    }
    if (feeApartmentIds.isNotEmpty) {
      // PROČ: Frontend Firewall – žádný holý client.from u vazební tabulky; tenant_id z auth kontextu.
      final ownersRes =
          await SupabaseService.safeFrom('apartment_owners', tenantId)
              .select('apartment_id, owner_id, is_primary_billing')
              .inFilter('apartment_id', feeApartmentIds)
              .isFilter('deleted_at', null);
      // Jeden majitel na apartmán – přednost is_primary_billing, jinak první (ochrana před dvojí fakturační u spoluvlastnictví).
      final apartmentToOwnerIdFee = _pickOneOwnerPerApartment(
        ownersRes as List,
      );
      final ownerIds = apartmentToOwnerIdFee.values.toSet().toList();
      if (ownerIds.isNotEmpty) {
        final clientsRes = await SupabaseService.safeFrom('clients', tenantId)
            .select('id, name, profile_id')
            .inFilter('profile_id', ownerIds)
            .isFilter('deleted_at', null);
        final ownerIdToClientIdFee = <String, String>{};
        for (final row in (clientsRes as List)) {
          final m = row as Map<String, dynamic>;
          final id = (m['id'] as String?)?.trim();
          final name = (m['name'] as String?)?.trim();
          final profileId = (m['profile_id'] as String?)?.trim();
          if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
            clientIdToName[id] = name;
          }
          if (id != null &&
              id.isNotEmpty &&
              profileId != null &&
              profileId.isNotEmpty) {
            ownerIdToClientIdFee[profileId] = id;
          }
        }
        for (final e in apartmentToOwnerIdFee.entries) {
          final cid = ownerIdToClientIdFee[e.value];
          if (cid != null && cid.isNotEmpty) {
            apartmentToClientId[e.key] = cid;
            final fee = feeByApartmentId[e.key] ?? 0.0;
            monthlyFeeByGroupKey[cid] = (monthlyFeeByGroupKey[cid] ?? 0) + fee;
          }
        }
        for (final cid in monthlyFeeByGroupKey.keys) {
          byGroupKey[cid] = [];
        }
      }
    }

    // Živá data – načti dokončené nevyfakturované úkoly POUZE pro vybraný měsíc (časové okno v DB).
    final startOfMonth = DateTime.utc(param.year, param.month, 1);
    final startOfNextMonth = DateTime.utc(param.year, param.month + 1, 1);
    final startIso = startOfMonth.toIso8601String();
    final endIso = startOfNextMonth.toIso8601String();

    // Krok 1: Načti dokončené nevyfakturované úkoly tenantu pro daný měsíc (filtr v DB).
    // PROČ: Výkon – bez filtru by se stahovala celá historie (OOM při 10 000+ úkolech).
    final tasksRes = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          'id, title, custom_title, task_type, apartment_id, reservation_id, service_id, client_id, '
          'completed_at, due_date, scheduled_start, metadata, media_urls, '
          'assigned_to, assigned_user_ids, '
          'reservations(guest_name, start_date, end_date)',
        )
        .eq('status', 'completed')
        .isFilter('invoiced_at', null)
        .isFilter('deleted_at', null)
        .gte('completed_at', startIso)
        .lt('completed_at', endIso)
        .limit(2000);

    final tasksList = (tasksRes as List).cast<Map<String, dynamic>>();
    // Úkoly jsou již vyfiltrované podle měsíce v DB; použijeme je přímo. Nepřerušujeme ani při 0 úkolech – skupiny mohou být jen z paušálu.
    final tasksInMonth = tasksList;

    // Krok 2: Ceny a plátce z reservation_services (historický snapshot – NIKDY z aktuálního ceníku).
    //
    // Zákaz mutace historie: Úkoly dokončené v minulosti musejí zobrazovat cenu a plátce tak, jak
    // byly uloženy u rezervace v době vzniku. Mapování reservation_services → úkol jde přes
    // apartment_services (apartment_service_id → service_id). Pokud byl apartmán později přeřazen
    // jinému majiteli a apartment_services byly nahrazeny, staré apartment_service_id už v DB
    // neexistují – bez fallbacku bychom vrátili 0 EUR a „guest“. Proto: řádky reservation_services,
    // u kterých nelze dohledat service_id (apartment_services smazány), ukládáme do fallbacku
    // po rezervaci; u úkolu s rezervací pak použijeme jediný takový řádek (typicky jedna služba
    // na rezervaci), takže historická cena a plátce zůstanou zachovány.
    final reservationIds = tasksInMonth
        .map((t) => (t['reservation_id'] as String?)?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final priceByResService = <String, double>{};
    final payerTypeByResService = <String, String>{};

    /// Fallback: rezervace → seznam (charged_price, payer_type) u řádků reservation_services,
    /// jejichž apartment_service_id už v apartment_services neexistuje (byt přeřazen, záznamy nahrazeny).
    final fallbackPricePayerByResId =
        <String, List<({double price, String payer})>>{};
    if (reservationIds.isNotEmpty) {
      final servicesByRes = await fetchByReservationIds(
        reservationIds,
        tenantId,
      );
      final apartmentServiceIds = <String>{};
      for (final list in servicesByRes.values) {
        for (final rs in list) {
          final id = rs.apartmentServiceId.trim();
          if (id.isNotEmpty) apartmentServiceIds.add(id);
        }
      }
      final aptServiceToServiceId = <String, String>{};
      if (apartmentServiceIds.isNotEmpty) {
        final aptRes = await SupabaseService.safeFrom(
          'apartment_services',
          tenantId,
        ).select('id, service_id').inFilter('id', apartmentServiceIds.toList());
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
        final resId = entry.key;
        for (final rs in entry.value) {
          final sid = aptServiceToServiceId[rs.apartmentServiceId];
          final price = (rs.chargedPrice ?? 0).toDouble();
          final payer = rs.payerType ?? 'guest';
          if (sid != null) {
            final key = '$resId|$sid';
            priceByResService[key] = price;
            payerTypeByResService[key] = payer;
          } else {
            // apartment_services záznam už neexistuje (např. přeřazení bytu) – uchováme pro fallback
            fallbackPricePayerByResId.putIfAbsent(resId, () => []).add((
              price: price,
              payer: payer,
            ));
          }
        }
      }
    }

    // Krok 3: Mapování byt → majitel (profile) → klient pro ÚKOLY. Vazba: apartment_owners.owner_id
    // = profiles.id, clients.profile_id = profiles.id. Doplnění do již naplněných map z Krok 0b (paušály).
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

    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (apartmentIdsFromTasks.isNotEmpty) {
      final ownersRes =
          await SupabaseService.safeFrom('apartment_owners', tenantId)
              .select('apartment_id, owner_id, is_primary_billing')
              .inFilter('apartment_id', apartmentIdsFromTasks)
              .isFilter('deleted_at', null);
      // Jeden majitel na apartmán – přednost is_primary_billing, jinak první (ochrana před dvojí fakturační u spoluvlastnictví).
      final picked = _pickOneOwnerPerApartment(ownersRes as List);
      for (final e in picked.entries) {
        apartmentToOwnerId[e.key] = e.value;
      }
    }

    final profileIdsToFetch = apartmentToOwnerId.values.toSet().toList();
    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (profileIdsToFetch.isNotEmpty) {
      final clientsByProfileRes =
          await SupabaseService.safeFrom('clients', tenantId)
              .select('id, name, profile_id')
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
        if (id != null &&
            id.isNotEmpty &&
            profileId != null &&
            profileId.isNotEmpty) {
          ownerIdToClientId[profileId] = id;
        }
      }
    }

    // Ochrana proti chybě Supabase: inFilter nesmí dostat prázdné pole, jinak dotaz tiše zhavaruje.
    if (clientIdsFromTasks.isNotEmpty) {
      final clientsDirectRes =
          await SupabaseService.safeFrom('clients', tenantId)
              .select('id, name')
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

    for (final e in apartmentToOwnerId.entries) {
      final cid = ownerIdToClientId[e.value];
      if (cid != null) apartmentToClientId[e.key] = cid;
    }

    // Krok 3b: Firemní výdaje s apartment_id – PŘIČÍTÁME k faktuře, majitel proplácí agentuře.
    // Načti transakce COMPANY_EXPENSE v daném měsíci včetně detailů (note, receipt_image_url).
    final expensesByClientId = <String, List<BillingExpenseItem>>{};
    final expensesRes =
        await SupabaseService.safeFrom('employee_cash_transactions', tenantId)
            .select(
              'id, apartment_id, amount, note, receipt_image_url, created_at',
            )
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
          : (amountRaw != null
                    ? double.tryParse(amountRaw.toString())?.abs()
                    : null) ??
                0.0;
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
      expensesByClientId
          .putIfAbsent(clientId, () => [])
          .add(
            BillingExpenseItem(
              id: id,
              date: date,
              description: note.isEmpty ? '-' : note,
              amount: amount,
              mediaUrls: mediaUrls,
            ),
          );
    }

    // Krok 3c: Nedoplatky z peněženky (amount < expected_amount) – pro zobrazení v řádcích úkolů.
    final taskIds = tasksInMonth
        .map((t) => (t['id'] as String?)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final shortfallByTaskId =
        <String, ({String id, double missing, String note, bool resolved})>{};
    if (taskIds.isNotEmpty) {
      try {
        final shortfallRes =
            await SupabaseService.safeFrom(
                  'employee_cash_transactions',
                  tenantId,
                )
                .select(
                  'id, task_id, amount, expected_amount, note, is_shortfall_resolved',
                )
                .eq('transaction_type', 'COLLECTED_FROM_GUEST')
                .not('expected_amount', 'is', null)
                .inFilter('task_id', taskIds);
        for (final row in (shortfallRes as List)) {
          final m = row as Map<String, dynamic>;
          final tid = (m['task_id'] as String?)?.trim();
          if (tid == null || tid.isEmpty) continue;
          final amount = _toDouble(m['amount']);
          final expected = _toDouble(m['expected_amount']);
          if (amount == null || expected == null || amount >= expected)
            continue;
          final id = (m['id'] as String?)?.trim() ?? '';
          if (id.isEmpty) continue;
          final note = (m['note'] as String?)?.trim() ?? '';
          final resolved = m['is_shortfall_resolved'] == true;
          shortfallByTaskId[tid] = (
            id: id,
            missing: expected - amount,
            note: note,
            resolved: resolved,
          );
        }
      } catch (_) {
        // Nedoplatky nejsou kritické pro sestavení podkladů – pokračujeme bez nich.
      }
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
      final completedAt = completedAtRaw?.toLocal();
      final scheduledStartRaw = _parseDateTime(t['scheduled_start']);
      final scheduledStart = scheduledStartRaw?.toLocal();
      final clientId = (t['client_id'] as String?)?.trim() ?? '';
      final resId = (t['reservation_id'] as String?)?.trim() ?? '';
      final svcId = (t['service_id'] as String?)?.trim() ?? '';
      final resSvcKey = '$resId|$svcId';

      // Cena a plátce VŽDY z historie (úkol / reservation_services), nikdy z aktuálního ceníku klienta.
      double chargedPrice;
      String payerType;
      final meta = t['metadata'];
      final metaServicePrice = meta is Map
          ? double.tryParse((meta['service_price']?.toString() ?? '').trim())
          : null;
      final metaAmountToCollect = meta is Map
          ? double.tryParse(
              (meta['amount_to_collect']?.toString() ?? '').trim(),
            )
          : null;
      final metaPayerType = meta is Map
          ? ((meta['payer_type'] as String?)?.trim())
          : null;
      final requiresPhoto = _requiresPhotoFromMetadata(meta);
      final assignedToRaw = (t['assigned_to'] as String?)?.trim();
      final assignedTo =
          assignedToRaw != null && assignedToRaw.isNotEmpty ? assignedToRaw : null;
      final assignedUserIds = _parseUuidList(t['assigned_user_ids']);

      if (resId.isNotEmpty && svcId.isNotEmpty) {
        // PRAVIDLO A: Úkol napojen na rezervaci – primárně reservation_services (jak bylo uloženo u rezervace).
        final fromRes = priceByResService[resSvcKey];
        final payerFromRes = payerTypeByResService[resSvcKey];
        if (fromRes != null && payerFromRes != null) {
          chargedPrice = metaServicePrice ?? metaAmountToCollect ?? fromRes;
          payerType = payerFromRes;
        } else {
          // Mapování selhalo (apartment_services po přeřazení bytu už neexistují) – fallback z reservation_services.
          final fallbackList = fallbackPricePayerByResId[resId];
          if (fallbackList != null && fallbackList.length == 1) {
            chargedPrice =
                metaServicePrice ??
                metaAmountToCollect ??
                fallbackList.first.price;
            payerType = fallbackList.first.payer;
          } else {
            chargedPrice = metaServicePrice ?? metaAmountToCollect ?? 0.0;
            payerType = _resolvePayerType(
              metaPayerType,
              metaAmountToCollect,
              clientId,
            );
          }
        }
      } else {
        // PRAVIDLO B: Manuální/externí úkol bez rezervace – VŽDY respektovat metadata.payer_type.
        // Legacy: amount_to_collect > 0 implikuje guest (konzistentní s mobilním UI).
        chargedPrice = metaServicePrice ?? metaAmountToCollect ?? 0.0;
        payerType = _resolvePayerType(
          metaPayerType,
          metaAmountToCollect,
          clientId,
        );
      }

      final reservationId =
          (t['reservation_id'] as String?)?.trim().isNotEmpty == true
          ? (t['reservation_id'] as String).trim()
          : null;
      final guestName = _parseGuestName(t['reservations']);
      final (resStart, resEnd) = _parseReservationDates(t['reservations']);
      final mediaUrls = _parseMediaUrls(t['media_urls']);
      final shortfall = shortfallByTaskId[taskId];

      items.add(
        BillingTaskItem(
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
          cashShortfallTransactionId: shortfall?.id,
          cashShortfallMissingAmount: shortfall?.missing,
          cashShortfallNote: shortfall?.note.isEmpty == true
              ? null
              : shortfall?.note,
          isShortfallResolved: shortfall?.resolved ?? false,
          assignedTo: assignedTo,
          assignedUserIds: assignedUserIds,
          requiresPhoto: requiresPhoto,
        ),
      );
    }

    // Krok 4b: Nedoplatky převedené na majitele (billing_shortfall_transfers) v daném měsíci.
    final shortfallTransfersByClientId =
        <String, List<BillingShortfallTransferItem>>{};
    try {
      final transfersRes =
          await SupabaseService.safeFrom(
                'billing_shortfall_transfers',
                tenantId,
              )
              .select(
                'id, client_id, amount, description, task_id, cash_transaction_id, created_at',
              )
              .gte('created_at', startIso)
              .lt('created_at', endIso);
      for (final row in (transfersRes as List)) {
        final m = row as Map<String, dynamic>;
        final clientId = (m['client_id'] as String?)?.trim();
        if (clientId == null || clientId.isEmpty) continue;
        final id = (m['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) continue;
        final amount = _toDouble(m['amount']) ?? 0.0;
        if (amount <= 0) continue;
        final description = (m['description'] as String?)?.trim();
        final taskIdTr = (m['task_id'] as String?)?.trim();
        final cashTxId = (m['cash_transaction_id'] as String?)?.trim() ?? '';
        if (cashTxId.isEmpty) continue;
        DateTime? createdAt;
        final raw = m['created_at'];
        if (raw != null) {
          if (raw is DateTime) {
            createdAt = raw.toUtc();
          } else if (raw is String) {
            createdAt = DateTime.tryParse(raw)?.toUtc();
          }
        }
        shortfallTransfersByClientId
            .putIfAbsent(clientId, () => [])
            .add(
              BillingShortfallTransferItem(
                id: id,
                amount: amount,
                description: description,
                taskId: taskIdTr?.isEmpty == true ? null : taskIdTr,
                cashTransactionId: cashTxId,
                createdAt: createdAt,
              ),
            );
      }
    } catch (_) {
      // Tabulka může chybět na starších migracích – ignorujeme.
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
    //
    // PROČ Map místo firstWhere v cyklu: O(n) místo O(n²) při tisících úkolů (hlavní izolát).
    final tasksById = <String, Map<String, dynamic>>{
      for (final t in tasksInMonth)
        if ((t['id'] as String?)?.trim().isNotEmpty == true)
          (t['id'] as String).trim(): t,
    };
    for (final item in items) {
      final t = tasksById[item.taskId];
      if (t == null) continue;
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
      final totalToInvoice = sortedList.fold<double>(
        0,
        (s, i) => s + i.chargedPrice,
      );
      final groupExpenses = expensesByClientId[entry.key] ?? [];
      final totalExpenses = groupExpenses.fold<double>(
        0,
        (s, e) => s + e.amount,
      );
      final groupShortfallTransfers =
          shortfallTransfersByClientId[entry.key] ?? [];
      final groupMonthlyFee = monthlyFeeByGroupKey[entry.key] ?? 0.0;
      groups.add(
        BillingGroup(
          groupKey: entry.key,
          groupName: _resolveGroupName(entry.key, clientIdToName),
          tasks: sortedList,
          totalToInvoice: totalToInvoice,
          totalExpenses: totalExpenses,
          expenses: groupExpenses,
          shortfallTransfers: groupShortfallTransfers,
          monthlyManagementFee: groupMonthlyFee,
        ),
      );
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

/// Vyřeší nedoplatek z peněženky: označí transakci jako vyřešenou a volitelně
/// vytvoří položku „Přenést na majitele“ v billing_shortfall_transfers.
///
/// [resolutionType] = 'transfer_to_owner' | 'write_off' | 'other'.
/// Při 'transfer_to_owner' jsou povinné [transferClientId] a [transferAmount].
Future<void> resolveBillingShortfall({
  required String tenantId,
  required String cashTransactionId,
  required String resolutionType,
  String? resolutionNote,
  String? transferClientId,
  double? transferAmount,
  String? transferDescription,
  String? taskId,
}) async {
  await SupabaseService.safeFrom('employee_cash_transactions', tenantId)
      .update({
        'is_shortfall_resolved': true,
        'shortfall_resolution_type': resolutionType,
        if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
          'shortfall_resolution_note': resolutionNote.trim(),
      })
      .eq('id', cashTransactionId);

  if (resolutionType == 'transfer_to_owner' &&
      transferClientId != null &&
      transferClientId.trim().isNotEmpty &&
      transferAmount != null &&
      transferAmount > 0) {
    await SupabaseService.safeFrom(
      'billing_shortfall_transfers',
      tenantId,
    ).insert({
      'client_id': transferClientId.trim(),
      'amount': transferAmount,
      if (transferDescription != null && transferDescription.trim().isNotEmpty)
        'description': transferDescription.trim(),
      if (taskId != null && taskId.trim().isNotEmpty) 'task_id': taskId.trim(),
      'cash_transaction_id': cashTransactionId,
    });
  }
}

/// Načte položky k fakturaci pro daného klienta – úkoly s cenou > 0, status completed,
/// které patří klientovi (client_id) nebo jeho apartmánům (apartment_owners).
/// Stejná logika výpočtu ceny jako v Podkladech pro fakturaci (reservation_services / metadata).
/// Vrací i již vyfakturované úkoly (invoiced_at IS NOT NULL) pro zobrazení statusu.
final clientBillingProvider = FutureProvider.autoDispose
    .family<List<ClientBillingItem>, String>((ref, clientId) async {
      if (clientId.trim().isEmpty) return [];
      final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) return [];

      try {
        // Krok 1: Klientův profile_id a seznam apartment_id (majitel bytů).
        final clientRes = await SupabaseService.safeFrom('clients', tenantId)
            .select('id, profile_id')
            .eq('id', clientId)
            .isFilter('deleted_at', null)
            .maybeSingle();
        if (clientRes == null) return [];

        final profileId = (clientRes['profile_id'] as String?)?.trim();

        final apartmentIds = <String>[];
        if (profileId != null && profileId.isNotEmpty) {
          final ownersRes =
              await SupabaseService.safeFrom('apartment_owners', tenantId)
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

        final byClientRes = await SupabaseService.safeFrom('tasks', tenantId)
            .select(selectCols)
            .eq('status', 'completed')
            .eq('client_id', clientId)
            .isFilter('deleted_at', null);
        for (final row in (byClientRes as List)) {
          final m = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final id = (m['id'] as String?)?.trim() ?? '';
          if (id.isNotEmpty && seenIds.add(id)) tasksForClient.add(m);
        }

        if (apartmentIds.isNotEmpty) {
          final byAptRes = await SupabaseService.safeFrom('tasks', tenantId)
              .select(selectCols)
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

        // Krok 3: Ceny z reservation_services (stejná logika + fallback jako v billingReportProvider – zákaz mutace historie).
        final reservationIds = tasksForClient
            .map((t) => (t['reservation_id'] as String?)?.trim())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        final priceByResService = <String, double>{};
        final fallbackPriceByResId = <String, List<double>>{};
        if (reservationIds.isNotEmpty) {
          final servicesByRes = await fetchByReservationIds(
            reservationIds,
            tenantId,
          );
          final apartmentServiceIds = <String>{};
          for (final list in servicesByRes.values) {
            for (final rs in list) {
              final id = rs.apartmentServiceId.trim();
              if (id.isNotEmpty) apartmentServiceIds.add(id);
            }
          }
          final aptServiceToServiceId = <String, String>{};
          if (apartmentServiceIds.isNotEmpty) {
            final aptRes =
                await SupabaseService.safeFrom('apartment_services', tenantId)
                    .select('id, service_id')
                    .inFilter('id', apartmentServiceIds.toList());
            for (final row in (aptRes as List)) {
              final m = row as Map<String, dynamic>;
              final id = (m['id'] as String?)?.trim();
              final sid = (m['service_id'] as String?)?.trim();
              if (id != null &&
                  id.isNotEmpty &&
                  sid != null &&
                  sid.isNotEmpty) {
                aptServiceToServiceId[id] = sid;
              }
            }
          }
          for (final entry in servicesByRes.entries) {
            final resId = entry.key;
            for (final rs in entry.value) {
              final sid = aptServiceToServiceId[rs.apartmentServiceId];
              final price = (rs.chargedPrice ?? 0).toDouble();
              if (sid != null) {
                priceByResService['$resId|$sid'] = price;
              } else {
                fallbackPriceByResId.putIfAbsent(resId, () => []).add(price);
              }
            }
          }
        }

        // Krok 4: Převedení na ClientBillingItem – cena vždy z úkolu / reservation_services (historie), ne z ceníku.
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
          final meta = t['metadata'];
          final metaServicePrice = meta is Map
              ? double.tryParse(
                  (meta['service_price']?.toString() ?? '').trim(),
                )
              : null;
          final metaAmountToCollect = meta is Map
              ? double.tryParse(
                  (meta['amount_to_collect']?.toString() ?? '').trim(),
                )
              : null;

          double chargedPrice;
          if (resId.isNotEmpty && svcId.isNotEmpty) {
            final fromRes = priceByResService[resSvcKey];
            if (fromRes != null) {
              chargedPrice = metaServicePrice ?? metaAmountToCollect ?? fromRes;
            } else {
              final fallbackList = fallbackPriceByResId[resId];
              chargedPrice =
                  metaServicePrice ??
                  metaAmountToCollect ??
                  (fallbackList != null && fallbackList.length == 1
                      ? fallbackList.first
                      : 0.0);
            }
          } else {
            chargedPrice = metaServicePrice ?? metaAmountToCollect ?? 0.0;
          }
          if (chargedPrice <= 0) continue;

          final scheduledStartRaw = _parseDateTime(t['scheduled_start']);
          final completedAtRaw = _parseDateTime(t['completed_at']);
          final date = (scheduledStartRaw ?? completedAtRaw)?.toLocal();
          final invoicedAtRaw = t['invoiced_at'];
          final isInvoiced =
              invoicedAtRaw != null &&
              ((invoicedAtRaw is String && invoicedAtRaw.trim().isNotEmpty) ||
                  invoicedAtRaw is DateTime);

          items.add(
            ClientBillingItem(
              taskId: taskId,
              title: title,
              date: date,
              chargedPrice: chargedPrice,
              isInvoiced: isInvoiced,
            ),
          );
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

/// Určí plátce z metadata.payer_type; legacy: amount_to_collect > 0 implikuje guest.
String _resolvePayerType(
  String? metaPayerType,
  double? metaAmountToCollect,
  String clientId,
) {
  if (metaPayerType == 'guest' ||
      metaPayerType == 'owner' ||
      metaPayerType == 'client') {
    return metaPayerType!;
  }
  // Konzistence s mobilním UI: amount_to_collect = „host platí hotovost“ (viz DATA_FLOW_PRICING.md).
  if ((metaAmountToCollect ?? 0) > 0) return 'guest';
  return clientId.isNotEmpty ? 'client' : 'owner';
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

/// Parsuje media_urls (text[]) z PostgreSQL – vrací seznam URL řetězců.
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

/// Parsuje pole UUID (`assigned_user_ids`) z PostgreSQL / JSON snapshotu.
List<String> _parseUuidList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw
        .map((e) => e?.toString().trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

/// `metadata.requires_photo` – služba vyžaduje fotodokumentaci před uzamčením fakturace.
bool _requiresPhotoFromMetadata(dynamic meta) {
  if (meta is! Map) return false;
  final v = meta['requires_photo'];
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  if (v is num) return v != 0;
  return false;
}
