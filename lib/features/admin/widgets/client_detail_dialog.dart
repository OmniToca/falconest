import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/models/client_address_model.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/client/client_repository.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/admin_apartments_screen.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/widgets/client_form_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// `mailto:` pro CRM řádek – pouze pokud je neprázdný e-mail.
Uri? _clientDetailMailtoUri(String? email) {
  final t = email?.trim() ?? '';
  if (t.isEmpty) return null;
  return Uri(scheme: 'mailto', path: t);
}

/// `tel:` pro CRM – stejné čištění jako u rezervací (jen čísla a +).
Uri? _clientDetailTelUri(String? phone) {
  final raw = phone?.trim() ?? '';
  if (raw.isEmpty) return null;
  final cleanedAndPlus = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleanedAndPlus.isEmpty) return null;
  final cleaned = cleanedAndPlus.contains('+')
      ? '+${cleanedAndPlus.replaceAll('+', '')}'
      : cleanedAndPlus.replaceAll('+', '');
  return Uri(scheme: 'tel', path: cleaned);
}

Future<void> _launchClientContactUri(BuildContext context, Uri uri) async {
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e, st) {
    // PROČ: Špatně formátovaný kontakt nebo chybějící handler (simulátor) nesmí shodit dialog.
    AppLogger.error('_launchClientContactUri: otevření mailto/tel selhalo', e, st);
  }
}

/// Mapování client_type na i18n klíč.
String _clientTypeLabel(BuildContext context, String? clientType) {
  if (clientType == null || clientType.isEmpty) return '–';
  switch (clientType.toLowerCase()) {
    case 'owner':
      return 'clients.type_owner'.tr();
    case 'external':
      return 'clients.type_external'.tr();
    case 'agency':
      return 'clients.type_agency'.tr();
    default:
      return clientType;
  }
}

/// Dialog Detail klienta – vyskakovací okno v duchu ClientFormDialog.
///
/// PROČ podmíněné taby: Majitel potřebuje Apartmány a Rezervace; Agentura potřebuje
/// Adresář a Doporučení klienti; Externí jen Přehled a Úkoly. Zobrazení záložek
/// podle client_type zjednodušuje UI a eliminuje prázdné nebo nesmyslné sekce.
class ClientDetailDialog extends ConsumerWidget {
  const ClientDetailDialog({super.key, required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabData = _buildTabData(client);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.colors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(client: client),
            Flexible(
              child: DefaultTabController(
                length: tabData.length,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: tabData
                          .map((t) => Tab(text: t.labelKey.tr()))
                          .toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: tabData.map((t) => t.child).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PROČ: Sestavení tabů podle client_type – owner má Apartmány+Rezervace+Finance,
  /// agency má Adresář+Doporučení+Finance, external Přehled+Úkoly+Finance. Finance je u všech.
  static List<({String labelKey, Widget child})> _buildTabData(
    ClientModel client,
  ) {
    final type = client.clientType?.toLowerCase() ?? '';
    switch (type) {
      case 'owner':
        return [
          (
            labelKey: 'clients.client_tab_overview',
            child: _OverviewTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_apartments',
            child: _ApartmentsTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_reservations',
            child: _ReservationsTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_tasks',
            child: _TasksTab(client: client),
          ),
          (labelKey: 'clients.tab_finance', child: _FinanceTab(client: client)),
        ];
      case 'agency':
        return [
          (
            labelKey: 'clients.client_tab_overview',
            child: _OverviewTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_address_directory',
            child: _AddressDirectoryTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_recommended',
            child: _RecommendedClientsTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_tasks',
            child: _TasksTab(client: client),
          ),
          (labelKey: 'clients.tab_finance', child: _FinanceTab(client: client)),
        ];
      case 'external':
      default:
        return [
          (
            labelKey: 'clients.client_tab_overview',
            child: _OverviewTab(client: client),
          ),
          (
            labelKey: 'clients.client_tab_tasks',
            child: _TasksTab(client: client),
          ),
          (labelKey: 'clients.tab_finance', child: _FinanceTab(client: client)),
        ];
    }
  }
}

/// Hlavička dialogu – jméno klienta vlevo, tužka, koš a X vpravo.
class _DialogHeader extends ConsumerWidget {
  const _DialogHeader({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              client.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'admin.apartments_edit'.tr(),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.colors.error),
            tooltip: 'admin.apartments_delete'.tr(),
            onPressed: () => _showDeleteConfirm(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.close'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ClientFormDialog(
        ref: ref,
        client: client,
        onSaved: () {
          invalidatePaginatedClientTabs(ref);
          ref.invalidate(clientsFullListProvider);
          ref.invalidate(agencyNamesMapProvider);
        },
      ),
    );
  }

  /// Stejný potvrzovací dialog jako v seznamu klientů. Po potvrzení soft delete, zavření dialogu a toast.
  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.apartments_delete'.tr()),
        content: Text('clients.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('clients.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(softDeleteClientProvider)(client.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  invalidatePaginatedClientTabs(ref);
                  ref.invalidate(clientsFullListProvider);
                  ref.invalidate(agencyNamesMapProvider);
                  final aid = client.agencyId?.trim();
                  if (aid != null && aid.isNotEmpty) {
                    ref.invalidate(recommendedClientsCountByAgencyProvider(aid));
                  }
                  if ((client.clientType?.toLowerCase() ?? '') == 'agency') {
                    ref.invalidate(
                        recommendedClientsCountByAgencyProvider(client.id));
                    ref.invalidate(
                        clientsRecommendedListByAgencyProvider(client.id));
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('clients.deleted'.tr()),
                      backgroundColor: context.customColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('${'common.error'.tr()}: $e'),
                      backgroundColor: context.colors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text('admin.apartments_delete'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Tab Přehled – základní údaje klienta.
///
/// PROČ podmíněné sekce: Portál a Apartmány jen pro owner; Adresář pro agency
/// je v samostatné záložce; u external zobrazíme doporučující agenturu.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'clients.client_tab_overview'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'clients.email'.tr(),
            value: (client.email ?? '').trim().isEmpty ? '–' : client.email!,
            linkUri: _clientDetailMailtoUri(client.email),
            linkTooltipKey: 'admin.crm_contact_open_email',
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'clients.phone'.tr(),
            value: (client.phone ?? '').trim().isEmpty ? '–' : client.phone!,
            linkUri: _clientDetailTelUri(client.phone),
            linkTooltipKey: 'admin.crm_contact_open_phone',
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            icon: Icons.business_outlined,
            label: 'clients.type'.tr(),
            value: _clientTypeLabel(context, client.clientType),
          ),
          if ((client.clientType?.toLowerCase() ?? '') == 'owner' &&
              client.profileId != null &&
              client.profileId!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _PortalStatusSection(profileId: client.profileId!),
            const SizedBox(height: AppSpacing.md),
            _OwnerPortalViewButton(client: client),
            const SizedBox(height: AppSpacing.md),
            _ApartmentsCountSection(profileId: client.profileId!),
          ],
          // PROČ: U externího klienta zobrazíme doporučující agenturu (pokud má agency_id).
          if ((client.clientType?.toLowerCase() ?? '') == 'external' &&
              client.agencyId != null &&
              client.agencyId!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _RecommendingAgencyRow(agencyId: client.agencyId!),
          ],
        ],
      ),
    );
  }
}

/// Řádek s názvem doporučující agentury – pro externí klienty s agency_id.
class _RecommendingAgencyRow extends ConsumerWidget {
  const _RecommendingAgencyRow({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsFullListProvider);
    return clientsAsync.when(
      data: (clients) {
        final agency = clients.where((c) => c.id == agencyId).firstOrNull;
        return _DetailRow(
          icon: Icons.handshake_outlined,
          label: 'clients.recommended_by_agency'.tr(),
          value: agency?.name ?? '–',
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Tab Finance – Fakturace (k úhradě klientem) a Provize (výplaty klientovi).
///
/// Sekce A: Fakturace / K úhradě – úkoly z clientBillingProvider (completed, cena > 0).
/// Sekce B: Provize / Výplaty – task_commissions z clientFinancesProvider.
/// Prémiový zámek: pokud není aktivní modul settlements, zobrazí se zamčený overlay.
class _FinanceTab extends ConsumerWidget {
  const _FinanceTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsActive = isModuleActive(ref, 'settlements');
    final billingAsync = ref.watch(clientBillingProvider(client.id));
    final commissionsAsync = ref.watch(clientFinancesProvider(client.id));

    if (!settlementsActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: GestureDetector(
          onTap: () => PremiumUpsellDialog.show(
            context,
            moduleKey: 'settlements',
            titleKey: 'admin.upsell.settlements.title',
            descriptionKey: 'admin.upsell.settlements.description',
          ),
          child: Opacity(
            opacity: 0.85,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: context.colors.outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'clients.finance_locked_message'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (billingAsync.isLoading && commissionsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final billingError = billingAsync.hasError ? billingAsync.error : null;
    final commissionsError = commissionsAsync.hasError
        ? commissionsAsync.error
        : null;
    if (billingError != null || commissionsError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: context.colors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'common.generic_error_user_friendly'.tr(),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final billingList = billingAsync.valueOrNull ?? [];
    final commissionsList = commissionsAsync.valueOrNull ?? [];

    if (billingList.isEmpty && commissionsList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'clients.finance_empty'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'clients.tab_finance'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Sekce A: Fakturace / K úhradě
                Text(
                  'clients.finance_billing_title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (billingList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'clients.finance_billing_empty'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...billingList.map((item) {
                    final dateStr = item.date != null
                        ? DateFormat.yMd(
                            context.locale.toString(),
                          ).format(item.date!.toLocal())
                        : '–';
                    final statusLabel = item.isInvoiced
                        ? 'clients.finance_billing_status_invoiced'.tr()
                        : 'clients.finance_billing_status_pending'.tr();
                    final amountStr = formatWalletAmount(
                      context,
                      ref,
                      item.chargedPrice,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$dateStr • $statusLabel',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                        ),
                        trailing: Text(
                          amountStr,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.tertiary,
                              ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: AppSpacing.md),
                // Sekce B: Provize / Výplaty
                Text(
                  'clients.finance_commissions_title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (commissionsList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'clients.finance_commissions_empty'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...commissionsList.map((row) {
                    final taskTitle = row['task_title'] as String? ?? '–';
                    final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
                    final status =
                        (row['status'] as String?)?.trim().toLowerCase() ??
                        'pending';
                    final createdAt = row['created_at'];
                    DateTime? date;
                    if (createdAt != null) {
                      if (createdAt is DateTime) {
                        date = createdAt;
                      } else if (createdAt is String) {
                        date = DateTime.tryParse(createdAt);
                      }
                    }
                    final statusLabel = status == 'paid'
                        ? 'clients.finance_status_paid'.tr()
                        : 'clients.finance_status_pending'.tr();
                    final dateStr = date != null
                        ? DateFormat.yMd(
                            context.locale.toString(),
                          ).format(date.toLocal())
                        : '–';
                    final amountStr = formatWalletAmount(context, ref, amount);
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(taskTitle, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '$dateStr • $statusLabel',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                        ),
                        trailing: Text(
                          amountStr,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.customColors.success,
                              ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Adresář – pouze pro agentury. Adresy pro transfery (odvoz/vyzvednutí).
class _AddressDirectoryTab extends ConsumerWidget {
  const _AddressDirectoryTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'clients.client_tab_address_directory'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: _AddressDirectorySection(client: client),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Doporučení klienti – pouze pro agentury. Externí klienti s agency_id = tato agentura.
class _RecommendedClientsTab extends ConsumerWidget {
  const _RecommendedClientsTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(
      clientsRecommendedListByAgencyProvider(client.id),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'clients.client_tab_recommended'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: recommendedAsync.when(
              data: (clients) {
                if (clients.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'clients.recommended_empty'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final c = clients[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          Icons.person_outline,
                          color: context.colors.primary,
                        ),
                        title: Text(c.name, overflow: TextOverflow.ellipsis),
                        subtitle: (c.email ?? '').trim().isNotEmpty
                            ? Text(c.email!, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => ClientDetailDialog(client: c),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: context.colors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'common.generic_error_user_friendly'.tr(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jeden řádek v detailu – ikona, label, hodnota.
///
/// PROČ [linkUri]: E-mail a telefon mají být jedním klepnutím otevřitelné v systémové aplikaci;
/// vizuálně odlišíme primary + podtržení, aby šlo o rozšíření bez změny layoutu ostatních řádků.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.linkUri,
    this.linkTooltipKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final Uri? linkUri;
  /// Volitelný klíč tooltipu (např. admin.crm_contact_open_email); výchozí obecný text.
  final String? linkTooltipKey;

  @override
  Widget build(BuildContext context) {
    final link = linkUri;
    final canOpen = link != null && value != '–';

    final baseStyle = Theme.of(context).textTheme.bodyLarge;
    final linkStyle = baseStyle?.copyWith(
      color: context.colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.primary,
    );

    Widget valueWidget = Text(
      value,
      style: canOpen ? linkStyle : baseStyle,
    );

    if (canOpen) {
      valueWidget = Tooltip(
        message: (linkTooltipKey ?? 'admin.crm_contact_tap_to_open').tr(),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () => _launchClientContactUri(context, link),
              child: valueWidget,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              valueWidget,
            ],
          ),
        ),
      ],
    );
  }
}

/// Tlačítko pro náhled Klientského portálu majitele (read-only impersonation z CRM).
///
/// PROČ: Dispečer vidí stejná data jako majitel bez odhlášení; audit v [owner_portal_view_sessions].
/// Zobrazí se jen admin/manager, aktivní profil (ne pending) a bez souběžného HQ převtělení.
class _OwnerPortalViewButton extends ConsumerWidget {
  const _OwnerPortalViewButton({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    if (!auth.state.isAdminOrManager) {
      return const SizedBox.shrink();
    }
    if (auth.state.isImpersonating) {
      return const SizedBox.shrink();
    }

    final profileId = client.profileId?.trim() ?? '';
    if (profileId.isEmpty) {
      return const SizedBox.shrink();
    }

    final statusAsync = ref.watch(clientPortalStatusProvider(profileId));
    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final portalStatus =
            (data['status']?.toString() ?? 'pending').trim().toLowerCase();
        if (portalStatus == 'pending') {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.visibility_outlined),
            label: Text('admin.owner_view_portal_button'.tr()),
            onPressed: () => _openOwnerPortalView(context, ref, profileId),
          ),
        );
      },
    );
  }

  Future<void> _openOwnerPortalView(
    BuildContext context,
    WidgetRef ref,
    String profileId,
  ) async {
    if (ref.read(authNotifierProvider).state.isImpersonating) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.owner_view_error_hq_impersonating'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final started = await ref.read(authNotifierProvider).startOwnerView(
          clientId: client.id,
          ownerProfileId: profileId,
          displayName: client.name,
        );

    if (!context.mounted) return;

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.owner_view_error_start'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    context.go('/owner/dashboard');
  }
}

/// Sekce se stavem Klientského portálu (pending/active, zvací odkaz).
class _PortalStatusSection extends ConsumerWidget {
  const _PortalStatusSection({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(clientPortalStatusProvider(profileId));
    return statusAsync.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final status = (data['status']?.toString() ?? 'pending').toLowerCase();
        final lastLogin = data['last_login'] as DateTime?;
        final inviteLink = data['invite_link'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'clients.portal_status'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (status == 'pending') ...[
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: context.customColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'clients.portal_pending'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.customColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (inviteLink != null && inviteLink.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        size: 18,
                        color: context.colors.tertiary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      tooltip: 'clients.copy_invite_link'.tr(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteLink));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('clients.link_copied'.tr())),
                          );
                        }
                      },
                    ),
                  ],
                ] else ...[
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: context.customColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'clients.portal_active'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.customColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (lastLogin != null) ...[
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                    Text(
                      'clients.portal_last_login'.tr(
                        namedArgs: {
                          'date': DateFormat.yMd(
                            context.locale.toString(),
                          ).add_Hm().format(lastLogin.toLocal()),
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'common.loading'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Sekce s počtem apartmánů (pouze pro majitele).
class _ApartmentsCountSection extends ConsumerWidget {
  const _ApartmentsCountSection({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(ownerApartmentCountsProvider);
    return countsAsync.when(
      data: (map) {
        final count = map[profileId] ?? 0;
        return _DetailRow(
          icon: Icons.apartment,
          label: 'clients.apartments_count_label'.tr(),
          value: '$count',
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Sekce Adresář pro transfery – pouze pro klienty typu agency.
///
/// Zobrazuje seznam adres partnerské agentury a umožňuje přidávat/mazat.
/// Po změně se invaliduje clientAddressesProvider pro okamžité překreslení.
class _AddressDirectorySection extends ConsumerWidget {
  const _AddressDirectorySection({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(clientAddressesProvider(client.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'clients.address_directory'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        addressesAsync.when(
          data: (addresses) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...addresses.map(
                  (addr) => ListTile(
                    title: Text(addr.label),
                    subtitle: Text(addr.address),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: context.colors.error,
                      ),
                      tooltip: 'admin.apartments_delete'.tr(),
                      onPressed: () => _deleteAddress(context, ref, addr),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('clients.add_address'.tr()),
                  onPressed: () => _showAddAddressDialog(context, ref),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: SizedBox(
                width: AppSpacing.lg,
                height: AppSpacing.lg,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _deleteAddress(
    BuildContext context,
    WidgetRef ref,
    ClientAddressModel addr,
  ) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      await ClientRepository.deleteClientAddress(tenantId, addr.id);
      ref.invalidate(clientAddressesProvider(client.id));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('clients.address_deleted'.tr())));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error'.tr()}: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddAddressDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _AddAddressDialog(),
    );
    if (result == null || !context.mounted) return;
    final label = result['label']?.trim() ?? '';
    final address = result['address']?.trim() ?? '';
    if (label.isEmpty || address.isEmpty) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      await ClientRepository.addAddressToClient(
        tenantId,
        client.id,
        label: label,
        address: address,
      );
      ref.invalidate(clientAddressesProvider(client.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error'.tr()}: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }
}

/// Dialog pro přidání nové adresy – dvě textová pole.
class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('clients.add_address'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'clients.address_label_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'clients.address_value_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('clients.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelController.text.trim();
            final address = _addressController.text.trim();
            if (label.isEmpty || address.isEmpty) return;
            Navigator.of(context).pop({'label': label, 'address': address});
          },
          child: Text('clients.save'.tr()),
        ),
      ],
    );
  }
}

/// Tab Apartmány – lazy-loaded seznam bytů přiřazených majiteli.
class _ApartmentsTab extends ConsumerWidget {
  const _ApartmentsTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (client.profileId == null || client.profileId!.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'clients.no_owner_profile'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final apartmentsAsync = ref.watch(
      apartmentsForProfileProvider(client.profileId!),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'clients.client_tab_apartments'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('clients.btn_add_apartment_context'.tr()),
                onPressed: () {
                  showAddApartmentDialog(
                    context,
                    ref,
                    prefilledClient: client,
                    onSaved: () {
                      ref.invalidate(apartmentsProvider);
                      ref.invalidate(apartmentsFullListProvider);
                      ref.invalidate(
                        apartmentsForProfileProvider(client.profileId!),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: apartmentsAsync.when(
              data: (apartments) {
                if (apartments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'clients.apartments_empty'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: apartments.length,
                  itemBuilder: (context, index) {
                    final apt = apartments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: Icon(
                          Icons.apartment,
                          color: context.colors.tertiary,
                        ),
                        title: Text(apt.name),
                        subtitle:
                            apt.address != null &&
                                apt.address!.trim().isNotEmpty
                            ? Text(
                                apt.address!,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showApartmentEditDialog(
                            context,
                            ref,
                            apt,
                            onSaved: () {
                              ref.invalidate(apartmentsProvider);
                              ref.invalidate(apartmentsFullListProvider);
                              ref.invalidate(
                                apartmentsForProfileProvider(client.profileId!),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: context.colors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'common.generic_error_user_friendly'.tr(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parsuje datum příjezdu rezervace z textu (DD.MM.YYYY) pro řazení.
/// PROČ: ReservationRow má checkIn jako zobrazený řetězec; pro řazení potřebujeme DateTime.
DateTime? _parseReservationStartDate(String? checkIn) {
  if (checkIn == null || checkIn.trim().isEmpty) return null;
  final parts = checkIn.trim().split(' ');
  final dParts = parts[0].split('.');
  if (dParts.length < 3) return null;
  try {
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
    );
  } catch (e, st) {
    AppLogger.error('_parseReservationStartDate: parsování check_in selhalo', e, st);
    return null;
  }
}

/// True, pokud je rezervace v „dokončeném“ stavu (Odhlášeno / Zrušeno) – jde na konec seznamu.
bool _isReservationCompleted(ReservationRow r) {
  final s = r.status.trim().toLowerCase();
  return s == 'checked_out' || s == 'cancelled';
}

/// Seřadí rezervace: primárně podle start_date ASC, sekundárně dokončené (checked_out/cancelled) na konec.
List<ReservationRow> _sortReservationsForClientTab(List<ReservationRow> list) {
  final sorted = List<ReservationRow>.from(list);
  sorted.sort((a, b) {
    final aDate = _parseReservationStartDate(a.checkIn);
    final bDate = _parseReservationStartDate(b.checkIn);
    final aEnd = _isReservationCompleted(a) ? 1 : 0;
    final bEnd = _isReservationCompleted(b) ? 1 : 0;
    if (aEnd != bEnd) return aEnd.compareTo(bEnd);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return sorted;
}

/// Tab Rezervace – seznam rezervací souvisejících s klientem (pouze pro majitele).
///
/// Řazení: start_date ASC, položky Odhlášeno/Zrušeno na konec. Ve výchozím stavu se zobrazují
/// jen aktivní; dokončené lze rozbalit tlačítkem „Zobrazit historii dokončených (N)“.
class _ReservationsTab extends ConsumerStatefulWidget {
  const _ReservationsTab({required this.client});

  final ClientModel client;

  @override
  ConsumerState<_ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends ConsumerState<_ReservationsTab> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final reservationsAsync = ref.watch(clientReservationsProvider(client.id));
    final isOwner =
        (client.clientType?.toLowerCase() ?? '') == 'owner' &&
        client.profileId != null &&
        client.profileId!.trim().isNotEmpty;
    final apartmentsAsync = isOwner
        ? ref.watch(apartmentsForProfileProvider(client.profileId!))
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOwner)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'clients.client_tab_reservations'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('clients.btn_add_reservation_context'.tr()),
                  onPressed: () async {
                    final apartments = apartmentsAsync?.valueOrNull ?? [];
                    final firstApartmentId = apartments.isNotEmpty
                        ? apartments.first.id
                        : null;
                    if (!context.mounted) return;
                    AdminReservationsScreen.showAddReservationDialog(
                      context,
                      ref,
                      initialApartmentId: firstApartmentId,
                      onSaved: () =>
                          ref.invalidate(clientReservationsProvider(client.id)),
                    );
                  },
                ),
              ],
            )
          else
            Text(
              'clients.client_tab_reservations'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: reservationsAsync.when(
              data: (reservations) {
                if (reservations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'clients.client_no_reservations'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final sorted = _sortReservationsForClientTab(reservations);
                final completed = sorted
                    .where(_isReservationCompleted)
                    .toList();
                final active = sorted
                    .where((r) => !_isReservationCompleted(r))
                    .toList();
                final visible = _showHistory ? sorted : active;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'clients.client_no_reservations'.tr(),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final r = visible[index];
                                final term = [
                                  r.checkIn ?? '–',
                                  r.checkOut ?? '–',
                                ].join(' – ');
                                return Card(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.calendar_month,
                                      color: context.colors.tertiary,
                                    ),
                                    title: Text(term),
                                    subtitle: Text(
                                      [
                                        (r.guestName ?? '').trim().isNotEmpty
                                            ? r.guestName!
                                            : '–',
                                        reservationStatusLabelKey(
                                          r.status,
                                        ).tr(),
                                      ].join(' • '),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      AdminReservationsScreen.showEditReservationDialog(
                                        context,
                                        ref,
                                        r,
                                        onSaved: () => ref.invalidate(
                                          clientReservationsProvider(client.id),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    if (completed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: TextButton.icon(
                          icon: Icon(
                            _showHistory
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                          ),
                          label: Text(
                            _showHistory
                                ? 'common.hide_history'.tr()
                                : 'common.show_history_count'.tr(
                                    namedArgs: {'count': '${completed.length}'},
                                  ),
                          ),
                          onPressed: () =>
                              setState(() => _showHistory = !_showHistory),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: context.colors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'common.generic_error_user_friendly'.tr(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mapování stavu úkolu na systémový klíč pro i18n (task_status.*).
String _taskStatusKey(String? status) {
  if (status == null || status.trim().isEmpty) return 'task_status.pending';
  final s = status.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') {
    return 'task_status.pending';
  }
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') {
    return 'task_status.assigned';
  }
  if (s == 'in_progress' || s == 'probíhá') {
    return 'task_status.in_progress';
  }
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') {
    return 'task_status.completed';
  }
  if (s == 'problém' || s == 'problem' || s == 'issue') {
    return 'task_status.problem';
  }
  return 'task_status.pending';
}

/// True, pokud je úkol v „dokončeném“ stavu (Hotovo / Zrušeno) – jde na konec seznamu.
bool _isTaskCompletedOrCancelled(TaskRow t) {
  final s = t.status.trim().toLowerCase();
  return s == 'completed' ||
      s == 'done' ||
      s == 'hotovo' ||
      s == 'dokončeno' ||
      s == 'cancelled';
}

/// Vrací datum pro řazení úkolu (scheduled_start nebo due_date).
DateTime _taskSortDate(TaskRow t) {
  final start = t.scheduledStart;
  if (start != null) return start;
  return t.dueDate;
}

/// Seřadí úkoly: primárně podle scheduled_start/due_date ASC, sekundárně dokončené/zrušené na konec.
List<TaskRow> _sortTasksForClientTab(List<TaskRow> list) {
  final sorted = List<TaskRow>.from(list);
  sorted.sort((a, b) {
    final aEnd = _isTaskCompletedOrCancelled(a) ? 1 : 0;
    final bEnd = _isTaskCompletedOrCancelled(b) ? 1 : 0;
    if (aEnd != bEnd) return aEnd.compareTo(bEnd);
    return _taskSortDate(a).compareTo(_taskSortDate(b));
  });
  return sorted;
}

/// Tab Úkoly – seznam úkolů souvisejících s klientem.
///
/// Řazení: scheduled_start/due_date ASC, položky Hotovo/Zrušeno na konec. Ve výchozím stavu
/// se zobrazují jen aktivní; dokončené lze rozbalit tlačítkem „Zobrazit historii dokončených (N)“.
class _TasksTab extends ConsumerStatefulWidget {
  const _TasksTab({required this.client});

  final ClientModel client;

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final tasksAsync = ref.watch(clientTasksProvider(client.id));
    final isOwner =
        (client.clientType?.toLowerCase() ?? '') == 'owner' &&
        client.profileId != null &&
        client.profileId!.trim().isNotEmpty;
    final apartmentsAsync = isOwner
        ? ref.watch(apartmentsForProfileProvider(client.profileId!))
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'clients.client_tab_tasks'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('clients.btn_add_task_context'.tr()),
                onPressed: () {
                  if (isOwner) {
                    final apartments = apartmentsAsync?.valueOrNull ?? [];
                    final firstApartmentId = apartments.isNotEmpty
                        ? apartments.first.id
                        : null;
                    AdminTasksScreen.showAddTaskDialog(
                      context,
                      ref,
                      initialApartmentId: firstApartmentId,
                      onSaved: () =>
                          ref.invalidate(clientTasksProvider(client.id)),
                    );
                  } else {
                    AdminTasksScreen.showAddTaskDialog(
                      context,
                      ref,
                      initialClientId: client.id,
                      onSaved: () =>
                          ref.invalidate(clientTasksProvider(client.id)),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'clients.client_no_tasks'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final sorted = _sortTasksForClientTab(tasks);
                final completed = sorted
                    .where(_isTaskCompletedOrCancelled)
                    .toList();
                final active = sorted
                    .where((t) => !_isTaskCompletedOrCancelled(t))
                    .toList();
                final visible = _showHistory ? sorted : active;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  'clients.client_no_tasks'.tr(),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final t = visible[index];
                                final displayTitle =
                                    (t.customTitle ?? t.title).trim().isNotEmpty
                                    ? (t.customTitle ?? t.title)
                                    : (t.apartmentName ?? t.apartmentId);
                                return Card(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.task_alt,
                                      color: context.colors.tertiary,
                                    ),
                                    title: Text(
                                      displayTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _taskStatusKey(t.status).tr(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      AdminTasksScreen.showEditTaskDialog(
                                        context,
                                        ref,
                                        t,
                                        onSaved: () => ref.invalidate(
                                          clientTasksProvider(client.id),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    if (completed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: TextButton.icon(
                          icon: Icon(
                            _showHistory
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                          ),
                          label: Text(
                            _showHistory
                                ? 'common.hide_history'.tr()
                                : 'common.show_history_count'.tr(
                                    namedArgs: {'count': '${completed.length}'},
                                  ),
                          ),
                          onPressed: () =>
                              setState(() => _showHistory = !_showHistory),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: context.colors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'common.generic_error_user_friendly'.tr(),
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
