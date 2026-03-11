import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/features/admin/models/zone_model.dart';
import 'package:falconest/features/admin/providers/zones_provider.dart';
import 'package:falconest/features/settings/zone_editor_dialog.dart';

/// Znovupoužitelný widget seznamu oblastí – bez Scaffold/AppBar.
/// Používá se jako záložka v Nastavení nebo jako obsah obrazovky /settings/zones.
/// Vizuálně sjednocený se seznamem služeb (karty, tlačítko přidat ve stejném stylu).
class ZonesListTab extends ConsumerWidget {
  const ZonesListTab({
    super.key,
    this.showAddButton = true,
  });

  /// Zda zobrazit tlačítko „Přidat oblast“ nahoře (jako u Služeb). V embedded tabu true.
  final bool showAddButton;

  /// Zobrazí modal dialog pro přidání nové oblasti.
  static void showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const ZoneEditorDialog(existing: null),
    ).then((_) => ref.invalidate(zonesProvider));
  }

  /// Zobrazí modal dialog pro úpravu oblasti.
  static void showEditDialog(BuildContext context, WidgetRef ref, ZoneRow zone) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ZoneEditorDialog(existing: zone),
    ).then((_) => ref.invalidate(zonesProvider));
  }

  /// Potvrdí a provede soft delete oblasti.
  static Future<void> confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ZoneRow zone,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.zone_delete_confirm_title'.tr()),
        content: Text(
          'admin.zone_delete_confirm'.tr(namedArgs: {'name': zone.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('admin.zone_delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ZonesRepository.softDelete(zone.id, zone.tenantId);
      if (!context.mounted) return;
      ref.invalidate(zonesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.zone_deleted'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.zone_delete_error'.tr(namedArgs: {'error': e.message}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.zone_delete_error'.tr(namedArgs: {'error': '$e'}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(zonesProvider).when(
          data: (zones) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAddButton) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'admin.zones_title'.tr(),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[900],
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => showAddDialog(context, ref),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('admin.add_zone'.tr()),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: zones.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'admin.zones_empty'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'admin.zones_empty_hint'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: zones.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _ZoneCardRow(
                            zone: zones[index],
                            onEdit: () =>
                                showEditDialog(context, ref, zones[index]),
                            onDelete: () =>
                                confirmDelete(context, ref, zones[index]),
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  Text(
                    'common.error_with_message'.tr(
                      namedArgs: {'message': err.toString()},
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(zonesProvider),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

/// Jedna karta oblasti – vizuálně sjednocená s _ServiceCardRow (bílá, 16 radius, stín).
class _ZoneCardRow extends StatelessWidget {
  const _ZoneCardRow({
    required this.zone,
    required this.onEdit,
    required this.onDelete,
  });

  final ZoneRow zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.map, color: Colors.blue.shade700, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              zone.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[700]),
            tooltip: 'settings.service_edit'.tr(),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            tooltip: 'settings.service_delete'.tr(),
          ),
        ],
      ),
    );
  }
}
