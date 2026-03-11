import 'package:easy_localization/easy_localization.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Sdílená služba pro odeslání notifikací adminům o nové žádosti o absenci (zvoneček).
///
/// Volá se z worker dialogu po přímém INSERTu i z [DriftMutationQueueService] po úspěšném
/// odeslání položky fronty pro tabulku staff_absences (offline → po syncu).
/// Zachovává i18n klíče admin.notification_absence_request_*.
class AbsenceNotificationService {
  AbsenceNotificationService._();

  /// Odešle notifikaci všem adminům/manažerům tenantu (zvoneček).
  /// [userName] – zobrazené jméno pracovníka, [formattedStart]/[formattedEnd] – např. dd.MM.yyyy.
  /// Při chybě tiše selže (stejně jako původní implementace v dialogu).
  static Future<void> notifyAdminsAboutAbsenceRequest({
    required String tenantId,
    required String userName,
    required String formattedStart,
    required String formattedEnd,
  }) async {
    try {
      final client = SupabaseService.client;
      final adminsRes = await client
          .from('profiles')
          .select('id')
          .eq('tenant_id', tenantId)
          .inFilter('role', ['admin', 'manager'])
          .isFilter('deleted_at', null);
      final admins = List<dynamic>.from(adminsRes as List);
      if (admins.isEmpty) return;
      final title =
          'admin.notification_absence_request_title'.tr(namedArgs: {'name': userName});
      final message =
          'admin.notification_absence_request_message'.tr(namedArgs: {
        'start': formattedStart,
        'end': formattedEnd,
      });
      final payloads = <Map<String, dynamic>>[];
      for (final a in admins) {
        final m = Map<String, dynamic>.from(a as Map);
        final adminId = (m['id'] as String?)?.trim();
        if (adminId == null || adminId.isEmpty) continue;
        payloads.add({
          'tenant_id': tenantId,
          'profile_id': adminId,
          'title': title,
          'message': message,
          'type': 'absence',
        });
      }
      if (payloads.isEmpty) return;
      await client.from('notifications').insert(payloads);
    } catch (_) {}
  }

  /// Vyčte z payloadu staff_absences (tenant_id, profile_id, start_date, end_date, status),
  /// dohodí jméno pracovníka z profiles a formátované datumy a zavolá [notifyAdminsAboutAbsenceRequest].
  /// Volá se z [DriftMutationQueueService] po úspěšném INSERTu – pouze pro status 'pending' (žádost z mobilu).
  static Future<void> notifyAdminsAboutAbsenceFromPayload(
    Map<String, dynamic> payload,
  ) async {
    final tenantId = (payload['tenant_id'] as String?)?.trim();
    if (tenantId == null || tenantId.isEmpty) return;
    // Pouze žádosti o schválení z workeru – ne absence zadané adminem (approved).
    final status = (payload['status'] as String?)?.trim();
    if (status != 'pending') return;

    final profileId = (payload['profile_id'] as String?)?.trim();
    String userName = 'worker.drawer_my_profile'.tr();
    if (profileId != null && profileId.isNotEmpty) {
      try {
        final res = await SupabaseService.client
            .from('profiles')
            .select('name, first_name, last_name')
            .eq('id', profileId)
            .maybeSingle();
        if (res != null) {
          final m = Map<String, dynamic>.from(res as Map);
          final name = (m['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            userName = name;
          } else {
            final first = (m['first_name'] as String?)?.trim() ?? '';
            final last = (m['last_name'] as String?)?.trim() ?? '';
            final combined = '$first $last'.trim();
            if (combined.isNotEmpty) userName = combined;
          }
        }
      } catch (_) {}
    }

    final startStr = (payload['start_date'] as String?)?.trim();
    final endStr = (payload['end_date'] as String?)?.trim();
    String formattedStart = '—';
    String formattedEnd = '—';
    if (startStr != null && startStr.isNotEmpty) {
      final startDt = DateTime.tryParse(startStr);
      if (startDt != null) {
        formattedStart = DateFormat('dd.MM.yyyy').format(startDt);
      }
    }
    if (endStr != null && endStr.isNotEmpty) {
      final endDt = DateTime.tryParse(endStr);
      if (endDt != null) {
        formattedEnd = DateFormat('dd.MM.yyyy').format(endDt);
      }
    }

    await notifyAdminsAboutAbsenceRequest(
      tenantId: tenantId,
      userName: userName,
      formattedStart: formattedStart,
      formattedEnd: formattedEnd,
    );
  }
}
