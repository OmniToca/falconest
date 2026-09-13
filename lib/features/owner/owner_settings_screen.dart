import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';
import 'package:falconest/core/models/notification_preferences_model.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';
import 'package:falconest/features/settings/providers/notification_preferences_provider.dart';

/// Nastavení Klientského portálu (majitel) – především upozornění z terénu.
///
/// PROČ: Majitel si zvolí kanály (e-mail, zvoneček v aplikaci, push) pro události
/// u svých bytů; hodnoty se ukládají do [notification_preferences] přes sdílený
/// [notificationPreferencesProvider] (stejný jako v admin Nastavení).
class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  bool _saveInProgress = false;

  Future<void> _persist(BuildContext context, NotificationPreferencesModel next) async {
    setState(() => _saveInProgress = true);
    final ok = await ref.read(notificationPreferencesProvider.notifier).save(next);
    if (mounted) setState(() => _saveInProgress = false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.settings_notifications_save_error'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final readOnly = ref.watch(isOwnerViewReadOnlyProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('owner.settings_title'.tr()),
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.colors.surfaceContainerLowest,
      ),
      body: Stack(
        children: [
          prefsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(notificationPreferencesProvider),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            ),
            data: (model) {
              if (model == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'owner.settings_notifications_unavailable'.tr(),
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: ownerPortalConstrainBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'owner.settings_subtitle'.tr(),
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (readOnly) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.visibility_outlined, color: cs.primary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'admin.owner_view_read_only_hint'.tr(),
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _FieldAlertsCard(
                        model: model,
                        busy: _saveInProgress || readOnly,
                        onChanged: readOnly ? (_) {} : (next) => _persist(context, next),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_saveInProgress)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sekce „Upozornění z terénu“ – 3 události × 3 přepínače.
class _FieldAlertsCard extends StatelessWidget {
  const _FieldAlertsCard({
    required this.model,
    required this.busy,
    required this.onChanged,
  });

  final NotificationPreferencesModel model;
  final bool busy;
  final void Function(NotificationPreferencesModel next) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: cs.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'owner.settings_field_alerts_title'.tr(),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'owner.settings_field_alerts_hint'.tr(),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _OwnerEventSwitches(
                title: 'owner.settings_event_task_started'.tr(),
                subtitle: 'owner.settings_event_task_started_sub'.tr(),
                channels: model.ownerTaskStarted,
                busy: busy,
                onToggleEmail: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerTaskStarted, NotificationDeliveryChannel.email, v),
                ),
                onToggleWeb: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerTaskStarted, NotificationDeliveryChannel.web, v),
                ),
                onTogglePush: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerTaskStarted, NotificationDeliveryChannel.push, v),
                ),
              ),
              Divider(height: 32, color: cs.outlineVariant.withValues(alpha: 0.4)),
              _OwnerEventSwitches(
                title: 'owner.settings_event_task_completed'.tr(),
                subtitle: 'owner.settings_event_task_completed_sub'.tr(),
                channels: model.ownerTaskCompleted,
                busy: busy,
                onToggleEmail: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerTaskCompleted, NotificationDeliveryChannel.email, v),
                ),
                onToggleWeb: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerTaskCompleted, NotificationDeliveryChannel.web, v),
                ),
                onTogglePush: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerTaskCompleted, NotificationDeliveryChannel.push, v),
                ),
              ),
              Divider(height: 32, color: cs.outlineVariant.withValues(alpha: 0.4)),
              _OwnerEventSwitches(
                title: 'owner.settings_event_cash_collected'.tr(),
                subtitle: 'owner.settings_event_cash_collected_sub'.tr(),
                channels: model.ownerCashCollected,
                busy: busy,
                onToggleEmail: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerCashCollected, NotificationDeliveryChannel.email, v),
                ),
                onToggleWeb: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerCashCollected, NotificationDeliveryChannel.web, v),
                ),
                onTogglePush: (v) => onChanged(
                  model.setChannel(NotificationEventKind.ownerCashCollected, NotificationDeliveryChannel.push, v),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

/// Tři přepínače v pořadí: E-mail, Zvoneček, Push.
class _OwnerEventSwitches extends StatelessWidget {
  const _OwnerEventSwitches({
    required this.title,
    required this.subtitle,
    required this.channels,
    required this.busy,
    required this.onToggleEmail,
    required this.onToggleWeb,
    required this.onTogglePush,
  });

  final String title;
  final String subtitle;
  final NotificationChannels channels;
  final bool busy;
  final ValueChanged<bool> onToggleEmail;
  final ValueChanged<bool> onToggleWeb;
  final ValueChanged<bool> onTogglePush;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget row(String labelKey, bool value, ValueChanged<bool> onChanged) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            labelKey.tr(),
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          value: value,
          onChanged: busy ? null : onChanged,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        row('owner.settings_channel_email', channels.email, onToggleEmail),
        row('owner.settings_channel_web', channels.web, onToggleWeb),
        row('owner.settings_channel_push', channels.push, onTogglePush),
      ],
    );
  }
}
