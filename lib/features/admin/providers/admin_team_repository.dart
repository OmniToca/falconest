import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';

/// Repozitář mutací personálu (tabulka `profiles` + navazující záznamy).
///
/// PROČ samostatná vrstva: obrazovka nemá obsahovat SQL ani orchestraci audit logu
/// a odpojení úkolů. Veškeré zápisy do `profiles` pro danou agenturu musí projít
/// [SupabaseService.safeFrom('profiles', tenantId)], aby se při impersonaci Super Admina
/// vynutil filtr `tenant_id` i tam, kde by čistý [SupabaseService.client] mohl omylem
/// adresovat řádky mimo zobrazený tenant (viz dokumentace u [SupabaseService.safeFrom]).
///
/// POZNÁMKA k tabulce `user_roles`: v modulu Personál se používají sloupce `profiles.role`
/// a `profiles.roles`; tabulka `user_roles` zde není dotčena. Nemá sloupec `tenant_id`,
/// takže [safeFrom] by na ni nešlo mechanicky aplikovat bez rozšíření schématu.
class AdminTeamRepository {
  AdminTeamRepository._();

  /// Odpojí personál od nedokončených úkolů (nebo v zadaném rozsahu datumů).
  ///
  /// Stejná logika jako dříve v `admin_team_screen.dart` – přesunuto kvůli znovupoužití.
  /// Dotazy na `tasks` používají [SupabaseService.safeFrom] s [tenantId].
  static Future<void> unassignOpenTasksForMember(
    Ref ref,
    String tenantId,
    String memberId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? memberName,
  }) async {
    if (memberId.isEmpty) return;
    if (tenantId.isEmpty) return;
    try {
      final tasksRes = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id, due_date, status, assigned_to, assigned_user_ids')
          .or('assigned_to.eq.$memberId,assigned_user_ids.cs.{$memberId}')
          .isFilter('deleted_at', null);
      final taskList = tasksRes as List<dynamic>? ?? [];
      for (final t in taskList) {
        final map = t is Map ? Map<String, dynamic>.from(t) : null;
        if (map == null) continue;
        final status = (map['status'] as String?)?.trim() ?? '';
        final isCompleted =
            status.toLowerCase().contains('hotovo') || status == 'completed';
        final isInProgress =
            status.toLowerCase().contains('probíhá') || status == 'in_progress';
        if (isCompleted || isInProgress) continue;
        if (fromDate != null || toDate != null) {
          final dueRaw = map['due_date'];
          DateTime? due;
          if (dueRaw is DateTime) {
            due = dueRaw;
          } else if (dueRaw != null) {
            due = DateTime.tryParse(dueRaw.toString());
          }
          if (due == null) continue;
          final dueDay = DateTime(due.year, due.month, due.day);
          if (fromDate != null) {
            final fromDay = DateTime(fromDate.year, fromDate.month, fromDate.day);
            if (dueDay.isBefore(fromDay)) continue;
          }
          if (toDate != null) {
            final toDay = DateTime(toDate.year, toDate.month, toDate.day);
            if (dueDay.isAfter(toDay)) continue;
          }
        }
        final taskId = map['id']?.toString();
        if (taskId == null || taskId.isEmpty) continue;

        final currentAssignedTo = map['assigned_to']?.toString().trim();
        final newAssignedTo = (currentAssignedTo == memberId) ? null : currentAssignedTo;

        final rawIds = map['assigned_user_ids'];
        List<String> currentIds = [];
        if (rawIds != null && rawIds is List) {
          currentIds = rawIds
              .map((e) => e?.toString().trim())
              .where((s) => s != null && s.isNotEmpty)
              .cast<String>()
              .toList();
        }
        final newIds = currentIds.where((id) => id != memberId).toList();

        final payload = <String, dynamic>{
          'assigned_to': newAssignedTo,
          'assigned_user_ids': newIds,
          'status': 'pending',
        };
        if (newAssignedTo == null) {
          payload['unassigned_info'] = jsonEncode({
            'previous_id': memberId,
            'previous_name': memberName ?? '',
            'unassigned_at': DateTime.now().toUtc().toIso8601String(),
          });
        }

        await SupabaseService.safeFrom('tasks', tenantId)
            .update(payload)
            .eq('id', taskId);
      }
      ref.invalidate(adminTasksProvider);
      ref.invalidate(planningCalendarAllTasksProvider);
      ref.invalidate(planningCalendarAllTasksForMonthProvider);
    } catch (e, st) {
      debugPrint('Chyba při unassignOpenTasksForMember: $e\n$st');
    }
  }

  /// Soft-delete člena: čekající pozvánka = `deleted_at` na profilu + zneplatnění invitation;
  /// aktivní člen = `tenant_id` null + `deleted_at`. Vždy [safeFrom] na `profiles`.
  static Future<void> softDeleteTeamMember({
    required Ref ref,
    required String tenantId,
    required bool isFromInvitation,
    required String profileId,
    required String memberName,
    required Map<String, dynamic> previousStateForAudit,
  }) async {
    if (tenantId.isEmpty || profileId.isEmpty) return;
    final deletedAt = DateTime.now().toUtc().toIso8601String();

    if (isFromInvitation) {
      await SupabaseService.safeFrom('profiles', tenantId)
          .update({'deleted_at': deletedAt})
          .eq('id', profileId);
      try {
        await SupabaseService.safeFrom('invitations', tenantId)
            .update({'deleted_at': deletedAt})
            .eq('profile_id', profileId);
      } catch (_) {
        await SupabaseService.safeFrom('invitations', tenantId)
            .delete()
            .eq('profile_id', profileId);
      }
    } else {
      await SupabaseService.safeFrom('profiles', tenantId)
          .update({'tenant_id': null, 'deleted_at': deletedAt})
          .eq('id', profileId);
    }

    final userId = SupabaseService.client.auth.currentUser?.id;
    await AuditLogService.logEnterprise(
      tenantId: tenantId,
      userId: userId,
      actionType: 'SOFT_DELETE',
      tableName: 'profiles',
      recordId: profileId,
      recordName: memberName,
      previousState: previousStateForAudit,
      triggeredBy: AuditTriggeredBy.manual,
    );

    await unassignOpenTasksForMember(ref, tenantId, profileId, memberName: memberName);
  }

  /// Aktualizace profilu člena (společné pro pending i aktivní) – pouze [safeFrom].
  static Future<void> updateTeamMemberProfile({
    required String tenantId,
    required String profileId,
    required Map<String, dynamic> profileUpdate,
  }) async {
    if (tenantId.isEmpty || profileId.isEmpty) return;
    await SupabaseService.safeFrom('profiles', tenantId)
        .update(profileUpdate)
        .eq('id', profileId);
  }

  /// Vloží nový profil (pending), pozvánku a volitelně propojí majitele k bytům.
  ///
  /// Vrací UUID nového profilu. [profilePayload] a [invitationPayload] připraví UI
  /// (včetně překladů); repozitář je jen předává do [safeFrom].
  static Future<String> inviteStaffMember({
    required String tenantId,
    required Map<String, dynamic> profilePayload,
    required Map<String, dynamic> invitationPayload,
    required List<String> propertyOwnerApartmentIds,
  }) async {
    if (tenantId.isEmpty) {
      throw StateError('tenantId je prázdný');
    }

    final profileRes = await SupabaseService.safeFrom('profiles', tenantId)
        .insert(profilePayload)
        .select('id')
        .single();
    final profileId = (profileRes as Map)['id']?.toString();
    if (profileId == null || profileId.isEmpty) {
      throw PostgrestException(
        message: 'Profil nebyl vytvořen',
        code: '500',
        details: 'internal',
      );
    }

    final invPayload = Map<String, dynamic>.from(invitationPayload);
    invPayload['profile_id'] = profileId;

    await SupabaseService.safeFrom('invitations', tenantId).insert(invPayload);

    for (final aptId in propertyOwnerApartmentIds) {
      if (aptId.trim().isEmpty) continue;
      await ApartmentOwnersRepository.addOwner(
        apartmentId: aptId,
        ownerId: profileId,
        tenantId: tenantId,
      );
    }

    return profileId;
  }
}
