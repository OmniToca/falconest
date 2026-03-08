import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/providers/hq_staff_provider.dart';
import 'package:falconest/features/super_admin/screens/add_hq_member_dialog.dart';
import 'package:falconest/features/super_admin/screens/hq_staff_detail_screen.dart';

/// Modální okno seznamu členů HQ týmu – stejný vzor jako Nastavení / Fakturace.
///
/// PROČ: Po kliknutí na „HQ Tým“ na dashboardu se neotevře full-screen stránka, ale
/// vyskakovací modál (showAppModal). Odstraňuje „hnusné bílé plochy“ a sjednocuje UX.
class HqTeamModal {
  HqTeamModal._();

  /// Otevře seznam HQ týmu jako modální dialog. Voláno z dashboardu místo context.push.
  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showAppModal<void>(
      context: context,
      barrierLabel: 'super_admin.barrier_hq_team'.tr(),
      maxWidth: 800,
      maxHeightFraction: 0.85,
      child: const _HqTeamModalContent(),
    );
  }
}

/// Vnitřní obsah modalu – hlavička s titulkem, křížkem a tlačítkem Přidat; seznam karet.
class _HqTeamModalContent extends ConsumerWidget {
  const _HqTeamModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(hqStaffListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'super_admin.hq_team_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: 'super_admin.hq_member_add_btn'.tr(),
                onPressed: () => AddHqMemberDialog.show(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'common.cancel'.tr(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncList.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'super_admin.hq_team_empty'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final staff = list[index];
                  final roleLabel = _roleLabel(staff.role);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 1,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      child: InkWell(
                        onTap: () => HqStaffDetailModal.show(context, ref, staff.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  (staff.displayName.isNotEmpty ? staff.displayName[0] : '?').toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.displayName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    if (roleLabel != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        roleLabel,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'super_admin.hq_team_load_error'.tr(),
                      style: TextStyle(color: Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(hqStaffListProvider),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String? _roleLabel(String? role) {
    if (role == null || role.isEmpty) return null;
    switch (role) {
      case 'super_admin':
        return 'super_admin.hq_team_role_super_admin'.tr();
      case 'account_manager':
        return 'super_admin.hq_team_role_account_manager'.tr();
      default:
        return role;
    }
  }
}
