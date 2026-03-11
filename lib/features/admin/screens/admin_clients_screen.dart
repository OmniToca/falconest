import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/widgets/client_form_dialog.dart';
import 'package:falconest/features/admin/widgets/client_detail_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController1.addListener(() => _onScroll(_scrollController1));
    _scrollController2.addListener(() => _onScroll(_scrollController2));
    _scrollController3.addListener(() => _onScroll(_scrollController3));
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

  /// Při scrollu ke konci (0.9 * maxScrollExtent) načte další stránku.
  void _onScroll(ScrollController controller) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.9) {
      ref.read(clientsProvider.notifier).loadMore();
    }
  }

  /// Server-side vyhledávání s debounce 500 ms – neposílá dotaz při každém stisku.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      ref.read(clientsProvider.notifier).search(query);
    });
  }

  /// Rozdělí klienty do 3 skupin podle client_type.
  /// owner = majitelé, agency = agentury, external = externí + staré záznamy (null).
  void _splitByType(
    List<ClientModel> filtered,
    List<ClientModel> ownerClients,
    List<ClientModel> agencyClients,
    List<ClientModel> externalClients,
  ) {
    ownerClients.clear();
    agencyClients.clear();
    externalClients.clear();
    for (final c in filtered) {
      final t = c.clientType?.toLowerCase();
      if (t == 'owner') {
        ownerClients.add(c);
      } else if (t == 'agency') {
        agencyClients.add(c);
      } else {
        // external nebo null (staré záznamy bez client_type)
        externalClients.add(c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final loadingMore = ref.watch(clientsLoadingMoreProvider);

    return Scaffold(
      body: clientsAsync.when(
        data: (clients) {
          final ownerClients = <ClientModel>[];
          final agencyClients = <ClientModel>[];
          final externalClients = <ClientModel>[];
          _splitByType(clients, ownerClients, agencyClients, externalClients);

          return DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopActionBar(
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onAdd: () => _showAddDialog(context, ref),
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
                        clients: ownerClients,
                        searchQuery: _searchController.text.trim(),
                        scrollController: _scrollController1,
                        isLoadingMore: loadingMore,
                        onEdit: (c) => _showClientDetail(context, ref, c),
                        onDelete: (c) => _showDeleteConfirm(context, ref, c),
                      ),
                      _ClientsTabContent(
                        clients: agencyClients,
                        searchQuery: _searchController.text.trim(),
                        scrollController: _scrollController2,
                        isLoadingMore: loadingMore,
                        onEdit: (c) => _showClientDetail(context, ref, c),
                        onDelete: (c) => _showDeleteConfirm(context, ref, c),
                      ),
                      _ClientsTabContent(
                        clients: externalClients,
                        searchQuery: _searchController.text.trim(),
                        scrollController: _scrollController3,
                        isLoadingMore: loadingMore,
                        onEdit: (c) => _showClientDetail(context, ref, c),
                        onDelete: (c) => _showDeleteConfirm(context, ref, c),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                'common.error_with_message'.tr(
                  namedArgs: {'message': err.toString()},
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(clientsProvider);
                  ref.invalidate(clientsFullListProvider);
                },
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
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
                  ref.invalidate(clientsProvider);
                  ref.invalidate(clientsFullListProvider);
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
                  ref.invalidate(clientsProvider);
                  ref.invalidate(clientsFullListProvider);
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

/// Obsah jedné záložky – Grid karet nebo prázdný stav. Podporuje scroll controller a indikátor načítání další stránky.
class _ClientsTabContent extends StatelessWidget {
  const _ClientsTabContent({
    required this.clients,
    required this.searchQuery,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClientModel> clients;
  final String searchQuery;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty && !isLoadingMore) {
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
    return Column(
      children: [
        Expanded(
          child: _ClientsCardList(
            clients: clients,
            scrollController: scrollController,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
        if (isLoadingMore)
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
  }
}

/// Horní lišta – titulek, vyhledávání, tlačítko Přidat klienta.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
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
                fillColor: Colors.white,
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
    );
  }
}

/// Responzivní Grid klientů – maxCrossAxisExtent 500 (mobil 1 sloupec, desktop 2–3).
/// Každá buňka je Card s klikacím řádkem (onTap = úprava) a ikonou koše.
/// [scrollController] slouží pro nekonečný scroll (loadMore při dosažení konce).
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
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _ClientListTile(
              client: c,
              onEdit: onEdit,
              onDelete: onDelete,
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
    required this.onEdit,
    required this.onDelete,
  });

  final ClientModel client;
  final ValueChanged<ClientModel> onEdit;
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

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => onEdit(client),
        child: Padding(
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
        ),
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
/// Načítá clientsRecommendedByAgencyProvider – klienti s agency_id = tato agentura.
class _CompactAgencyMeta extends ConsumerWidget {
  const _CompactAgencyMeta({required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(clientsRecommendedByAgencyProvider(agencyId));
    return recommendedAsync.when(
      data: (clients) {
        final count = clients.length;
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
    final clientsAsync = ref.watch(clientsFullListProvider);
    return clientsAsync.when(
      data: (clients) {
        final agency = clients.where((c) => c.id == agencyId).firstOrNull;
        final name = agency?.name.trim() ?? '–';
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

