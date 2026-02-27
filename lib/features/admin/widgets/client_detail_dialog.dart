import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/features/admin/admin_apartments_screen.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/widgets/client_form_dialog.dart';

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
/// Zobrazuje se po kliknutí na kartu klienta v seznamu. Obsahuje záložky
/// (Přehled, Apartmány). Přehled zobrazuje základní údaje, Apartmány načítá
/// seznam bytů lazy-loaded dotazem (apartmentsForProfileProvider).
class ClientDetailDialog extends ConsumerWidget {
  const ClientDetailDialog({
    super.key,
    required this.client,
  });

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(client: client),
            Flexible(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'clients.client_tab_overview'.tr()),
                        Tab(text: 'clients.client_tab_apartments'.tr()),
                        Tab(text: 'clients.client_tab_reservations'.tr()),
                        Tab(text: 'clients.client_tab_tasks'.tr()),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _OverviewTab(client: client),
                          _ApartmentsTab(client: client),
                          _ReservationsTab(client: client),
                          _TasksTab(client: client),
                        ],
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
}

/// Hlavička dialogu – jméno klienta vlevo, tužka a X vpravo.
class _DialogHeader extends ConsumerWidget {
  const _DialogHeader({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              client.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'admin.apartments_edit'.tr(),
            onPressed: () => _showEditDialog(context, ref),
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
          ref.invalidate(clientsProvider);
        },
      ),
    );
  }
}

/// Tab Přehled – základní údaje klienta.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'clients.email'.tr(),
            value: (client.email ?? '').trim().isEmpty ? '–' : client.email!,
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'clients.phone'.tr(),
            value: (client.phone ?? '').trim().isEmpty ? '–' : client.phone!,
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.business_outlined,
            label: 'clients.type'.tr(),
            value: _clientTypeLabel(context, client.clientType),
          ),
          if ((client.clientType?.toLowerCase() ?? '') == 'owner' &&
              client.profileId != null &&
              client.profileId!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _PortalStatusSection(profileId: client.profileId!),
          ],
          if ((client.clientType?.toLowerCase() ?? '') == 'owner' &&
              client.profileId != null &&
              client.profileId!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _ApartmentsCountSection(profileId: client.profileId!),
          ],
        ],
      ),
    );
  }
}

/// Jeden řádek v detailu – ikona, label, hodnota.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
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
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (status == 'pending') ...[
                  Icon(Icons.schedule, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'clients.portal_pending'.tr(),
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (inviteLink != null && inviteLink.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.copy, size: 18, color: Colors.teal.shade700),
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
                  Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'clients.portal_active'.tr(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (lastLogin != null) ...[
                    const SizedBox(width: 12),
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
          const SizedBox(width: 8),
          Text('common.loading'.tr(), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
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
      error: (_, __) => const SizedBox.shrink(),
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
          padding: const EdgeInsets.all(24),
          child: Text(
            'clients.no_owner_profile'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final apartmentsAsync = ref.watch(apartmentsForProfileProvider(client.profileId!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('clients.btn_add_apartment_context'.tr()),
              onPressed: () {
                showAddApartmentDialog(
                  context,
                  ref,
                  prefilledClient: client,
                  onSaved: () {
                    ref.invalidate(apartmentsProvider);
                    ref.invalidate(apartmentsForProfileProvider(client.profileId!));
                  },
                );
              },
            ),
          ),
        ),
        Expanded(
          child: apartmentsAsync.when(
            data: (apartments) {
              if (apartments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'clients.apartments_empty'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apartments.length,
                itemBuilder: (context, index) {
                  final apt = apartments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.apartment, color: Colors.teal.shade700),
                      title: Text(apt.name),
                      subtitle: apt.address != null && apt.address!.trim().isNotEmpty
                          ? Text(apt.address!, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showApartmentEditDialog(context, ref, apt, onSaved: () {
                          ref.invalidate(apartmentsProvider);
                          ref.invalidate(apartmentsForProfileProvider(client.profileId!));
                        });
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, __) => Center(
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
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
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
}

/// Tab Rezervace – seznam rezervací souvisejících s klientem (pouze pro majitele).
///
/// Používá clientReservationsProvider, který načte rezervace přes byty přiřazené
/// majiteli (apartment_owners → reservations). Pro externí/agency klienty vrací
/// prázdný seznam (tab zůstane prázdný).
class _ReservationsTab extends ConsumerWidget {
  const _ReservationsTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(clientReservationsProvider(client.id));
    final isOwner = (client.clientType?.toLowerCase() ?? '') == 'owner' &&
        client.profileId != null &&
        client.profileId!.trim().isNotEmpty;
    final apartmentsAsync = isOwner ? ref.watch(apartmentsForProfileProvider(client.profileId!)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('clients.btn_add_reservation_context'.tr()),
                onPressed: () async {
                  final apartments = apartmentsAsync?.valueOrNull ?? [];
                  final firstApartmentId = apartments.isNotEmpty ? apartments.first.id : null;
                  if (!context.mounted) return;
                  AdminReservationsScreen.showAddReservationDialog(
                    context,
                    ref,
                    initialApartmentId: firstApartmentId,
                    onSaved: () => ref.invalidate(clientReservationsProvider(client.id)),
                  );
                },
              ),
            ),
          ),
        Expanded(
          child: reservationsAsync.when(
            data: (reservations) {
              if (reservations.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'clients.client_no_reservations'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  final r = reservations[index];
                  final term = [
                    r.checkIn ?? '–',
                    r.checkOut ?? '–',
                  ].join(' – ');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.calendar_month, color: Colors.teal.shade700),
                      title: Text(term),
                      subtitle: Text(
                        [
                          (r.guestName ?? '').trim().isNotEmpty ? r.guestName! : '–',
                          reservationStatusLabelKey(r.status).tr(),
                        ].join(' • '),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        AdminReservationsScreen.showEditReservationDialog(
                          context,
                          ref,
                          r,
                          onSaved: () => ref.invalidate(clientReservationsProvider(client.id)),
                        );
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, __) => Center(
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
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
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
}

/// Mapování stavu úkolu na systémový klíč pro i18n (task_status.*).
String _taskStatusKey(String? status) {
  if (status == null || status.trim().isEmpty) return 'task_status.pending';
  final s = status.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') return 'task_status.pending';
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') return 'task_status.assigned';
  if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress';
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') return 'task_status.completed';
  if (s == 'problém' || s == 'problem' || s == 'issue') return 'task_status.problem';
  return 'task_status.pending';
}

/// Tab Úkoly – seznam úkolů souvisejících s klientem.
///
/// Pro majitele: úkoly na jeho bytech. Pro externí/agency: úkoly s client_id.
class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.client});

  final ClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(clientTasksProvider(client.id));
    final isOwner = (client.clientType?.toLowerCase() ?? '') == 'owner' &&
        client.profileId != null &&
        client.profileId!.trim().isNotEmpty;
    final apartmentsAsync = isOwner ? ref.watch(apartmentsForProfileProvider(client.profileId!)) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text('clients.btn_add_task_context'.tr()),
              onPressed: () {
                if (isOwner) {
                  final apartments = apartmentsAsync?.valueOrNull ?? [];
                  final firstApartmentId = apartments.isNotEmpty ? apartments.first.id : null;
                  AdminTasksScreen.showAddTaskDialog(
                    context,
                    ref,
                    initialApartmentId: firstApartmentId,
                    onSaved: () => ref.invalidate(clientTasksProvider(client.id)),
                  );
                } else {
                  AdminTasksScreen.showAddTaskDialog(
                    context,
                    ref,
                    initialClientId: client.id,
                    onSaved: () => ref.invalidate(clientTasksProvider(client.id)),
                  );
                }
              },
            ),
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'clients.client_no_tasks'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final t = tasks[index];
                  final displayTitle = (t.customTitle ?? t.title).trim().isNotEmpty
                      ? (t.customTitle ?? t.title)
                      : (t.apartmentName ?? t.apartmentId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.task_alt, color: Colors.teal.shade700),
                      title: Text(displayTitle, overflow: TextOverflow.ellipsis),
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
                          onSaved: () => ref.invalidate(clientTasksProvider(client.id)),
                        );
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, __) => Center(
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
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
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
}
