import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/features/super_admin/audit_log_display_helpers.dart';
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';
import 'package:falconest/features/super_admin/providers/audit_log_provider.dart';
import 'package:falconest/features/super_admin/services/audit_log_repository.dart';

/// Modální dialog Audit Log (Odpadkový koš) – vizuálně shodný s dialogem Nastavení.
///
/// Zobrazuje záznamy z audit_logs, filtr podle tenanta a akce Obnovit / Trvalé smazání.
/// Uživatel zůstane v kontextu Super Admin velína (žádná nová route). Z dashboardu
/// volat AuditLogModal.show(context) místo context.push('/super-admin/audit-log').
class AuditLogModal {
  AuditLogModal._();

  /// Otevře Audit Log jako modální dialog (blur, centrované okno se zakulacenými rohy).
  /// Používáme showGeneralDialog místo nové routy, aby uživatel zůstal na nástěnce a
  /// mohl po zavření dialogu pokračovat bez přepínání obrazovky.
  static Future<void> show(BuildContext hostContext) {
    return showGeneralDialog<void>(
      context: hostContext,
      barrierDismissible: true,
      barrierLabel: 'Audit Log',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              child: _AuditLogModalContent(hostContext: hostContext),
            ),
          ),
        );
      },
    );
  }
}

/// Obsah modalu – filtr, tabulka logu a tlačítko zavření. Vizuálně odpovídá dialogu Nastavení.
class _AuditLogModalContent extends ConsumerWidget {
  const _AuditLogModalContent({required this.hostContext});

  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsWithStatusProvider);
    final logsAsync = ref.watch(auditLogListProvider);
    final actorNamesAsync = ref.watch(auditLogActorNamesProvider);
    final selectedTenantId = ref.watch(auditLogTenantFilterProvider);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1000,
            maxHeight: 800,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterBar(
                        tenantsAsync: tenantsAsync,
                        selectedTenantId: selectedTenantId,
                        onTenantChanged: (id) =>
                            ref.read(auditLogTenantFilterProvider.notifier).state = id,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: logsAsync.when(
                          data: (list) {
                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  'super_admin.audit_log_empty'.tr(),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              );
                            }
                            final tenantNames = _tenantIdToNameMap(tenantsAsync.valueOrNull);
                            final actorNames = actorNamesAsync.valueOrNull ?? {};
                            return _AuditLogList(
                              entries: list,
                              tenantIdToName: tenantNames,
                              userIdToName: actorNames,
                              onRestore: (e) => _confirmRestore(context, ref, e),
                              onHardDelete: (e) => _confirmHardDelete(context, ref, e),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'super_admin.audit_log_load_error'.tr(),
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => ref.invalidate(auditLogListProvider),
                                  child: Text('common.retry'.tr()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onClose() {
    Navigator.of(hostContext).pop();
  }

  /// Sestaví mapu tenant_id → název agentury pro zobrazení místo UUID.
  /// PROČ: Uživatel vidí „Farma SOKOL“, ne surové UUID z DB.
  static Map<String, String> _tenantIdToNameMap(List<TenantWithStatus>? tenants) {
    if (tenants == null) return {};
    final map = <String, String>{};
    for (final t in tenants) {
      map[t.tenant.id] = t.tenant.name;
    }
    return map;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'super_admin.audit_log_title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: _onClose,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref, AuditLogEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.audit_log_restore_confirm_title'.tr()),
        content: Text('super_admin.audit_log_restore_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('super_admin.audit_log_btn_restore'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AuditLogRepository.restore(entry);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.audit_log_restore_success'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(auditLogListProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.audit_log_restore_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, WidgetRef ref, AuditLogEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.audit_log_hard_delete_confirm_title'.tr()),
        content: Text('super_admin.audit_log_hard_delete_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('super_admin.audit_log_btn_hard_delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AuditLogRepository.hardDelete(entry);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.audit_log_hard_delete_success'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(auditLogListProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.audit_log_hard_delete_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Obrazovka pro route /super-admin/audit-log – zobrazí stejný modal a po zavření vrátí na velín.
/// Umožňuje přímý odkaz na audit log; po zavření dialogu uživatel skončí na dashboardu.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AuditLogModal.show(context).then((_) {
        if (mounted) context.go('/super-admin');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Horní lišta s výběrem tenanta pro filtrování audit logu.
///
/// Oprava duplicity: před dropdownem je jeden popisek (audit_log_filter_label),
/// v rozevíracím seznamu pak položky „Všechny agentury“ resp. „Agentura: {name}“.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.tenantsAsync,
    required this.selectedTenantId,
    required this.onTenantChanged,
  });

  final AsyncValue<List<TenantWithStatus>> tenantsAsync;
  final String? selectedTenantId;
  final ValueChanged<String?> onTenantChanged;

  @override
  Widget build(BuildContext context) {
    final tenants = tenantsAsync.valueOrNull ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Text(
            'super_admin.audit_log_filter_label'.tr(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedTenantId,
                isExpanded: true,
                hint: Text('super_admin.audit_log_filter_all'.tr()),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('super_admin.audit_log_filter_all'.tr()),
                  ),
                  ...tenants.map((t) {
                    final name = t.tenant.name;
                    final id = t.tenant.id;
                    return DropdownMenuItem<String?>(
                      value: id,
                      child: Text(
                        'super_admin.audit_log_filter_tenant'.tr(namedArgs: {'name': name}),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: onTenantChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// High-density list záznamů audit logu: kompaktní řádky pro lepší čitelnost při 1000+ záznamech.
///
/// Místo velkých karet používáme minimální padding a jeden řádek metadat (čas • agentura •
/// uživatel • zkrácené ID), aby na obrazovku vešlo víc položek. Tlačítka Obnovit / Trvale
/// smazat zůstávají funkční (IconButton s tooltipem).
class _AuditLogList extends StatelessWidget {
  const _AuditLogList({
    required this.entries,
    required this.tenantIdToName,
    required this.userIdToName,
    required this.onRestore,
    required this.onHardDelete,
  });

  final List<AuditLogEntry> entries;
  final Map<String, String> tenantIdToName;
  final Map<String, String> userIdToName;
  final ValueChanged<AuditLogEntry> onRestore;
  final ValueChanged<AuditLogEntry> onHardDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) => _AuditLogRow(
        entry: entries[index],
        tenantIdToName: tenantIdToName,
        userIdToName: userIdToName,
        onRestore: onRestore,
        onHardDelete: onHardDelete,
      ),
    );
  }
}

/// Jeden kompaktní řádek záznamu: malá ikona, nadpis, jeden řádek metadat (čas • agentura • uživatel • ID), ikonová tlačítka vpravo.
///
/// High-density layout: minimal padding a vertikální rozestup, aby na obrazovku vešlo
/// co nejvíc záznamů (důležité pro 1000+ položek). Actor (kdo akci provedl) se bere
/// z userIdToName; chybí-li, zobrazí se překlad audit_log_actor_unknown.
class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({
    required this.entry,
    required this.tenantIdToName,
    required this.userIdToName,
    required this.onRestore,
    required this.onHardDelete,
  });

  final AuditLogEntry entry;
  final Map<String, String> tenantIdToName;
  final Map<String, String> userIdToName;
  final ValueChanged<AuditLogEntry> onRestore;
  final ValueChanged<AuditLogEntry> onHardDelete;

  static const String _metadataSeparator = ' • ';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRestore = AuditLogRepository.canRestore(entry);
    final canHardDelete = AuditLogRepository.canHardDelete(entry);
    final actionKey = auditLogActionToTranslationKey(entry.actionType);
    final tableKey = auditLogTableToTranslationKey(entry.tableName);
    final actionLabel = actionKey.tr();
    final entityLabel = tableKey.tr();
    final isDelete = entry.actionType == AuditActionType.softDelete ||
        entry.actionType == AuditActionType.softDeleteCascade;
    final fallbackTitle = isDelete
        ? 'super_admin.audit_log_entry_title_deleted'.tr(namedArgs: {'entity': entityLabel})
        : '$actionLabel – $entityLabel';
    final recordName = EnterpriseAuditPayload.getRecordName(entry.details);
    final titleText = (recordName != null && recordName.isNotEmpty) ? recordName : fallbackTitle;
    final agencyName = (entry.tenantId != null
            ? (tenantIdToName[entry.tenantId] ?? entry.tenantId)
            : null) ??
        '—';
    final actorFromSnapshot = EnterpriseAuditPayload.getActorNameFromSnapshot(entry.details);
    final actorName = actorFromSnapshot ??
        (entry.userId == null || entry.userId!.isEmpty
            ? 'super_admin.audit_log_actor_system'.tr()
            : (userIdToName[entry.userId] ?? 'super_admin.audit_log_actor_unknown'.tr()));
    final clientInfo = EnterpriseAuditPayload.getClientInfoFromDetails(entry.details);
    final deviceLabel = clientInfo != null ? _deviceDisplayKey(clientInfo) : null;
    final timeStr = DateFormat('d. M. yyyy HH:mm').format(entry.createdAt.toLocal());
    final recordSuffix = getAuditLogDisplayNameFromDetails(entry) ?? shortRecordId(entry.recordId);
    final metaParts = <String>[timeStr, agencyName, actorName];
    if (deviceLabel != null) metaParts.add(deviceLabel);
    metaParts.add(recordSuffix);
    final metadataLine = metaParts.join(_metadataSeparator);
    final detailsLine = formatAuditLogDetailsForDisplay(entry.details);
    final hasExpandableDetail = EnterpriseAuditPayload.getPreviousState(entry.details) != null ||
        EnterpriseAuditPayload.getNewState(entry.details) != null;

    Widget rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          getAuditLogIconForTable(entry.tableName),
          size: 20,
          color: theme.colorScheme.primary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                metadataLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (detailsLine != null && detailsLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detailsLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (canRestore || canHardDelete)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRestore)
                IconButton(
                  onPressed: () => onRestore(entry),
                  icon: const Icon(Icons.restore, size: 20),
                  tooltip: 'super_admin.audit_log_btn_restore'.tr(),
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              if (canHardDelete)
                IconButton(
                  onPressed: () => onHardDelete(entry),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  tooltip: 'super_admin.audit_log_btn_hard_delete'.tr(),
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
      ],
    );
    if (hasExpandableDetail) {
      rowContent = InkWell(
        onTap: () => _showAuditDetailDialog(context, entry),
        child: rowContent,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: rowContent,
    );
  }

  /// Překlad hodnoty client_info (Web, iOS, Android) pro zobrazení v řádku – vše přes i18n.
  static String _deviceDisplayKey(String clientInfo) {
    switch (clientInfo) {
      case 'Web':
        return 'super_admin.audit_log_device_web'.tr();
      case 'iOS':
        return 'super_admin.audit_log_device_ios'.tr();
      case 'Android':
        return 'super_admin.audit_log_device_android'.tr();
      default:
        return clientInfo;
    }
  }

  /// Otevře sub-dialog s previous_state a new_state („Původní stav“, „Nová hodnota“) – vše přes i18n.
  static void _showAuditDetailDialog(BuildContext context, AuditLogEntry entry) {
    final prev = EnterpriseAuditPayload.getPreviousState(entry.details);
    final newState = EnterpriseAuditPayload.getNewState(entry.details);
    if (prev == null && newState == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.audit_log_detail_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (prev != null) ...[
                Text(
                  'super_admin.audit_log_detail_previous_state'.tr(),
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  EnterpriseAuditPayload.formatStateForDisplay(prev),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              if (newState != null) ...[
                Text(
                  'super_admin.audit_log_detail_new_state'.tr(),
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  EnterpriseAuditPayload.formatStateForDisplay(newState),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('super_admin.audit_log_detail_close'.tr()),
          ),
        ],
      ),
    );
  }
}
