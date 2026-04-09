import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart'
    show ReservationRow;
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';

/// Rychlé přechody z detailu úkolu na související entity (SaaS cross-linking).
///
/// PROČ: Dispečer nemusí ručně hledat byt/rezervaci/klienta – jedním klikem zavře dialog,
/// přepne záložku a cílová obrazovka otevře stejný detail jako při kliknutí v seznamu.
class AdminTaskCrossLinkRow extends ConsumerWidget {
  const AdminTaskCrossLinkRow({super.key, required this.task});

  final TaskRow task;

  void _jump(
    BuildContext context,
    WidgetRef ref, {
    required int tabIndex,
    required void Function() armPending,
  }) {
    Navigator.of(context).pop();
    ref.read(adminTabJumpRequestProvider.notifier).state = tabIndex;
    armPending();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];
    final aptId = task.apartmentId.trim();
    if (aptId.isNotEmpty) {
      chips.add(
        TextButton.icon(
          onPressed: () => _jump(
            context,
            ref,
            tabIndex: adminTabIndexApartments,
            armPending: () =>
                ref.read(adminCrossNavPendingProvider.notifier).openApartment(aptId),
          ),
          icon: const Icon(Icons.apartment_outlined, size: 18),
          label: Text('admin.common.go_to_apartment'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }
    final resId = task.reservationId?.trim();
    if (resId != null && resId.isNotEmpty) {
      chips.add(
        TextButton.icon(
          onPressed: () => _jump(
            context,
            ref,
            tabIndex: adminTabIndexReservations,
            armPending: () => ref
                .read(adminCrossNavPendingProvider.notifier)
                .openReservation(resId),
          ),
          icon: const Icon(Icons.event_note_outlined, size: 18),
          label: Text('admin.common.go_to_reservation'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }
    final clientId = task.clientId?.trim();
    if (clientId != null && clientId.isNotEmpty) {
      chips.add(
        TextButton.icon(
          onPressed: () => _jump(
            context,
            ref,
            tabIndex: adminTabIndexClients,
            armPending: () =>
                ref.read(adminCrossNavPendingProvider.notifier).openClient(clientId),
          ),
          icon: const Icon(Icons.person_outline, size: 18),
          label: Text('admin.common.go_to_client'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.hub_outlined, size: 18, color: context.colors.onSurfaceVariant),
          Text(
            'admin.common.cross_links_section'.tr(),
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          ...chips,
        ],
      ),
    );
  }
}

/// Rychlé přechody z detailu rezervace na apartmán a na klienta-majitele (dle apartment_owners).
///
/// PROČ: Rezervace nemá přímo client_id; majitele odvodíme z primární fakturace na bytu,
/// aby CRM dialog odpovídal reálnému vztahu „byt → majitel“.
class AdminReservationCrossLinkRow extends ConsumerWidget {
  const AdminReservationCrossLinkRow({super.key, required this.reservation});

  final ReservationRow reservation;

  void _jump(
    BuildContext context,
    WidgetRef ref, {
    required int tabIndex,
    required void Function() armPending,
  }) {
    Navigator.of(context).pop();
    ref.read(adminTabJumpRequestProvider.notifier).state = tabIndex;
    armPending();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aptId = reservation.apartmentId.trim();
    if (aptId.isEmpty) return const SizedBox.shrink();

    final ownersAsync = ref.watch(apartmentOwnersForApartmentProvider(aptId));
    final clientsAsync = ref.watch(clientsFullListProvider);

    final chips = <Widget>[
      TextButton.icon(
        onPressed: () => _jump(
          context,
          ref,
          tabIndex: adminTabIndexApartments,
          armPending: () =>
              ref.read(adminCrossNavPendingProvider.notifier).openApartment(aptId),
        ),
        icon: const Icon(Icons.apartment_outlined, size: 18),
        label: Text('admin.common.go_to_apartment'.tr()),
        style: TextButton.styleFrom(
          foregroundColor: context.colors.primary,
          visualDensity: VisualDensity.compact,
        ),
      ),
    ];

    String? ownerClientId;
    final owners = ownersAsync.valueOrNull;
    final clients = clientsAsync.valueOrNull;
    if (owners != null && clients != null) {
      final primary =
          owners.firstWhereOrNull((o) => o.isPrimaryBilling) ?? owners.firstOrNull;
      if (primary != null) {
        final client = clients.firstWhereOrNull(
          (c) => c.profileId != null && c.profileId == primary.ownerId,
        );
        ownerClientId = client?.id;
      }
    }

    if (ownerClientId != null && ownerClientId.isNotEmpty) {
      // PROČ: Dart nepromuje String? uvnitř closure – lokální kopie pro [openClient].
      final resolvedClientId = ownerClientId;
      chips.add(
        TextButton.icon(
          onPressed: () => _jump(
            context,
            ref,
            tabIndex: adminTabIndexClients,
            armPending: () => ref
                .read(adminCrossNavPendingProvider.notifier)
                .openClient(resolvedClientId),
          ),
          icon: const Icon(Icons.person_outline, size: 18),
          label: Text('admin.common.go_to_client'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.hub_outlined, size: 18, color: context.colors.onSurfaceVariant),
          Text(
            'admin.common.cross_links_section'.tr(),
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          ...chips,
        ],
      ),
    );
  }
}
