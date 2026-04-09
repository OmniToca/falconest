import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/checklist_templates_list_provider.dart';

/// Read-only náhled [apartment_services]: spouštěč a šablona checklistu u služby v dialogu rezervace.
///
/// PROČ: Dispečer vidí konkrétní hodnoty bez proklikávání do modulu apartmánu; data už máme
/// v [ApartmentServiceOption] z [apartmentServicesOptionsProvider], název checklistu z [checklistTemplatesListProvider].
class ReservationServiceRowWidget extends ConsumerWidget {
  const ReservationServiceRowWidget({
    super.key,
    required this.option,
  });

  final ApartmentServiceOption option;

  /// Mapuje DB hodnotu trigger_type na existující admin.* překlady.
  static String _localizedTriggerValue(String raw) {
    final t = raw.trim();
    switch (t) {
      case 'before_checkin':
        return 'admin.trigger_before_checkin'.tr();
      case 'after_checkout':
        return 'admin.trigger_after_checkout'.tr();
      case 'both_ways':
        return 'admin.trigger_both_ways'.tr();
      case 'on_demand':
        return 'admin.trigger_on_demand'.tr();
      case 'scheduled':
        return 'admin.trigger_scheduled'.tr();
      default:
        return 'admin.detail_not_set'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggerText = _localizedTriggerValue(option.triggerType);
    final templatesAsync = ref.watch(checklistTemplatesListProvider);

    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? context.colors.surfaceContainerHighest
        : context.colors.surfaceContainerLowest;
    final borderColor = Theme.of(context).brightness == Brightness.dark
        ? context.colors.outlineVariant
        : context.colors.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoLine(
            icon: Icons.schedule_outlined,
            text: 'admin.reservations_inherited_trigger_line'.tr(
              namedArgs: {'value': triggerText},
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          templatesAsync.when(
            data: (templates) {
              final id = option.checklistTemplateId?.trim();
              String checklistValue;
              if (id == null || id.isEmpty) {
                checklistValue = 'checklists.no_checklist'.tr();
              } else {
                final match = templates.where((x) => x.id == id).firstOrNull;
                checklistValue =
                    (match?.name.trim().isNotEmpty == true) ? match!.name.trim() : 'checklists.no_checklist'.tr();
              }
              return _InfoLine(
                icon: Icons.checklist_rtl,
                text: 'admin.reservations_inherited_checklist_line'.tr(
                  namedArgs: {'value': checklistValue},
                ),
              );
            },
            loading: () => _InfoLine(
              icon: Icons.checklist_rtl,
              text: 'admin.reservations_inherited_checklist_line'.tr(
                namedArgs: {'value': 'common.loading'.tr()},
              ),
            ),
            error: (err, stack) => _InfoLine(
              icon: Icons.checklist_rtl,
              text: 'admin.reservations_inherited_checklist_line'.tr(
                namedArgs: {'value': 'checklists.no_checklist'.tr()},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jedna řádka s ikonou a zalamovatelným textem (read-only nápověda).
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
