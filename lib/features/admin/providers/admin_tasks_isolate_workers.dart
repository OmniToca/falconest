// =============================================================================
// FalcoNest – těžké výpočty generování úkolů a přepočtu personálu mimo UI vlákno.
//
// PROČ: Fáze C generátoru (kolize, pickAssigneeWithCollisionAvoidance) a smyčka
// přepočtu personálu běží CPU-náročně; na mobilu/desktopu je spouštíme v Isolate,
// aby hlavní vlákno nesekalo animace. Na webu Isolate není k dispozici – volá stejná
// funkce synchronně (volá admin_tasks_provider po kIsWeb).
//
// ZÁKAZ: Neměnit byznysovou logiku – kód je zkopírován z AdminTasksNotifier
// (stejné podmínky, stejný engine). Pouze přepakované vstupy (Map) místo Riverpod.
// =============================================================================

import 'package:intl/intl.dart';

import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart'
    show ReservationServiceRow, parseFlightFromCustomNote;
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/task_assignment_engine.dart';

// --- Kopie pomocných pravidel z admin_tasks_provider (1:1 chování) -------------

/// Deserializace mapy částek (např. collection_breakdown) z JSON přeneseného do Isolate.
Map<String, num> _decodeStringNumMap(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, num>{};
  for (final e in raw.entries) {
    final k = e.key?.toString();
    final v = e.value;
    if (k == null || k.isEmpty) continue;
    if (v is num) out[k] = v;
  }
  return out;
}

/// Průtok z řádku [reservation_services] → `metadata.transit_amount_to_collect` u úkolu téže služby.
void _applyTransitFromReservationService(Map<String, dynamic> metadata, dynamic rsRaw) {
  if (rsRaw is! Map) return;
  final rs = ReservationServiceRow.fromJson(Map<String, dynamic>.from(rsRaw));
  final tr = (rs.transitCashToCollect ?? 0).toDouble();
  if (tr > 0) {
    metadata['transit_amount_to_collect'] = tr;
  }
}

/// Host platí jen průtok (bez agenturní hotovosti) nebo jen audit není – nastavíme plátce pro mobilní UI.
void _ensureGuestPayerWhenTransitWithoutAgencyCash(Map<String, dynamic> metadata) {
  final transit = (metadata['transit_amount_to_collect'] as num?)?.toDouble() ?? 0;
  final agency = (metadata['amount_to_collect'] as num?)?.toDouble() ?? 0;
  if (transit > 0 && agency <= 0 && !metadata.containsKey('expected_audit_total')) {
    metadata['payer_type'] = 'guest';
  }
}

bool _hasRole(TeamMember m, String role) {
  if (assignableId(m).isEmpty) return false;
  final r = role.toLowerCase();
  return m.roles.any((x) => x.toLowerCase() == r);
}

bool _hasZoneBlacklist(TeamMember m, String zoneId) {
  final prefs = m.zonePreferences;
  if (prefs == null || prefs.isEmpty) return false;
  final val = prefs[zoneId];
  return val == -1;
}

List<TeamMember> _filterAndSortByZonePreferences(
  List<TeamMember> candidates,
  String? zoneId,
) {
  if (zoneId == null || zoneId.isEmpty) return candidates;
  final withoutBlacklist =
      candidates.where((m) => !_hasZoneBlacklist(m, zoneId)).toList();
  withoutBlacklist.sort(
    (a, b) => zonePreferencePriority(a, zoneId).compareTo(zonePreferencePriority(b, zoneId)),
  );
  return withoutBlacklist;
}

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

bool _isSacredTaskType(String taskType) {
  final t = taskType.trim().toLowerCase();
  return t.contains('check_in') ||
      t.contains('check_out') ||
      t.contains('transfer_in') ||
      t.contains('transfer_out') ||
      (t == 'transfer');
}

bool _shouldApplyNightRestByTaskType(String taskType) {
  final t = taskType.toLowerCase();
  return !(t.contains('transfer') ||
      t.contains('řidič') ||
      t.contains('driver') ||
      t.contains('check-in') ||
      t.contains('check-out') ||
      t.contains('check_in') ||
      t.contains('check_out'));
}

bool _isWithinContract(TeamMember member, DateTime taskDate) {
  final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
  if (member.startDate != null) {
    final startDay = DateTime(
        member.startDate!.year, member.startDate!.month, member.startDate!.day);
    if (taskDay.isBefore(startDay)) return false;
  }
  if (member.endDate != null) {
    final endDay =
        DateTime(member.endDate!.year, member.endDate!.month, member.endDate!.day);
    if (taskDay.isAfter(endDay)) return false;
  }
  return true;
}

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
    AppLogger.error('admin_tasks_isolate_workers._parseReservationCheckInDate selhalo', e, st);
    return null;
  }
}

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
    AppLogger.error('admin_tasks_isolate_workers._parseReservationCheckOutDate selhalo', e, st);
    return null;
  }
}

DateTime? _getReservationCheckInDateTime(Map<String, dynamic> r) {
  final atStr = r['arrival_time'] as String?;
  if (atStr != null && atStr.isNotEmpty) {
    final at = DateTime.tryParse(atStr);
    if (at != null) {
      return DateTime(at.year, at.month, at.day, at.hour, at.minute);
    }
  }
  return _parseReservationCheckInDate(r['check_in'] as String?);
}

DateTime? _getReservationCheckOutDateTime(Map<String, dynamic> r) {
  final dtStr = r['departure_time'] as String?;
  if (dtStr != null && dtStr.isNotEmpty) {
    final dt = DateTime.tryParse(dtStr);
    if (dt != null) {
      return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
    }
  }
  return _parseReservationCheckOutDate(r['check_out'] as String?);
}

DateTime _computeTaskDeadlineForReservation(
  Map<String, dynamic> currentRes,
  List<Map<String, dynamic>> allReservations,
) {
  final checkOutDt = _getReservationCheckOutDateTime(currentRes);
  if (checkOutDt == null) return DateTime.now().add(const Duration(days: 3));

  DateTime? nearestNextCheckIn;
  final currentId = currentRes['id'] as String? ?? '';
  final currentApt = currentRes['apartment_id'] as String? ?? '';
  for (final other in allReservations) {
    if ((other['id'] as String? ?? '') == currentId) continue;
    if ((other['apartment_id'] as String? ?? '') != currentApt) continue;
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

TeamMember _teamMemberFromMap(Map<String, dynamic> raw) {
  Map<String, int>? zp;
  final z = raw['zone_preferences'];
  if (z is Map) {
    zp = <String, int>{};
    for (final e in z.entries) {
      final k = e.key?.toString();
      final v = e.value;
      if (k == null || k.isEmpty) continue;
      if (v is int) zp[k] = v;
      if (v is num) zp[k] = v.toInt();
    }
    if (zp.isEmpty) zp = null;
  }
  final rolesRaw = raw['roles'];
  final roles = rolesRaw is List
      ? rolesRaw.map((e) => e.toString()).toList()
      : <String>[];
  final whRaw = raw['weeklyHours'] ?? raw['weekly_hours'];
  var weeklyHours = 40;
  if (whRaw is int) {
    weeklyHours = whRaw;
  } else if (whRaw is num) {
    weeklyHours = whRaw.toInt();
  }
  return TeamMember(
    id: raw['id'] as String? ?? '',
    name: raw['name'] as String? ?? '',
    email: raw['email'] as String?,
    role: raw['role'] as String? ?? 'worker',
    roles: roles,
    isFromInvitation: raw['isFromInvitation'] == true,
    profileId: raw['profileId'] as String?,
    invitationId: raw['invitationId'] as String?,
    weeklyHours: weeklyHours,
    startDate: raw['start_date'] != null
        ? DateTime.tryParse(raw['start_date'] as String)
        : null,
    endDate:
        raw['end_date'] != null ? DateTime.tryParse(raw['end_date'] as String) : null,
    zonePreferences: zp,
    lastSignInAt: raw['lastSignInAt'] != null
        ? DateTime.tryParse(raw['lastSignInAt'] as String)
        : null,
    systemRole: raw['systemRole'] as String?,
  );
}

/// Výsledek fáze C generátoru – řádky pro INSERT + šablony + minuty pro lokalizovaný popis.
class SmartGenPhaseCResult {
  SmartGenPhaseCResult({
    required this.toInsert,
    required this.checklistTemplateIds,
    required this.effectiveDurations,
  });
  final List<Map<String, dynamic>> toInsert;
  final List<String?> checklistTemplateIds;
  final List<int> effectiveDurations;
}

/// Vstup pro [runSmartGenerationPhaseCSync] – pouze serializovatelné typy.
class SmartGenPhaseCPack {
  SmartGenPhaseCPack({
    required this.tenantId,
    required this.teamMaps,
    required this.tasksList,
    required this.existingTasksData,
    required this.absenceMaps,
    required this.apartmentByIdMaps,
    required this.reservationMaps,
    required this.apartmentFallback,
    required this.candidateMaps,
  });
  final String tenantId;
  final List<Map<String, dynamic>> teamMaps;
  final List<dynamic> tasksList;
  final List<Map<String, dynamic>> existingTasksData;
  final List<Map<String, dynamic>> absenceMaps;
  /// apartment_id -> { 'standardCleaning': int, 'zoneId': String? }
  final Map<String, Map<String, dynamic>> apartmentByIdMaps;
  final List<Map<String, dynamic>> reservationMaps;
  final Map<String, Map<String, dynamic>> apartmentFallback;
  final List<Map<String, dynamic>> candidateMaps;
}

/// Stejná logika jako smyčka „FÁZE C“ v [AdminTasksNotifier.generateSmartTasks].
SmartGenPhaseCResult runSmartGenerationPhaseCSync(SmartGenPhaseCPack pack) {
  final team = pack.teamMaps.map(_teamMemberFromMap).toList();
  final absences =
      pack.absenceMaps.map((m) => StaffAbsence.fromJson(m)).toList();
  final apartmentById = pack.apartmentByIdMaps;

  final toInsert = <Map<String, dynamic>>[];
  final checklistTemplateIdsForBatch = <String?>[];
  final effectiveDurations = <int>[];

  for (final cMap in pack.candidateMaps) {
    if (toInsert.length >= 50) break;

    final r = Map<String, dynamic>.from(cMap['reservation'] as Map);
    final svcMap = Map<String, dynamic>.from(cMap['service'] as Map);
    final taskDate = DateTime.parse(cMap['taskDate'] as String);
    final effectiveTaskType = cMap['effectiveTaskType'] as String;
    final serviceTypeNorm = (svcMap['serviceType'] as String).trim().toLowerCase();

    final reservationId = r['id'] as String? ?? '';
    final serviceId = svcMap['serviceId'] as String? ?? '';

    if (_taskAlreadyExists(pack.existingTasksData, toInsert, reservationId, serviceId)) {
      continue;
    }

    final apartmentId = r['apartment_id'] as String? ?? '';
    final aptMeta = apartmentById[apartmentId];
    final standardCleaning =
        (aptMeta?['standardCleaning'] is int) ? aptMeta!['standardCleaning'] as int : 120;
    final zoneId = aptMeta?['zoneId'] as String?;

    final durationMinutes = (svcMap['durationMinutes'] is int)
        ? svcMap['durationMinutes'] as int
        : (svcMap['durationMinutes'] as num?)?.toInt();

    final effectiveDuration = _isSacredTaskType(effectiveTaskType)
        ? (durationMinutes ?? 60)
        : _taskDurationMinutes(
            serviceType: svcMap['serviceType'] as String,
            apartmentStandardCleaning: standardCleaning,
            serviceDurationMinutes: durationMinutes ?? 60,
          );

    final checkInDt = cMap['checkInDt'] != null
        ? DateTime.parse(cMap['checkInDt'] as String)
        : null;
    final checkOutDt = DateTime.parse(cMap['checkOutDt'] as String);

    final DateTime effectiveAnchor;
    final bool taskEndsAtAnchor;
    final triggerType = svcMap['triggerType'] as String;
    switch (triggerType) {
      case 'before_checkin':
        effectiveAnchor = checkInDt ?? taskDate;
        taskEndsAtAnchor = true;
        break;
      case 'after_checkout':
        effectiveAnchor = checkOutDt;
        taskEndsAtAnchor = false;
        break;
      case 'both_ways':
        final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
        final checkInDay = checkInDt != null
            ? DateTime(checkInDt.year, checkInDt.month, checkInDt.day)
            : null;
        if (checkInDay != null && taskDay == checkInDay) {
          // V této větvi je checkInDay odvozen od checkInDt ⇒ checkInDt je ne-null.
          effectiveAnchor = checkInDt!;
          taskEndsAtAnchor = true;
        } else {
          effectiveAnchor = checkOutDt;
          taskEndsAtAnchor = false;
        }
        break;
      case 'on_demand':
        effectiveAnchor = taskDate;
        taskEndsAtAnchor = false;
        break;
      default:
        effectiveAnchor = taskDate;
        taskEndsAtAnchor = false;
    }

    final DateTime taskStart;
    final DateTime taskEnd;
    if (taskEndsAtAnchor) {
      taskEnd = effectiveAnchor;
      taskStart = effectiveAnchor.subtract(Duration(minutes: effectiveDuration));
    } else {
      taskStart = effectiveAnchor;
      taskEnd = effectiveAnchor.add(Duration(minutes: effectiveDuration));
    }

    final requiredRole = svcMap['requiredRole'] as String?;
    List<TeamMember> candidatesList;
    if (requiredRole == null ||
        requiredRole.trim().isEmpty ||
        requiredRole.toLowerCase() == 'any') {
      candidatesList = team.where((m) => assignableId(m).isNotEmpty).toList();
    } else {
      candidatesList = team.where((m) => _hasRole(m, requiredRole)).toList();
    }
    var available = candidatesList
        .where((m) =>
            !_isAbsentOnDate(m, taskDate, absences) && _isWithinContract(m, taskDate))
        .toList();
    available = _filterAndSortByZonePreferences(available, zoneId);

    final deadline = _computeTaskDeadlineForReservation(r, pack.reservationMaps);
    final applyNightRest = _shouldApplyNightRestByTaskType(effectiveTaskType);
    final isSacredTask = _isSacredTaskType(effectiveTaskType);

    final result = pickAssigneeWithCollisionAvoidance(
      candidates: available,
      taskStart: taskStart,
      taskEnd: taskEnd,
      deadline: deadline,
      applyNightRest: applyNightRest,
      existingTasksRaw: pack.tasksList,
      toInsert: toInsert,
      zoneId: zoneId,
      isSacredTask: isSacredTask,
    );

    final guestName = cMap['guest_name'] as String;
    final serviceName = svcMap['serviceName'] as String;
    final title = '$serviceName: $guestName';

    final checkInTotal = (cMap['checkInTotal'] as num?)?.toDouble() ?? 0.0;
    final checkInBreakdown = _decodeStringNumMap(cMap['checkInBreakdown']);
    final checkOutTotal = (cMap['checkOutTotal'] as num?)?.toDouble() ?? 0.0;
    final checkOutBreakdown = _decodeStringNumMap(cMap['checkOutBreakdown']);

    final apartmentServiceId = svcMap['apartmentServiceId'] as String;
    final fallback = pack.apartmentFallback[apartmentServiceId];
    double finalPrice = (fallback?['price'] as num?)?.toDouble() ?? 0.0;
    String finalPayer = fallback?['payer'] as String? ?? 'owner';
    bool finalPhoto = fallback?['photo'] as bool? ?? false;
    String? finalNote;
    String? finalFlight;

    final rsRaw = cMap['reservation_service'];
    if (rsRaw is Map) {
      final rs = ReservationServiceRow.fromJson(Map<String, dynamic>.from(rsRaw));
      if (rs.chargedPrice != null) finalPrice = rs.chargedPrice!.toDouble();
      if (rs.payerType != null) finalPayer = rs.payerType!;
      if (rs.requiresPhoto != null) finalPhoto = rs.requiresPhoto!;

      final flightAndNote = parseFlightFromCustomNote(rs.customNote);
      finalFlight = rs.flightNumber ?? flightAndNote.$1;
      finalNote = (rs.flightNumber != null && rs.flightNumber!.isNotEmpty)
          ? rs.customNote
          : flightAndNote.$2;
    }

    final payerGuest = finalPayer == 'guest';
    final metadata = <String, dynamic>{};

    metadata['requires_photo'] = finalPhoto;
    if (finalNote != null && finalNote.isNotEmpty) metadata['custom_note'] = finalNote;
    if (finalFlight != null && finalFlight.isNotEmpty) {
      metadata['flight_number'] = finalFlight;
    }

    if (serviceTypeNorm == 'transfer_in' ||
        serviceTypeNorm == 'transfer_out' ||
        serviceTypeNorm == 'transfer') {
      if (payerGuest && finalPrice > 0) {
        metadata['amount_to_collect'] = finalPrice;
        metadata['payer_type'] = 'guest';
      } else {
        if (finalPrice > 0) metadata['service_price'] = finalPrice;
        metadata['payer_type'] = finalPayer;
      }
    } else if (serviceTypeNorm == 'check_in') {
      if (checkInTotal > 0) {
        metadata['amount_to_collect'] = checkInTotal;
        metadata['collection_breakdown'] =
            Map<String, dynamic>.from(checkInBreakdown.map((k, v) => MapEntry(k, v)));
        metadata['payer_type'] = 'guest';
      } else {
        metadata['payer_type'] = finalPayer;
      }
    } else if (serviceTypeNorm == 'check_out') {
      if (checkOutTotal > 0) {
        metadata['expected_audit_total'] = checkOutTotal;
        metadata['payer_type'] = 'guest';
      } else {
        metadata['payer_type'] = finalPayer;
      }
      if (checkOutBreakdown.isNotEmpty) {
        metadata['collection_breakdown'] =
            Map<String, dynamic>.from(checkOutBreakdown.map((k, v) => MapEntry(k, v)));
      }
    } else {
      if (payerGuest && finalPrice > 0) {
        metadata['amount_to_collect'] = finalPrice;
        metadata['payer_type'] = 'guest';
      } else {
        if (finalPrice > 0) metadata['service_price'] = finalPrice;
        metadata['payer_type'] = finalPayer;
      }
    }

    _applyTransitFromReservationService(metadata, rsRaw);
    _ensureGuestPayerWhenTransitWithoutAgencyCash(metadata);

    toInsert.add({
      'tenant_id': pack.tenantId,
      'apartment_id': apartmentId,
      'reservation_id': reservationId,
      'service_id': serviceId,
      'assigned_to': result.assignTo,
      'reference_number': generateTaskRef(),
      'title': title,
      'description': '',
      'status': 'pending',
      'task_type': effectiveTaskType,
      'scheduled_start': result.start.toIso8601String(),
      'due_date': result.end.toIso8601String(),
      'metadata': metadata,
    });
    checklistTemplateIdsForBatch.add(svcMap['checklistTemplateId'] as String?);
    effectiveDurations.add(effectiveDuration);
  }

  return SmartGenPhaseCResult(
    toInsert: toInsert,
    checklistTemplateIds: checklistTemplateIdsForBatch,
    effectiveDurations: effectiveDurations,
  );
}

// --- Přepočet personálu (recalculateAssignees) --------------------------------

/// Stejné jako statické parsování UTC v admin_tasks_provider – řetězec bez Z = UTC wall-clock.
DateTime? _parseAsUtcNullable(dynamic raw) {
  if (raw == null) return null;
  final s = raw is String ? raw.trim() : raw.toString().trim();
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  if (d == null) return null;
  if (d.isUtc) return d;
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
  );
}

/// Stejné jako [_parseTaskDueSafe] v admin_tasks_provider.
DateTime _parseTaskDueSafeWorker(dynamic dueRaw, DateTime fallback) {
  if (dueRaw == null) return fallback;
  if (dueRaw is DateTime) return dueRaw;
  final s = dueRaw.toString().trim();
  if (s.isEmpty) return fallback;
  try {
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
  } catch (e, st) {
    AppLogger.error('admin_tasks_isolate_workers: _parseTaskDueSafeWorker (ISO krok) selhal', e, st);
  }
  try {
    return DateFormat('dd.MM.yyyy').parse(s);
  } catch (e, st) {
    AppLogger.error('admin_tasks_isolate_workers: _parseTaskDueSafeWorker (dd.MM.yyyy) selhal', e, st);
  }
  try {
    return DateFormat('yyyy-MM-dd').parse(s);
  } catch (e, st) {
    AppLogger.error('admin_tasks_isolate_workers: _parseTaskDueSafeWorker (yyyy-MM-dd) selhal', e, st);
  }
  return fallback;
}

bool _isDifferentMinuteUtc(DateTime a, DateTime b) {
  final au = a.toUtc();
  final bu = b.toUtc();
  return au.year != bu.year ||
      au.month != bu.month ||
      au.day != bu.day ||
      au.hour != bu.hour ||
      au.minute != bu.minute;
}

/// Vstup pro přepočet personálu (max 50 úkolů v pack.taskMaps).
class RecalculateAssigneesPack {
  RecalculateAssigneesPack({
    required this.teamMaps,
    required this.taskMaps,
    required this.absenceMaps,
    required this.reservationMaps,
    required this.apartmentByIdMaps,
    required this.catalogServiceMaps,
    required this.tomorrowStartIso,
  });
  final List<Map<String, dynamic>> teamMaps;
  final List<Map<String, dynamic>> taskMaps;
  final List<Map<String, dynamic>> absenceMaps;
  final List<Map<String, dynamic>> reservationMaps;
  final Map<String, Map<String, dynamic>> apartmentByIdMaps;
  /// id -> { required_role, service_type }
  final List<Map<String, dynamic>> catalogServiceMaps;
  /// Shodné s [AdminTasksNotifier.recalculateAssignees] – fallback pro parsování due_date.
  final String tomorrowStartIso;
}

/// Vrací mapy polí pro [TaskRecalculationProposal] (datumy jako ISO UTC).
List<Map<String, dynamic>> runRecalculateAssigneesSync(RecalculateAssigneesPack pack) {
  final team = pack.teamMaps.map(_teamMemberFromMap).toList();
  final absences =
      pack.absenceMaps.map((m) => StaffAbsence.fromJson(m)).toList();
  final apartmentById = pack.apartmentByIdMaps;
  final catalogById = <String, Map<String, dynamic>>{
    for (final s in pack.catalogServiceMaps)
      if ((s['id'] as String?)?.isNotEmpty == true) s['id'] as String: s,
  };

  final proposals = <Map<String, dynamic>>[];
  final list = pack.taskMaps;

  for (final raw in list) {
    final map = Map<String, dynamic>.from(raw);
    final taskId = map['id']?.toString();
    if (taskId == null || taskId.isEmpty) continue;

    final taskTitle = (map['title'] as String?)?.trim() ?? '';
    final apartmentId = map['apartment_id']?.toString().trim();
    final apartment = apartmentId != null && apartmentId.isNotEmpty
        ? apartmentById[apartmentId]
        : null;
    final zoneId = apartment?['zoneId'] as String?;

    final dueRaw = map['due_date'] ?? map['scheduled_start'];
    final tomorrowStart = DateTime.parse(pack.tomorrowStartIso);
    final taskDue = _parseTaskDueSafeWorker(dueRaw, tomorrowStart);

    final taskTypeRaw = (map['task_type'] as String?)?.trim() ?? '';
    final taskType = taskTypeRaw.toLowerCase();
    final currentAssigned = map['assigned_to']?.toString().trim();

    final oldStartRaw = map['scheduled_start'];
    final oldEndRaw = map['due_date'];
    final oldStart =
        _parseAsUtcNullable(oldStartRaw) ?? parseTaskDateTime(oldStartRaw) ?? taskDue;
    final oldEnd =
        _parseAsUtcNullable(oldEndRaw) ?? parseTaskDateTime(oldEndRaw) ?? taskDue;

    DateTime deadline;
    final reservationId = map['reservation_id']?.toString().trim();
    if (reservationId != null && reservationId.isNotEmpty) {
      final resMatch =
          pack.reservationMaps.where((r) => r['id'] == reservationId).toList();
      if (resMatch.isNotEmpty) {
        deadline = _computeTaskDeadlineForReservation(resMatch.first, pack.reservationMaps);
      } else {
        deadline = taskDue.add(const Duration(days: 3));
      }
    } else {
      deadline = taskDue.add(const Duration(days: 3));
    }

    final applyNightRest = _shouldApplyNightRestByTaskType(taskTypeRaw);

    String? requiredRole;
    final serviceId = map['service_id']?.toString().trim();
    if (serviceId != null && serviceId.isNotEmpty) {
      requiredRole = catalogById[serviceId]?['required_role'] as String?;
    }
    if (requiredRole == null || requiredRole.trim().isEmpty) {
      for (final s in pack.catalogServiceMaps) {
        if ((s['service_type'] as String?)?.trim().toLowerCase() == taskType) {
          requiredRole = s['required_role'] as String?;
          break;
        }
      }
    }
    final roleNullOrAny = requiredRole == null ||
        requiredRole.trim().isEmpty ||
        requiredRole.trim().toLowerCase() == 'any';

    var candidates = roleNullOrAny
        ? team.where((m) => assignableId(m).isNotEmpty).toList()
        : team.where((m) => _hasRole(m, requiredRole!)).toList();
    candidates = candidates
        .where((m) =>
            !_isAbsentOnDate(m, taskDue, absences) && _isWithinContract(m, taskDue))
        .toList();
    candidates = _filterAndSortByZonePreferences(candidates, zoneId);

    final others = list
        .where((x) => (x['id']?.toString() ?? '') != taskId)
        .toList();

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
    final timeChanged =
        _isDifferentMinuteUtc(newStart, oldStart) || _isDifferentMinuteUtc(newEnd, oldEnd);
    if (!assigneeChanged && !timeChanged) continue;

    final nameByProfileId = <String, String>{
      for (final m in team)
        if (assignableId(m).isNotEmpty) assignableId(m): m.name,
    };

    proposals.add({
      'taskId': taskId,
      'taskTitle': taskTitle,
      'oldAssigneeId': currentAssigned,
      'oldAssigneeName':
          currentAssigned != null ? nameByProfileId[currentAssigned] : null,
      'newAssigneeId': newAssignTo,
      'newAssigneeName': newAssignTo != null ? nameByProfileId[newAssignTo] : null,
      'oldStart': oldStart.toIso8601String(),
      'oldEnd': oldEnd.toIso8601String(),
      'newStart': newStart.toIso8601String(),
      'newEnd': newEnd.toIso8601String(),
      'timeChanged': timeChanged,
    });
  }

  return proposals;
}
