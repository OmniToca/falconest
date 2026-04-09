import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/models/message_template_local.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';
import 'package:falconest/features/communication/models/message_template_selector_context.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/features/communication/providers/message_templates_provider.dart';
import 'package:falconest/features/communication/services/whatsapp_sender_service.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Spodní sheet pro výběr šablony zprávy (Smart Template Selector).
///
/// PROČ: Klient nechce plnou automatizaci – uživatel vybere šablonu, otevře se WhatsApp
/// s předvyplněným textem a číslem, a uživatel zprávu ručně odešle.
class MessageTemplateSelectorBottomSheet extends ConsumerWidget {
  const MessageTemplateSelectorBottomSheet({
    super.key,
    required this.templateContext,
  });

  final MessageTemplateSelectorContext templateContext;

  /// Helper pro snadné volání odkudkoliv (Admin i Worker).
  /// Pozn.: [ref] je tu záměrně v signatuře pro konzistentní API volání z existujících obrazovek.
  static void show(
    BuildContext context,
    WidgetRef ref,
    MessageTemplateSelectorContext templateContext,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MessageTemplateSelectorBottomSheet(templateContext: templateContext),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(authNotifierProvider.select((s) => s.tenantIdForData)) ?? '';

    // Šablony pro Admin (Supabase) a Worker (Drift). Na webu Worker provider vrací prázdný list.
    final adminAsync = ref.watch(messageTemplatesAdminProvider);
    final workerAsync = tenantId.isEmpty
        ? const AsyncValue<List<MessageTemplateLocal>>.data([])
        : ref.watch(messageTemplatesForWorkerProvider(tenantId));

    // Kategorie pro hezké ikony/barvy u trigger_context.
    final categoriesByCode = ref.watch(taskCategoriesProvider).valueOrNull ?? <String, TaskCategoryModel>{};

    final guestLang = templateContext.preferredGuestLanguageCode;
    final templates = _mergeTemplates(adminAsync, workerAsync, guestLang);
    final filtered = _filterTemplates(
      templates,
      templateContext.preferredContexts,
    ).where((t) => t.channel == 'whatsapp' && t.resolvedBody.trim().isNotEmpty).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'communication.template_selector_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (adminAsync.isLoading && workerAsync.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'communication.empty_list'.tr(),
                  style: TextStyle(color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final t = filtered[index];
                    final trig = t.triggerContext;
                    final isGeneral = trig == null || trig.trim().isEmpty;
                    final icon = isGeneral
                        ? Icons.chat_bubble_outline
                        : TaskVisuals.getIcon(trig, categoriesByCode: categoriesByCode);
                    final bg = isGeneral
                        ? Colors.grey.shade100
                        : TaskVisuals.getBackgroundColor(trig, categoriesByCode: categoriesByCode);
                    final fg = isGeneral
                        ? Colors.grey.shade700
                        : TaskVisuals.getBorderColor(trig, categoriesByCode: categoriesByCode);
                    final triggerLabel = isGeneral
                        ? 'communication.template_trigger_general'.tr()
                        : 'admin.task_type_${trig.trim()}'.tr();

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onTemplateTap(context, ref, t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: bg,
                                child: Icon(icon, size: 18, color: fg),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      triggerLabel,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Jeden společný pohled na šablonu pro UI, aby se nemíchal Admin/Worker model.
  static List<_TemplateVm> _mergeTemplates(
    AsyncValue<List<MessageTemplateRow>> adminAsync,
    AsyncValue<List<MessageTemplateLocal>> workerAsync,
    String guestLanguageCode,
  ) {
    final admin = adminAsync.valueOrNull ?? const <MessageTemplateRow>[];
    final worker = workerAsync.valueOrNull ?? const <MessageTemplateLocal>[];

    // Preferujeme Admin zdroj, pokud existuje (web/administrace); jinak použijeme Worker lokální (offline-first).
    if (admin.isNotEmpty) {
      return admin
          .map(
            (t) => _TemplateVm(
              name: t.name,
              channel: t.channel,
              resolvedBody: t.resolvedBodyForGuest(guestLanguageCode),
              triggerContext: t.triggerContext,
              templateId: t.id,
            ),
          )
          .toList();
    }
    return worker
        .map(
          (t) => _TemplateVm(
            name: t.name,
            channel: (t.channel ?? 'whatsapp').trim().toLowerCase(),
            resolvedBody: t.resolvedBodyForGuest(guestLanguageCode),
            triggerContext: t.triggerContext,
            templateId: t.supabaseId,
          ),
        )
        .toList();
  }

  static List<_TemplateVm> _filterTemplates(
    List<_TemplateVm> templates,
    List<String?> preferredContexts,
  ) {
    final preferred = preferredContexts
        .map((e) => e?.trim().toLowerCase())
        .toSet();
    final allowsGeneral = preferred.contains(null);

    bool match(_TemplateVm t) {
      final ctx = t.triggerContext?.trim().toLowerCase();
      if (ctx == null || ctx.isEmpty) return allowsGeneral;
      return preferred.contains(ctx);
    }

    final filtered = templates.where(match).toList();

    // Řazení: nejdřív přesná shoda s prvním preferovaným kontextem, pak obecné, pak zbytek.
    int rank(_TemplateVm t) {
      final ctx = t.triggerContext?.trim().toLowerCase();
      if (ctx == null || ctx.isEmpty) return 1;
      if (preferredContexts.isNotEmpty && ctx == preferredContexts.first?.trim().toLowerCase()) return 0;
      return 2;
    }

    filtered.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  Future<void> _onTemplateTap(BuildContext context, WidgetRef ref, _TemplateVm template) async {
    final ok = await WhatsAppSenderService.send(
      context,
      ref,
      templateContext,
      WhatsAppTemplateData(
        name: template.name,
        body: template.resolvedBody,
        triggerContext: template.triggerContext,
        templateId: template.templateId,
      ),
    );
    if (ok && context.mounted) Navigator.of(context).pop();
  }
}

class _TemplateVm {
  const _TemplateVm({
    required this.name,
    required this.channel,
    required this.resolvedBody,
    required this.triggerContext,
    this.templateId,
  });

  final String name;
  final String channel;
  final String resolvedBody;
  final String? triggerContext;
  final String? templateId;
}

