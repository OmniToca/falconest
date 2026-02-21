import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Jemné barvy pro prémiový design – konzistentní s owner_layout.
const _cleanColor = Color(0xFF2E7D32);
const _cleaningColor = Color(0xFF1976D2);
const _pendingColor = Color(0xFFC62828);
const _unknownColor = Color(0xFF757575);

/// Přehled apartmánů majitele s aktuálním stavem úklidu.
///
/// Data se načítají přes [ownerApartmentsProvider] – Supabase vrací byty
/// s vnořenými úkoly. Stav bytu se určuje z nejnovějšího úkolu (completed
/// → Čistý, in_progress → Probíhá úklid, pending → Čeká na úklid).
class OwnerApartmentsScreen extends ConsumerWidget {
  const OwnerApartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartmentsAsync = ref.watch(ownerApartmentsProvider);

    return Scaffold(
      body: apartmentsAsync.when(
        data: (apartments) => _buildContent(context, apartments),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _buildError(context, ref),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<OwnerApartmentWithStatus> apartments,
  ) {
    if (apartments.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: apartments.length,
      itemBuilder: (context, index) {
        return _ApartmentCard(apartment: apartments[index]);
      },
    );
  }

  /// Prázdný stav – majitel nemá přiřazeny žádné byty.
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'owner.apartments_empty'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Chybový stav s možností obnovit.
  Widget _buildError(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 24),
            Text(
              'owner.apartments_load_error'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(ownerApartmentsProvider),
              icon: const Icon(Icons.refresh),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta bytu – prémiový design s názvem, adresou a barevným štítkem stavu.
class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({required this.apartment});

  final OwnerApartmentWithStatus apartment;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusStyle(apartment.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apartment.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (apartment.address != null &&
                          apartment.address!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          apartment.address!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _StatusChip(
                  label: _getStatusLabel(apartment.status),
                  color: color,
                  icon: icon,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _getStatusStyle(OwnerApartmentStatus status) {
    switch (status) {
      case OwnerApartmentStatus.clean:
        return (_cleanColor, Icons.check_circle);
      case OwnerApartmentStatus.cleaningInProgress:
        return (_cleaningColor, Icons.cleaning_services);
      case OwnerApartmentStatus.pendingCleaning:
        return (_pendingColor, Icons.schedule);
      case OwnerApartmentStatus.unknown:
        return (_unknownColor, Icons.help_outline);
    }
  }

  String _getStatusLabel(OwnerApartmentStatus status) {
    switch (status) {
      case OwnerApartmentStatus.clean:
        return 'owner.status_clean'.tr();
      case OwnerApartmentStatus.cleaningInProgress:
        return 'owner.status_cleaning'.tr();
      case OwnerApartmentStatus.pendingCleaning:
        return 'owner.status_pending'.tr();
      case OwnerApartmentStatus.unknown:
        return 'owner.status_unknown'.tr();
    }
  }
}

/// Barevný štítek stavu – Chip s ikonou.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
