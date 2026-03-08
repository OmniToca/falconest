import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart'
    show ReservationServiceRow, parseFlightFromCustomNote;
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_repository.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';
import 'package:falconest/features/admin/providers/task_assignment_engine.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Návrh změny přiřazení/času úkolu z přepočtu personálu – dispečer může vybrat, které změny potvrdit.
class TaskRecalculationProposal {
  const TaskRecalculationProposal({
    required this.taskId,
    required this.taskTitle,
    this.oldAssigneeId,
    this.oldAssigneeName,
    this.newAssigneeId,
    this.newAssigneeName,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });
  final String taskId;
  final String taskTitle;
  final String? oldAssigneeId;
  final String? oldAssigneeName;
  final String? newAssigneeId;
  final String? newAssigneeName;
  final DateTime oldStart;
  final DateTime oldEnd;
  final DateTime newStart;
  final DateTime newEnd;
}

/// Model úkolu – propojuje Apartmány (apartment_id), Personál (assigned_to), Rezervaci (reservation_id) a vlastní údaje.
///
/// [apartmentName] a [assignedToName] se doplní v provideru z joinů.
/// [reservationId] – vazba na rezervaci; umožňuje mazání při změně termínu.
///
/// Kontextová pole (pro „Apple Vibe“ read-only blok v detailu úkolu):
/// [reservationGuestName], [reservationStartDate], [reservationEndDate], [reservationGuestCount],
/// [createdAt] – vyplní se z JOINů při načítání, jinak null.
class TaskRow {
  const TaskRow({
    required this.id,
    required this.apartmentId,
    this.referenceNumber,
    this.clientId,
    this.customTitle,
    this.customLocation,
    this.assignedTo,
    this.assignedUserIds = const [],
    required this.title,
    required this.description,
    required this.status,
    required this.taskType,
    required this.dueDate,
    this.scheduledStart,
    this.apartmentName,
    this.assignedToName,
    this.deletedAt,
    this.reservationId,
    this.serviceId,
    this.reservationGuestName,
    this.reservationStartDate,
    this.reservationEndDate,
    this.reservationGuestCount,
    this.createdAt,
    this.metadata,
    this.mediaUrls = const [],
    this.invoicedAt,
  });

  /// URL fotek v Supabase Storage (tasks/) – hlášení závad, check-in pasy, úklid.
  final List<String> mediaUrls;

  /// Flexibilní data pro UI (např. částka k vybrání, poznámky z rezervace, číslo letu).
  final Map<String, dynamic>? metadata;

  final String id;
  final String apartmentId;
  /// Referenční číslo úkolu (např. TSK-X7M2P4). Lidsky čitelný identifikátor pro podporu.
  final String? referenceNumber;
  /// Pro externí úkoly bez bytu – FK na clients.
  final String? clientId;
  /// Název služby pro externí úkoly (např. "Transfer letiště").
  final String? customTitle;
  /// Adresa/lokace pro externí úkoly.
  final String? customLocation;
  final String? assignedTo;
  /// Další přiřazení pracovníci – pro sdílení úkolu a dělení odměny.
  final List<String> assignedUserIds;
  final String title;
  final String description;
  final String status;
  final String taskType;
  final DateTime dueDate;
  /// Skutečný naplánovaný začátek (scheduled_start) – pro zobrazení v kalendáři a v dialozích.
  final DateTime? scheduledStart;
  final String? apartmentName;
  final String? assignedToName;
  /// Soft delete: když není null, záznam je považován za smazaný (v UI se neukazuje).
  final DateTime? deletedAt;
  /// Rezervace, pro kterou byl úkol vygenerován (pro mazání při změně termínu).
  final String? reservationId;
  /// Služba z katalogu (tenant_services.id). Pro scheduled úkoly: identifikace a ochranný štít.
  final String? serviceId;
  /// Jméno hosta z propojené rezervace (pro kontext v detailu úkolu).
  final String? reservationGuestName;
  /// Datum začátku rezervace (pro zobrazení termínu v kontextu).
  final DateTime? reservationStartDate;
  /// Datum konce rezervace.
  final DateTime? reservationEndDate;
  /// Celkový počet hostů (guest_adults + guest_children) – null, pokud není k dispozici.
  final int? reservationGuestCount;
  /// Kdy byl úkol vytvořen (audit) – pokud tabulka tasks má sloupec created_at.
  final DateTime? createdAt;
  /// Soft-archivace pro fakturaci: NULL = aktivní, NOT NULL = vyfakturovaný (skrytý z Nástěnky/Plachty).
  final DateTime? invoicedAt;

  static DateTime _parseDueDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  factory TaskRow.fromJson(Map<String, dynamic> json) {
    final refNum = (json['reference_number'] as String?)?.trim();
    return TaskRow(
      id: json['id'] as String? ?? '',
      referenceNumber: (refNum != null && refNum.isNotEmpty) ? refNum : null,
      apartmentId: () {
        final v = json['apartment_id'];
        if (v == null) return '';
        final s = v.toString().trim();
        return s;
      }(),
      clientId: () {
        final v = json['client_id'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      customTitle: () {
        final s = (json['custom_title'] as String?)?.trim();
        return (s != null && s.isNotEmpty) ? s : null;
      }(),
      customLocation: () {
        final s = (json['custom_location'] as String?)?.trim();
        return (s != null && s.isNotEmpty) ? s : null;
      }(),
      assignedTo: () {
        final v = json['assigned_to'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      assignedUserIds: _parseUuidList(json['assigned_user_ids']),
      title: (json['title'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'pending',
      taskType: (json['task_type'] as String?)?.trim() ?? 'Jiné',
      dueDate: _parseDueDate(json['due_date'] ?? json['scheduled_start']),
      scheduledStart: _parseOptionalDateTime(json['scheduled_start']) ?? _parseDueDate(json['due_date'] ?? json['scheduled_start']),
      apartmentName: null,
      assignedToName: null,
      deletedAt: _parseOptionalDateTime(json['deleted_at']),
      reservationId: () {
        final v = json['reservation_id'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      serviceId: () {
        final v = json['service_id'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      metadata: _parseMetadata(json['metadata']),
      mediaUrls: _parseMediaUrls(json['media_urls']),
      invoicedAt: _parseOptionalDateTime(json['invoiced_at']),
    );
  }

  /// Parsuje assigned_user_ids (uuid[]) z PostgreSQL – vrací List<String>.
  static List<String> _parseUuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      final list = <String>[];
      for (final e in raw) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) list.add(s);
      }
      return list;
    }
    return const [];
  }

  /// Unikátní spojení assignedTo (pokud existuje) a prvků z assignedUserIds.
  List<String> get allAssignees {
    final ids = <String>{};
    if (assignedTo != null && assignedTo!.isNotEmpty) ids.add(assignedTo!);
    ids.addAll(assignedUserIds);
    return ids.toList();
  }

  /// Parsuje media_urls (text[]) z PostgreSQL – vrací List<String>.
  static List<String> _parseMediaUrls(dynamic raw) {
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

  /// Parsuje metadata z JSONB – může přijít jako Map nebo null.
  static Map<String, dynamic>? _parseMetadata(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Parsuje řádek z Supabase včetně vnořených JOINů (apartments, reservations, profiles).
  /// [apartmentById] a [nameByProfileId] slouží jako fallback, pokud JOIN nevrátí data.
  static TaskRow fromSupabaseRow(
    Map<String, dynamic> row, {
    required Map<String, String> apartmentById,
    required Map<String, String> nameByProfileId,
  }) {
    final task = TaskRow.fromJson(row);

    // Extrakce z vnořeného objektu apartments (JOIN).
    String? apartmentName = _extractApartmentName(row['apartments']);
    if (apartmentName == null || apartmentName.isEmpty) {
      apartmentName = apartmentById[task.apartmentId];
    }

    // Extrakce z profiles (JOIN) – možná klíč "profiles" nebo "profiles!tasks_assigned_to_fkey".
    String? assignedToName = _extractProfileName(row['profiles'] ?? row['profiles!tasks_assigned_to_fkey']);
    if ((assignedToName == null || assignedToName.isEmpty) && task.assignedTo != null) {
      assignedToName = nameByProfileId[task.assignedTo] ?? 'common.removed_user'.tr();
    }

    // Extrakce z reservations (JOIN).
    final res = row['reservations'];
    String? reservationGuestName;
    DateTime? reservationStartDate;
    DateTime? reservationEndDate;
    int? reservationGuestCount;
    if (res != null && res is Map) {
      final r = res as Map<String, dynamic>;
      final guest = (r['guest_name'] as String?)?.trim();
      reservationGuestName = guest != null && guest.isNotEmpty ? guest : null;
      reservationStartDate = TaskRow._parseOptionalDateTime(r['start_date']);
      reservationEndDate = TaskRow._parseOptionalDateTime(r['end_date']);
      final adults = (r['guest_adults'] is int) ? r['guest_adults'] as int : null;
      final children = (r['guest_children'] is int) ? r['guest_children'] as int : null;
      if (adults != null || children != null) {
        reservationGuestCount = (adults ?? 0) + (children ?? 0);
      }
    }

    return TaskRow(
      id: task.id,
      apartmentId: task.apartmentId,
      referenceNumber: task.referenceNumber,
      clientId: task.clientId,
      customTitle: task.customTitle,
      customLocation: task.customLocation,
      assignedTo: task.assignedTo,
      assignedUserIds: task.assignedUserIds,
      title: task.title,
      description: task.description,
      status: task.status,
      taskType: task.taskType,
      dueDate: task.dueDate,
      scheduledStart: task.scheduledStart,
      apartmentName: apartmentName,
      assignedToName: assignedToName,
      deletedAt: task.deletedAt,
      reservationId: task.reservationId,
      serviceId: task.serviceId,
      reservationGuestName: reservationGuestName,
      reservationStartDate: reservationStartDate,
      reservationEndDate: reservationEndDate,
      reservationGuestCount: reservationGuestCount,
      createdAt: TaskRow._parseOptionalDateTime(row['created_at']),
      metadata: task.metadata,
      mediaUrls: task.mediaUrls,
      invoicedAt: task.invoicedAt,
    );
  }

  static String? _extractApartmentName(dynamic apartments) {
    if (apartments == null) return null;
    final a = apartments is Map ? apartments : (apartments is List && apartments.isNotEmpty ? apartments[0] : null);
    if (a == null || a is! Map) return null;
    final n = (a['name'] as String?)?.trim();
    return n != null && n.isNotEmpty ? n : null;
  }

  static String? _extractProfileName(dynamic profiles) {
    if (profiles == null) return null;
    final p = profiles is Map ? profiles : (profiles is List && profiles.isNotEmpty ? profiles[0] : null);
    if (p == null || p is! Map) return null;
    final name = (p['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final first = (p['first_name'] as String?)?.trim();
    final last = (p['last_name'] as String?)?.trim();
    final combined = '$first $last'.trim();
    return combined.isNotEmpty ? combined : null;
  }

  /// Mapuje model na formát pro Supabase. DB vyžaduje scheduled_start (NOT NULL).
  /// Pro externí úkoly: apartment_id null, client_id, custom_title, custom_location.
  Map<String, dynamic> toMap() {
    final iso = dueDate.toIso8601String();
    final map = <String, dynamic>{
      'apartment_id': apartmentId.isEmpty ? null : apartmentId,
      if (clientId != null && clientId!.isNotEmpty) 'client_id': clientId,
      if (customTitle != null && customTitle!.isNotEmpty) 'custom_title': customTitle,
      if (customLocation != null && customLocation!.isNotEmpty) 'custom_location': customLocation,
      'assigned_to': assignedTo?.isEmpty ?? true ? null : assignedTo,
      if (assignedUserIds.isNotEmpty) 'assigned_user_ids': assignedUserIds,
      'title': title,
      'description': description,
      'status': status,
      'task_type': taskType,
      'due_date': iso,
      'scheduled_start': iso,
    };
    // Fallback na prázdný JSON objekt, protože DB sloupec metadata má NOT NULL constraint.
    map['metadata'] = metadata ?? {};
    if (invoicedAt != null) map['invoiced_at'] = invoicedAt!.toUtc().toIso8601String();
    return map;
  }

  /// Serializace do JSON pro API nebo lokální uložení.
  Map<String, dynamic> toJson() => toMap();

  TaskRow copyWith({
    String? id,
    String? apartmentId,
    String? referenceNumber,
    String? clientId,
    String? customTitle,
    String? customLocation,
    String? assignedTo,
    List<String>? assignedUserIds,
    String? title,
    String? description,
    String? status,
    String? taskType,
    DateTime? dueDate,
    DateTime? scheduledStart,
    String? apartmentName,
    String? assignedToName,
    DateTime? deletedAt,
    String? reservationId,
    String? serviceId,
    String? reservationGuestName,
    DateTime? reservationStartDate,
    DateTime? reservationEndDate,
    int? reservationGuestCount,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    List<String>? mediaUrls,
    DateTime? invoicedAt,
  }) {
    return TaskRow(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      clientId: clientId ?? this.clientId,
      customTitle: customTitle ?? this.customTitle,
      customLocation: customLocation ?? this.customLocation,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      taskType: taskType ?? this.taskType,
      dueDate: dueDate ?? this.dueDate,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      apartmentName: apartmentName ?? this.apartmentName,
      assignedToName: assignedToName ?? this.assignedToName,
      deletedAt: deletedAt ?? this.deletedAt,
      reservationId: reservationId ?? this.reservationId,
      serviceId: serviceId ?? this.serviceId,
      reservationGuestName: reservationGuestName ?? this.reservationGuestName,
      reservationStartDate: reservationStartDate ?? this.reservationStartDate,
      reservationEndDate: reservationEndDate ?? this.reservationEndDate,
      reservationGuestCount: reservationGuestCount ?? this.reservationGuestCount,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      invoicedAt: invoicedAt ?? this.invoicedAt,
    );
  }
}

/// Jedna položka služby přiřazené k bytu s údaji z katalogu – pro dynamické generování úkolů.
/// [triggerType] určuje, na které datum (check-in / check-out / on_demand) se úkol vytvoří.
/// [durationMinutes] – časová náročnost / rezerva z katalogu (fallback 60).
/// [serviceId] – id služby z katalogu (pro vazbu do tasks.service_id a ochranný štít).
/// [apartmentServiceId] – id z apartment_services (pro párování s reservation_services).
/// [isMandatory] – pokud true, úkol se vždy generuje; jinak jen když je v reservation_services.
class _ServiceTrigger {
  const _ServiceTrigger({
    required this.serviceName,
    this.requiredRole,
    required this.serviceType,
    required this.triggerType,
    this.durationMinutes,
    required this.serviceId,
    required this.apartmentServiceId,
    this.isMandatory = false,
    this.requiresPhotoFromApartment,
  });
  final String serviceName;
  final String? requiredRole;
  final String serviceType;
  final String triggerType;
  /// Časová náročnost / rezerva v minutách z katalogu (null = použít fallback 60).
  final int? durationMinutes;
  final String serviceId;
  final String apartmentServiceId;
  final bool isMandatory;
  /// Override z apartment_services; null = dědit z katalogu (tenant_services).
  final bool? requiresPhotoFromApartment;
}

/// Kandidát úkolu pro Smart Planner – drží data potřebná pro řazení a následné přiřazení.
/// Používá se ve fázi sběru: nejprve se vygenerují kandidáti, seřadí podle priorit,
/// potom se pro každého volá engine pro přiřazení personálu.
class _SmartTaskCandidate {
  const _SmartTaskCandidate({
    required this.reservation,
    required this.service,
    required this.taskDate,
    required this.effectiveTaskType,
    required this.planningPriority,
    required this.isBackToBackCleaning,
    required this.checkInDt,
    required this.checkOutDt,
    required this.resServicesList,
    required this.resServicesByApt,
    required this.checkInTotal,
    required this.checkInBreakdown,
    required this.checkOutTotal,
    required this.checkOutBreakdown,
    required this.expectedAuditTotal,
    required this.expectedAuditBreakdown,
    required this.reservationService,
    required this.guestName,
  });

  final dynamic reservation;
  final _ServiceTrigger service;
  final DateTime taskDate;
  final String effectiveTaskType;
  final int planningPriority;
  /// true = úklid v den příjezdu dalšího hosta (Back-to-back) – vyšší priorita při stejné planning_priority.
  final bool isBackToBackCleaning;
  final DateTime? checkInDt;
  final DateTime checkOutDt;
  final List<ReservationServiceRow> resServicesList;
  final Map<String, ReservationServiceRow> resServicesByApt;
  final double checkInTotal;
  final Map<String, num> checkInBreakdown;
  /// Pro Check-out úkol separujeme čistě jen poplatek za check-out. Nesmí se tam míchat celkový audit pobytu.
  final double checkOutTotal;
  final Map<String, num> checkOutBreakdown;
  final double expectedAuditTotal;
  final Map<String, dynamic> expectedAuditBreakdown;
  final ReservationServiceRow? reservationService;
  final String guestName;
}

/// Notifier pro úkoly – mutace (insert, update, generování návrhů). Data z Realtime streamu.
///
/// Seznam úkolů pro UI poskytuje [adminTasksStreamProvider]. Tento notifier slouží pro akce
/// (insertTaskInAdmin, updateTaskStatus, generateSmartTasks atd.). build() vrací [], aby nedocházelo
/// k duplicitnímu načítání – stream provider se stará o data.
class AdminTasksNotifier extends AsyncNotifier<List<TaskRow>> {
  @override
  Future<List<TaskRow>> build() async {
    // Prázdný stav – data pochází z adminTasksStreamProvider (Realtime).
    // Notifier je zachován pro mutační metody (.notifier.insertTaskInAdmin atd.).
    return [];
  }

  /// Chytrý dispečink: z rezervací vygeneruje návrhy úkolů (Úklid, Transfer) a uloží je.
  /// Vrací počet vygenerovaných úkolů (0 = nic nového). Invalidaci provideru provede UI po návratu.
  /// Idempotence: na začátku stáhneme existující úkoly (title, apartment_id, status) a před vložením kontrolujeme duplicity.
  ///
  /// PŘÍSNÉ PRAVIDLO OCHRANY: Pokud pro danou rezervaci již existuje úkol se statusem JINÝM než
  /// 'Návrh' nebo 'pending', generátor na něj NESMÍ sahat (nesmí ho mazat, přepisovat ani updatovat).
  /// Generátor smí promazávat/přepisovat výhradně úkoly ve fázi Návrhu.
  ///
  /// [getEstimateMinutesText] volitelný callback pro lokalizovaný text odhadu (např. 'Odhad: X min').
  Future<int> generateSmartTasks({
    String Function(int hours)? getEstimateHoursText,
    String Function()? getEstimate1HourText,
    String Function(int minutes)? getEstimateMinutesText,
  }) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return 0;

    final allReservations = await ref.read(adminReservationsProvider.future);
    // BUGFIX: Generujeme úkoly pouze pro potvrzené rezervace.
    final reservations = allReservations.where((r) => r.status == 'confirmed').toList();
    final apartments = await ref.read(apartmentsFullListProvider.future);
    final team = _staffOnly(await ref.read(teamFullListProvider.future));

    // Načtení existujících úkolů včetně reservation_id a service_id – pro idempotentní kontrolu duplicit.
    final existingTasksDataRaw = await SupabaseService.client
        .from('tasks')
        .select('reservation_id, service_id')
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);
    final existingTasksData =
        (existingTasksDataRaw as List).cast<Map<String, dynamic>>();

    // Plný seznam úkolů pro přiřazení personálu (počty úkolů na den).
    final tasksRaw = await SupabaseService.client
        .from('tasks')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .order('due_date', ascending: true);
    final tasksList = tasksRaw as List;

    // --- FÁZE 1: Načtení aktivních služeb bytů (apartment_services) + katalog (tenant_services) ---
    // Služby bytu určují, které úkoly se generují a kdy (trigger_type). Z katalogu bereme název, required_role, service_type.
    final apartmentServicesRaw = await SupabaseService.client
        .from('apartment_services')
        .select('id, apartment_id, service_id, trigger_type, is_mandatory, requires_photo')
        .eq('tenant_id', tenantId);
    final catalog = await ref.read(tenantServicesProvider.future);
    final catalogById = {for (final s in catalog) s.id: s};

    // Sestavení mapy: apartment_id -> seznam služeb. apartmentServiceId -> serviceType (pro metadata).
    const triggerDriven = ['before_checkin', 'after_checkout', 'both_ways', 'on_demand'];
    final servicesByApartment = <String, List<_ServiceTrigger>>{};
    final apartmentServiceIdToServiceType = <String, String>{};
    for (final row in apartmentServicesRaw as List) {
      final map = row as Map<String, dynamic>;
      final apartmentServiceId = (map['id'] as String?)?.trim() ?? '';
      final apartmentId = (map['apartment_id'] as String?)?.trim() ?? '';
      final serviceId = (map['service_id'] as String?)?.trim() ?? '';
      final triggerType = (map['trigger_type'] as String?)?.trim() ?? '';
      final isMandatory = map['is_mandatory'] == true || map['is_mandatory'] == 1;
      if (apartmentId.isEmpty || serviceId.isEmpty || apartmentServiceId.isEmpty ||
          !triggerDriven.contains(triggerType)) {
        continue;
      }
      final service = catalogById[serviceId];
      if (service == null) continue; // služba smazaná nebo neaktivní v katalogu
      final rawRequiresPhoto = map['requires_photo'];
      bool? requiresPhotoFromApartment;
      if (rawRequiresPhoto != null) {
        if (rawRequiresPhoto is bool) {
          requiresPhotoFromApartment = rawRequiresPhoto;
        } else if (rawRequiresPhoto is int) {
          requiresPhotoFromApartment = rawRequiresPhoto == 1;
        } else if (rawRequiresPhoto is String) {
          final l = rawRequiresPhoto.toLowerCase();
          if (l == 'true' || l == '1') requiresPhotoFromApartment = true;
          else if (l == 'false' || l == '0') requiresPhotoFromApartment = false;
        }
      }
      apartmentServiceIdToServiceType[apartmentServiceId] = service.serviceType.trim().toLowerCase();
      servicesByApartment.putIfAbsent(apartmentId, () => []).add(
            _ServiceTrigger(
              serviceName: service.name.trim().isEmpty ? service.id : service.name,
              requiredRole: service.requiredRole?.trim().isEmpty == true ? null : service.requiredRole,
              serviceType: service.serviceType,
              triggerType: triggerType,
              durationMinutes: service.durationMinutes,
              serviceId: serviceId,
              apartmentServiceId: apartmentServiceId,
              isMandatory: isMandatory,
              requiresPhotoFromApartment: requiresPhotoFromApartment,
            ),
          );
    }

    // --- FÁZE 2: Načtení reservation_services pro všechny rezervace – pro filtr volitelných a metadata ---
    // Ochranný limit: max 500 rezervací na jedno spuštění – zabraňuje nekonečné smyčce / zamrznutí UI.
    const int _maxReservationsPerRun = 500;
    final reservationsLimited = reservations.take(_maxReservationsPerRun).toList();
    final reservationIds = reservationsLimited.map((r) => r.id).where((id) => id.isNotEmpty).toList();
    final reservationServicesByRes = await fetchByReservationIds(reservationIds, tenantId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final absences = await ref.read(staffAbsencesProvider.future);
    final apartmentById = {for (final a in apartments) a.id: a};
    final categoriesByCode = await ref.read(taskCategoriesProvider.future);

    // --- FÁZE A: Sbírka kandidátů – všechny úkoly k vygenerování ---
    final candidates = <_SmartTaskCandidate>[];
    for (final r in reservationsLimited) {
      final checkOutDt = _getReservationCheckOutDateTime(r);
      final checkInDt = _getReservationCheckInDateTime(r);
      if (checkOutDt == null) continue;
      if (checkOutDt.isBefore(today)) continue;
      if (apartmentById[r.apartmentId] == null) continue;

      final guestName = (r.guestName ?? '').trim().isEmpty ? 'admin.dashboard_guest_unknown'.tr() : r.guestName!;
      final apartmentServicesList = (servicesByApartment[r.apartmentId] ?? [])
          .toList()
          ..sort((a, b) => _getServicePriority(a.serviceType).compareTo(_getServicePriority(b.serviceType)));

      final resServicesList = reservationServicesByRes[r.id] ?? [];
      final resServicesByApt = <String, ReservationServiceRow>{
        for (final rs in resServicesList) rs.apartmentServiceId: rs,
      };

      double checkInTotal = 0;
      final checkInBreakdown = <String, num>{};
      // Pro Check-out úkol separujeme čistě jen poplatek za check-out. Nesmí se tam míchat celkový audit pobytu.
      double checkOutTotal = 0;
      final checkOutBreakdown = <String, num>{};
      double expectedAuditTotal = 0;
      final expectedAuditBreakdown = <String, dynamic>{};
      for (final rs in resServicesList) {
        final st = apartmentServiceIdToServiceType[rs.apartmentServiceId] ?? '';
        final price = (rs.chargedPrice ?? 0).toDouble();
        if (rs.payerType == 'guest' && price > 0) {
          expectedAuditTotal += price;
          final key = st.isEmpty ? 'extra' : st;
          expectedAuditBreakdown[key] = ((expectedAuditBreakdown[key] as num?) ?? 0.0) + price;
          // Do Check-in platby nezahrnujeme transfery ani check-out. Vybírá se primárně jen za check-in a úklid.
          if (st != 'transfer_in' && st != 'transfer_out' && st != 'transfer' && st != 'check_out' && st != 'checkout') {
            checkInTotal += price;
            checkInBreakdown[key] = (checkInBreakdown[key] ?? 0) + price;
          }
          // Pro Check-out úkol separujeme čistě jen poplatek za check-out. Nesmí se tam míchat celkový audit pobytu.
          if (st == 'check_out' || st == 'checkout') {
            checkOutTotal += price;
            checkOutBreakdown[key] = (checkOutBreakdown[key] ?? 0) + price;
          }
        }
      }

      for (final svc in apartmentServicesList) {
        final reservationService = resServicesByApt[svc.apartmentServiceId];
        if (!svc.isMandatory && reservationService == null) continue;

        final serviceTypeNorm = svc.serviceType.trim().toLowerCase();
        final datesToCreate = <DateTime>[];
        if (svc.triggerType == 'before_checkin' && checkInDt != null && !checkInDt.isBefore(today)) {
          datesToCreate.add(checkInDt);
        } else if (svc.triggerType == 'after_checkout') {
          datesToCreate.add(checkOutDt);
        } else if (svc.triggerType == 'both_ways') {
          if (checkInDt != null && !checkInDt.isBefore(today)) datesToCreate.add(checkInDt);
          datesToCreate.add(checkOutDt);
        } else if (svc.triggerType == 'on_demand' && checkInDt != null && !checkInDt.isBefore(today)) {
          final nextDay = checkInDt.add(const Duration(days: 1));
          datesToCreate.add(DateTime(nextDay.year, nextDay.month, nextDay.day, 10, 0, 0));
        }

        for (final taskDate in datesToCreate) {
          final effectiveTaskType = _effectiveTaskTypeForDate(
            serviceTypeNorm: serviceTypeNorm,
            triggerType: svc.triggerType,
            taskDate: taskDate,
            checkInDt: checkInDt,
            checkOutDt: checkOutDt,
          );
          final planningPriority = _getPlanningPriorityForTaskType(effectiveTaskType, categoriesByCode);
          final isBackToBack = effectiveTaskType == 'cleaning' &&
              _isBackToBackCleaning(r.apartmentId, taskDate, r.id, reservations);

          candidates.add(_SmartTaskCandidate(
            reservation: r,
            service: svc,
            taskDate: taskDate,
            effectiveTaskType: effectiveTaskType,
            planningPriority: planningPriority,
            isBackToBackCleaning: isBackToBack,
            checkInDt: checkInDt,
            checkOutDt: checkOutDt,
            resServicesList: resServicesList,
            resServicesByApt: resServicesByApt,
            checkInTotal: checkInTotal,
            checkInBreakdown: checkInBreakdown,
            checkOutTotal: checkOutTotal,
            checkOutBreakdown: checkOutBreakdown,
            expectedAuditTotal: expectedAuditTotal,
            expectedAuditBreakdown: expectedAuditBreakdown,
            reservationService: reservationService,
            guestName: guestName,
          ));
        }
      }
    }

    // --- FÁZE B: Chytré řazení – Svaté úkoly první, pak Back-to-back úklidy, pak běžné ---
    candidates.sort((a, b) {
      if (a.planningPriority != b.planningPriority) {
        return a.planningPriority.compareTo(b.planningPriority);
      }
      if (a.isBackToBackCleaning != b.isBackToBackCleaning) {
        return a.isBackToBackCleaning ? -1 : 1; // Back-to-back před běžné
      }
      return a.taskDate.compareTo(b.taskDate);
    });

    // --- FÁZE C: Přiřazení personálu v pořadí priorit a vložení do DB ---
    final toInsert = <Map<String, dynamic>>[];
    for (final c in candidates) {
      if (toInsert.length >= 50) break;

      final r = c.reservation;
      final svc = c.service;
      final taskDate = c.taskDate;
      final effectiveTaskType = c.effectiveTaskType;
      final serviceTypeNorm = svc.serviceType.trim().toLowerCase();

      if (_taskAlreadyExists(existingTasksData, toInsert, r.id, svc.serviceId)) continue;

      final apartment = apartmentById[r.apartmentId];
      // Skutečná délka z katalogu služeb. Anchor time se resetuje pro každý úkol.
      final effectiveDuration = _isSacredTaskType(effectiveTaskType)
          ? (svc.durationMinutes ?? 60)  // Svaté: přímo z DB, bez přičítání úklidu
          : taskBlockDurationMinutes(
              serviceType: svc.serviceType,
              apartmentStandardCleaning: apartment?.standardCleaningDuration ?? 120,
              serviceDurationMinutes: svc.durationMinutes ?? 60,
            );
      // OPRAVA KOTVY: vychází striktně z triggerType a z toho, který den zpracováváme (both_ways).
      // before_checkin → kotva = příjezd hosta; after_checkout → kotva = odjezd; both_ways → podle taskDate.
      final DateTime effectiveAnchor;
      final bool taskEndsAtAnchor; // true = úkol KONČÍ v kotvě (před příjezdem); false = úkol ZAČÍNÁ v kotvě (po odjezdu).
      switch (svc.triggerType) {
        case 'before_checkin':
          effectiveAnchor = c.checkInDt ?? taskDate;
          taskEndsAtAnchor = true; // Úklid/transfer před příjezdem: musí skončit v momentě příjezdu.
          break;
        case 'after_checkout':
          effectiveAnchor = c.checkOutDt;
          taskEndsAtAnchor = false; // Úklid/check-out/transfer po odjezdu: začíná v momentě odjezdu.
          break;
        case 'both_ways':
          final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
          final checkInDay = c.checkInDt != null
              ? DateTime(c.checkInDt!.year, c.checkInDt!.month, c.checkInDt!.day)
              : null;
          if (checkInDay != null && taskDay == checkInDay) {
            effectiveAnchor = c.checkInDt!;
            taskEndsAtAnchor = true; // Den příjezdu: úkol končí v check-in čas.
          } else {
            effectiveAnchor = c.checkOutDt;
            taskEndsAtAnchor = false; // Den odjezdu: úkol začíná v check-out čas.
          }
          break;
        case 'on_demand':
          effectiveAnchor = taskDate;
          taskEndsAtAnchor = false; // Na požádání: start v taskDate (např. 10:00 další den).
          break;
        default:
          effectiveAnchor = taskDate;
          taskEndsAtAnchor = false;
      }
      // OPRAVA SMĚRU ČASU: před kotvou = taskEnd = anchor, taskStart = anchor - duration; po kotvě = taskStart = anchor, taskEnd = anchor + duration.
      final DateTime taskStart;
      final DateTime taskEnd;
      if (taskEndsAtAnchor) {
        taskEnd = effectiveAnchor;
        taskStart = effectiveAnchor.subtract(Duration(minutes: effectiveDuration));
      } else {
        taskStart = effectiveAnchor;
        taskEnd = effectiveAnchor.add(Duration(minutes: effectiveDuration));
      }

      List<TeamMember> candidatesList;
      if (svc.requiredRole == null || svc.requiredRole!.trim().isEmpty || svc.requiredRole!.toLowerCase() == 'any') {
        candidatesList = team.where((m) => assignableId(m).isNotEmpty).toList();
      } else {
        candidatesList = team.where((m) => _hasRole(m, svc.requiredRole!)).toList();
      }
      var available = candidatesList
          .where((m) =>
              !_isAbsentOnDate(m, taskDate, absences) &&
              _isWithinContract(m, taskDate))
          .toList();
      available = _filterAndSortByZonePreferences(available, apartment?.zoneId);

      final deadline = _computeTaskDeadlineForReservation(r, reservations);
      final applyNightRest = _shouldApplyNightRestByTaskType(effectiveTaskType);

      final isSacredTask = _isSacredTaskType(effectiveTaskType);
      final result = pickAssigneeWithCollisionAvoidance(
        candidates: available,
        taskStart: taskStart,
        taskEnd: taskEnd,
        deadline: deadline,
        applyNightRest: applyNightRest,
        existingTasksRaw: tasksList,
        toInsert: toInsert,
        zoneId: apartment?.zoneId,
        isSacredTask: isSacredTask,
      );

      final title = '${svc.serviceName}: ${c.guestName}';
      final description = getEstimateMinutesText?.call(effectiveDuration) ?? 'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': effectiveDuration.toString()});

      final metadata = <String, dynamic>{};
      // PROČ: Kaskáda requires_photo – rezervace -> byt -> katalog. null = podívej se o úroveň výš.
      final bool requiresPhoto = c.reservationService?.requiresPhoto ??
          svc.requiresPhotoFromApartment ??
          (catalogById[svc.serviceId]?.requiresPhoto ?? false);
      metadata['requires_photo'] = requiresPhoto;
      if (c.reservationService != null) {
        final rs = c.reservationService!;
        final flightNo = rs.flightNumber ?? (parseFlightFromCustomNote(rs.customNote).$1);
        final noteRest = rs.flightNumber != null && rs.flightNumber!.isNotEmpty
            ? rs.customNote
            : (parseFlightFromCustomNote(rs.customNote).$2);
        if (noteRest != null && noteRest.isNotEmpty) metadata['custom_note'] = noteRest;
        if (flightNo != null && flightNo.isNotEmpty) metadata['flight_number'] = flightNo;
        final price = (c.reservationService!.chargedPrice ?? 0).toDouble();
        final payerGuest = c.reservationService!.payerType == 'guest';

        if (serviceTypeNorm == 'transfer_in' ||
            serviceTypeNorm == 'transfer_out' ||
            serviceTypeNorm == 'transfer') {
          if (payerGuest && price > 0) metadata['amount_to_collect'] = price;
        } else if (serviceTypeNorm == 'check_in') {
          if (c.checkInTotal > 0) {
            metadata['amount_to_collect'] = c.checkInTotal;
            metadata['collection_breakdown'] = Map<String, dynamic>.from(
                c.checkInBreakdown.map((k, v) => MapEntry(k, v)));
          }
        } else if (serviceTypeNorm == 'check_out') {
          // Pro Check-out úkol separujeme čistě jen poplatek za check-out. Nesmí se tam míchat celkový audit pobytu.
          if (c.checkOutTotal > 0) metadata['expected_audit_total'] = c.checkOutTotal;
          if (c.checkOutBreakdown.isNotEmpty) metadata['collection_breakdown'] = Map<String, dynamic>.from(c.checkOutBreakdown.map((k, v) => MapEntry(k, v)));
        }
      }

      toInsert.add({
        'tenant_id': tenantId,
        'apartment_id': r.apartmentId,
        'reservation_id': r.id,
        'service_id': svc.serviceId,
        'assigned_to': result.assignTo,
        'reference_number': generateTaskRef(),
        'title': title,
        'description': description,
        'status': 'pending',
        'task_type': effectiveTaskType,
        'scheduled_start': result.start.toIso8601String(),
        'due_date': result.end.toIso8601String(),
        // Vždy posíláme metadata (min. prázdný objekt), protože DB sloupec metadata má NOT NULL constraint.
        'metadata': metadata,
      });
    }

    if (toInsert.isEmpty) return 0;
    try {
      await SupabaseService.client.from('tasks').insert(toInsert);
      return toInsert.length;
    } catch (e) {
      // PROČ: Pokud selže odeslání na server kvůli chybějícímu internetu,
      // zachráníme data do lokální fronty. NetworkSyncWatcher je později odešle.
      if (isNetworkError(e)) {
        final mutationQueue = ref.read(mutationQueueServiceProvider);
        for (final payload in toInsert) {
          await mutationQueue.enqueueMutation(
            table: 'tasks',
            action: 'INSERT',
            payload: Map<String, dynamic>.from(payload),
          );
        }
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (přidat do lokálního stavu), aby si nemyslel, že se ztratila.
        final current = state.valueOrNull ?? [];
        final apartmentNameById = {for (final a in apartments) a.id: a.name};
        final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
        final baseMs = DateTime.now().millisecondsSinceEpoch;
        final newRows = <TaskRow>[];
        for (var i = 0; i < toInsert.length; i++) {
          final p = toInsert[i];
          final tempId = 'offline_${baseMs}_$i';
          final aptId = (p['apartment_id'] as String?) ?? '';
          final assignedTo = p['assigned_to'] as String?;
          final map = <String, dynamic>{
            'id': tempId,
            'apartment_id': aptId,
            'assigned_to': assignedTo,
            'title': p['title'],
            'description': p['description'],
            'status': p['status'],
            'task_type': p['task_type'],
            'due_date': p['due_date'],
            'scheduled_start': p['scheduled_start'],
            'apartment_name': apartmentNameById[aptId],
            'assigned_to_name': assignedTo != null ? nameByProfileId[assignedTo] : null,
            'reservation_id': p['reservation_id'],
            'service_id': p['service_id'],
            'metadata': p['metadata'] ?? {},
          };
          newRows.add(TaskRow.fromJson(map));
        }
        state = AsyncValue.data([...current, ...newRows]);
        return toInsert.length;
      }
      rethrow;
    }
  }

  /// Generuje pravidelné (scheduled) úkoly pro apartmány – nezávisle na rezervacích.
  /// Iteruje přes apartment_services s trigger_type='scheduled' a schedule_interval.
  /// Ochranný štít: nepřidá úkol, pokud už existuje aktivní (Návrh/Nový/Probíhá) pro dané apartment+service.
  /// Výpočet data: baseDate = datum posledního hotového úkolu nebo now; přičte interval.
  Future<int> generateScheduledTasks({
    String Function(int minutes)? getEstimateMinutesText,
  }) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return 0;

    final apartments = await ref.read(apartmentsFullListProvider.future);
    final team = _staffOnly(await ref.read(teamFullListProvider.future));
    final catalog = await ref.read(tenantServicesProvider.future);
    final catalogById = {for (final s in catalog) s.id: s};
    final absences = await ref.read(staffAbsencesProvider.future);
    final apartmentById = {for (final a in apartments) a.id: a};

    // Načtení apartment_services s trigger_type='scheduled' a schedule_interval
    final apartmentServicesRaw = await SupabaseService.client
        .from('apartment_services')
        .select('apartment_id, service_id, trigger_type, schedule_interval, requires_photo')
        .eq('tenant_id', tenantId);
    final scheduledServices = <Map<String, dynamic>>[];
    for (final row in apartmentServicesRaw as List) {
      final map = row as Map<String, dynamic>;
      final triggerType = (map['trigger_type'] as String?)?.trim() ?? '';
      final scheduleInterval = (map['schedule_interval'] as String?)?.trim();
      if (triggerType == 'scheduled' && scheduleInterval != null && scheduleInterval.isNotEmpty) {
        scheduledServices.add(map);
      }
    }

    final tasksRaw = await SupabaseService.client
        .from('tasks')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null);
    final tasksList = (tasksRaw as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final toInsert = <Map<String, dynamic>>[];

    // Žádné řetězení: každý úkol se počítá z čistého taskDate. Striktní ukotvení bez vláčku.

    // Ochranný limit: max 100 scheduled služeb na jedno spuštění – zabraňuje zamrznutí při velkém objemu.
    const int _maxScheduledPerRun = 100;
    for (final row in scheduledServices.take(_maxScheduledPerRun)) {
      final apartmentId = (row['apartment_id'] as String?)?.trim() ?? '';
      final serviceId = (row['service_id'] as String?)?.trim() ?? '';
      final scheduleInterval = (row['schedule_interval'] as String?)?.trim() ?? '';
      if (apartmentId.isEmpty || serviceId.isEmpty || scheduleInterval.isEmpty) continue;

      final service = catalogById[serviceId];
      if (service == null) continue;

      // --- OCHRANNÝ ŠTÍT: Nepřidat úkol, pokud už existuje aktivní (pending/assigned/in_progress) pro apartment+service ---
      const activeStatuses = ['pending', 'draft', 'Návrh', 'assigned', 'Nový', 'in_progress', 'Probíhá'];
      bool hasActive = tasksList.any((t) {
        final apt = t['apartment_id']?.toString().trim();
        final svc = t['service_id']?.toString().trim();
        if (apt != apartmentId || svc != serviceId) return false;
        final st = (t['status'] as String?)?.trim() ?? '';
        return activeStatuses.contains(st);
      });
      if (hasActive) continue;
      hasActive = toInsert.any((m) =>
          m['apartment_id']?.toString() == apartmentId &&
          m['service_id']?.toString() == serviceId);
      if (hasActive) continue;

      // --- Výpočet data: najít poslední hotový úkol pro apartment+service ---
      final completed = tasksList
          .where((t) =>
              t['apartment_id']?.toString() == apartmentId &&
              t['service_id']?.toString() == serviceId &&
              _isCompletedStatus((t['status'] as String?)?.trim() ?? ''))
          .toList();
      DateTime? baseDate;
      if (completed.isNotEmpty) {
        final withDate = completed
            .map((t) => parseTaskDateTime(t['due_date']) ?? parseTaskDateTime(t['scheduled_start']))
            .whereType<DateTime>()
            .toList();
        if (withDate.isNotEmpty) {
          baseDate = withDate.reduce((a, b) => a.isAfter(b) ? a : b);
        }
      }
      baseDate ??= now;

      // Převod schedule_interval na Duration a výpočet dalšího data
      final nextDate = _addScheduleInterval(baseDate, scheduleInterval);
      if (nextDate.isBefore(today)) continue; // negenerovat do minulosti

      final taskDate = DateTime(nextDate.year, nextDate.month, nextDate.day, 10, 0, 0);
      final apartment = apartmentById[apartmentId];
      final serviceDurationMinutes = service.durationMinutes ?? 60;
      final totalMinutes = taskBlockDurationMinutes(
        serviceType: service.serviceType,
        apartmentStandardCleaning: apartment?.standardCleaningDuration ?? 120,
        serviceDurationMinutes: serviceDurationMinutes,
      );
      // Bez řetězení: každý úkol startuje přesně v taskDate. Engine posune flexibilní při kolizi.
      final taskStart = taskDate;
      final taskEnd = taskStart.add(Duration(minutes: totalMinutes));

      final serviceName = service.name.trim().isEmpty ? service.id : service.name;
      final title = '$serviceName: ${'admin.task_title_scheduled_maintenance'.tr()}';

      List<TeamMember> candidates;
      if (service.requiredRole == null || service.requiredRole!.trim().isEmpty || service.requiredRole!.toLowerCase() == 'any') {
        candidates = team.where((m) => assignableId(m).isNotEmpty).toList();
      } else {
        candidates = team.where((m) => _hasRole(m, service.requiredRole!)).toList();
      }
      var available = candidates
          .where((m) =>
              !_isAbsentOnDate(m, taskDate, absences) &&
              _isWithinContract(m, taskDate))
          .toList();

      // Zónové preference: P0=null zóna→bez změny, P1=Blacklist -1, P2=Řazení 1–99.
      available = _filterAndSortByZonePreferences(available, apartment?.zoneId);

      // Deadline: scheduled úkoly – konec taskDate + 3 dny (bezpečnostní limit).
      final deadline = taskDate.add(const Duration(days: 3));
      final applyNightRest = _shouldApplyNightRest(service.requiredRole, service.serviceType);

      final result = pickAssigneeWithCollisionAvoidance(
        candidates: available,
        taskStart: taskStart,
        taskEnd: taskEnd,
        deadline: deadline,
        applyNightRest: applyNightRest,
        existingTasksRaw: tasksList,
        toInsert: toInsert,
        zoneId: apartment?.zoneId,
      );

      final description = getEstimateMinutesText?.call(totalMinutes) ?? 'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': totalMinutes.toString()});
      final scheduledMetadata = <String, dynamic>{};
      // Kaskáda: apartment_services.requires_photo -> tenant_services.requires_photo (pro scheduled není reservation).
      final rawApartmentReq = row['requires_photo'];
      bool? apartmentReqPhoto;
      if (rawApartmentReq != null) {
        if (rawApartmentReq is bool) apartmentReqPhoto = rawApartmentReq;
        else if (rawApartmentReq is int) apartmentReqPhoto = rawApartmentReq == 1;
        else if (rawApartmentReq is String) {
          final l = rawApartmentReq.toLowerCase();
          if (l == 'true' || l == '1') apartmentReqPhoto = true;
          else if (l == 'false' || l == '0') apartmentReqPhoto = false;
        }
      }
      final bool scheduledRequiresPhoto = apartmentReqPhoto ?? service.requiresPhoto;
      scheduledMetadata['requires_photo'] = scheduledRequiresPhoto;
      toInsert.add({
        'tenant_id': tenantId,
        'apartment_id': apartmentId,
        'service_id': serviceId,
        'assigned_to': result.assignTo,
        'reference_number': generateTaskRef(),
        'title': title,
        'description': description,
        'status': 'pending',
        'task_type': service.serviceType,
        'scheduled_start': result.start.toIso8601String(),
        'due_date': result.end.toIso8601String(),
        // Vždy posíláme metadata (min. prázdný objekt), protože DB sloupec metadata má NOT NULL constraint.
        'metadata': scheduledMetadata,
      });
      // Ochrana proti přetížení API (Batching). Vygenerujeme max 50 pravidelných úkolů na jedno spuštění.
      if (toInsert.length >= 50) {
        break;
      }
    }

    if (toInsert.isEmpty) return 0;
    try {
      await SupabaseService.client.from('tasks').insert(toInsert);
      return toInsert.length;
    } catch (e) {
      // PROČ: Síťová chyba – zachránit do fronty. NetworkSyncWatcher odešle po obnovení sítě.
      if (isNetworkError(e)) {
        final mutationQueue = ref.read(mutationQueueServiceProvider);
        for (final payload in toInsert) {
          await mutationQueue.enqueueMutation(
            table: 'tasks',
            action: 'INSERT',
            payload: Map<String, dynamic>.from(payload),
          );
        }
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (přidat do lokálního stavu), aby si nemyslel, že se ztratila.
        final current = state.valueOrNull ?? [];
        final apartmentNameById = {for (final a in apartments) a.id: a.name};
        final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
        final baseMs = DateTime.now().millisecondsSinceEpoch;
        final newRows = <TaskRow>[];
        for (var i = 0; i < toInsert.length; i++) {
          final p = toInsert[i];
          final tempId = 'offline_${baseMs}_$i';
          final aptId = (p['apartment_id'] as String?) ?? '';
          final assignedTo = p['assigned_to'] as String?;
          final map = <String, dynamic>{
            'id': tempId,
            'apartment_id': aptId,
            'assigned_to': assignedTo,
            'title': p['title'],
            'description': p['description'],
            'status': p['status'],
            'task_type': p['task_type'],
            'due_date': p['due_date'],
            'scheduled_start': p['scheduled_start'],
            'apartment_name': apartmentNameById[aptId],
            'assigned_to_name': assignedTo != null ? nameByProfileId[assignedTo] : null,
            'reservation_id': p['reservation_id'],
            'service_id': p['service_id'],
            'metadata': p['metadata'] ?? {},
          };
          newRows.add(TaskRow.fromJson(map));
        }
        state = AsyncValue.data([...current, ...newRows]);
        return toInsert.length;
      }
      rethrow;
    }
  }

  /// Aktualizuje stav úkolu v Supabase (pro Kanban drag & drop).
  /// [newStatus] musí být systémová hodnota: pending, assigned, in_progress, completed, problem.
  /// Po úspěchu volající invaliduje provider úkolů pro překreslení UI.
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      await SupabaseService.client
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', taskId)
          .eq('tenant_id', tenantId);
    } catch (e) {
      // PROČ: Offline – uložit do fronty. NetworkSyncWatcher odešle při návratu sítě.
      if (isNetworkError(e)) {
        await ref.read(mutationQueueServiceProvider).enqueueMutation(
              table: 'tasks',
              action: 'UPDATE',
              payload: {'status': newStatus, 'tenant_id': tenantId},
              recordId: taskId,
            );
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (aktualizovat lokální stav), aby si nemyslel, že se změna ztratila.
        final current = state.valueOrNull;
        if (current != null) {
          final idx = current.indexWhere((t) => t.id == taskId);
          if (idx >= 0) {
            final updated = current[idx].copyWith(status: newStatus);
            state = AsyncValue.data([
              ...current.sublist(0, idx),
              updated,
              ...current.sublist(idx + 1),
            ]);
          }
        }
      } else {
        rethrow;
      }
    }
  }

  /// Vloží nový úkol do Supabase. Veškerá logika (insert → catch → enqueue → optimistic state) v jednom místě.
  /// UI jen volá tuto metodu a čeká na výsledek. [payload] musí obsahovat tenant_id, apartment_id, title,
  /// description, status, task_type, due_date, scheduled_start; volitelně assigned_to, metadata.
  /// Vrací true při úspěchu (online i offline), při chybě vyhodí výjimku.
  Future<void> insertTaskInAdmin(Map<String, dynamic> payload) async {
    final p = Map<String, dynamic>.from(payload);
    if (p['metadata'] == null) p['metadata'] = {};
    if (p['reference_number'] == null || (p['reference_number'] as String).trim().isEmpty) {
      p['reference_number'] = generateTaskRef();
    }
    try {
      await SupabaseService.client.from('tasks').insert(p);
      return;
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(mutationQueueServiceProvider).enqueueMutation(
          table: 'tasks',
          action: 'INSERT',
          payload: p,
        );
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (přidat do lokálního stavu), aby si nemyslel, že se ztratila.
        final apartments = ref.read(apartmentsFullListProvider).valueOrNull ?? [];
        final team = ref.read(teamFullListProvider).valueOrNull ?? [];
        final apartmentNameById = {for (final a in apartments) a.id: a.name};
        final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final aptId = (p['apartment_id'] as String?) ?? '';
        final assignedTo = p['assigned_to'] as String?;
        final map = <String, dynamic>{
          'id': tempId,
          'apartment_id': aptId,
          'assigned_to': assignedTo,
          'title': p['title'],
          'description': p['description'],
          'status': p['status'],
          'task_type': p['task_type'],
          'due_date': p['due_date'],
          'scheduled_start': p['scheduled_start'],
          'apartment_name': apartmentNameById[aptId],
          'assigned_to_name': assignedTo != null ? nameByProfileId[assignedTo] : null,
          'metadata': p['metadata'] ?? {},
        };
        final newRow = TaskRow.fromJson(map);
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([...current, newRow]);
        return;
      }
      rethrow;
    }
  }

  /// Aktualizuje existující úkol v Supabase. Veškerá logika (update → catch → enqueue → optimistic state) v jednom místě.
  /// [taskId] – ID úkolu, [updateFields] – mapuje sloupce na nové hodnoty (apartment_id, assigned_to, title, atd.).
  /// Uloží se tenant_id do payloadu pro frontu. Vrací při úspěchu (online i offline), při chybě vyhodí.
  Future<void> updateTaskInAdmin(String taskId, Map<String, dynamic> updateFields) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Missing tenant_id');
    }
    final payload = Map<String, dynamic>.from(updateFields)..['tenant_id'] = tenantId;
    try {
      await SupabaseService.client
          .from('tasks')
          .update(updateFields)
          .eq('id', taskId)
          .eq('tenant_id', tenantId);
      // PROČ: Po uložení přeřazení invalidujeme načtení jednoho úkolu, aby Finance/Reporty
      // po zavření dialogu viděly aktuální data.
      ref.invalidate(taskByIdProvider(taskId));
      return;
    } catch (e) {
      if (isNetworkError(e)) {
        await ref.read(mutationQueueServiceProvider).enqueueMutation(
          table: 'tasks',
          action: 'UPDATE',
          payload: payload,
          recordId: taskId,
        );
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (aktualizovat lokální stav), aby si nemyslel, že se změna ztratila.
        final current = state.valueOrNull;
        if (current != null) {
          final idx = current.indexWhere((t) => t.id == taskId);
          if (idx >= 0) {
            final old = current[idx];
            final newAptId = (payload['apartment_id'] as String?) ?? old.apartmentId;
            final newAssignedTo = payload['assigned_to'] as String?;
            final apartments = ref.read(apartmentsFullListProvider).valueOrNull ?? [];
            final team = ref.read(teamFullListProvider).valueOrNull ?? [];
            final apartmentNameById = {for (final a in apartments) a.id: a.name};
            final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
            final parsedDue = TaskRow._parseOptionalDateTime(payload['due_date']) ??
                TaskRow._parseOptionalDateTime(payload['scheduled_start']);
            final parsedSched = TaskRow._parseOptionalDateTime(payload['scheduled_start']) ??
                TaskRow._parseOptionalDateTime(payload['due_date']);
            final newMetadata = payload['metadata'];
            // PROČ: Při přeřazení úkolu (změna client_id / apartment_id) musí optimistic update
            // zahrnout i clientId, aby se změna hned projevila v seznamu a v Reportech/Financích.
            final newClientId = payload.containsKey('client_id')
                ? payload['client_id'] as String?
                : old.clientId;
            final updated = old.copyWith(
              apartmentId: newAptId,
              clientId: newClientId,
              assignedTo: newAssignedTo,
              title: (payload['title'] as String?) ?? old.title,
              description: (payload['description'] as String?) ?? old.description,
              status: (payload['status'] as String?) ?? old.status,
              taskType: (payload['task_type'] as String?) ?? old.taskType,
              dueDate: parsedDue ?? old.dueDate,
              scheduledStart: parsedSched ?? old.scheduledStart ?? old.dueDate,
              apartmentName: apartmentNameById[newAptId] ?? old.apartmentName,
              assignedToName: newAssignedTo != null ? nameByProfileId[newAssignedTo] : null,
              serviceId: payload.containsKey('service_id') ? payload['service_id'] as String? : old.serviceId,
              metadata: newMetadata != null ? TaskRow._parseMetadata(newMetadata) : old.metadata,
            );
            state = AsyncValue.data([
              ...current.sublist(0, idx),
              updated,
              ...current.sublist(idx + 1),
            ]);
          }
        }
        return;
      }
      rethrow;
    }
  }

  /// Hromadně schválí všechny úkoly se stavem pending – změní je na assigned.
  /// Akceptuje i legacy hodnoty (Návrh, Nový) pro zpětnou kompatibilitu.
  /// Rozdělení do dávek (batch) po 50 kusech, aby nedošlo k chybě 400 Bad Request ze Supabase
  /// při příliš dlouhém URL/parametrech inFilter() při velkém počtu ID.
  ///
  /// BUGFIX: Data bereme z adminTasksStreamProvider (Realtime), ne ze state – ten vrací [].
  Future<int> approveAllPendingTasks() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return 0;
    final currentTasks = ref.read(adminTasksStreamProvider).valueOrNull ?? [];
    final pending = currentTasks
        .where((t) {
          final s = t.status.trim().toLowerCase();
          return s == 'pending' || s == 'draft' || s == 'návrh';
        })
        .toList();
    if (pending.isEmpty) return 0;
    final ids = pending.map((e) => e.id).toList();

    const int batchSize = 50;
    for (int i = 0; i < ids.length; i += batchSize) {
      final end = (i + batchSize < ids.length) ? i + batchSize : ids.length;
      final batch = ids.sublist(i, end);
      await SupabaseService.client
          .from('tasks')
          .update({'status': 'assigned'})
          .eq('tenant_id', tenantId)
          .inFilter('id', batch);
    }
    return pending.length;
  }

  /// Porovná dva DateTime s přesností na minuty (ignoruje sekundy a mikrosekundy).
  /// PROČ: Předchází falešným změnám kvůli mikrosekundám nebo rozdílům v parsování (UTC vs Local).
  static bool _isDifferentMinute(DateTime a, DateTime b) {
    final aUtc = a.toUtc();
    final bUtc = b.toUtc();
    return aUtc.year != bUtc.year ||
        aUtc.month != bUtc.month ||
        aUtc.day != bUtc.day ||
        aUtc.hour != bUtc.hour ||
        aUtc.minute != bUtc.minute;
  }

  /// Simulace přepočtu personálu: používá chytrý algoritmus (noční klid, kolize, zóny) jako při generování,
  /// ale NEUKLÁDÁ do DB. Vrací seznam návrhů změn pro dispečerské schválení.
  /// Načítá pouze úkoly se statusem pending/draft/návrh nebo assigned/nový od zítřka dál.
  Future<List<TaskRecalculationProposal>> recalculateAssignees() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];

    final now = DateTime.now();
    final tomorrowStart = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final List<TeamMember> team;
    try {
      team = _staffOnly(await ref.read(teamFullListProvider.future));
    } catch (_) {
      return [];
    }
    final absences = await ref.read(staffAbsencesProvider.future);
    final reservations = await ref.read(adminReservationsProvider.future);
    final nameByProfileId = <String, String>{};
    for (final m in team) {
      final id = assignableId(m);
      if (id.isNotEmpty) nameByProfileId[id] = m.name;
    }

    final cleaners = team.where((m) => _hasRole(m, 'cleaner')).toList();
    final drivers = team.where((m) => _hasRole(m, 'driver')).toList();
    final maintainers = team.where((m) => _hasRole(m, 'maintenance')).toList();
    final checkInOutCandidates = team.where((m) => assignableId(m).isNotEmpty).toList();

    final apartments = await ref.read(apartmentsFullListProvider.future);
    final apartmentById = {for (final a in apartments) a.id: a};

    dynamic res;
    try {
      res = await SupabaseService.client
          .from('tasks')
          .select('id, apartment_id, reservation_id, title, due_date, scheduled_start, assigned_to, task_type, status')
          .eq('tenant_id', tenantId)
          .isFilter('deleted_at', null)
          // BUSINESS RULE: Přepočítávat smíme POUZE úkoly ve stavu návrh (pending) a zadáno (assigned).
          // Úkoly, které probíhají nebo jsou hotové, jsou nedotknutelné.
          .inFilter('status', ['pending', 'assigned'])
          .gte('due_date', tomorrowStart.toIso8601String())
          .order('due_date', ascending: true);
    } catch (_) {
      return [];
    }

    final list = res is List ? res : <dynamic>[];
    // Ochrana proti zamrznutí UI a přetížení API. Zpracováváme max 50 úkolů v jedné dávce.
    final limitedTasksToProcess = list.take(50).toList();
    final proposals = <TaskRecalculationProposal>[];

    for (final raw in limitedTasksToProcess) {
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final taskId = map['id']?.toString();
      if (taskId == null || taskId.isEmpty) continue;

      final taskTitle = (map['title'] as String?)?.trim() ?? '';
      final apartmentId = map['apartment_id']?.toString().trim();
      final apartment = apartmentId != null && apartmentId.isNotEmpty
          ? apartmentById[apartmentId]
          : null;
      final zoneId = apartment?.zoneId;

      final dueRaw = map['due_date'] ?? map['scheduled_start'];
      final taskDue = _parseTaskDueSafe(dueRaw, tomorrowStart);
      final taskTypeRaw = (map['task_type'] as String?)?.trim() ?? '';
      final taskType = taskTypeRaw.toLowerCase();
      final currentAssigned = map['assigned_to']?.toString().trim();

      final oldStartRaw = map['scheduled_start'];
      final oldEndRaw = map['due_date'];
      final oldStart = parseTaskDateTime(oldStartRaw) ?? taskDue;
      final oldEnd = parseTaskDateTime(oldEndRaw) ?? taskDue;

      // Deadline: pro úkoly s reservation_id z nejbližšího check-inu stejného bytu, jinak due_date + 3 dny.
      DateTime deadline;
      final reservationId = map['reservation_id']?.toString().trim();
      if (reservationId != null && reservationId.isNotEmpty) {
        final resMatch = reservations.where((r) => r.id == reservationId).toList();
        if (resMatch.isNotEmpty) {
          deadline = _computeTaskDeadlineForReservation(resMatch.first, reservations);
        } else {
          deadline = taskDue.add(const Duration(days: 3));
        }
      } else {
        deadline = taskDue.add(const Duration(days: 3));
      }

      final applyNightRest = _shouldApplyNightRestByTaskType(taskTypeRaw);

      final isCleaning = taskType.contains('úklid') || taskType.contains('cleaning');
      final isTransferIn = taskType.contains('transfer_in') || (taskType.contains('transfer') && taskType.contains('in'));
      final isTransferOut = taskType.contains('transfer_out') || (taskType.contains('transfer') && taskType.contains('out'));
      final isTransfer = isTransferIn || isTransferOut || taskType == 'transfer';
      final isCheckIn = taskType.contains('check_in');
      final isCheckOut = taskType.contains('check_out');
      final isMaintenance = taskType.contains('issue') || taskType.contains('material') ||
          taskType.contains('závada') || taskType.contains('údržba') || taskType.contains('maintenance');

      List<TeamMember> candidates = [];
      if (isCleaning) {
        candidates = cleaners
            .where((c) =>
                !_isAbsentOnDate(c, taskDue, absences) &&
                _isWithinContract(c, taskDue))
            .toList();
      } else if (isTransfer) {
        candidates = drivers
            .where((d) =>
                !_isAbsentOnDate(d, taskDue, absences) &&
                _isWithinContract(d, taskDue))
            .toList();
      } else if (isCheckIn || isCheckOut) {
        candidates = checkInOutCandidates
            .where((m) =>
                !_isAbsentOnDate(m, taskDue, absences) &&
                _isWithinContract(m, taskDue))
            .toList();
      } else if (isMaintenance) {
        candidates = maintainers
            .where((m) =>
                !_isAbsentOnDate(m, taskDue, absences) &&
                _isWithinContract(m, taskDue))
            .toList();
      } else {
        candidates = checkInOutCandidates
            .where((m) =>
                !_isAbsentOnDate(m, taskDue, absences) &&
                _isWithinContract(m, taskDue))
            .toList();
      }

      candidates = _filterAndSortByZonePreferences(candidates, zoneId);

      // Chytrý algoritmus: kolize, noční klid, rovnoměrné rozložení. Předáváme seznam BEZ aktuálního úkolu.
      final others = list.where((x) {
        final m = x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
        return m['id']?.toString() != taskId;
      }).toList();
      final isSacredRecalc = _isSacredTaskType(taskTypeRaw);
      final result = pickAssigneeWithCollisionAvoidance(
        candidates: candidates,
        taskStart: oldStart,
        taskEnd: oldEnd,
        deadline: deadline,
        applyNightRest: applyNightRest,
        existingTasksRaw: others,
        toInsert: [],
        zoneId: zoneId,
        isSacredTask: isSacredRecalc,
      );

      final newAssignTo = result.assignTo;
      final newStart = result.start;
      final newEnd = result.end;

      final assigneeChanged = (currentAssigned ?? '') != (newAssignTo ?? '');
      // BUGFIX: Porovnání času s přesností na minuty – předcházíme falešným změnám kvůli
      // mikrosekundám nebo rozdílům v parsování (UTC vs Local). Viz např. "Petr (08:00) -> Petr (08:00)".
      final timeChanged = _isDifferentMinute(newStart, oldStart) || _isDifferentMinute(newEnd, oldEnd);
      if (!assigneeChanged && !timeChanged) continue;

      proposals.add(TaskRecalculationProposal(
        taskId: taskId,
        taskTitle: taskTitle,
        oldAssigneeId: currentAssigned,
        oldAssigneeName: currentAssigned != null ? nameByProfileId[currentAssigned] : null,
        newAssigneeId: newAssignTo,
        newAssigneeName: newAssignTo != null ? nameByProfileId[newAssignTo] : null,
        oldStart: oldStart,
        oldEnd: oldEnd,
        newStart: newStart,
        newEnd: newEnd,
      ));
    }

    return proposals;
  }

  /// Uloží schválené návrhy změn do databáze – aktualizuje assigned_to, scheduled_start, due_date.
  Future<void> applyRecalculationProposals(List<TaskRecalculationProposal> approved) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    for (final p in approved) {
      await SupabaseService.client
          .from('tasks')
          .update({
            'assigned_to': p.newAssigneeId,
            'scheduled_start': p.newStart.toIso8601String(),
            'due_date': p.newEnd.toIso8601String(),
          })
          .eq('id', p.taskId)
          .eq('tenant_id', tenantId);
    }
  }
}

/// Provider úkolů – AsyncNotifier pro mutace (insert, update, generateSmartTasks).
/// Seznam úkolů pro zobrazení v UI poskytuje [adminTasksStreamProvider].
final adminTasksProvider =
    AsyncNotifierProvider<AdminTasksNotifier, List<TaskRow>>(
  AdminTasksNotifier.new,
);

/// Aktuálně vybraný měsíc pro záložku Úkoly – první den měsíce (lokální čas).
///
/// PROČ: Výkon – stream úkolů načítá jen tento měsíc (limit 500 na měsíc), ne celou historii.
final selectedTaskMonthProvider =
    StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Realtime stream úkolů pro Admin – okamžitá aktualizace UI bez F5.
///
/// PROČ: Dispečer vidí změny (nové úkoly, přiřazení, status) hned po provedení.
/// Načítá pouze úkoly z [selectedTaskMonthProvider] (bezpečné časové okno, limit 500 na měsíc).
final adminTasksStreamProvider =
    StreamProvider<List<TaskRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final selectedMonth = ref.watch(selectedTaskMonthProvider);

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  await for (final rawList in AdminTasksRepository.instance.watchTasksRawForMonth(tenantId, selectedMonth)) {
    try {
      final rows = rawList.map((raw) => TaskRow.fromSupabaseRow(
        Map<String, dynamic>.from(raw),
        apartmentById: apartmentById,
        nameByProfileId: nameByProfileId,
      )).toList();
      yield rows;
    } on PostgrestException catch (e) {
      if (kDebugMode &&
          (e.code == '42703' ||
              e.message.contains('column') ||
              e.message.contains('does not exist'))) {
        // ignore: avoid_print
        print('Missing columns in tasks table. Run in Supabase SQL Editor:');
        // ignore: avoid_print
        print(_buildAlterTableSql());
      }
      rethrow;
    }
  }
});

/// Všechny úkoly navázané na jednu rezervaci – BEZ měsíčního/časového filtru.
///
/// PROČ: V detailu rezervace (Související úkoly) musí být vidět check-in i check-out úkoly;
/// úkoly spojené s odjezdem mohou spadat do dalšího měsíce a [adminTasksStreamProvider]
/// je neobsahuje. Tento provider načte výhradně úkoly s reservation_id == [reservationId].
final tasksForReservationProvider =
    FutureProvider.family<List<TaskRow>, String>((ref, reservationId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || reservationId.isEmpty) return [];
  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }
  final rawList = await AdminTasksRepository.fetchTasksForReservation(tenantId, reservationId);
  return rawList
      .map((raw) => TaskRow.fromSupabaseRow(
            Map<String, dynamic>.from(raw),
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          ))
      .toList();
});

/// Odlehčený stream úkolů pouze pro Nástěnku – zúžené časové okno (včera 00:00 → dnes + 14 dní 23:59).
///
/// PROČ: Dashboard nepotřebuje 500 úkolů; stačí výřez pro Dnešní plán, Skladbu úkolů, Kritické a Externí služby.
/// Ostatní moduly (záložka Úkoly, settlements, apartment_status) dál používají [adminTasksStreamProvider].
final adminDashboardTasksProvider =
    StreamProvider<List<TaskRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final fromLocal = today.subtract(const Duration(days: 1));
  final toDay = today.add(const Duration(days: 14));
  final toLocal = DateTime(toDay.year, toDay.month, toDay.day, 23, 59, 59, 999);
  final fromUtc = fromLocal.toUtc();
  final toUtc = toLocal.toUtc();

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  await for (final rawList in AdminTasksRepository.instance.watchTasksForDashboard(
    tenantId,
    from: fromUtc,
    to: toUtc,
  )) {
    try {
      final rows = rawList.map((raw) => TaskRow.fromSupabaseRow(
        Map<String, dynamic>.from(raw),
        apartmentById: apartmentById,
        nameByProfileId: nameByProfileId,
      )).toList();
      yield rows;
    } on PostgrestException catch (e) {
      if (kDebugMode &&
          (e.code == '42703' ||
              e.message.contains('column') ||
              e.message.contains('does not exist'))) {
        // ignore: avoid_print
        print('Missing columns in tasks table. Run in Supabase SQL Editor:');
        // ignore: avoid_print
        print(_buildAlterTableSql());
      }
      rethrow;
    }
  }
});

/// Provider: úkoly související s klientem (parametr clientId).
///
/// LOGIKA: Pro majitele (owner) – úkoly na jeho bytech (apartment_id IN apartments z apartment_owners).
/// Pro externí/agency – úkoly s client_id = clientId. Vyfiltruj deleted_at a invoiced_at (archivované).
/// Seřazeno podle due_date/scheduled_start od nejbližších.
final clientTasksProvider =
    FutureProvider.autoDispose.family<List<TaskRow>, String>((ref, clientId) async {
  if (clientId.trim().isEmpty) return [];

  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final clients = await ref.watch(clientsFullListProvider.future);
  final client = clients.where((c) => c.id == clientId).firstOrNull;
  if (client == null) return [];

  List<String> apartmentIds = [];
  String? filterClientId;

  final isOwner = (client.clientType?.toLowerCase() ?? '') == 'owner';
  final profileId = client.profileId?.trim();

  if (isOwner && profileId != null && profileId.isNotEmpty) {
    final apartments = await ref.watch(apartmentsForProfileProvider(profileId).future);
    apartmentIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toList();
  } else {
    filterClientId = clientId;
  }

  if (apartmentIds.isEmpty && filterClientId == null) return [];

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  dynamic query;
  if (apartmentIds.isNotEmpty) {
    query = SupabaseService.client
        .from('tasks')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null)
        .inFilter('apartment_id', apartmentIds)
        .order('scheduled_start', ascending: true);
  } else {
    query = SupabaseService.client
        .from('tasks')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null)
        .eq('client_id', filterClientId!)
        .order('scheduled_start', ascending: true);
  }

  final res = await query;
  final rawList = (res as List).cast<Map<String, dynamic>>();

  return rawList
      .map((raw) => TaskRow.fromSupabaseRow(
            raw,
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          ))
      .toList();
});

/// Načte jeden úkol podle ID. Bez filtru deleted_at/invoiced_at – umožňuje otevřít editaci
/// i u dokončených nebo vyfakturovaných úkolů (např. z podkladů pro fakturaci).
/// PROČ: Proklik z Finance na úpravu úkolu – potřebujeme načíst TaskRow pro showEditTaskDialog.
final taskByIdProvider =
    FutureProvider.autoDispose.family<TaskRow?, String>((ref, taskId) async {
  if (taskId.trim().isEmpty) return null;

  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  final res = await SupabaseService.client
      .from('tasks')
      .select()
      .eq('id', taskId)
      .eq('tenant_id', tenantId)
      .maybeSingle();

  if (res == null) return null;
  final raw = Map<String, dynamic>.from(res as Map);
  return TaskRow.fromSupabaseRow(
    raw,
    apartmentById: apartmentById,
    nameByProfileId: nameByProfileId,
  );
});

/// Provider: úkoly pro jeden byt (pro záložku Úkoly v detailu apartmánu).
///
/// Načte úkoly s apartment_id = [apartmentId], deleted_at IS NULL, invoiced_at IS NULL,
/// řazeno scheduled_start ASC. Invaliduj po přidání/úpravě/smazání úkolu.
final tasksForApartmentProvider =
    FutureProvider.autoDispose.family<List<TaskRow>, String>((ref, apartmentId) async {
  if (apartmentId.trim().isEmpty) return [];

  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  final res = await SupabaseService.client
      .from('tasks')
      .select()
      .eq('tenant_id', tenantId)
      .eq('apartment_id', apartmentId)
      .isFilter('deleted_at', null)
      .isFilter('invoiced_at', null)
      .order('scheduled_start', ascending: true);

  final rawList = (res as List).cast<Map<String, dynamic>>();
  return rawList
      .map((raw) => TaskRow.fromSupabaseRow(
            raw,
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          ))
      .toList();
});

/// Provider: úkoly přiřazené danému členovi týmu (hlavní řešitel nebo spolupracovník).
///
/// PROČ: Záložka Úkoly v detailu člena – zobrazí historii i aktivní úkoly.
/// Filtruje: assigned_to = profileId NEBO profileId v assigned_user_ids, deleted_at IS NULL.
final tasksForMemberProvider =
    FutureProvider.autoDispose.family<List<TaskRow>, String>((ref, profileId) async {
  if (profileId.trim().isEmpty) return [];

  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  final res = await SupabaseService.client
      .from('tasks')
      .select()
      .eq('tenant_id', tenantId)
      .isFilter('deleted_at', null)
      .or('assigned_to.eq.$profileId,assigned_user_ids.cs.{$profileId}')
      .order('scheduled_start', ascending: true);

  final rawList = (res as List).cast<Map<String, dynamic>>();
  return rawList
      .map((raw) => TaskRow.fromSupabaseRow(
            raw,
            apartmentById: apartmentById,
            nameByProfileId: nameByProfileId,
          ))
      .toList();
});

/// Bezpečný výpočet trendu v procentech: (today - yesterday) / yesterday * 100.
/// Používá se pro srovnání Dnes vs. Včera u úkolů.
double _calculateTasksTrend(int today, int yesterday) {
  if (yesterday == 0) {
    if (today > 0) return 100.0;
    return 0.0;
  }
  return ((today - yesterday) / yesterday) * 100;
}

/// Derive provider: tasksTrend porovnávající celkový počet dnešních úkolů vůči včerejším.
/// Srovnání Dnes vs. Včera.
final adminTasksTrendProvider = Provider<double>((ref) {
  final async = ref.watch(adminTasksStreamProvider);
  final tasks = async.valueOrNull ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayEnd = today.add(const Duration(days: 1));
  final yesterday = today.subtract(const Duration(days: 1));
  final yesterdayEnd = yesterday.add(const Duration(days: 1));

  // PROČ toLocal(): dueDate je UTC ze Supabase. Pro porovnání s lokálním dnem použijeme lokální datum.
  final todayTasks = tasks.where((t) {
    final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(today) && day.isBefore(todayEnd);
  }).length;
  final yesterdayTasks = tasks.where((t) {
    final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(yesterday) && day.isBefore(yesterdayEnd);
  }).length;

  return _calculateTasksTrend(todayTasks, yesterdayTasks);
});

/// Pravidlo B a C: true, pokud má člen danou roli a lze mu přiřadit úkol (aktivní i čekající na přihlášení).
bool _hasRole(TeamMember m, String role) {
  if (assignableId(m).isEmpty) return false;
  final r = role.toLowerCase();
  return m.roles.any((x) => x.toLowerCase() == r);
}

/// BUGFIX: Majitelé apartmánů (owners) jsou klienti, nesmí se jim přiřazovat úkoly. Filtrujeme pouze reálný personál.
List<TeamMember> _staffOnly(List<TeamMember> team) =>
    team.where((m) => m.role != 'property_owner').toList();

/// Hard Blacklist (Pravidlo Z1): true, pokud má zaměstnanec pro danou zónu hodnotu -1 (Nikdy).
/// Takový zaměstnanec NESMÍ být přiřazen k úkolu v této oblasti.
bool _hasZoneBlacklist(TeamMember m, String zoneId) {
  final prefs = m.zonePreferences;
  if (prefs == null || prefs.isEmpty) return false;
  final val = prefs[zoneId];
  return val == -1;
}

/// Filtruje a seřadí kandidáty podle zónových preferencí apartmánu.
///
/// Pravidlo 0 (Fallback): Pokud apartmán nemá přiřazenou zónu (zoneId je null nebo prázdné),
/// PŘESKOČ veškerou zónovou logiku – neaplikuj Blacklist ani Prioritizaci. Kandidáti zůstanou
/// pouze podle dostupnosti/rolí/absencí (bez změny pořadí).
///
/// Pravidlo 1 (Blacklist): Má-li apartmán zoneId, zaměstnanci s hodnotou -1 (Nikdy) pro tuto
/// zónu jsou VYŘAZENI ze seznamu kandidátů.
///
/// Pravidlo 2 (Prioritizace): Seřadí zbývající kandidáty podle preference 1–5 (1 = nejraději).
/// Chybí-li preference v mapě, vrací se 99 (Nouzová záchrana). Řazení vzestupně.
List<TeamMember> _filterAndSortByZonePreferences(
  List<TeamMember> candidates,
  String? zoneId,
) {
  // Pravidlo 0: Fallback – apartmán bez zóny: žádná zónová logika.
  if (zoneId == null || zoneId.isEmpty) return candidates;

  // Pravidlo 1: Hard Blacklist – vyřazení zaměstnanců s -1 (Nikdy) pro danou zónu.
  final withoutBlacklist = candidates
      .where((m) => !_hasZoneBlacklist(m, zoneId))
      .toList();

  // Pravidlo 2: Weighted Sorting – řazení podle preferencí 1–5, chybí = 99.
  withoutBlacklist.sort(
    (a, b) => zonePreferencePriority(a, zoneId).compareTo(zonePreferencePriority(b, zoneId)),
  );
  return withoutBlacklist;
}

/// Převod schedule_interval na Duration a přičtení k baseDate.
/// Hodnoty: 1_week, 2_weeks, 1_month, 2_months, 3_months, 6_months.
DateTime _addScheduleInterval(DateTime baseDate, String scheduleInterval) {
  final s = scheduleInterval.toLowerCase();
  switch (s) {
    case '1_week':
      return baseDate.add(const Duration(days: 7));
    case '2_weeks':
      return baseDate.add(const Duration(days: 14));
    case '1_month':
      return baseDate.add(const Duration(days: 30));
    case '2_months':
      return baseDate.add(const Duration(days: 60));
    case '3_months':
      return baseDate.add(const Duration(days: 90));
    case '6_months':
      return baseDate.add(const Duration(days: 180));
    default:
      return baseDate.add(const Duration(days: 30));
  }
}

/// Vrací planning_priority pro Smart Planner – z task_categories nebo fallback dle byznysových pravidel.
/// Svaté úkoly (check-in, check-out, transfery) = 1; cleaning = 10; maintenance = 20; extra = 30.
int _getPlanningPriorityForTaskType(
  String effectiveTaskType,
  Map<String, TaskCategoryModel> categoriesByCode,
) {
  final code = effectiveTaskType.trim().toLowerCase();
  final cat = categoriesByCode[code];
  if (cat != null) {
    return cat.planningPriority;
  }
  // Fallback podle známých typů – bez závislosti na DB.
  switch (code) {
    case 'check_in':
    case 'check_out':
    case 'transfer_in':
    case 'transfer_out':
      return 1;
    case 'cleaning':
      return 10;
    case 'maintenance':
      return 20;
    case 'extra':
      return 30;
    default:
      return 99;
  }
}

/// Zjistí, zda jde o Back-to-back úklid: v daný den přijíždí nový host do stejného bytu.
/// Back-to-back úklidy mají vyšší prioritu než běžné – musí být hotovy před check-inem.
bool _isBackToBackCleaning(
  String apartmentId,
  DateTime taskDate,
  String currentReservationId,
  List<dynamic> allReservations,
) {
  final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
  for (final other in allReservations) {
    if (other.id == currentReservationId) continue;
    if (other.apartmentId != apartmentId) continue;
    final nextCheckIn = _getReservationCheckInDateTime(other);
    if (nextCheckIn == null) continue;
    final otherDay = DateTime(nextCheckIn.year, nextCheckIn.month, nextCheckIn.day);
    if (taskDay == otherDay) return true; // Stejný den = Back-to-back
  }
  return false;
}

/// Vrací prioritu služby (nižší číslo = vyšší priorita) pro štafetové řazení úkolů v bytě.
/// Pořadí: údržba → úklid → extra → transfer → ostatní.
int _getServicePriority(String serviceType) {
  final t = serviceType.toLowerCase();
  switch (t) {
    case 'maintenance':
      return 1;
    case 'cleaning':
      return 2;
    case 'extra':
      return 3;
    case 'transfer':
      return 4;
    default:
      return 5;
  }
}

/// Bezpečně parsuje datum úkolu (ISO, dd.MM.yyyy nebo objekt). Při selhání vrací [fallback].
DateTime _parseTaskDueSafe(dynamic dueRaw, DateTime fallback) {
  if (dueRaw == null) return fallback;
  if (dueRaw is DateTime) return dueRaw;
  final s = dueRaw.toString().trim();
  if (s.isEmpty) return fallback;
  try {
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
  } catch (_) {}
  try {
    return DateFormat('dd.MM.yyyy').parse(s);
  } catch (_) {}
  try {
    return DateFormat('yyyy-MM-dd').parse(s);
  } catch (_) {}
  return fallback;
}

/// Vrací efektivní datum/čas check-inu – priorita arrival_time z rezervace, fallback parsed check_in string.
/// Používáme hodiny a minuty přesně tak, jak jsou uloženy (bez UTC konverze), aby nedošlo k nechtěnému posunu +1h.
DateTime? _getReservationCheckInDateTime(dynamic r) {
  final at = r.arrivalTime;
  if (at != null) {
    return DateTime(at.year, at.month, at.day, at.hour, at.minute);
  }
  return _parseReservationCheckInDate(r.checkIn);
}

/// Vrací efektivní datum/čas check-outu – priorita departure_time z rezervace, fallback parsed check_out string.
/// Používáme hodiny a minuty přesně tak, jak jsou uloženy (bez UTC konverze), aby nedošlo k nechtěnému posunu +1h.
DateTime? _getReservationCheckOutDateTime(dynamic r) {
  final dt = r.departureTime;
  if (dt != null) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }
  return _parseReservationCheckOutDate(r.checkOut);
}

/// Parsuje rezervaci check_in string (DD.MM.YYYY nebo DD.MM.YYYY HH:mm) na DateTime – standardní příjezd 15:00.
DateTime? _parseReservationCheckInDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  final dStr = parts[0];
  final dParts = dStr.split('.');
  if (dParts.length < 3) return null;
  try {
    int h = 15, min = 0;
    if (parts.length >= 2) {
      final tParts = parts[1].split(':');
      if (tParts.length >= 2) {
        h = int.parse(tParts[0]);
        min = int.parse(tParts[1]);
      }
    }
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
      h,
      min,
    );
  } catch (_) {
    return null;
  }
}

/// Vypočítá uzávěrku (deadline) pro úkol navázaný na rezervaci.
/// Pokud existuje další rezervace v témže bytě s check-in po check-out aktuální rezervace,
/// deadline = check-in té další rezervace (úkol musí být hotov před příjezdem dalšího hosta).
/// Jinak deadline = check-out + 3 dny (bezpečnostní limit).
DateTime _computeTaskDeadlineForReservation(
  dynamic currentRes,
  List<dynamic> allReservations,
) {
  final checkOutDt = _getReservationCheckOutDateTime(currentRes);
  if (checkOutDt == null) return DateTime.now().add(const Duration(days: 3));

  DateTime? nearestNextCheckIn;
  for (final other in allReservations) {
    if (other.id == currentRes.id) continue;
    if (other.apartmentId != currentRes.apartmentId) continue;
    final nextCi = _getReservationCheckInDateTime(other);
    if (nextCi == null) continue;
    if (!nextCi.isAfter(checkOutDt)) continue;
    if (nearestNextCheckIn == null || nextCi.isBefore(nearestNextCheckIn)) {
      nearestNextCheckIn = nextCi;
    }
  }
  if (nearestNextCheckIn != null) return nearestNextCheckIn;
  return checkOutDt.add(const Duration(days: 3));
}

/// Vrací efektivní task_type pro úkol na dané datum.
/// both_ways: první (checkInDt) = transfer_in, druhý (checkOutDt) = transfer_out.
/// Jinak používá service_type z katalogu; prázdný = fallback 'extra'.
String _effectiveTaskTypeForDate({
  required String serviceTypeNorm,
  required String triggerType,
  required DateTime taskDate,
  required DateTime? checkInDt,
  required DateTime checkOutDt,
}) {
  if (triggerType == 'both_ways') {
    final isTransfer = serviceTypeNorm == 'transfer' ||
        serviceTypeNorm == 'transfer_in' ||
        serviceTypeNorm == 'transfer_out';
    if (isTransfer) {
      if (checkInDt != null && taskDate == checkInDt) return 'transfer_in';
      if (taskDate == checkOutDt) return 'transfer_out';
    }
  }
  return serviceTypeNorm.isNotEmpty ? serviceTypeNorm : 'extra';
}

/// Určí, zda je typ úkolu Svatý – check-in, check-out, transfery. Svaté úkoly se NESMÍ posouvat v čase.
bool _isSacredTaskType(String taskType) {
  final t = taskType.trim().toLowerCase();
  return t.contains('check_in') || t.contains('check_out') ||
      t.contains('transfer_in') || t.contains('transfer_out') ||
      (t == 'transfer');
}

/// Určí, zda pro danou službu platí noční klid (20:00–07:00).
/// Transfery a check-in/check-out jsou výjimky – mohou běžet i v noci.
bool _shouldApplyNightRestByTaskType(String taskType) {
  final t = taskType.toLowerCase();
  return !(t.contains('transfer') || t.contains('řidič') || t.contains('driver') ||
      t.contains('check-in') || t.contains('check-out') || t.contains('check_in') || t.contains('check_out'));
}

/// Přetížení pro volání s requiredRole + serviceType (např. generateScheduledTasks).
bool _shouldApplyNightRest(String? requiredRole, String serviceType) {
  final role = (requiredRole ?? '').toLowerCase();
  final st = serviceType.toLowerCase();
  if (role.contains('transfer') || role.contains('řidič') || role.contains('driver') ||
      role.contains('check-in') || role.contains('check-out')) {
    return false;
  }
  if (st.contains('transfer') || st.contains('check_in') || st.contains('check_out')) return false;
  return true;
}

/// Parsuje rezervaci check_out string (DD.MM.YYYY nebo DD.MM.YYYY HH:mm) na DateTime – standardní odjezd 10:00.
DateTime? _parseReservationCheckOutDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  final dStr = parts[0];
  final dParts = dStr.split('.');
  if (dParts.length < 3) return null;
  try {
    int h = 10, min = 0;
    if (parts.length >= 2) {
      final tParts = parts[1].split(':');
      if (tParts.length >= 2) {
        h = int.parse(tParts[0]);
        min = int.parse(tParts[1]);
      }
    }
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
      h,
      min,
    );
  } catch (_) {
    return null;
  }
}

/// Pravidlo B (Časová platnost smlouvy): personál je pro úkol dostupný, pokud datum úkolu je >= start_date
/// a (end_date je null NEBO datum úkolu <= end_date). Porovnává se pouze kalendářní datum.
bool _isWithinContract(TeamMember member, DateTime taskDate) {
  final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
  if (member.startDate != null) {
    final startDay = DateTime(
        member.startDate!.year, member.startDate!.month, member.startDate!.day);
    if (taskDay.isBefore(startDay)) return false;
  }
  if (member.endDate != null) {
    final endDay = DateTime(
        member.endDate!.year, member.endDate!.month, member.endDate!.day);
    if (taskDay.isAfter(endDay)) return false;
  }
  return true;
}

/// Pravidlo C (Nepřítomnost): true, pokud má daný personál v datum T záznam nepřítomnosti.
/// Absence s neplatným datem (startDate/endDate null po chybě parsování) se ignorují.
bool _isAbsentOnDate(TeamMember member, DateTime date, List<StaffAbsence> absences) {
  final tDay = DateTime(date.year, date.month, date.day);
  return absences.any((a) {
    if (!a.belongsTo(member)) return false;
    if (a.startDate == null || a.endDate == null) return false;
    final aStart = DateTime(a.startDate!.year, a.startDate!.month, a.startDate!.day);
    final aEnd = DateTime(a.endDate!.year, a.endDate!.month, a.endDate!.day);
    return !tDay.isBefore(aStart) && !tDay.isAfter(aEnd);
  });
}

/// Kontrola idempotence: úkol pro danou rezervaci a službu už existuje v DB nebo v dávce k vložení.
///
/// Unikátní klíč tvoří striktní kombinace reservation_id + service_id (ne title, který obsahuje jméno hosta –
/// stejný host může přijet do stejného bytu znovu v budoucnu). Tím eliminujeme byznysové riziko falešných duplicit.
bool _taskAlreadyExists(
  List<Map<String, dynamic>> existingTasksData,
  List<Map<String, dynamic>> toInsert,
  String reservationId,
  String serviceId,
) {
  if (existingTasksData.any((e) =>
      e['reservation_id'] == reservationId && e['service_id'] == serviceId)) {
    return true;
  }
  return toInsert.any((m) =>
      m['reservation_id'] == reservationId && m['service_id'] == serviceId);
}

/// Vrací true, pokud status znamená dokončený úkol (completed, done, Hotovo + legacy).
bool _isCompletedStatus(String status) {
  final s = status.trim().toLowerCase();
  return s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno';
}

String _buildAlterTableSql() {
  return '''
-- Přidání chybějících sloupců do tasks (spouštěj jeden po druhém, pokud už existují, přeskoč):
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS title TEXT DEFAULT '';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS task_type TEXT DEFAULT 'Jiné';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL;
''';
}
