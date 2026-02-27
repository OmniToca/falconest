import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filtruje klienty podle vyhledávacího dotazu – jméno, email, telefon.
  List<ClientModel> _computeFiltered(List<ClientModel> clients) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return clients;
    return clients.where((c) {
      final name = (c.name).toLowerCase();
      final email = (c.email ?? '').toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);

    return Scaffold(
      body: clientsAsync.when(
        data: (clients) {
          final filtered = _computeFiltered(clients);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopActionBar(
                searchController: _searchController,
                onSearchChanged: () => setState(() {}),
                onAdd: () => _showAddDialog(context, ref),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'clients.empty_list'.tr()
                              : 'admin.apartments_search_no_results'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : _ClientsCardList(
                        clients: filtered,
                        onEdit: (c) => _showClientDetail(context, ref, c),
                        onDelete: (c) => _showDeleteConfirm(context, ref, c),
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
                'common.error_with_message'.tr(
                  namedArgs: {'message': err.toString()},
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(clientsProvider),
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
        onSaved: () => ref.invalidate(clientsProvider),
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

/// Minimální výška karty klienta – sjednocuje výšku karet bez ohledu na
/// to, zda má majitel zobrazen stavový řádek portálu (_ClientPortalStatusRow).
/// Pojme i případ s načítáním/active+last_login.
const double _kClientCardMinHeight = 220;

/// Mřížka karet klientů – shodná struktura jako _ApartmentsCardList.
class _ClientsCardList extends StatelessWidget {
  const _ClientsCardList({
    required this.clients,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClientModel> clients;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth * 0.025;
        final availableWidth =
            constraints.maxWidth - (horizontalPadding * 2);
        const spacing = 16.0;
        final isWide = constraints.maxWidth > 800;
        final cardWidth =
            isWide ? (availableWidth - spacing) / 2 : availableWidth;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: clients
                .map(
                  (c) => ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: cardWidth,
                      maxWidth: cardWidth,
                      minHeight: _kClientCardMinHeight,
                    ),
                    child: _ClientCard(
                      client: c,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// Jedna karta klienta – jméno, email, telefon, typ klienta.
/// Pro majitele (clientType=owner) s profile_id zobrazuje živý stav Klientského portálu.
class _ClientCard extends ConsumerWidget {
  const _ClientCard({
    required this.client,
    required this.onEdit,
    required this.onDelete,
  });

  final ClientModel client;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => onEdit(client),
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.teal.shade100,
                child: Icon(Icons.person, size: 28, color: Colors.teal.shade800),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      text: (client.email ?? '').trim().isEmpty
                          ? '–'
                          : client.email!,
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      text: (client.phone ?? '').trim().isEmpty
                          ? '–'
                          : client.phone!,
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.business_outlined,
                      text: _clientTypeLabel(context, client.clientType),
                    ),
                    if ((client.clientType?.toLowerCase() ?? '') == 'owner' &&
                        client.profileId != null &&
                        client.profileId!.trim().isNotEmpty)
                      _ClientPortalStatusRow(profileId: client.profileId!),
                    if ((client.clientType?.toLowerCase() ?? '') == 'owner' &&
                        client.profileId != null &&
                        client.profileId!.trim().isNotEmpty)
                      _OwnerApartmentsCountRow(profileId: client.profileId!),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: Colors.grey.shade700),
                        const SizedBox(width: 12),
                        Text('admin.apartments_edit'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Text(
                          'admin.apartments_delete'.tr(),
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit(client);
                  } else if (value == 'delete') {
                    onDelete(client);
                  }
                },
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

/// Řádek s počtem apartmánů majitele – čte synchronně z přednačtené Mapy.
/// Zobrazuje se pouze při úspěšně načtených datech (loading/error = prázdný řádek).
class _OwnerApartmentsCountRow extends ConsumerWidget {
  const _OwnerApartmentsCountRow({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(ownerApartmentCountsProvider);
    return countsAsync.when(
      data: (map) {
        final count = map[profileId] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.apartment, size: 16, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                'clients.apartments_count'.tr(namedArgs: {'count': '$count'}),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Řádek se stavem Klientského portálu pro majitele s profile_id.
/// Zobrazuje pending/active stav a možnost zkopírovat zvací odkaz.
class _ClientPortalStatusRow extends ConsumerWidget {
  const _ClientPortalStatusRow({required this.profileId});

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
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (status == 'pending') ...[
                Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'clients.portal_pending'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (inviteLink != null && inviteLink.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: Colors.teal.shade700),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'clients.copy_invite_link'.tr(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('clients.link_copied'.tr()),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
              ] else ...[
                Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'clients.portal_active'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (lastLogin != null)
                        Text(
                          'clients.portal_last_login'.tr(
                            namedArgs: {
                              'date': DateFormat.yMd(context.locale.toString())
                                  .add_Hm()
                                  .format(lastLogin.toLocal()),
                            },
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'common.loading'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Řádek s ikonou a textem – sdílená komponenta pro karty.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade800,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
