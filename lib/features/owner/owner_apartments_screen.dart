import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/owner/owner_apartment_detail_screen.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservations_provider.dart';
import 'package:falconest/features/owner/widgets/owner_report_issue_dialog.dart';

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
    final apartments = apartmentsAsync.valueOrNull ?? [];
    final profileId = ref.read(authNotifierProvider).state.profileId ?? '';

    return Scaffold(
      body: apartmentsAsync.when(
        data: (apartments) => _buildContent(context, apartments),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _buildError(context, ref),
      ),
      floatingActionButton: apartments.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openOwnerReportIssueDialog(
                context,
                apartments: apartments,
                profileId: profileId,
              ),
              icon: const Icon(Icons.report_problem_outlined),
              label: Text('owner.report_issue_btn'.tr()),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 380).floor().clamp(1, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.85,
          ),
          itemCount: apartments.length,
          itemBuilder: (context, index) {
            return _PropertyCard(
              apartment: apartments[index],
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: OwnerApartmentDetailScreen(
                      apartmentId: apartments[index].id,
                    ),
                  ),
                ),
              ),
            );
          },
        );
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

// FEATURE: Výpočet obsazenosti pro aktuální měsíc (teploměr).
/// Vrací (počet obsazených dní, celkový počet dní v měsíci).
/// Nezahrnuje zrušené rezervace, řeší průnik rezervace se začátkem/koncem měsíce.
(int, int) _computeMonthlyOccupancy(
  String apartmentId,
  List<OwnerReservation> reservations,
  DateTime now,
) {
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month, daysInMonth);

  final occupiedDays = <int>{};
  for (final r in reservations) {
    if (r.apartmentId != apartmentId) continue;
    if (r.status == 'cancelled') continue;

    final resStart = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
    final resEnd = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);

    final overlapStart = resStart.isBefore(monthStart) ? monthStart : resStart;
    final overlapEnd = resEnd.isAfter(monthEnd) ? monthEnd : resEnd;
    if (overlapStart.isAfter(overlapEnd)) continue;

    for (var d = overlapStart; !d.isAfter(overlapEnd); d = d.add(const Duration(days: 1))) {
      occupiedDays.add(d.day);
    }
  }
  return (occupiedDays.length, daysInMonth);
}

// FEATURE: Získání 3 nejbližších rezervací pro rychlý přehled na kartě.
/// Filtruje platné rezervace (ne zrušené), endDate >= dnes, řadí podle startDate vzestupně.
List<OwnerReservation> _getUpcomingReservations(
  String apartmentId,
  List<OwnerReservation> reservations,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final filtered = reservations.where((r) {
    if (r.apartmentId != apartmentId || r.status == 'cancelled') return false;
    final endDay = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
    return !endDay.isBefore(today);
  }).toList();
  filtered.sort((a, b) => a.startDate.compareTo(b.startDate));
  return filtered.take(3).toList();
}

/// Krátký formát data pro výpis rezervace: 15.3. - 20.3.
String _formatDateRange(OwnerReservation r) {
  final from = '${r.startDate.day}.${r.startDate.month}.';
  final to = '${r.endDate.day}.${r.endDate.month}.';
  return '$from – $to';
}

// UI: Moderní Property Card pro Klientský portál.
/// Karta nemovitosti – hlavička s ikonou, tělo s názvem/adresou/statusem,
/// teploměr obsazenosti, patička s proklikem na detail.
class _PropertyCard extends ConsumerWidget {
  const _PropertyCard({required this.apartment, required this.onTap});

  final OwnerApartmentWithStatus apartment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hlavička – barevný placeholder simulující fotku apartmánu (zkrácená)
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50,
                    Colors.blue.shade100,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.apartment,
                  size: 40,
                  color: Colors.blue.shade300,
                ),
              ),
            ),
            // Tělo karty – SingleChildScrollView zabraňuje přetečení při více datech
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apartment.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (apartment.address != null &&
                        apartment.address!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              apartment.address!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Status Chip – vpravo nahoře v těle karty
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildStatusChip(context, apartment.status),
                    ),
                    // Teploměr obsazenosti + nejbližší rezervace – data z ownerReservationsProvider
                    const SizedBox(height: 12),
                    _buildOccupancyAndUpcomingSection(context, ref),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Patička – proklik na detail
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'owner.show_apartment_detail'.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status Chip – barva podle stavu bytu (úklid).
  Widget _buildStatusChip(BuildContext context, OwnerApartmentStatus status) {
    final (color, icon) = _getStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            _getStatusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Teploměr obsazenosti + výpis 3 nejbližších rezervací.
  Widget _buildOccupancyAndUpcomingSection(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(ownerReservationsProvider);
    return reservationsAsync.when(
      data: (reservations) {
        final now = DateTime.now();
        final (occupied, total) = _computeMonthlyOccupancy(
          apartment.id,
          reservations,
          now,
        );
        final ratio = total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;
        // Barva: >= 70% zelená, 30–70% oranžová, < 30% červená
        final barColor = ratio >= 0.7
            ? Colors.green.shade400
            : ratio >= 0.3
                ? Colors.orange.shade400
                : Colors.red.shade400;

        final upcoming =
            _getUpcomingReservations(apartment.id, reservations, now);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Teploměr
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'owner.occupancy_this_month'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'owner.occupancy_days'.tr(
                    namedArgs: {'occupied': '$occupied', 'total': '$total'},
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final w = constraints.maxWidth * ratio;
                    return Stack(
                      children: [
                        if (w > 0)
                          Container(
                            width: w,
                            decoration: BoxDecoration(color: barColor),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Nejbližší rezervace
            const SizedBox(height: 16),
            Text(
              'owner.upcoming_reservations'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            if (upcoming.isEmpty)
              Text(
                'owner.no_upcoming_reservations'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              )
            else
              ...upcoming.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateRange(r),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (r.guestName != null && r.guestName!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.guestName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 22,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
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

