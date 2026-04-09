import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/client/client_repository.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/widgets/client_form_dialog.dart';
import 'package:falconest/features/admin/widgets/client_detail_dialog.dart';

/// Rychlé CRM filtry nad již načteným (a vyhledaným) seznamem — bez změny dotazů na Supabase.
List<ClientModel> applyCrmQuickClientFilters(
  List<ClientModel> clients, {
  required bool portalAccessOnly,
  required bool noEmailOnly,
}) {
  var it = clients.where((c) => c.deletedAt == null);
  if (portalAccessOnly) {
    it = it.where(
      (c) => c.profileId != null && c.profileId!.trim().isNotEmpty,
    );
  }
  if (noEmailOnly) {
    it = it.where((c) => (c.email ?? '').trim().isEmpty);
  }
  return it.toList();
}

/// Mapování client_type z DB na i18n klíč pro zobrazení.
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

/// Administrativní obrazovka správy klientů (CRM).
///
/// Zobrazuje seznam klientů agentury – majitelé, externí klienti, agentury.
/// Slouží pro fakturaci externích úkolů (transfery bez bytu). Design ladí s
/// obrazovkami Apartmány a Personál – karty, vyhledávání, tlačítko Přidat.
class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() =>
      _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  final _scrollController1 = ScrollController();
  final _scrollController2 = ScrollController();
  final _scrollController3 = ScrollController();

  /// Rychlé filtry (kombinují se s FTS vyhledáváním) — aplikují se lokálně na stránkovaný výsledek.
  bool _crmQuickFilterPortal = false;
  bool _crmQuickFilterNoEmail = false;

  @override
  void initState() {
    super.initState();
    _scrollController1.addListener(
        () => _onScroll(_scrollController1, ClientPaginatedFilterKind.owner));
    _scrollController2.addListener(
        () => _onScroll(_scrollController2, ClientPaginatedFilterKind.agency));
    _scrollController3.addListener(
        () => _onScroll(_scrollController3, ClientPaginatedFilterKind.external));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    super.dispose();
  }

  /// Při scrollu ke konci (0.9 * maxScrollExtent) načte další stránku pro danou záložku.
  void _onScroll(ScrollController controller, ClientPaginatedFilterKind tabKind) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.9) {
      ref.read(paginatedClientsByTabProvider(tabKind).notifier).loadMore();
    }
  }

  /// Server-side FTS (`clients.search_vector`, websearch + simple) – stejný řetězec pro všechny tři záložky.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      for (final k in ClientPaginatedFilterKind.values) {
        ref.read(paginatedClientsByTabProvider(k).notifier).search(query);
      }
    });
  }

  void _invalidateClientCaches(WidgetRef r) {
    invalidatePaginatedClientTabs(r);
    r.invalidate(clientsFullListProvider);
    r.invalidate(agencyNamesMapProvider);
  }

  @override
  Widget build(BuildContext context) {
    // PROČ: Po křížové navigaci z úkolu/rezervace otevřeme stejný dialog detailu klienta jako při kliknutí v CRM.
    ref.listen<AdminCrossNavPending>(adminCrossNavPendingProvider, (previous, next) {
      final id = next.clientId;
      if (id == null || id.isEmpty) return;
      final full = ref.read(clientsFullListProvider).valueOrNull;
      ClientModel? client;
      if (full != null) {
        for (final c in full) {
          if (c.id == id) {
            client = c;
            break;
          }
        }
      }
      if (client == null) {
        for (final k in ClientPaginatedFilterKind.values) {
          final paginated =
              ref.read(paginatedClientsByTabProvider(k)).valueOrNull;
          if (paginated == null) continue;
          for (final c in paginated) {
            if (c.id == id) {
              client = c;
              break;
            }
          }
          if (client != null) break;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(adminCrossNavPendingProvider.notifier).clear();
        if (client != null) {
          _showClientDetail(context, ref, client);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.cross_nav_client_not_found'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    });
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopActionBar(
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onAdd: () => _showAddDialog(context, ref),
              portalFilter: _crmQuickFilterPortal,
              noEmailFilter: _crmQuickFilterNoEmail,
              onPortalFilterChanged: (v) =>
                  setState(() => _crmQuickFilterPortal = v),
              onNoEmailFilterChanged: (v) =>
                  setState(() => _crmQuickFilterNoEmail = v),
            ),
            TabBar(
              tabs: [
                Tab(text: 'clients.tab_owners'.tr()),
                Tab(text: 'clients.tab_agencies'.tr()),
                Tab(text: 'clients.tab_external'.tr()),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ClientsTabContent(
                    tabKind: ClientPaginatedFilterKind.owner,
                    searchQuery: _searchController.text.trim(),
                    scrollController: _scrollController1,
                    portalFilter: _crmQuickFilterPortal,
                    noEmailFilter: _crmQuickFilterNoEmail,
                    onEdit: (c) => _showClientDetail(context, ref, c),
                    onDelete: (c) => _showDeleteConfirm(context, ref, c),
                  ),
                  _ClientsTabContent(
                    tabKind: ClientPaginatedFilterKind.agency,
                    searchQuery: _searchController.text.trim(),
                    scrollController: _scrollController2,
                    portalFilter: _crmQuickFilterPortal,
                    noEmailFilter: _crmQuickFilterNoEmail,
                    onEdit: (c) => _showClientDetail(context, ref, c),
                    onDelete: (c) => _showDeleteConfirm(context, ref, c),
                  ),
                  _ClientsTabContent(
                    tabKind: ClientPaginatedFilterKind.external,
                    searchQuery: _searchController.text.trim(),
                    scrollController: _scrollController3,
                    portalFilter: _crmQuickFilterPortal,
                    noEmailFilter: _crmQuickFilterNoEmail,
                    onEdit: (c) => _showClientDetail(context, ref, c),
                    onDelete: (c) => _showDeleteConfirm(context, ref, c),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClientDetail(BuildContext context, WidgetRef ref, ClientModel client) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ClientDetailDialog(client: client),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ClientFormDialog(
        ref: ref,
        onSaved: () {
          _invalidateClientCaches(ref);
        },
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    ClientModel client,
  ) {
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
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  _invalidateClientCaches(ref);
                  final aid = client.agencyId?.trim();
                  if (aid != null && aid.isNotEmpty) {
                    ref.invalidate(recommendedClientsCountByAgencyProvider(aid));
                  }
                  if ((client.clientType?.toLowerCase() ?? '') == 'agency') {
                    ref.invalidate(
                        recommendedClientsCountByAgencyProvider(client.id));
                  }
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('clients.deleted'.tr()),
                      backgroundColor: Colors.green,
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
                      backgroundColor: Colors.red.shade700,
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

/// Obsah jedné záložky – vlastní stránkovaný provider podle [tabKind] (filtr na Supabase).
class _ClientsTabContent extends ConsumerWidget {
  const _ClientsTabContent({
    required this.tabKind,
    required this.searchQuery,
    required this.scrollController,
    required this.portalFilter,
    required this.noEmailFilter,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientPaginatedFilterKind tabKind;
  final String searchQuery;
  final ScrollController scrollController;
  final bool portalFilter;
  final bool noEmailFilter;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(paginatedClientsByTabProvider(tabKind));
    final loadingMore = ref.watch(clientsLoadingMoreByTabProvider(tabKind));

    return clientsAsync.when(
      data: (clients) {
        final filtered = applyCrmQuickClientFilters(
          clients,
          portalAccessOnly: portalFilter,
          noEmailOnly: noEmailFilter,
        );
        if (clients.isEmpty && !loadingMore) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                searchQuery.isEmpty
                    ? 'clients.tab_empty'.tr()
                    : 'admin.apartments_search_no_results'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (filtered.isEmpty && !loadingMore) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'admin.clients_quick_filter_empty'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: _ClientsCardList(
                clients: filtered,
                scrollController: scrollController,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
            if (loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'common.generic_error_user_friendly'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                invalidatePaginatedClientTabs(ref);
                ref.invalidate(clientsFullListProvider);
                ref.invalidate(agencyNamesMapProvider);
              },
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horní lišta – titulek, vyhledávání, tlačítko Přidat klienta.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
    required this.portalFilter,
    required this.noEmailFilter,
    required this.onPortalFilterChanged,
    required this.onNoEmailFilterChanged,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;
  final bool portalFilter;
  final bool noEmailFilter;
  final ValueChanged<bool> onPortalFilterChanged;
  final ValueChanged<bool> onNoEmailFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'clients.title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  decoration: InputDecoration(
                    hintText: 'admin.apartments_search_hint'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: context.colors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 20),
                label: Text('clients.add_new'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('admin.clients_filter_portal_access'.tr()),
                selected: portalFilter,
                onSelected: onPortalFilterChanged,
              ),
              FilterChip(
                label: Text('admin.clients_filter_no_email'.tr()),
                selected: noEmailFilter,
                onSelected: onNoEmailFilterChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Responzivní grid – dlaždice s [premiumCardDecoration] (stejný standard jako nástěnka).
class _ClientsCardList extends StatelessWidget {
  const _ClientsCardList({
    required this.clients,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClientModel> clients;
  final ScrollController scrollController;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.md);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        controller: scrollController,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500,
          mainAxisExtent: 100,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: clients.length,
        itemBuilder: (context, index) {
          final c = clients[index];
          return ClipRRect(
            borderRadius: radius,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onEdit(c),
                borderRadius: radius,
                child: Ink(
                  decoration: premiumCardDecoration(context),
                  child: _ClientListTile(
                    client: c,
                    onDelete: onDelete,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kompaktní řádek klienta – avatar, jméno + badge typu, email/telefon, akce.
/// Pro majitel s profile_id==null zobrazí oranžovou ikonku "Čeká na aktivaci".
class _ClientListTile extends ConsumerWidget {
  const _ClientListTile({
    required this.client,
    required this.onDelete,
  });

  final ClientModel client;
  final ValueChanged<ClientModel> onDelete;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isEmpty ? '?' : parts[0].substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static Color _badgeColor(String? clientType) {
    switch (clientType?.toLowerCase()) {
      case 'owner':
        return Colors.teal.shade700;
      case 'external':
        return Colors.blue.shade700;
      case 'agency':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = (client.clientType?.toLowerCase() ?? '') == 'owner';
    final hasProfileId =
        client.profileId != null && client.profileId!.trim().isNotEmpty;
    final awaitingActivation = isOwner && !hasProfileId;

    final email = (client.email ?? '').trim();
    final phone = (client.phone ?? '').trim();
    final subtitleParts = <String>[];
    if (email.isNotEmpty) subtitleParts.add(email);
    if (phone.isNotEmpty) subtitleParts.add(phone);
    final subtitle = subtitleParts.isEmpty ? '–' : subtitleParts.join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  _initials(client.name),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            client.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _badgeColor(client.clientType)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _clientTypeLabel(context, client.clientType),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: _badgeColor(client.clientType),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (awaitingActivation) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'clients.portal_pending'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (isOwner && hasProfileId)
                      _CompactOwnerMeta(profileId: client.profileId!),
                    if ((client.clientType?.toLowerCase() ?? '') == 'agency')
                      _CompactAgencyMeta(agencyId: client.id),
                    if ((client.clientType?.toLowerCase() ?? '') == 'external' &&
                        client.agencyId != null &&
                        client.agencyId!.trim().isNotEmpty)
                      _CompactExternalAgencyMeta(agencyId: client.agencyId!),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => onDelete(client),
                tooltip: 'admin.apartments_delete'.tr(),
              ),
            ],
          ),
    );
  }
}

/// Kompaktní meta pro majitele s profile_id – stav portálu nebo počet apartmánů.
class _CompactOwnerMeta extends ConsumerWidget {
  const _CompactOwnerMeta({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(clientPortalStatusProvider(profileId));
    final countsAsync = ref.watch(ownerApartmentCountsProvider);
    return statusAsync.when(
      data: (data) {
        if (data == null) {
          return _apartmentCount(context,
              countsAsync.valueOrNull?[profileId] ?? 0);
        }
        final status = (data['status']?.toString() ?? 'pending').toLowerCase();
        if (status == 'pending') {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 12, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'clients.portal_pending'.tr(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          );
        }
        return _apartmentCount(context,
            countsAsync.valueOrNull?[profileId] ?? 0);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _apartmentCount(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.apartment, size: 12, color: Colors.teal.shade700),
          const SizedBox(width: 4),
          Text(
            'clients.apartments_count'.tr(namedArgs: {'count': '$count'}),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

/// Kompaktní meta pro agenturu – počet doporučených externích klientů.
///
/// PROČ: Administrátor na první pohled vidí, kolik klientů daná agentura přivedla.
/// Počet doporučení z [recommendedClientsCountByAgencyProvider] (COUNT na serveru).
class _CompactAgencyMeta extends ConsumerWidget {
  const _CompactAgencyMeta({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync =
        ref.watch(recommendedClientsCountByAgencyProvider(agencyId));
    return recommendedAsync.when(
      data: (count) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 12, color: Colors.purple.shade700),
              const SizedBox(width: 4),
              Text(
                'clients.card_recommended_count'.tr(namedArgs: {'count': '$count'}),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Kompaktní meta pro externího klienta s agencyId – název doporučující agentury.
///
/// PROČ: Ukazuje, kdo nám klienta přivedl (např. "Pepa – doporučila agentura David").
/// Bez agencyId se nezobrazuje nic – viz podmínka v _ClientListTile.
class _CompactExternalAgencyMeta extends ConsumerWidget {
  const _CompactExternalAgencyMeta({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapAsync = ref.watch(agencyNamesMapProvider);
    return mapAsync.when(
      data: (map) {
        final name = (map[agencyId] ?? '').trim().isEmpty
            ? '–'
            : map[agencyId]!.trim();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.handshake_outlined, size: 12, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'clients.card_recommended_by_agency'.tr(namedArgs: {'name': name}),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

