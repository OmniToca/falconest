import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/super_admin/services/audit_log_shared.dart';
import 'package:falconest/features/communication/models/message_template_selector_context.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';

/// Data šablony pro odeslání WhatsApp – společná pro Admin (MessageTemplateRow) i Worker (MessageTemplateLocal).
class WhatsAppTemplateData {
  const WhatsAppTemplateData({
    required this.name,
    required this.body,
    this.triggerContext,
    this.templateId,
  });

  final String name;
  final String body;
  final String? triggerContext;
  /// UUID šablony (Supabase tenant_message_templates.id). Null u Worker lokálních šablon.
  final String? templateId;
}

/// Služba pro odeslání WhatsApp zprávy (placeholdery, audit log, denormalizace last_communication_*, launchUrl).
///
/// PROČ: Jedna sdílená logika pro mobilní Bottom Sheet (Worker) i pro Web Admin inline seznamy v dialozích.
/// Volající zajišťuje UI (např. zavření sheetu po úspěchu).
class WhatsAppSenderService {
  WhatsAppSenderService._();

  /// Odešle zprávu: validace telefonu, nahrazení placeholderů, audit log, fire-and-forget update DB, otevření wa.me.
  /// Vrací true pokud byl odkaz otevřen (nebo pokus proběhl), false pokud chybí telefon (zobrazí SnackBar).
  static Future<bool> send(
    BuildContext context,
    WidgetRef ref,
    MessageTemplateSelectorContext templateContext,
    WhatsAppTemplateData template,
  ) async {
    // PROČ: Safari/iOS pop-up blocker vyžaduje otevření URL přímo v kontextu uživatelského kliku.
    // Proto před launchUrl nečekáme na žádné síťové operace (audit/DB update).
    final phone = templateContext.guestPhone?.trim();
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('communication.template_selector_missing_phone'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final contextMap = templateContext.placeholders;
    final parsedText = TemplatePlaceholderService.replacePlaceholders(template.body, contextMap);
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('communication.template_selector_missing_phone'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final encodedText = Uri.encodeComponent(parsedText);
    final url = Uri.parse('https://wa.me/$cleanedPhone?text=$encodedText');

    bool launched = false;
    try {
      launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Záměrně tiché: WhatsApp nemusí být dostupný; uživatel může text opsat.
    }
    if (!launched) return false;

    final source = _auditSourceFromContext(templateContext);
    final messagePreview = parsedText.length > 200 ? '${parsedText.substring(0, 200)}…' : parsedText;
    final details = <String, dynamic>{
      'record_name': 'WhatsApp → $phone',
      'guest_phone': phone,
      'template_name': template.name,
      'message_preview': messagePreview,
      'source': source,
    };
    unawaited(_logAudit(ref, details));

    final reservationId = templateContext.reservationId;
    final taskId = templateContext.taskId;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    unawaited(
      _updateLastCommunication(
        tenantId: tenantId,
        reservationId: reservationId,
        taskId: taskId,
        triggerContext: template.triggerContext,
        templateId: template.templateId,
      ),
    );

    return true;
  }

  static String _auditSourceFromContext(MessageTemplateSelectorContext ctx) {
    if (ctx is WorkerTaskTemplateContext) return 'worker_task';
    if (ctx is ReservationTemplateContext) return 'reservation';
    if (ctx is AdminTaskTemplateContext) return 'admin_task';
    return 'unknown';
  }

  /// Fire-and-forget audit zápis po úspěšném otevření WhatsApp odkazu.
  static Future<void> _logAudit(
    WidgetRef ref,
    Map<String, dynamic> details,
  ) async {
    try {
      final auth = ref.read(authNotifierProvider);
      await AuditLogService.log(
        tenantId: auth.tenantIdForData,
        userId: SupabaseService.client.auth.currentUser?.id,
        actionType: AuditActionType.whatsappLinkOpened,
        tableName: null,
        recordId: null,
        details: details,
      );
    } catch (e) {
      debugPrint('Audit log failed: $e');
    }
  }

  /// Fire-and-forget: zápis last_communication_* do reservations a tasks (s template_id).
  ///
  /// PROČ [safeFrom]: při známém [tenantId] vynutíme rozsah (Super Admin v kontextu agentury).
  /// Bez tenanta zůstává holý klient (edge přihlášení / worker bez tenantIdForData v mapě).
  static Future<void> _updateLastCommunication({
    String? tenantId,
    String? reservationId,
    String? taskId,
    String? triggerContext,
    String? templateId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final ctxVal = triggerContext?.trim().isEmpty == true ? null : triggerContext?.trim();
    final tid = tenantId?.trim();
    final scoped = tid != null && tid.isNotEmpty;

    if (reservationId != null && reservationId.isNotEmpty) {
      try {
        final patch = {
          'last_communication_template_id': templateId,
          'last_communication_template_context': ctxVal,
          'last_communication_at': now,
        };
        if (scoped) {
          await SupabaseService.safeFrom('reservations', tid).update(patch).eq('id', reservationId);
        }
        // Bez tenantId nelze bezpečně vynutit safeFrom – zápis přeskočíme (edge přihlášení bez kontextu agentury).
      } catch (e) {
        debugPrint('Reservation last_communication update failed: $e');
      }
    }

    if (taskId != null && taskId.isNotEmpty) {
      try {
        final patch = {
          'last_communication_template_id': templateId,
          'last_communication_template_context': ctxVal,
          'last_communication_at': now,
        };
        if (scoped) {
          await SupabaseService.safeFrom('tasks', tid).update(patch).eq('id', taskId);
        }
      } catch (e) {
        debugPrint('Task last_communication update failed: $e');
      }
    }
  }
}
