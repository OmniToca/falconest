import 'dart:convert';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/geo_json_point.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/offline/offline_web_exception.dart';
import 'package:falconest/core/offline/offline_web_mutation_feedback.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart'
    show ReservationServiceRow;
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_isolate_workers.dart';
import 'package:falconest/features/admin/providers/admin_tasks_repository.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';
import 'package:falconest/features/admin/providers/task_assignment_engine.dart';
import 'package:falconest/features/admin/models/task_custom_tag.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/core/repositories/task/supabase_task_insert_repository.dart';
import 'package:falconest/core/repositories/task/task_insert_sanitizer.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Sentinel pro [TaskRow.copyWith]: `null` jako hodnota znamená vymazat souřadnice, ne „ponechat staré“.
const Object _kTaskRowGeoCopyUnset = Object();

/// Návrh změny přiřazení/času úkolu z přepočtu personálu – dispečer může vybrat, které změny potvrdit.
///
/// [timeChanged] – pokud engine reálně neposunul čas (rozdíl 0 minut v UTC), je false.
/// Při ukládání se pak neposílají scheduled_start/due_date, aby nedošlo k nechtěnému posunu (+1 h).
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
    required this.timeChanged,
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
  /// True, pokud engine skutečně změnil čas (scheduled_start nebo due_date) o alespoň 1 minutu (v UTC).
  final bool timeChanged;
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
    this.latitude,
    this.longitude,
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
    this.unassignedInfo,
    this.createdBy,
    this.lastCommunicationTemplateId,
    this.lastCommunicationTemplateContext,
    this.lastCommunicationAt,
    this.startedAt,
    /// Čas dokončení úkolu z DB (`completed_at`) – pro stav apartmánu, fakturaci, reporty.
    this.completedAt,
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
  /// Bod z `tasks.geo_location` (PostGIS / GeoJSON), volitelně k textové adrese.
  final double? latitude;
  final double? longitude;
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
  /// Soft-Unassign: při automatickém odebrání (absence/výpověď) obsahuje previous_id, previous_name, unassigned_at.
  final Map<String, dynamic>? unassignedInfo;
  /// Profil tvůrce úkolu (profiles.id) – pro rozlišení „nahlášeno majitelem“ v Klientském portálu.
  final String? createdBy;
  /// ID šablony (tenant_message_templates.id) použitée pro poslední WhatsApp odkaz.
  final String? lastCommunicationTemplateId;
  /// trigger_context šablony (např. check_in, transfer_in).
  final String? lastCommunicationTemplateContext;
  /// Čas posledního vygenerování WhatsApp odkazu.
  final DateTime? lastCommunicationAt;
  /// Kdy pracovník zahájil úkol (Supabase `tasks.started_at`) – pro admin rentabilitu (skutečné trvání).
  final DateTime? startedAt;
  /// Kdy byl úkol dokončen (Supabase `tasks.completed_at`) – pro výpočet „po hostech“ u stavu bytu.
  final DateTime? completedAt;

  static DateTime _parseDueDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  factory TaskRow.fromJson(Map<String, dynamic> json) {
    final refNum = (json['reference_number'] as String?)?.trim();
    final geo = GeoJsonPoint.parseFromPostgrest(json['geo_location']);
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
      latitude: geo?.latitude,
      longitude: geo?.longitude,
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
      unassignedInfo: _parseUnassignedInfo(json['unassigned_info']),
      createdBy: () {
        final v = json['created_by'];
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      lastCommunicationTemplateId: (json['last_communication_template_id'] as String?)?.trim().isEmpty == true
          ? null
          : (json['last_communication_template_id'] as String?)?.trim(),
      lastCommunicationTemplateContext: (json['last_communication_template_context'] as String?)?.trim().isEmpty == true
          ? null
          : (json['last_communication_template_context'] as String?)?.trim(),
      lastCommunicationAt: TaskRow._parseOptionalDateTime(json['last_communication_at']),
      startedAt: TaskRow._parseOptionalDateTime(json['started_at']),
      completedAt: TaskRow._parseOptionalDateTime(json['completed_at']),
    );
  }

  /// Parsuje unassigned_info (jsonb) z DB – previous_id, previous_name, unassigned_at.
  /// Supabase může vracet JSONB jako String (když byl uložen přes jsonEncode), proto parsujeme i String.
  static Map<String, dynamic>? _parseUnassignedInfo(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('Chyba při parsování unassigned_info: $e');
      }
    }
    return null;
  }

  /// Parsuje assigned_user_ids (uuid[]) z PostgreSQL – vrací `List<String>`.
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

  /// Parsuje media_urls (text[]) z PostgreSQL – vrací `List<String>`.
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
      latitude: task.latitude,
      longitude: task.longitude,
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
      unassignedInfo: task.unassignedInfo,
      createdBy: task.createdBy,
      lastCommunicationTemplateId: task.lastCommunicationTemplateId,
      lastCommunicationTemplateContext: task.lastCommunicationTemplateContext,
      lastCommunicationAt: task.lastCommunicationAt,
      startedAt: TaskRow._parseOptionalDateTime(row['started_at']) ?? task.startedAt,
      completedAt: TaskRow._parseOptionalDateTime(row['completed_at']) ?? task.completedAt,
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
    final geoForRow = GeoJsonPoint.toPostgrestJson(latitude, longitude);
    final map = <String, dynamic>{
      'apartment_id': apartmentId.isEmpty ? null : apartmentId,
      if (clientId != null && clientId!.isNotEmpty) 'client_id': clientId,
      if (customTitle != null && customTitle!.isNotEmpty) 'custom_title': customTitle,
      if (customLocation != null && customLocation!.isNotEmpty) 'custom_location': customLocation,
      if (geoForRow != null) 'geo_location': geoForRow,
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
    if (unassignedInfo != null && unassignedInfo!.isNotEmpty) map['unassigned_info'] = unassignedInfo;
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
    Object? latitude = _kTaskRowGeoCopyUnset,
    Object? longitude = _kTaskRowGeoCopyUnset,
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
    Map<String, dynamic>? unassignedInfo,
    String? createdBy,
    String? lastCommunicationTemplateId,
    String? lastCommunicationTemplateContext,
    DateTime? lastCommunicationAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TaskRow(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      clientId: clientId ?? this.clientId,
      customTitle: customTitle ?? this.customTitle,
      customLocation: customLocation ?? this.customLocation,
      latitude: identical(latitude, _kTaskRowGeoCopyUnset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _kTaskRowGeoCopyUnset)
          ? this.longitude
          : longitude as double?,
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
      unassignedInfo: unassignedInfo ?? this.unassignedInfo,
      createdBy: createdBy ?? this.createdBy,
      lastCommunicationTemplateId: lastCommunicationTemplateId ?? this.lastCommunicationTemplateId,
      lastCommunicationTemplateContext: lastCommunicationTemplateContext ?? this.lastCommunicationTemplateContext,
      lastCommunicationAt: lastCommunicationAt ?? this.lastCommunicationAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
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
    this.checklistTemplateId,
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
  /// Šablona checklistu pro tuto službu u bytu (apartment_services.checklist_template_id).
  final String? checklistTemplateId;
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

/// Minimální mapa rezervace pro výpočet deadline v Isolate ([runSmartGenerationPhaseCSync]).
Map<String, dynamic> _reservationRowToSmartGenMap(ReservationRow r) => <String, dynamic>{
      'id': r.id,
      'apartment_id': r.apartmentId,
      'check_in': r.checkIn,
      'check_out': r.checkOut,
      'arrival_time': r.arrivalTime?.toIso8601String(),
      'departure_time': r.departureTime?.toIso8601String(),
    };

/// Serializace [TeamMember] pro worker – pole musí sedět s [_teamMemberFromMap] v isolate souboru.
Map<String, dynamic> _teamMemberToIsolateMap(TeamMember m) => <String, dynamic>{
      'id': m.id,
      'name': m.name,
      'email': m.email,
      'role': m.role,
      'roles': m.roles,
      'isFromInvitation': m.isFromInvitation,
      'profileId': m.profileId,
      'invitationId': m.invitationId,
      'weeklyHours': m.weeklyHours,
      'start_date': m.startDate?.toIso8601String(),
      'end_date': m.endDate?.toIso8601String(),
      'zone_preferences': m.zonePreferences,
      'lastSignInAt': m.lastSignInAt?.toIso8601String(),
      'systemRole': m.systemRole,
    };

Map<String, dynamic> _staffAbsenceToIsolateMap(StaffAbsence a) => <String, dynamic>{
      'id': a.id,
      'profile_id': a.profileId,
      'invitation_id': a.invitationId,
      'start_date': a.startDate?.toIso8601String(),
      'end_date': a.endDate?.toIso8601String(),
      'reason': a.reason,
      'status': a.status,
    };

/// Převod kandidáta smart generátoru na čistě serializovatelný payload pro [Isolate.run].
Map<String, dynamic> _smartTaskCandidateToIsolateMap(_SmartTaskCandidate c) {
  final svc = c.service;
  final rs = c.reservationService;
  return <String, dynamic>{
    'reservation': _reservationRowToSmartGenMap(c.reservation as ReservationRow),
    'service': <String, dynamic>{
      'serviceName': svc.serviceName,
      'requiredRole': svc.requiredRole,
      'serviceType': svc.serviceType,
      'triggerType': svc.triggerType,
      'durationMinutes': svc.durationMinutes,
      'serviceId': svc.serviceId,
      'apartmentServiceId': svc.apartmentServiceId,
      'checklistTemplateId': svc.checklistTemplateId,
    },
    'taskDate': c.taskDate.toIso8601String(),
    'effectiveTaskType': c.effectiveTaskType,
    'checkInDt': c.checkInDt?.toIso8601String(),
    'checkOutDt': c.checkOutDt.toIso8601String(),
    'checkInTotal': c.checkInTotal,
    'checkInBreakdown': c.checkInBreakdown,
    'checkOutTotal': c.checkOutTotal,
    'checkOutBreakdown': c.checkOutBreakdown,
    'guest_name': c.guestName,
    if (rs != null)
      'reservation_service': <String, dynamic>{
        'id': rs.id,
        'tenant_id': rs.tenantId,
        'reservation_id': rs.reservationId,
        'apartment_service_id': rs.apartmentServiceId,
        'charged_price': rs.chargedPrice,
        'custom_note': rs.customNote,
        'flight_number': rs.flightNumber,
        'payer_type': rs.payerType,
        'requires_photo': rs.requiresPhoto,
        'transit_cash_to_collect': rs.transitCashToCollect,
      },
  };
}

/// Fáze C generátoru: na webu synchronně (Isolate tam není spolehlivý), jinde v worker isolate.
Future<SmartGenPhaseCResult> _runSmartGenerationPhaseCAsync(SmartGenPhaseCPack pack) async {
  if (kIsWeb) {
    return runSmartGenerationPhaseCSync(pack);
  }
  return Isolate.run(() => runSmartGenerationPhaseCSync(pack));
}

/// Přepočet personálu – stejná větev web vs. isolate jako u smart generátoru.
Future<List<Map<String, dynamic>>> _runRecalculateAssigneesAsync(
  RecalculateAssigneesPack pack,
) async {
  if (kIsWeb) {
    return runRecalculateAssigneesSync(pack);
  }
  return Isolate.run(() => runRecalculateAssigneesSync(pack));
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
    final existingTasksDataRaw = await SupabaseService.safeFrom('tasks', tenantId)
        .select('reservation_id, service_id')
        .isFilter('deleted_at', null);
    final existingTasksData =
        (existingTasksDataRaw as List).cast<Map<String, dynamic>>();

    // Plný seznam úkolů pro přiřazení personálu (počty úkolů na den).
    final tasksRaw = await SupabaseService.safeFrom('tasks', tenantId)
        .select()
        .isFilter('deleted_at', null)
        .order('due_date', ascending: true);
    final tasksList = tasksRaw as List;

    // --- FÁZE 1: Načtení aktivních služeb bytů (apartment_services) + katalog (tenant_services) ---
    // Kompletní data včetně custom_price a payer_type pro Bulletproof Cascade (fallback u starých rezervací).
    final apartmentServicesRaw = await SupabaseService.safeFrom('apartment_services', tenantId)
        .select(
            'id, apartment_id, service_id, trigger_type, is_mandatory, requires_photo, custom_price, payer_type, checklist_template_id');
    final catalog = await ref.read(tenantServicesProvider.future);
    final catalogById = {for (final s in catalog) s.id: s};

    // Sestavení map: apartment_id -> seznam služeb, apartmentServiceId -> serviceType, apartmentFallback (cena/plátce/foto z bytu nebo katalogu).
    const triggerDriven = ['before_checkin', 'after_checkout', 'both_ways', 'on_demand'];
    final servicesByApartment = <String, List<_ServiceTrigger>>{};
    final apartmentServiceIdToServiceType = <String, String>{};
    final apartmentFallback = <String, Map<String, dynamic>>{};
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
          if (l == 'true' || l == '1') {
            requiresPhotoFromApartment = true;
          } else if (l == 'false' || l == '0') {
            requiresPhotoFromApartment = false;
          }
        }
      }
      double? customPrice;
      final cp = map['custom_price'];
      if (cp != null) {
        if (cp is num) {
          customPrice = cp.toDouble();
        } else {
          customPrice = double.tryParse(cp.toString());
        }
      }
      final catalogPrice = service.defaultPrice?.toDouble();
      final pt = (map['payer_type'] as String?)?.trim();
      final payerType = (pt == 'owner' || pt == 'guest') ? pt : 'owner';
      final catalogRequiresPhoto = service.requiresPhoto;
      apartmentFallback[apartmentServiceId] = {
        'price': customPrice ?? catalogPrice,
        'payer': payerType,
        'photo': requiresPhotoFromApartment ?? catalogRequiresPhoto,
      };
      apartmentServiceIdToServiceType[apartmentServiceId] = service.serviceType.trim().toLowerCase();
      final rawTpl = map['checklist_template_id'];
      final checklistTpl = rawTpl == null
          ? null
          : (rawTpl.toString().trim().isEmpty ? null : rawTpl.toString().trim());
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
              checklistTemplateId: checklistTpl,
            ),
          );
    }

    // --- FÁZE 2: Načtení reservation_services pro všechny rezervace – pro filtr volitelných a metadata ---
    // Ochranný limit: max 500 rezervací na jedno spuštění – zabraňuje nekonečné smyčce / zamrznutí UI.
    const int maxReservationsPerRun = 500;
    final reservationsLimited = reservations.take(maxReservationsPerRun).toList();
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

      final resServicesList = reservationServicesByRes[r.id.trim()] ?? [];
      final resServicesByApt = <String, ReservationServiceRow>{
        for (final rs in resServicesList) rs.apartmentServiceId.trim(): rs,
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
        final reservationService = resServicesByApt[svc.apartmentServiceId.trim()];
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
          // PROČ: Pro stejnou službu může vzniknout jiný task_type podle dne (both_ways transfer) – musí se vyřešit před řazením a engine.
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

    // --- FÁZE C: Přiřazení personálu a sestavení řádků – těžký výpočet mimo UI vlákno (kromě webu).
    // PROČ: Kolizní engine a iterace kandidátů zatěžují hlavní isolate; [Isolate.run] udrží Kanban plynulý.
    final reservationMaps =
        reservationsLimited.map(_reservationRowToSmartGenMap).toList();
    final apartmentByIdMaps = <String, Map<String, dynamic>>{
      for (final a in apartments)
        a.id: <String, dynamic>{
          'standardCleaning': a.standardCleaningDuration ?? 120,
          'zoneId': a.zoneId,
        },
    };
    final teamMaps = team.map(_teamMemberToIsolateMap).toList();
    final absenceMaps = absences.map(_staffAbsenceToIsolateMap).toList();
    final candidateMaps = candidates.map(_smartTaskCandidateToIsolateMap).toList();

    final phaseCPack = SmartGenPhaseCPack(
      tenantId: tenantId,
      teamMaps: teamMaps,
      tasksList: tasksList,
      existingTasksData: existingTasksData,
      absenceMaps: absenceMaps,
      apartmentByIdMaps: apartmentByIdMaps,
      reservationMaps: reservationMaps,
      apartmentFallback: apartmentFallback,
      candidateMaps: candidateMaps,
    );
    final phaseCResult = await _runSmartGenerationPhaseCAsync(phaseCPack);
    final toInsert = phaseCResult.toInsert;
    final checklistTemplateIdsForBatch = phaseCResult.checklistTemplateIds;
    // Lokalizovaný popis odhadu minut musí zůstat na hlavním vláknu (EasyLocalization / kontext UI).
    for (var i = 0; i < toInsert.length; i++) {
      final dm = phaseCResult.effectiveDurations[i];
      toInsert[i]['description'] = getEstimateMinutesText?.call(dm) ??
          'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': dm.toString()});
    }

    if (toInsert.isEmpty) return 0;
    try {
      final insertedIds = await SupabaseTaskInsertRepository.createTasksBatch(toInsert);
      final n = insertedIds.length < checklistTemplateIdsForBatch.length
          ? insertedIds.length
          : checklistTemplateIdsForBatch.length;
      for (var i = 0; i < n; i++) {
        final tpl = checklistTemplateIdsForBatch[i];
        if (tpl != null && tpl.isNotEmpty) {
          await ChecklistTemplateRepository.instance.instantiateChecklistForTask(
            tenantId: tenantId,
            taskId: insertedIds[i],
            templateId: tpl,
          );
        }
      }
      return toInsert.length;
    } catch (e) {
      // PROČ: Pokud selže odeslání na server kvůli chybějícímu internetu,
      // zachráníme data do lokální fronty. NetworkSyncWatcher je později odešle.
      if (isNetworkError(e)) {
        final mutationQueue = ref.read(mutationQueueServiceProvider);
        try {
          for (final payload in toInsert) {
            final sanitized = sanitizeTaskInsertPayload(Map<String, dynamic>.from(payload));
            await mutationQueue.enqueueMutation(
              table: 'tasks',
              action: 'INSERT',
              payload: sanitized,
            );
          }
        } on OfflineWebException catch (_) {
          // PROČ: Web nemá Drift frontu; enqueue je záměrný fail-fast – nesmíme spustit optimistic UI pod falešnou jistotou uložení.
          reportOfflineWebMutationEnqueueFailed(ref);
          return 0;
        }
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (přidat do lokálního stavu), aby si nemyslel, že se ztratila.
        final current = state.valueOrNull ?? [];
        final apartmentNameById = {for (final a in apartments) a.id: a.name};
        final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
        final baseMs = DateTime.now().millisecondsSinceEpoch;
        final newRows = <TaskRow>[];
        for (var i = 0; i < toInsert.length; i++) {
          final p = sanitizeTaskInsertPayload(Map<String, dynamic>.from(toInsert[i]));
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
  ///
  /// PROČ odděleně od rezervací: údržba „každé 2 týdny“ nemá trigger z pobytu hosta, ale z konfigurace bytu
  /// (`apartment_services.schedule_interval`). Tok: načteme scheduled řádky → pro každou dvojici byt+služba ověříme,
  /// že neexistuje aktivní otevřený úkol (jinak by vznikaly duplicity) → další termín = poslední dokončený úkol
  /// + interval, nebo „od teď“ → kotva času je vždy 10:00 v daný den → délku bloku počítá [_taskDurationMinutes]
  /// → [pickAssigneeWithCollisionAvoidance] najde člena týmu bez kolize s ostatními úkoly (včetně právě generovaných
  /// v `toInsert`). Metadata nesou cenu/plátce/foto stejně jako u úkolů z rezervací, aby byl downstream (worker, fakturace) konzistentní.
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

    // Načtení apartment_services s trigger_type='scheduled' a schedule_interval.
    // PROČ: Jen tyto řádky definují periodickou službu na bytě; ostatní triggery (before_checkin, …) řeší jiná větev planneru.
    // KROK 2: custom_price a payer_type pro vypálení finančních dat do metadata úkolu.
    final apartmentServicesRaw = await SupabaseService.safeFrom('apartment_services', tenantId)
        .select(
            'apartment_id, service_id, trigger_type, schedule_interval, requires_photo, custom_price, payer_type, checklist_template_id');
    final scheduledServices = <Map<String, dynamic>>[];
    for (final row in apartmentServicesRaw as List) {
      final map = row as Map<String, dynamic>;
      final triggerType = (map['trigger_type'] as String?)?.trim() ?? '';
      final scheduleInterval = (map['schedule_interval'] as String?)?.trim();
      if (triggerType == 'scheduled' && scheduleInterval != null && scheduleInterval.isNotEmpty) {
        scheduledServices.add(map);
      }
    }

    final tasksRaw = await SupabaseService.safeFrom('tasks', tenantId)
        .select()
        .isFilter('deleted_at', null);
    final tasksList = (tasksRaw as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Anti-amnézie: jedna sdílená reference toInsert; po každém volání engine ihned .add(...).
    final toInsert = <Map<String, dynamic>>[];
    // Pořadí odpovídá toInsert – checklist_template_id z apartment_services u scheduled služby.
    final checklistTemplateIdsForScheduledBatch = <String?>[];

    // Žádné řetězení: každý úkol se počítá z čistého taskDate. Striktní ukotvení bez vláčku.

    // Ochranný limit: max 100 scheduled služeb na jedno spuštění – zabraňuje zamrznutí při velkém objemu.
    const int maxScheduledPerRun = 100;
    for (final row in scheduledServices.take(maxScheduledPerRun)) {
      final apartmentId = (row['apartment_id'] as String?)?.trim() ?? '';
      final serviceId = (row['service_id'] as String?)?.trim() ?? '';
      final scheduleInterval = (row['schedule_interval'] as String?)?.trim() ?? '';
      if (apartmentId.isEmpty || serviceId.isEmpty || scheduleInterval.isEmpty) continue;

      final service = catalogById[serviceId];
      if (service == null) continue;

      // --- OCHRANNÝ ŠTÍT: Nepřidat úkol, pokud už existuje aktivní (pending/assigned/in_progress) pro apartment+service ---
      // PROČ: Bez toho by každé spuštění generátoru poslalo další stejný údržbový úkol dřív, než ten předchozí skončí.
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
      // PROČ: Interval se počítá od skutečného dokončení, ne od plánu – jinak by se po zpoždění hromadily fiktivní termíny.
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

      // Převod schedule_interval na Duration a výpočet dalšího data (viz [_addScheduleInterval] – textové hodnoty z DB).
      final nextDate = _addScheduleInterval(baseDate, scheduleInterval);
      if (nextDate.isBefore(today)) continue; // negenerovat do minulosti

      // PROČ fixní 10:00: scheduled úkoly nemají kotvu na příjezd hosta; jednotný „den práce“ zjednodušuje plánovač i UI.
      final taskDate = DateTime(nextDate.year, nextDate.month, nextDate.day, 10, 0, 0);
      final apartment = apartmentById[apartmentId];
      final serviceDurationMinutes = service.durationMinutes ?? 60;
      final totalMinutes = _taskDurationMinutes(
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
      // Anti-amnézie: ihned přidat do toInsert, aby další iterace engine viděla přiřazení.
      final description = getEstimateMinutesText?.call(totalMinutes) ?? 'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': totalMinutes.toString()});
      final scheduledMetadata = <String, dynamic>{};
      // Kaskáda: apartment_services.requires_photo -> tenant_services.requires_photo (pro scheduled není reservation).
      final rawApartmentReq = row['requires_photo'];
      bool? apartmentReqPhoto;
      if (rawApartmentReq != null) {
        if (rawApartmentReq is bool) {
          apartmentReqPhoto = rawApartmentReq;
        } else if (rawApartmentReq is int) {
          apartmentReqPhoto = rawApartmentReq == 1;
        } else if (rawApartmentReq is String) {
          final l = rawApartmentReq.toLowerCase();
          if (l == 'true' || l == '1') {
            apartmentReqPhoto = true;
          } else if (l == 'false' || l == '0') {
            apartmentReqPhoto = false;
          }
        }
      }
      final bool scheduledRequiresPhoto = apartmentReqPhoto ?? service.requiresPhoto;
      scheduledMetadata['requires_photo'] = scheduledRequiresPhoto;
      // KROK 2 OPRAVA: Vypálit cenu a plátce z apartment_services (příp. tenant_services) do metadata.
      // Kaskáda: custom_price přepisuje default_price; payer_type z bytu, fallback 'owner'.
      final customPriceRaw = row['custom_price'];
      final catalogPrice = service.defaultPrice;
      double? resolvedPrice;
      if (customPriceRaw != null) {
        if (customPriceRaw is num) {
          resolvedPrice = customPriceRaw.toDouble();
        } else {
          resolvedPrice = double.tryParse(customPriceRaw.toString());
        }
      }
      resolvedPrice ??= catalogPrice?.toDouble();
      final aptPayer = (row['payer_type'] as String?)?.trim();
      final scheduledPayerType =
          (aptPayer == 'owner' || aptPayer == 'guest') ? aptPayer! : 'owner';
      scheduledMetadata['payer_type'] = scheduledPayerType;
      if (resolvedPrice != null && resolvedPrice > 0) {
        if (scheduledPayerType == 'guest') {
          scheduledMetadata['amount_to_collect'] = resolvedPrice;
        } else {
          scheduledMetadata['service_price'] = resolvedPrice;
        }
      }
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
      final rawSchTpl = row['checklist_template_id'];
      checklistTemplateIdsForScheduledBatch.add(
        rawSchTpl == null ? null : (rawSchTpl.toString().trim().isEmpty ? null : rawSchTpl.toString().trim()),
      );
      // Ochrana proti přetížení API (Batching). Vygenerujeme max 50 pravidelných úkolů na jedno spuštění.
      if (toInsert.length >= 50) {
        break;
      }
    }

    if (toInsert.isEmpty) return 0;
    try {
      final insertedScheduledIds = await SupabaseTaskInsertRepository.createTasksBatch(toInsert);
      final ns = insertedScheduledIds.length < checklistTemplateIdsForScheduledBatch.length
          ? insertedScheduledIds.length
          : checklistTemplateIdsForScheduledBatch.length;
      for (var i = 0; i < ns; i++) {
        final tpl = checklistTemplateIdsForScheduledBatch[i];
        if (tpl != null && tpl.isNotEmpty) {
          await ChecklistTemplateRepository.instance.instantiateChecklistForTask(
            tenantId: tenantId,
            taskId: insertedScheduledIds[i],
            templateId: tpl,
          );
        }
      }
      return toInsert.length;
    } catch (e) {
      // PROČ: Síťová chyba – zachránit do fronty. NetworkSyncWatcher odešle po obnovení sítě.
      if (isNetworkError(e)) {
        final mutationQueue = ref.read(mutationQueueServiceProvider);
        try {
          for (final payload in toInsert) {
            final sanitized = sanitizeTaskInsertPayload(Map<String, dynamic>.from(payload));
            await mutationQueue.enqueueMutation(
              table: 'tasks',
              action: 'INSERT',
              payload: sanitized,
            );
          }
        } on OfflineWebException catch (_) {
          // PROČ: Na webu nelze zařadit INSERT do fronty; bez catch by UI tvrdilo úspěch při ztrátě dat.
          reportOfflineWebMutationEnqueueFailed(ref);
          return 0;
        }
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (přidat do lokálního stavu), aby si nemyslel, že se ztratila.
        final current = state.valueOrNull ?? [];
        final apartmentNameById = {for (final a in apartments) a.id: a.name};
        final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
        final baseMs = DateTime.now().millisecondsSinceEpoch;
        final newRows = <TaskRow>[];
        for (var i = 0; i < toInsert.length; i++) {
          final p = sanitizeTaskInsertPayload(Map<String, dynamic>.from(toInsert[i]));
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
      await SupabaseService.safeFrom('tasks', tenantId)
          .update({'status': newStatus})
          .eq('id', taskId);
    } catch (e) {
      // PROČ: Offline – uložit do fronty. NetworkSyncWatcher odešle při návratu sítě.
      if (isNetworkError(e)) {
        try {
          await ref.read(mutationQueueServiceProvider).enqueueMutation(
                table: 'tasks',
                action: 'UPDATE',
                payload: {'status': newStatus, 'tenant_id': tenantId},
                recordId: taskId,
              );
        } on OfflineWebException catch (_) {
          // PROČ: Kanban na webu bez sítě nesmí „uspět“ tiše – uživatel musí vědět, že stav nebyl persistován.
          reportOfflineWebMutationEnqueueFailed(ref);
          return;
        }
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

  /// Hromadná změna stavu úkolů (Kanban výběr). Volá [updateTaskStatus] pro každé id — zachová offline frontu a optimistic UI.
  ///
  /// PROČ: Stejná obchodní logika jako u drag & drop; u dokončení (`completed`) se nevyvolává dialog hotovosti —
  /// ten zůstává jen u přetahování do sloupce Hotovo.
  Future<void> bulkUpdateTaskStatus(
    List<String> taskIds,
    String newStatus,
  ) async {
    for (final id in taskIds) {
      if (id.isEmpty) continue;
      await updateTaskStatus(id, newStatus);
    }
  }

  /// Hromadné přiřazení hlavního pracovníka (`assigned_to`). Prázdné [profileId] = odpřiřazení.
  ///
  /// PROČ: Opakované použití [updateTaskInAdmin] kvůli konzistenci s jednotlivou úpravou a offline chováním.
  Future<void> bulkAssignTasks(List<String> taskIds, String? profileId) async {
    final uuid = profileId?.trim();
    final assigned = (uuid != null && uuid.isNotEmpty) ? uuid : null;
    for (final id in taskIds) {
      if (id.isEmpty) continue;
      await updateTaskInAdmin(id, {
        'assigned_to': assigned,
        if (assigned != null) 'unassigned_info': null,
      });
    }
  }

  /// Vloží nový úkol do Supabase. Veškerá logika (insert → catch → enqueue → optimistic state) v jednom místě.
  /// UI jen volá tuto metodu a čeká na výsledek. [payload] musí obsahovat tenant_id, apartment_id, title,
  /// description, status, task_type, due_date, scheduled_start; volitelně assigned_to, metadata.
  /// [checklistTemplateId]: pokud je vyplněno, použije se jako šablona (přepíše výchozí z bytu). Pokud je null
  /// nebo prázdné a payload má [apartment_id] i [service_id], načte se šablona z [apartment_services].
  /// [ChecklistTemplateRepository.instantiateChecklistForTask] zmrazí položky do `task_checklist_items`.
  /// Offline větev nemá reálné UUID úkolu – kopírování checklistu se neprovádí.
  /// Vrací true při úspěchu (online i offline), při chybě vyhodí výjimku.
  Future<void> insertTaskInAdmin(
    Map<String, dynamic> payload, {
    String? checklistTemplateId,
  }) async {
    final p = Map<String, dynamic>.from(payload);
    if (p['metadata'] == null) p['metadata'] = {};
    if (p['reference_number'] == null || (p['reference_number'] as String).trim().isEmpty) {
      p['reference_number'] = generateTaskRef();
    }
    final tenantId = ref.read(authNotifierProvider).tenantIdForData ?? p['tenant_id'] as String?;
    if (tenantId == null || tenantId.isEmpty) throw StateError('Missing tenant_id for insert');
    try {
      final taskId = await SupabaseTaskInsertRepository.createTask(p);
      // PROČ: Explicitní výběr v dialogu má přednost; jinak bereme šablonu z apartment_services (byt + služba).
      var tplId = checklistTemplateId?.trim();
      if (tplId == null || tplId.isEmpty) {
        final apt = p['apartment_id']?.toString().trim();
        final svc = p['service_id']?.toString().trim();
        if (apt != null && apt.isNotEmpty && svc != null && svc.isNotEmpty) {
          tplId = await fetchChecklistTemplateIdForApartmentAndService(
            tenantId: tenantId,
            apartmentId: apt,
            serviceId: svc,
          );
        }
      }
      if (tplId != null && tplId.isNotEmpty) {
        await ChecklistTemplateRepository.instance.instantiateChecklistForTask(
          tenantId: tenantId,
          taskId: taskId,
          templateId: tplId,
        );
      }
      invalidatePlanningCalendarCaches(ref);
      return;
    } catch (e) {
      if (isNetworkError(e)) {
        final sanitized = sanitizeTaskInsertPayload(Map<String, dynamic>.from(p));
        try {
          await ref.read(mutationQueueServiceProvider).enqueueMutation(
            table: 'tasks',
            action: 'INSERT',
            payload: sanitized,
          );
        } on OfflineWebException catch (_) {
          // PROČ: Stejný fail-fast jako u batch generátorů – dialog nesmí skončit jako uloženo, když nic nečeká ve frontě.
          reportOfflineWebMutationEnqueueFailed(ref);
          return;
        }
        // PROČ: Optimistic UI. I když jsme offline a data šla do fronty, musíme je uživateli hned
        // zobrazit na obrazovce (přidat do lokálního stavu), aby si nemyslel, že se ztratila.
        final apartments = ref.read(apartmentsFullListProvider).valueOrNull ?? [];
        final team = ref.read(teamFullListProvider).valueOrNull ?? [];
        final apartmentNameById = {for (final a in apartments) a.id: a.name};
        final nameByProfileId = {for (final m in team) m.dropdownId: m.name};
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final sanitizedP = sanitizeTaskInsertPayload(Map<String, dynamic>.from(p));
        final aptId = (sanitizedP['apartment_id'] as String?) ?? '';
        final assignedTo = sanitizedP['assigned_to'] as String?;
        final map = <String, dynamic>{
          'id': tempId,
          'apartment_id': aptId,
          'assigned_to': assignedTo,
          'title': sanitizedP['title'],
          'description': sanitizedP['description'],
          'status': sanitizedP['status'],
          'task_type': sanitizedP['task_type'],
          'due_date': sanitizedP['due_date'],
          'scheduled_start': sanitizedP['scheduled_start'],
          'apartment_name': apartmentNameById[aptId],
          'assigned_to_name': assignedTo != null ? nameByProfileId[assignedTo] : null,
          'metadata': sanitizedP['metadata'] ?? {},
        };
        final newRow = TaskRow.fromJson(map);
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([...current, newRow]);
        invalidatePlanningCalendarCaches(ref);
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
      await SupabaseService.safeFrom('tasks', tenantId)
          .update(updateFields)
          .eq('id', taskId);
      // PROČ: Po uložení přeřazení invalidujeme načtení jednoho úkolu, aby Finance/Reporty
      // po zavření dialogu viděly aktuální data.
      ref.invalidate(taskByIdProvider(taskId));
      invalidatePlanningCalendarCaches(ref);
      return;
    } catch (e) {
      if (isNetworkError(e)) {
        try {
          await ref.read(mutationQueueServiceProvider).enqueueMutation(
            table: 'tasks',
            action: 'UPDATE',
            payload: payload,
            recordId: taskId,
          );
        } on OfflineWebException catch (_) {
          // PROČ: Úprava úkolu z admin UI na webu bez připojení = žádná lokální fronta; varovat místo falešného merge stavu.
          reportOfflineWebMutationEnqueueFailed(ref);
          return;
        }
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
            double? newLat = old.latitude;
            double? newLng = old.longitude;
            if (payload.containsKey('geo_location')) {
              final g = GeoJsonPoint.parseFromPostgrest(payload['geo_location']);
              newLat = g?.latitude;
              newLng = g?.longitude;
            }
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
              latitude: newLat,
              longitude: newLng,
            );
            state = AsyncValue.data([
              ...current.sublist(0, idx),
              updated,
              ...current.sublist(idx + 1),
            ]);
            invalidatePlanningCalendarCaches(ref);
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
      await SupabaseService.safeFrom('tasks', tenantId)
          .update({'status': 'assigned'})
          .inFilter('id', batch);
    }
    return pending.length;
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
    } catch (e, st) {
      AppLogger.error('AdminTasksNotifier.recalculateAssignees: načtení týmu selhalo', e, st);
      return [];
    }
    final absences = await ref.read(staffAbsencesProvider.future);
    final reservations = await ref.read(adminReservationsProvider.future);

    final apartments = await ref.read(apartmentsFullListProvider.future);
    final catalog = await ref.read(tenantServicesProvider.future);

    dynamic res;
    try {
      res = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, apartment_id, reservation_id, title, due_date, scheduled_start, assigned_to, task_type, status, service_id')
          .isFilter('deleted_at', null)
          // BUSINESS RULE: Přepočítávat smíme POUZE úkoly ve stavu návrh (pending) a zadáno (assigned).
          // Úkoly, které probíhají nebo jsou hotové, jsou nedotknutelné.
          .inFilter('status', ['pending', 'assigned'])
          .gte('due_date', tomorrowStart.toIso8601String())
          .order('due_date', ascending: true);
    } catch (e, st) {
      AppLogger.error('AdminTasksNotifier.recalculateAssignees: dotaz úkolů pro přepočet selhal', e, st);
      return [];
    }

    final list = res is List ? res : <dynamic>[];
    // Ochrana proti zamrznutí UI a přetížení API. Zpracováváme max 50 úkolů v jedné dávce.
    final limitedTasksToProcess = list.take(50).toList();
    final teamMaps = team.map(_teamMemberToIsolateMap).toList();
    final absenceMaps = absences.map(_staffAbsenceToIsolateMap).toList();
    final reservationMaps = reservations.map(_reservationRowToSmartGenMap).toList();
    final apartmentByIdMaps = <String, Map<String, dynamic>>{
      for (final a in apartments)
        a.id: <String, dynamic>{
          'standardCleaning': a.standardCleaningDuration ?? 120,
          'zoneId': a.zoneId,
        },
    };
    final catalogServiceMaps = catalog
        .map(
          (s) => <String, dynamic>{
            'id': s.id,
            'required_role': s.requiredRole,
            'service_type': s.serviceType,
          },
        )
        .toList();
    final taskMaps = limitedTasksToProcess
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();

    final recalcPack = RecalculateAssigneesPack(
      teamMaps: teamMaps,
      taskMaps: taskMaps,
      absenceMaps: absenceMaps,
      reservationMaps: reservationMaps,
      apartmentByIdMaps: apartmentByIdMaps,
      catalogServiceMaps: catalogServiceMaps,
      tomorrowStartIso: tomorrowStart.toIso8601String(),
    );
    final proposalMaps = await _runRecalculateAssigneesAsync(recalcPack);

    return proposalMaps
        .map(
          (m) => TaskRecalculationProposal(
            taskId: m['taskId'] as String,
            taskTitle: m['taskTitle'] as String,
            oldAssigneeId: m['oldAssigneeId'] as String?,
            oldAssigneeName: m['oldAssigneeName'] as String?,
            newAssigneeId: m['newAssigneeId'] as String?,
            newAssigneeName: m['newAssigneeName'] as String?,
            oldStart: DateTime.parse(m['oldStart'] as String),
            oldEnd: DateTime.parse(m['oldEnd'] as String),
            newStart: DateTime.parse(m['newStart'] as String),
            newEnd: DateTime.parse(m['newEnd'] as String),
            timeChanged: m['timeChanged'] as bool,
          ),
        )
        .toList();
  }

  /// Uloží schválené návrhy změn do databáze.
  /// Pokud [timeChanged] je false, aktualizuje se pouze assigned_to (ne scheduled_start/due_date),
  /// aby nedošlo k nechtěnému posunu času o +1 h.
  Future<void> applyRecalculationProposals(List<TaskRecalculationProposal> approved) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    for (final p in approved) {
      final Map<String, dynamic> payload = {'assigned_to': p.newAssigneeId};
      if (p.timeChanged) {
        payload['scheduled_start'] = p.newStart.toIso8601String();
        payload['due_date'] = p.newEnd.toIso8601String();
      }
      await SupabaseService.safeFrom('tasks', tenantId)
          .update(payload)
          .eq('id', p.taskId);
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
/// PROČ: Výkon – stream úkolů načítá jen tento měsíc (řez podle scheduled_start v DB), ne celou historii.
final selectedTaskMonthProvider =
    StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Realtime stream úkolů pro Admin – okamžitá aktualizace UI bez F5.
///
/// PROČ: Dispečer vidí změny (nové úkoly, přiřazení, status) hned po provedení.
/// Načítá pouze úkoly z [selectedTaskMonthProvider] (bezpečné časové okno v dotazu, bez tichého limitu 500).
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

// --- Kanban: granulární překreslování sloupců (Fáze 3 výkon) -----------------

/// Kanonické systémové statusy v DB (shodné s UI výčtem na obrazovce úkolů).
const List<String> kanbanSystemStatuses = [
  'pending',
  'assigned',
  'in_progress',
  'completed',
  'problem',
];

/// Normalizace statusu z DB na systémovou hodnotu sloupce Kanbanu (legacy CZ/EN).
///
/// PROČ ve sdílené vrstvě: stejná pravidla pro [tasksBySystemStatusProvider] i pro DragTarget v UI.
String kanbanNormalizeToSystemStatus(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'pending';
  final s = raw.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') return 'pending';
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') {
    return 'assigned';
  }
  if (s == 'in_progress' || s == 'probíhá') return 'in_progress';
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') {
    return 'completed';
  }
  if (s == 'problém' || s == 'problem' || s == 'issue') return 'problem';
  if (kanbanSystemStatuses.contains(raw.trim())) return raw.trim();
  return 'pending';
}

/// Textové vyhledávání v Kanbanu – synchronizuje se z pole hledání na [AdminTasksScreen].
///
/// PROČ StateProvider: sloupce filtrují stejně jako textové hledání na obrazovce, bez přestavby celého Scaffoldu.
final kanbanTasksSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtrování úkolů podle dotazu (stejná sémantika jako dříve na obrazovce).
List<TaskRow> kanbanFilterTasksBySearchQuery(List<TaskRow> tasks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return tasks;
  return tasks.where((t) {
    final title = t.title.toLowerCase();
    final desc = t.description.toLowerCase();
    final apt = (t.apartmentName ?? '').toLowerCase();
    final who = (t.assignedToName ?? '').toLowerCase();
    final tags = TaskCustomTag.searchBlob(t.metadata);
    return title.contains(q) ||
        desc.contains(q) ||
        apt.contains(q) ||
        who.contains(q) ||
        tags.contains(q);
  }).toList();
}

/// Úkoly patřící do jednoho sloupce Kanbanu (včetně sloučení `problem` do „Probíhá“).
List<TaskRow> kanbanTasksForSystemStatusColumn(
  List<TaskRow> tasks,
  String systemStatus,
) {
  if (systemStatus == 'in_progress') {
    return tasks.where((t) {
      final norm = kanbanNormalizeToSystemStatus(t.status);
      return norm == 'in_progress' || norm == 'problem';
    }).toList();
  }
  return tasks
      .where((t) => kanbanNormalizeToSystemStatus(t.status) == systemStatus)
      .toList();
}

/// Porovnání polí [TaskRow] relevantních pro kartu Kanbanu – při shodě Riverpod nevyvolá rebuild sloupce.
bool _kanbanTaskRowKanbanVisualEquals(TaskRow a, TaskRow b) {
  return a.id == b.id &&
      a.status == b.status &&
      a.title == b.title &&
      a.description == b.description &&
      a.apartmentId == b.apartmentId &&
      a.apartmentName == b.apartmentName &&
      a.assignedTo == b.assignedTo &&
      a.assignedToName == b.assignedToName &&
      a.taskType == b.taskType &&
      a.dueDate == b.dueDate &&
      a.scheduledStart == b.scheduledStart &&
      a.referenceNumber == b.referenceNumber &&
      a.customTitle == b.customTitle &&
      a.customLocation == b.customLocation &&
      a.completedAt == b.completedAt &&
      const DeepCollectionEquality().equals(a.metadata, b.metadata);
}

/// Neměnný výřez úkolů jednoho sloupce s value equality – [Provider] překreslí jen při reálné změně dat sloupce.
@immutable
class KanbanColumnTasks {
  const KanbanColumnTasks(this.tasks);
  final List<TaskRow> tasks;

  /// Prázdný sloupec sdílí jednu konstantní instanci (méně alokací).
  factory KanbanColumnTasks.fromFiltered(List<TaskRow> source) {
    if (source.isEmpty) return const KanbanColumnTasks(<TaskRow>[]);
    return KanbanColumnTasks(List<TaskRow>.unmodifiable(source));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KanbanColumnTasks) return false;
    if (tasks.length != other.tasks.length) return false;
    for (var i = 0; i < tasks.length; i++) {
      if (!_kanbanTaskRowKanbanVisualEquals(tasks[i], other.tasks[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        tasks.map(
          (e) => Object.hash(
            e.id,
            e.status,
            e.title,
            e.description,
            e.apartmentName,
            e.assignedToName,
            e.taskType,
            e.dueDate,
            e.scheduledStart,
            e.referenceNumber,
            e.customTitle,
            e.customLocation,
            e.assignedTo,
            e.completedAt,
            const DeepCollectionEquality().hash(e.metadata),
          ),
        ),
      );
}

/// Výřez úkolů pro jeden systémový sloupec Kanbanu – sleduje stream + vyhledávání.
///
/// PROČ [Provider.family]: každý sloupec má vlastní předplatné; díky [KanbanColumnTasks]== se UI neobnoví,
/// pokud se změní jen jiný sloupec (např. přesun mezi „Zadáno“ a „Probíhá“ přepočítá jen tyto dva providery).
final tasksBySystemStatusProvider =
    Provider.family<KanbanColumnTasks, String>((ref, systemStatus) {
  final async = ref.watch(adminTasksStreamProvider);
  final tasks = async.valueOrNull ?? const <TaskRow>[];
  final q = ref.watch(kanbanTasksSearchQueryProvider);
  final filtered = kanbanFilterTasksBySearchQuery(tasks, q);
  final col = kanbanTasksForSystemStatusColumn(filtered, systemStatus);
  return KanbanColumnTasks.fromFiltered(col);
});

/// Zda Kanban zobrazí alespoň jeden úkol po aplikaci vyhledávání (prázdný stav vs. nástěnka).
final kanbanHasVisibleTasksProvider = Provider<bool>((ref) {
  final async = ref.watch(adminTasksStreamProvider);
  final tasks = async.valueOrNull ?? const <TaskRow>[];
  final q = ref.watch(kanbanTasksSearchQueryProvider);
  return kanbanFilterTasksBySearchQuery(tasks, q).isNotEmpty;
});

/// Stream úkolů pro výpočet vytížení na kartách Personál – **nezávislý** na [selectedTaskMonthProvider].
///
/// PROČ: Záložka Úkoly mění měsíc; metriky „tento / příští týden“ musí vždy čerpat z úzkého okna kolem dneška
/// (viz [AdminTasksRepository.watchTasksRawForTeamWorkloadWindow]), ne z celého měsíce v paměti.
final teamWeeklyWorkloadTasksProvider =
    StreamProvider<List<TaskRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final team = await ref.watch(teamFullListProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  final nameByProfileId = <String, String>{};
  for (final m in team) {
    final id = m.profileId ?? m.id;
    if (id.isNotEmpty) nameByProfileId[id] = m.name;
  }

  await for (final rawList
      in AdminTasksRepository.instance.watchTasksRawForTeamWorkloadWindow(tenantId)) {
    try {
      final rows = rawList
          .map((raw) => TaskRow.fromSupabaseRow(
                Map<String, dynamic>.from(raw),
                apartmentById: apartmentById,
                nameByProfileId: nameByProfileId,
              ))
          .toList();
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

/// Stream úkolů pro Nástěnku – B2B měsíční výhled (1. den aktuálního měsíce → poslední den příštího měsíce).
///
/// PROČ: Očekávaný příjem zobrazuje hotové k fakturaci + výhled tohoto a příštího měsíce. Dnešní plán a další
/// sekce používají stejný výřez. Ostatní moduly (záložka Úkoly, settlements) dál používají [adminTasksStreamProvider].
final adminDashboardTasksProvider =
    StreamProvider<List<TaskRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  // B2B fakturace: aktuální měsíc + příští měsíc (1. den běžného měsíce 00:00 → poslední den příštího měsíce 23:59).
  final now = DateTime.now();
  final fromLocal = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
  final nextMonth = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
  final lastDayNext = DateTime(nextMonth.year, nextMonth.month + 1, 0, 23, 59, 59, 999);
  final toLocal = lastDayNext;
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
    query = SupabaseService.safeFrom('tasks', tenantId)
        .select()
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null)
        .inFilter('apartment_id', apartmentIds)
        .order('scheduled_start', ascending: true);
  } else {
    query = SupabaseService.safeFrom('tasks', tenantId)
        .select()
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

  final res = await SupabaseService.safeFrom('tasks', tenantId)
      .select()
      .eq('id', taskId)
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

  final res = await SupabaseService.safeFrom('tasks', tenantId)
      .select()
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

  final res = await SupabaseService.safeFrom('tasks', tenantId)
      .select()
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

/// Vrací délku blokace úkolu v minutách.
///
/// PROČ složitější pravidlo pro úklid: standardní délka úklidu bytu (`apartmentStandardCleaning`) + délka konkrétní služby
/// z katalogu odpovídá realitě provozu (nejdřív základ bytu, pak nadstavba). Ostatní typy berou jen `serviceDurationMinutes`,
/// aby transfery/check-in nebyly uměle prodlouženy. Provider tím nahrazuje bývalý výpočet uvnitř enginu – engine a kolizní
/// logika dostávají už hotové `taskStart`/`taskEnd` a nemusí znát business pravidla délky.
int _taskDurationMinutes({
  required String serviceType,
  required int apartmentStandardCleaning,
  required int serviceDurationMinutes,
}) {
  if (serviceType.trim().toLowerCase() == 'cleaning') {
    return apartmentStandardCleaning + serviceDurationMinutes;
  }
  return serviceDurationMinutes > 0 ? serviceDurationMinutes : 60;
}

/// Vrací planning_priority pro Smart Planner výhradně z DB číselníku task_categories.
/// Žádný hardcoded fallback – batch se řadí čistě podle databáze (1 = nejdůležitější).
int _getPlanningPriorityForTaskType(
  String effectiveTaskType,
  Map<String, TaskCategoryModel> categoriesByCode,
) {
  final code = effectiveTaskType.trim().toLowerCase();
  return categoriesByCode[code]?.planningPriority ?? 99;
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
  } catch (e, st) {
    AppLogger.error('admin_tasks_provider._parseReservationCheckInDate selhalo', e, st);
    return null;
  }
}

/// Vrací efektivní `task_type` pro úkol na dané datum (hodnota jde do DB a řídí ikony, pravidla „svatých“ úkolů atd.).
///
/// PROČ zvláštní větev pro `both_ways` + transfer: jedna služba v katalogu může generovat **dva** úkoly (příjezd i odjezd).
/// Bez rozlišení `transfer_in` / `transfer_out` by oba měly stejný typ a plánovač by je nedokázal správně prioritizovat
/// ani párovat s časovými kotvami. Pro ostatní služby stačí normalizovaný `serviceTypeNorm` z katalogu, s bezpečným
/// fallbackem na `extra`, pokud je typ prázdný.
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
  } catch (e, st) {
    AppLogger.error('admin_tasks_provider._parseReservationCheckOutDate selhalo', e, st);
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
