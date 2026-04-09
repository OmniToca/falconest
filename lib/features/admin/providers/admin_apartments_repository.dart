import 'package:easy_localization/easy_localization.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';

/// Repozitář pro administrativní operace nad apartmány (Admin modul).
///
/// PROČ: Obrazovka [AdminApartmentsScreen] nesmí obsahovat přímé Supabase transakce –
/// veškerá DB logika (včetně soft-delete kaskády a auditu) patří do repozitáře (Clean Architecture).
/// Třída je statická stejně jako [AutomationRulesRepository] – jednoduché volání z UI bez DI.
class AdminApartmentsRepository {
  AdminApartmentsRepository._();

  /// Vrací true, pokud na byt existují aktivní budoucí rezervace (end_date ≥ dnes, status ≠ cancelled).
  ///
  /// PROČ: Mazání bytu je blokováno, aby nedošlo ke ztrátě budoucích pobytů.
  static Future<bool> hasActiveFutureReservations({
    required String? tenantId,
    required String apartmentId,
  }) async {
    if (tenantId == null || tenantId.isEmpty || apartmentId.isEmpty) return false;
    final today = DateTime.now();
    final todayIso =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await SupabaseService.safeFrom('reservations', tenantId)
        .select('id')
        .eq('apartment_id', apartmentId)
        .isFilter('deleted_at', null)
        .neq('status', 'cancelled')
        .gte('end_date', todayIso)
        .limit(1);
    final list = res is List ? res : <dynamic>[];
    return list.isNotEmpty;
  }

  /// Soft-delete bytu a kaskádně rezervací + úkolů přiřazených k bytu.
  ///
  /// PROČ: Jedna transakční jednotka – stejná logika jako dříve v UI, ale bez Supabase v widgetu.
  /// [cascadeReason] se předává přeložený řetězec z UI (i18n).
  static Future<void> softDeleteApartmentsCascade({
    required String? tenantId,
    required String? userId,
    required List<ApartmentRow> apartments,
    required String cascadeReason,
  }) async {
    final deletedAt = DateTime.now().toUtc().toIso8601String();

    for (final apartment in apartments) {
      final id = apartment.id;
      final previousState = Map<String, dynamic>.from(apartment.toMap())
        ..['id'] = apartment.id
        ..['tenant_id'] = apartment.tenantId;

      await SupabaseService.safeFrom('apartments', tenantId)
          .update({'deleted_at': deletedAt})
          .eq('id', id);
      await AuditLogService.logEnterprise(
        tenantId: tenantId,
        userId: userId,
        actionType: 'SOFT_DELETE',
        tableName: 'apartments',
        recordId: id,
        recordName: apartment.name,
        previousState: previousState,
        triggeredBy: AuditTriggeredBy.manual,
      );

      if (tenantId == null || tenantId.isEmpty) continue;

      try {
        final resRows = await SupabaseService.safeFrom('reservations', tenantId)
            .select('id, guest_name, start_date')
            .eq('apartment_id', id)
            .isFilter('deleted_at', null);
        final resList = resRows as List;

        for (final r in resList) {
          final map = Map<String, dynamic>.from(r as Map);
          final resId = map['id']?.toString().trim();
          if (resId == null || resId.isEmpty) continue;
          final guestName = (map['guest_name'] as String?)?.trim();
          final recordName = (guestName != null && guestName.isNotEmpty)
              ? guestName
              : 'super_admin.audit_log_reservation_fallback'.tr(
                  namedArgs: {'id': resId.length >= 8 ? resId.substring(0, 8) : resId},
                );

          await SupabaseService.safeFrom('reservations', tenantId)
              .update({'deleted_at': deletedAt})
              .eq('id', resId);
          await AuditLogService.logEnterprise(
            tenantId: tenantId,
            userId: userId,
            actionType: 'SOFT_DELETE_CASCADE',
            tableName: 'reservations',
            recordId: resId,
            recordName: recordName,
            triggeredBy: AuditTriggeredBy.cascade,
            reason: cascadeReason,
            extra: {'triggered_by': 'apartment', 'apartment_id': id},
          );
        }

        final taskRows = await SupabaseService.safeFrom('tasks', tenantId)
            .select('id, title')
            .eq('apartment_id', id)
            .isFilter('deleted_at', null);
        final taskList = taskRows as List;

        for (final t in taskList) {
          final map = Map<String, dynamic>.from(t as Map);
          final taskId = map['id']?.toString().trim();
          if (taskId == null || taskId.isEmpty) continue;
          final title = (map['title'] as String?)?.trim();
          final recordName = (title != null && title.isNotEmpty)
              ? title
              : '${taskId.length >= 8 ? taskId.substring(0, 8) : taskId}…';

          await SupabaseService.safeFrom('tasks', tenantId)
              .update({'deleted_at': deletedAt})
              .eq('id', taskId);
          await AuditLogService.logEnterprise(
            tenantId: tenantId,
            userId: userId,
            actionType: 'SOFT_DELETE_CASCADE',
            tableName: 'tasks',
            recordId: taskId,
            recordName: recordName,
            triggeredBy: AuditTriggeredBy.cascade,
            reason: cascadeReason,
            extra: {'triggered_by': 'apartment', 'apartment_id': id},
          );
        }
      } catch (e, st) {
        AppLogger.error('AdminApartmentsRepository: kaskádové soft-delete úkolu při mazání bytu selhalo', e, st);
      }
    }
  }
}
