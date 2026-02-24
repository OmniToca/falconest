import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/apartment_service_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/apartment_status_provider.dart';
import 'package:falconest/features/admin/providers/zones_provider.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Možné stavy bytu – mapování na i18n.
const _statusKeys = {
  'Uklizeno': 'admin.status_cleaned',
  'K úklidu': 'admin.status_to_clean',
  'Obsazeno hosty': 'admin.status_occupied',
  'Probíhá úklid': 'admin.status_cleaning',
  'Rekonstrukce': 'admin.status_renovation',
};

/// Barvy štítků stavu – ladí s Kanbanem úkolů (zelená/červená/modrá).
/// Pozadí shade100, text odpovídající barvou.
(Color, Color) _statusChipColors(String? status) {
  final s = (status == null || status.isEmpty) ? 'Uklizeno' : status;
  switch (s) {
    case 'Uklizeno':
      return (Colors.green.shade100, Colors.green.shade800);
    case 'K úklidu':
      return (Colors.red.shade100, Colors.red.shade800);
    case 'Obsazeno hosty':
      return (Colors.blue.shade100, Colors.blue.shade800);
    case 'Probíhá úklid':
      return (Colors.orange.shade100, Colors.orange.shade800);
    case 'Rekonstrukce':
      return (Colors.grey.shade200, Colors.grey.shade800);
    default:
      return (Colors.green.shade100, Colors.green.shade800);
  }
}

/// Štítek stavu bytu – čistá pilulka (jemné barevné pozadí, tučný text), bez ostrého ohraničení.
Widget _buildStatusBadge(String? status) {
  final s = (status == null || status.isEmpty) ? 'Uklizeno' : status;
  final (bgColor, textColor) = _statusChipColors(s);
  final label = _statusKeys.containsKey(s) ? (_statusKeys[s]!).tr() : s;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
  );
}

/// Krátký formát pro kartu – 120 → '2h', 60 → '1h', 90 → '90 min'.
String _formatCleaningShort(int? minutes) {
  if (minutes == null || minutes <= 0) return '–';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '$minutes min';
}

/// Parsuje datum z formátu DD.MM.YYYY (checkIn/checkOut z ReservationRow).
DateTime? _parseReservationDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split('.');
  if (parts.length >= 3) {
    return DateTime(
      int.tryParse(parts[2]) ?? 0,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[0]) ?? 1,
    );
  }
  return DateTime.tryParse(s);
}

/// Výpočet obsazenosti apartmánu pro aktuální měsíc – počet dní, kdy je byt obsazen (deletedAt == null, status != cancelled).
(int occupied, int total) _computeMonthlyOccupancy(
  List<ReservationRow> reservations,
  String apartmentId,
  DateTime now,
) {
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month, daysInMonth);

  final occupiedDays = <int>{};
  for (final r in reservations) {
    if (r.apartmentId != apartmentId) continue;
    if (r.deletedAt != null) continue;
    if (r.status == 'cancelled') continue;

    final start = _parseReservationDate(r.checkIn);
    final end = _parseReservationDate(r.checkOut);
    if (start == null || end == null) continue;

    final resStart = DateTime(start.year, start.month, start.day);
    final resEnd = DateTime(end.year, end.month, end.day);

    final overlapStart = resStart.isBefore(monthStart) ? monthStart : resStart;
    final overlapEnd = resEnd.isAfter(monthEnd) ? monthEnd : resEnd;
    if (overlapStart.isAfter(overlapEnd)) continue;

    for (var d = overlapStart;
        !d.isAfter(overlapEnd);
        d = d.add(const Duration(days: 1))) {
      occupiedDays.add(d.day);
    }
  }
  return (occupiedDays.length, daysInMonth);
}

/// Administrativní správa apartmánů – desktopový B2B layout.
///
/// Top Action Bar: titulek, vyhledávání, tlačítko Přidat.
/// DataTable s checkboxy a PopupMenu (Upravit, Smazat).
/// Bulk Actions Bar při výběru položek.
class AdminApartmentsScreen extends ConsumerStatefulWidget {
  const AdminApartmentsScreen({super.key});

  @override
  ConsumerState<AdminApartmentsScreen> createState() =>
      _AdminApartmentsScreenState();
}

class _AdminApartmentsScreenState extends ConsumerState<AdminApartmentsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Vypočte filtrovaný seznam podle vyhledávacího dotazu – bez ukládání do stavu.
  List<ApartmentRow> _computeFiltered(List<ApartmentRow> apartments) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return apartments;
    return apartments.where((a) {
      final name = (a.name).toLowerCase();
      final addr = (a.address ?? '').toLowerCase();
      return name.contains(query) || addr.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: apartmentsAsync.when(
        data: (apartments) {
          final filtered = _computeFiltered(apartments);
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
                              ? 'admin.apartments_empty'.tr()
                              : 'admin.apartments_search_no_results'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : _ApartmentsCardList(
                        apartments: filtered,
                        onEdit: (a) => _showEditDialog(context, ref, a),
                        onDelete: (a) => _showDeleteConfirm(context, ref, a),
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
                'admin.apartments_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(apartmentsProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddApartmentDialog(
        ref: ref,
        onSaved: () => ref.invalidate(apartmentsProvider),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ApartmentRow apartment,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditApartmentDialog(
        ref: ref,
        apartment: apartment,
        onSaved: () => ref.invalidate(apartmentsProvider),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    ApartmentRow apartment,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.apartments_delete'.tr()),
        content: Text('admin.apartments_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => _doDelete(ctx, ref, [apartment]),
            child: Text('admin.apartments_delete'.tr()),
          ),
        ],
      ),
    );
  }

  /// Neprůstřelná kaskáda Soft Delete při mazání bytu – žádné sirotčí úkoly ani rezervace.
  ///
  /// KROK A: Najdeme VŠECHNY rezervace patřící tomuto bytu (apartment_id = id, deleted_at IS NULL).
  ///          Bez filtru na datum – mažeme i minulé rezervace, aby po bytu nezůstalo nic.
  /// KROK B: Najdeme VŠECHNY úkoly přímo přiřazené k tomuto bytu (apartment_id = id, deleted_at IS NULL).
  ///          Bez filtru na scheduled_start – včetně přenosů a úkolů v minulosti; jinak zůstávají „sirotčí“.
  /// KROK C: Pokud by tabulka tasks měla sloupec reservation_id, zde bychom našli úkoly napojené na
  ///          rezervace z (A) a přidali je do množiny k smazání. V aktuálním schématu tasks má pouze
  ///          apartment_id, tedy kroky A a B pokrývají všechny závislé entity.
  /// KROK D: Nad všemi nalezenými entitami (byt, rezervace z A, úkoly z B) provedeme tvrdý Soft Delete
  ///          (nastavení deleted_at na stejné UTC). ŽÁDNÉ Unassign (nastavení apartment_id/reservation_id
  ///          na null) – smazání bytu je destruktivní, úkoly jdou do koše s ním.
  /// Každá smazaná entita se zapíše do Enterprise Audit Logu (logEnterprise) s triggeredBy: cascade,
  /// record_name a reason z i18n.
  Future<void> _doDelete(
    BuildContext dialogContext,
    WidgetRef ref,
    List<ApartmentRow> apartments,
  ) async {
    try {
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      final userId = SupabaseService.client.auth.currentUser?.id;
      final cascadeReason = 'super_admin.audit_log_cascade_reason_apartment_deleted'.tr();

      for (final apartment in apartments) {
        final id = apartment.id;
        final previousState = Map<String, dynamic>.from(apartment.toMap())
          ..['id'] = apartment.id
          ..['tenant_id'] = apartment.tenantId;

        await SupabaseService.client
            .from('apartments')
            .update({'deleted_at': deletedAt})
            .eq('id', id);
        await AuditLogService.logEnterprise(
          tenantId: tenantId,
          userId: userId,
          actionType: 'SOFT_DELETE',
          tableName: 'apartments',
          recordId: id,
          recordName: apartment.name,
          previousState: previousState,
          triggeredBy: AuditTriggeredBy.manual,
        );

        if (tenantId == null || tenantId.isEmpty) continue;

        try {
          // A) Všechny rezervace tohoto bytu (bez filtru na datum)
          final resRows = await SupabaseService.client
              .from('reservations')
              .select('id, guest_name, start_date')
              .eq('apartment_id', id)
              .isFilter('deleted_at', null);
          final resList = resRows as List;

          for (final r in resList) {
            final map = Map<String, dynamic>.from(r as Map);
            final resId = map['id']?.toString().trim();
            if (resId == null || resId.isEmpty) continue;
            final guestName = (map['guest_name'] as String?)?.trim();
            final recordName = (guestName != null && guestName.isNotEmpty)
                ? guestName
                : 'super_admin.audit_log_reservation_fallback'.tr(
                    namedArgs: {'id': resId.length >= 8 ? resId.substring(0, 8) : resId});

            await SupabaseService.client
                .from('reservations')
                .update({'deleted_at': deletedAt})
                .eq('id', resId);
            await AuditLogService.logEnterprise(
              tenantId: tenantId,
              userId: userId,
              actionType: 'SOFT_DELETE_CASCADE',
              tableName: 'reservations',
              recordId: resId,
              recordName: recordName,
              triggeredBy: AuditTriggeredBy.cascade,
              reason: cascadeReason,
              extra: {'triggered_by': 'apartment', 'apartment_id': id},
            );
          }

          // B) Všechny úkoly přímo přiřazené k tomuto bytu (bez filtru na datum)
          final taskRows = await SupabaseService.client
              .from('tasks')
              .select('id, title')
              .eq('tenant_id', tenantId)
              .eq('apartment_id', id)
              .isFilter('deleted_at', null);
          final taskList = taskRows as List;

          for (final t in taskList) {
            final map = Map<String, dynamic>.from(t as Map);
            final taskId = map['id']?.toString().trim();
            if (taskId == null || taskId.isEmpty) continue;
            final title = (map['title'] as String?)?.trim();
            final recordName = (title != null && title.isNotEmpty)
                ? title
                : '${taskId.length >= 8 ? taskId.substring(0, 8) : taskId}…';

            await SupabaseService.client
                .from('tasks')
                .update({'deleted_at': deletedAt})
                .eq('id', taskId);
            await AuditLogService.logEnterprise(
              tenantId: tenantId,
              userId: userId,
              actionType: 'SOFT_DELETE_CASCADE',
              tableName: 'tasks',
              recordId: taskId,
              recordName: recordName,
              triggeredBy: AuditTriggeredBy.cascade,
              reason: cascadeReason,
              extra: {'triggered_by': 'apartment', 'apartment_id': id},
            );
          }
        } catch (_) {}
      }

      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      ref.invalidate(apartmentsProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminTasksProvider);
      ref.invalidate(planningCalendarAllTasksProvider);
      ref.invalidate(planningCalendarAllTasksForMonthProvider);
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('common.saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      // ignore: avoid_print
      print('--- CHYBA MAZÁNÍ APARTMÁNŮ: $e');
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

/// Top Action Bar – titulek, vyhledávání, tlačítko Přidat apartmán.
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
            'admin.apartments_title'.tr(),
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
            label: Text('admin.fab_add_apartment'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responzivní mřížka karet – 3 sloupce na desktopu, 2 na notebooku, 1 na mobilu (Apple Vibe).
class _ApartmentsCardList extends StatelessWidget {
  const _ApartmentsCardList({
    required this.apartments,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ApartmentRow> apartments;
  final ValueChanged<ApartmentRow> onEdit;
  final ValueChanged<ApartmentRow> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. Výpočet dynamického okraje (2.5 % z každé strany = 95 % šířky pro karty)
        final double horizontalPadding = constraints.maxWidth * 0.025;
        final double availableWidth =
            constraints.maxWidth - (horizontalPadding * 2);
        const double spacing = 16.0;

        // 2. Logika sloupců a šířky karet
        double cardWidth;
        if (constraints.maxWidth > 1200) {
          // 3 sloupce na velkém monitoru (2 mezery)
          cardWidth = (availableWidth - (spacing * 2)) / 3;
        } else if (constraints.maxWidth > 750) {
          // 2 sloupce na notebooku/tabletu (1 mezera)
          cardWidth = (availableWidth - spacing) / 2;
        } else {
          // 1 sloupec na mobilu
          cardWidth = availableWidth;
        }

        // Responzivní mřížka využívající 95 % šířky obrazovky bez zbytečných prázdných pruhů.
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            24,
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: apartments
                .map(
                  (apt) => SizedBox(
                    width: cardWidth,
                    child: _ApartmentCard(
                      apartment: apt,
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

/// Jedna karta apartmánu – design ladící s _MemberCard: ikona vlevo, informace, status pilulka, progress obsazenosti.
/// Celá karta je klikací (InkWell) – otevře dialog pro úpravu.
/// Stav bytu z apartmentStatusProvider, obsazenost z adminReservationsProvider.
class _ApartmentCard extends ConsumerWidget {
  const _ApartmentCard({
    required this.apartment,
    required this.onEdit,
    required this.onDelete,
  });

  final ApartmentRow apartment;
  final ValueChanged<ApartmentRow> onEdit;
  final ValueChanged<ApartmentRow> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addr = (apartment.address ?? '').trim();
    final keybox = (apartment.keybox ?? '').trim();
    final keyboxLabel = keybox.isEmpty
        ? 'admin.apartments_key_not_set'.tr()
        : keybox;
    final durationStr =
        _formatCleaningShort(apartment.standardCleaningDuration);
    final cleaningLabel =
        'admin.badge_cleaning'.tr(namedArgs: {'duration': durationStr});

    final reservationsAsync = ref.watch(adminReservationsProvider);
    final status = ref.watch(apartmentStatusProvider(apartment.id));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onEdit(apartment),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Levá část – barevný čtverec s ikonou apartmánu (jako avatar u Personálu)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.apartment,
                        size: 32,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Střední část – název a kompaktní podrobnosti (ikona + text)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apartment.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            text: addr.isEmpty ? '–' : addr,
                          ),
                          _InfoRow(
                            icon: Icons.vpn_key_outlined,
                            text: keyboxLabel,
                          ),
                          _InfoRow(
                            icon: Icons.timer_outlined,
                            text: cleaningLabel,
                          ),
                          // Výjimky v časech – odlišný check-in/out než standard 15:00 / 10:00
                          if ((apartment.checkInTime ?? '15:00') != '15:00' ||
                              (apartment.checkOutTime ?? '10:00') != '10:00') ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  size: 14,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'admin.apartments_time_exception'.tr(
                                    namedArgs: {
                                      'checkIn': apartment.checkInTime ?? '15:00',
                                      'checkOut': apartment.checkOutTime ?? '10:00',
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Pravý horní roh – pilulka statusu, pod ní ikona koše
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(status),
                        const SizedBox(height: 8),
                        IconButton(
                          onPressed: () => onDelete(apartment),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade700,
                          ),
                          tooltip: 'admin.apartments_delete'.tr(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Spodní část – Progress bar obsazenosti (jako kapacita u Personálu)
                reservationsAsync.when(
                  data: (reservations) {
                    final now = DateTime.now();
                    final (occupied, total) = _computeMonthlyOccupancy(
                      reservations,
                      apartment.id,
                      now,
                    );
                    final ratio = total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;
                    // Barva: < 0.3 červená (málo hostů), < 0.7 oranžová, >= 0.7 zelená (super byznys)
                    final barColor = ratio < 0.3
                        ? Colors.red.shade400
                        : ratio < 0.7
                            ? Colors.orange.shade400
                            : Colors.green.shade400;

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'admin.apartments_occupancy_this_month'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'admin.apartments_occupancy_days'.tr(
                                  namedArgs: {
                                    'occupied': '$occupied',
                                    'total': '$total',
                                  },
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
                                          decoration: BoxDecoration(
                                            color: barColor,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                ),
                // Kritické poznámky majitele musí být pro dispečera okamžitě viditelné.
                if (apartment.ownerNotes != null &&
                    apartment.ownerNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            apartment.ownerNotes!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.amber.shade900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple Vibe styl pro formulářové inputy – zaoblené rohy, jemný border, focus primary.
InputDecoration _appleVibeInputDecoration(
  BuildContext context, {
  Widget? prefixIcon,
  String? labelText,
  String? hintText,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    prefixIcon: prefixIcon,
    labelText: labelText,
    hintText: hintText,
    alignLabelWithHint: alignLabelWithHint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// Řádek informace s ikonou – adresa, klíče, čas úklidu.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Dialog pro přidání nového apartmánu.
class _AddApartmentDialog extends ConsumerStatefulWidget {
  const _AddApartmentDialog({
    required this.ref,
    required this.onSaved,
  });

  final WidgetRef ref;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddApartmentDialog> createState() =>
      _AddApartmentDialogState();
}

/// Stav bytu se počítá dynamicky z Rezervací a Úkolů – nepřidáváme manuální výběr.
/// Tab 2 drží lokální stav služeb (apartment_services) do okamžiku Uložit.
class _AddApartmentDialogState extends ConsumerState<_AddApartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _keyboxController = TextEditingController();
  final _checkInController = TextEditingController(text: '15:00');
  final _checkOutController = TextEditingController(text: '10:00');
  final _cleaningDurationController = TextEditingController(text: '120');
  final _ownerNotesController = TextEditingController();
  bool _isSaving = false;
  /// Vybraná oblast (zone_id). null = Žádná oblast.
  String? _selectedZoneId;
  /// Služby a ceník (Tab 2): serviceId -> stav. Naplní se z tenantServicesProvider, uživatel zapíná a vyplňuje.
  Map<String, ApartmentServiceEditState> _servicesState = {};

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _keyboxController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _cleaningDurationController.dispose();
    _ownerNotesController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final duration = int.tryParse(_cleaningDurationController.text) ?? 120;
    try {
      // Dvoukrokové ukládání (Override Pattern Tier 2): nejdřív záznam v apartments,
      // potom konfigurace služeb bytu v apartment_services (závisí na apartment_id).
      // KROK 1: Vložení bytu a získání nového id (pro apartment_services).
      final insertPayload = {
        'tenant_id': tenantId,
        'name': _nameController.text.trim(),
        'zone_id': _selectedZoneId,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'keybox': _keyboxController.text.trim().isEmpty
            ? null
            : _keyboxController.text.trim(),
        'check_in_time': _checkInController.text.trim().isEmpty ? '15:00' : _checkInController.text.trim(),
        'check_out_time': _checkOutController.text.trim().isEmpty ? '10:00' : _checkOutController.text.trim(),
        'standard_cleaning_duration': duration,
        'owner_notes': _ownerNotesController.text.trim().isEmpty ? null : _ownerNotesController.text.trim(),
      };
      final res = await SupabaseService.client
          .from('apartments')
          .insert(insertPayload)
          .select('id')
          .single();
      final newId = res['id'] as String?;
      if (newId == null || newId.isEmpty) throw Exception('Insert apartments nevrátil id');

      // KROK 2: Uložení služeb a ceníku (apartment_services) pro nový byt.
      // Smazání starých záznamů a vložení nových podle stavu Tabu 2 (enabled + custom_price v EUR).
      await saveForApartment(
        apartmentId: newId,
        tenantId: tenantId,
        states: _servicesState,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.apartments_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA UKLÁDÁNÍ (Byty/Apartmány): $e');
      if (e.message.contains('column') || e.code == '42703') {
        // ignore: avoid_print
        print('>>> Sloupce v tabulce apartments ještě neexistují. Spusť v Supabase SQL Editoru:');
        // ignore: avoid_print
        print('>>> supabase/migrations/20250216_apartments_extended.sql');
        // ignore: avoid_print
        print('>>> Nebo: ALTER TABLE apartments ADD COLUMN IF NOT EXISTS status TEXT DEFAULT \'Uklizeno\', '
            'ADD COLUMN IF NOT EXISTS check_in_time TEXT DEFAULT \'15:00\', '
            'ADD COLUMN IF NOT EXISTS check_out_time TEXT DEFAULT \'10:00\', '
            'ADD COLUMN IF NOT EXISTS standard_cleaning_duration INTEGER DEFAULT 120, '
            'ADD COLUMN IF NOT EXISTS owner_notes TEXT;');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.apartments_save_error'.tr(namedArgs: {'error': e.message}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA UKLÁDÁNÍ (Byty/Apartmány): $e');
      // ignore: avoid_print
      print('>>> Pokud chybí sloupce v DB, spusť: supabase/migrations/20250216_apartments_extended.sql');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.apartments_save_error'.tr(namedArgs: {'error': '$e'}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Tab 1: základní informace (název, adresa, kód, check-in/out, doba úklidu, instrukce).
  Widget _buildTab1Basic(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.section_basic'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.label_outline),
            labelText: 'admin.field_name'.tr(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'admin.validation_name_required'.tr()
                  : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.location_on_outlined),
            labelText: 'admin.field_address'.tr(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'admin.validation_address_required'.tr()
                  : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _keyboxController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            labelText: 'admin.field_keybox'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) {
            final zonesAsync = ref.watch(zonesProvider);
            return zonesAsync.when(
              data: (zones) {
                return DropdownButtonFormField<String?>(
                  initialValue: _selectedZoneId,
                  decoration: _appleVibeInputDecoration(
                    context,
                    prefixIcon: const Icon(Icons.map_outlined),
                    labelText: 'admin.select_zone'.tr(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('admin.select_zone_none'.tr()),
                    ),
                    ...zones.map((z) => DropdownMenuItem<String?>(
                          value: z.id,
                          child: Text(z.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedZoneId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.section_schedule'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _checkInController,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.field_check_in'.tr(),
                  hintText: 'admin.hint_check_in'.tr(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _checkOutController,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.field_check_out'.tr(),
                  hintText: 'admin.hint_check_out'.tr(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cleaningDurationController,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.numbers_outlined),
                  labelText: 'admin.field_cleaning_duration'.tr(),
                  hintText: 'admin.hint_duration'.tr(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.section_staff_instructions'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ownerNotesController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.notes_outlined),
            labelText: 'admin.field_owner_notes'.tr(),
            hintText: 'admin.field_owner_notes_hint'.tr(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  /// Tab 2: služby a ceník – katalog tenant_services, přepínač + vlastní cena/popis/spouštěč/interval. Ceny zobrazujeme v preferované měně, ukládáme v EUR.
  Widget _buildTab2Services(BuildContext context) {
    final tenantServices = ref.watch(tenantServicesProvider).valueOrNull ?? [];
    final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    if (_servicesState.isEmpty && tenantServices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _servicesState = {
            for (final s in tenantServices)
              s.id: ApartmentServiceEditState(
                serviceId: s.id,
                serviceName: s.name,
                defaultPriceEur: s.defaultPrice?.toDouble(),
                enabled: false,
                customPriceEur: s.defaultPrice?.toDouble(),
                customDescription: null,
                triggerType: 'on_demand',
                scheduleInterval: null,
                isMandatory: false,
              ),
          };
        });
      });
    }

    if (tenantServices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'admin.apartment_services_empty'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tenantServices.length,
      itemBuilder: (context, index) {
        final s = tenantServices[index];
        final state = _servicesState[s.id] ?? ApartmentServiceEditState(
          serviceId: s.id,
          serviceName: s.name,
          defaultPriceEur: s.defaultPrice?.toDouble(),
          enabled: false,
          customPriceEur: s.defaultPrice?.toDouble(),
          customDescription: null,
          triggerType: 'on_demand',
          scheduleInterval: null,
          isMandatory: false,
        );
        final eurBase = (state.customPriceEur ?? state.defaultPriceEur?.toDouble()) ?? 0.0;
        final displayPrice = CurrencyService.convert(eurBase, preferredCurrency, currencies);
        final displayPriceStr = displayPrice.toStringAsFixed(2);

        return ExpansionTile(
          initiallyExpanded: false,
          controlAffinity: ListTileControlAffinity.leading,
          title: Row(
            children: [
              Switch(
                value: state.enabled,
                onChanged: (v) {
                  setState(() {
                    _servicesState[s.id] = state.copyWith(enabled: v);
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          children: state.enabled
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: TextFormField(
                            initialValue: displayPriceStr,
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey.shade500),
                              labelText: 'admin.field_custom_price_apartment'.tr(namedArgs: {'code': preferredCurrency}),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              final parsed = double.tryParse(v.replaceAll(',', '.'));
                              if (parsed == null) return;
                              final eur = CurrencyService.toEur(parsed, preferredCurrency, currencies);
                              setState(() {
                                _servicesState[s.id] = state.copyWith(customPriceEur: eur);
                              });
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: TextFormField(
                            initialValue: state.customDescription ?? '',
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.description_outlined),
                              labelText: 'admin.field_custom_description_apartment'.tr(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 2,
                            onChanged: (v) {
                              setState(() {
                                _servicesState[s.id] = state.copyWith(customDescription: v.isEmpty ? null : v);
                              });
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                            child: DropdownButtonFormField<String>(
                            initialValue: state.triggerType,
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.list_alt_outlined),
                              labelText: 'admin.field_trigger_type'.tr(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'on_demand', child: Text('admin.trigger_on_demand'.tr())),
                              DropdownMenuItem(value: 'before_checkin', child: Text('admin.trigger_before_checkin'.tr())),
                              DropdownMenuItem(value: 'after_checkout', child: Text('admin.trigger_after_checkout'.tr())),
                              DropdownMenuItem(value: 'both_ways', child: Text('admin.trigger_both_ways'.tr())),
                              DropdownMenuItem(value: 'scheduled', child: Text('admin.trigger_scheduled'.tr())),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _servicesState[s.id] = state.copyWith(triggerType: v, scheduleInterval: v == 'scheduled' ? (state.scheduleInterval ?? '1_week') : null);
                              });
                            },
                          ),
                        ),
                        if (state.triggerType == 'scheduled') ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 24.0),
                            child: DropdownButtonFormField<String>(
                              initialValue: state.scheduleInterval ?? '1_week',
                              decoration: _appleVibeInputDecoration(
                                context,
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                labelText: 'admin.field_schedule_interval'.tr(),
                              ),
                              items: ['1_week', '2_weeks', '1_month', '2_months', '3_months', '6_months']
                                  .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text('admin.schedule_interval_$k'.tr()),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _servicesState[s.id] = state.copyWith(scheduleInterval: v);
                                });
                              },
                            ),
                          ),
                        ],
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: DropdownButtonFormField<String>(
                            initialValue: state.payerType,
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.payment_outlined),
                              labelText: 'admin.payer_type_label'.tr(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'owner', child: Text('admin.payer_owner'.tr())),
                              DropdownMenuItem(value: 'guest', child: Text('admin.payer_guest'.tr())),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _servicesState[s.id] = state.copyWith(payerType: v);
                              });
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: SwitchListTile(
                            value: state.isMandatory,
                            onChanged: (v) {
                              setState(() {
                                _servicesState[s.id] = state.copyWith(isMandatory: v);
                              });
                            },
                            title: Text('admin.service_mandatory_label'.tr()),
                            secondary: const Icon(Icons.lock_outline),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : [],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernAdminPanel(
      title: 'admin.apartments_add'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.info_outline), text: 'admin.tab_basic_info'.tr()),
                  Tab(icon: const Icon(Icons.room_service_outlined), text: 'admin.tab_services_pricing'.tr()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(child: _buildTab1Basic(context)),
                    SingleChildScrollView(child: _buildTab2Services(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Dialog pro úpravu existujícího apartmánu.
class _EditApartmentDialog extends ConsumerStatefulWidget {
  const _EditApartmentDialog({
    required this.ref,
    required this.apartment,
    required this.onSaved,
  });

  final WidgetRef ref;
  final ApartmentRow apartment;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditApartmentDialog> createState() =>
      _EditApartmentDialogState();
}

class _EditApartmentDialogState extends ConsumerState<_EditApartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _keyboxController;
  late final TextEditingController _checkInController;
  late final TextEditingController _checkOutController;
  late final TextEditingController _cleaningDurationController;
  late final TextEditingController _ownerNotesController;
  bool _isSaving = false;
  /// Tab 2: stav služeb načtený z apartment_services + katalog (tenant_services).
  Map<String, ApartmentServiceEditState> _servicesState = {};
  bool _servicesLoaded = false;
  /// Vybraná oblast (zone_id). null = Žádná oblast.
  String? _selectedZoneId;

  @override
  void initState() {
    super.initState();
    final a = widget.apartment;
    _selectedZoneId = a.zoneId;
    _nameController = TextEditingController(text: a.name);
    _addressController = TextEditingController(text: a.address ?? '');
    _keyboxController = TextEditingController(text: a.keybox ?? '');
    _checkInController = TextEditingController(text: a.checkInTime ?? '15:00');
    _checkOutController = TextEditingController(text: a.checkOutTime ?? '10:00');
    _cleaningDurationController =
        TextEditingController(text: '${a.standardCleaningDuration ?? 120}');
    _ownerNotesController = TextEditingController(text: a.ownerNotes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _keyboxController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _cleaningDurationController.dispose();
    _ownerNotesController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final duration = int.tryParse(_cleaningDurationController.text) ?? 120;
    try {
      // Dvoukrokové ukládání (Override Pattern Tier 2): nejdřív úprava bytu, potom přepsání apartment_services.
      // KROK 1: Aktualizace záznamu bytu.
      await SupabaseService.client.from('apartments').update({
        'name': _nameController.text.trim(),
        'zone_id': _selectedZoneId,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'keybox': _keyboxController.text.trim().isEmpty
            ? null
            : _keyboxController.text.trim(),
        'check_in_time': _checkInController.text.trim().isEmpty
            ? '15:00'
            : _checkInController.text.trim(),
        'check_out_time': _checkOutController.text.trim().isEmpty
            ? '10:00'
            : _checkOutController.text.trim(),
        'standard_cleaning_duration': duration,
        'owner_notes': _ownerNotesController.text.trim().isEmpty
            ? null
            : _ownerNotesController.text.trim(),
      }).eq('id', widget.apartment.id);

      // KROK 2: Uložení služeb a ceníku (apartment_services) – replace všech záznamů pro tento byt (delete + insert dle stavu Tabu 2).
      await saveForApartment(
        apartmentId: widget.apartment.id,
        tenantId: tenantId,
        states: _servicesState,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.apartments_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA ÚPRAVY APARTMÁNU: $e');
      if (e.message.contains('column') || e.code == '42703') {
        // ignore: avoid_print
        print('>>> Sloupce v tabulce apartments neexistují. Spusť: supabase/migrations/20250216_apartments_extended.sql');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.apartments_save_error'.tr(namedArgs: {'error': e.message}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA ÚPRAVY APARTMÁNU: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.apartments_save_error'.tr(namedArgs: {'error': '$e'}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Načtení služeb bytu (Override Pattern Tier 2): načte záznamy z apartment_services pro tento byt
  /// a sloučí je s katalogem tenant_services do _servicesState pro předvyplnění Tabu 2.
  Future<void> _loadServicesState(List<TenantServiceModel> tenantServices) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    final rows = await fetchByApartmentId(widget.apartment.id, tenantId);
    final byServiceId = {for (final r in rows) r.serviceId: r};
    if (!mounted) return;
    setState(() {
      _servicesState = {
        for (final s in tenantServices)
          s.id: () {
            final row = byServiceId[s.id];
            if (row == null) {
              return ApartmentServiceEditState(
                serviceId: s.id,
                serviceName: s.name,
                defaultPriceEur: s.defaultPrice?.toDouble(),
                enabled: false,
                customPriceEur: s.defaultPrice?.toDouble(),
                customDescription: null,
                triggerType: 'on_demand',
                scheduleInterval: null,
                isMandatory: false,
                payerType: 'guest',
              );
            }
            return ApartmentServiceEditState(
              serviceId: s.id,
              serviceName: s.name,
              defaultPriceEur: s.defaultPrice?.toDouble(),
              enabled: true,
              customPriceEur: row.customPrice?.toDouble(),
              customDescription: row.customDescription,
              triggerType: row.triggerType,
              scheduleInterval: row.scheduleInterval,
              isMandatory: row.isMandatory,
              payerType: row.payerType,
            );
          }(),
      };
      _servicesLoaded = true;
    });
  }

  Widget _buildTab1Basic(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.section_basic'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.label_outline),
            labelText: 'admin.field_name'.tr(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'admin.validation_name_required'.tr()
                  : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.location_on_outlined),
            labelText: 'admin.field_address'.tr(),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'admin.validation_address_required'.tr()
                  : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _keyboxController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            labelText: 'admin.field_keybox'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) {
            final zonesAsync = ref.watch(zonesProvider);
            return zonesAsync.when(
              data: (zones) {
                return DropdownButtonFormField<String?>(
                  initialValue: _selectedZoneId,
                  decoration: _appleVibeInputDecoration(
                    context,
                    prefixIcon: const Icon(Icons.map_outlined),
                    labelText: 'admin.select_zone'.tr(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('admin.select_zone_none'.tr()),
                    ),
                    ...zones.map((z) => DropdownMenuItem<String?>(
                          value: z.id,
                          child: Text(z.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedZoneId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.section_schedule'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _checkInController,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.field_check_in'.tr(),
                  hintText: 'admin.hint_check_in'.tr(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _checkOutController,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  labelText: 'admin.field_check_out'.tr(),
                  hintText: 'admin.hint_check_out'.tr(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cleaningDurationController,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.numbers_outlined),
                  labelText: 'admin.field_cleaning_duration'.tr(),
                  hintText: 'admin.hint_duration'.tr(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.section_staff_instructions'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _ownerNotesController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.notes_outlined),
            labelText: 'admin.field_owner_notes'.tr(),
            hintText: 'admin.field_owner_notes_hint'.tr(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildTab2Services(BuildContext context) {
    final tenantServices = ref.watch(tenantServicesProvider).valueOrNull ?? [];
    final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    if (!_servicesLoaded && tenantServices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadServicesState(tenantServices);
      });
    }

    if (tenantServices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'admin.apartment_services_empty'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    if (!_servicesLoaded) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tenantServices.length,
      itemBuilder: (context, index) {
        final s = tenantServices[index];
        final state = _servicesState[s.id] ?? ApartmentServiceEditState(
          serviceId: s.id,
          serviceName: s.name,
          defaultPriceEur: s.defaultPrice?.toDouble(),
          enabled: false,
          customPriceEur: s.defaultPrice?.toDouble(),
          customDescription: null,
          triggerType: 'on_demand',
          scheduleInterval: null,
          isMandatory: false,
        );
        final eurBase = (state.customPriceEur ?? state.defaultPriceEur?.toDouble()) ?? 0.0;
        final displayPrice = CurrencyService.convert(eurBase, preferredCurrency, currencies);
        final displayPriceStr = displayPrice.toStringAsFixed(2);

        return ExpansionTile(
          initiallyExpanded: false,
          controlAffinity: ListTileControlAffinity.leading,
          title: Row(
            children: [
              Switch(
                value: state.enabled,
                onChanged: (v) {
                  setState(() {
                    _servicesState[s.id] = state.copyWith(enabled: v);
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          children: state.enabled
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: TextFormField(
                            initialValue: displayPriceStr,
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey.shade500),
                              labelText: 'admin.field_custom_price_apartment'.tr(namedArgs: {'code': preferredCurrency}),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              final parsed = double.tryParse(v.replaceAll(',', '.'));
                              if (parsed == null) return;
                              final eur = CurrencyService.toEur(parsed, preferredCurrency, currencies);
                              setState(() {
                                _servicesState[s.id] = state.copyWith(customPriceEur: eur);
                              });
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: TextFormField(
                            initialValue: state.customDescription ?? '',
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.description_outlined),
                              labelText: 'admin.field_custom_description_apartment'.tr(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 2,
                            onChanged: (v) {
                              setState(() {
                                _servicesState[s.id] = state.copyWith(customDescription: v.isEmpty ? null : v);
                              });
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                            child: DropdownButtonFormField<String>(
                            initialValue: state.triggerType,
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.list_alt_outlined),
                              labelText: 'admin.field_trigger_type'.tr(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'on_demand', child: Text('admin.trigger_on_demand'.tr())),
                              DropdownMenuItem(value: 'before_checkin', child: Text('admin.trigger_before_checkin'.tr())),
                              DropdownMenuItem(value: 'after_checkout', child: Text('admin.trigger_after_checkout'.tr())),
                              DropdownMenuItem(value: 'both_ways', child: Text('admin.trigger_both_ways'.tr())),
                              DropdownMenuItem(value: 'scheduled', child: Text('admin.trigger_scheduled'.tr())),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _servicesState[s.id] = state.copyWith(
                                  triggerType: v,
                                  scheduleInterval: v == 'scheduled' ? (state.scheduleInterval ?? '1_week') : null,
                                );
                              });
                            },
                          ),
                        ),
                        if (state.triggerType == 'scheduled') ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 24.0),
                            child: DropdownButtonFormField<String>(
                              initialValue: state.scheduleInterval ?? '1_week',
                              decoration: _appleVibeInputDecoration(
                                context,
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                labelText: 'admin.field_schedule_interval'.tr(),
                              ),
                              items: ['1_week', '2_weeks', '1_month', '2_months', '3_months', '6_months']
                                  .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text('admin.schedule_interval_$k'.tr()),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _servicesState[s.id] = state.copyWith(scheduleInterval: v);
                                });
                              },
                            ),
                          ),
                        ],
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: DropdownButtonFormField<String>(
                            initialValue: state.payerType,
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.payment_outlined),
                              labelText: 'admin.payer_type_label'.tr(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'owner', child: Text('admin.payer_owner'.tr())),
                              DropdownMenuItem(value: 'guest', child: Text('admin.payer_guest'.tr())),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _servicesState[s.id] = state.copyWith(payerType: v);
                              });
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: SwitchListTile(
                            value: state.isMandatory,
                            onChanged: (v) {
                              setState(() {
                                _servicesState[s.id] = state.copyWith(isMandatory: v);
                              });
                            },
                            title: Text('admin.service_mandatory_label'.tr()),
                            secondary: const Icon(Icons.lock_outline),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : [],
        );
      },
    );
  }

  /// Tab 3: Sekce Majitelé – výpis přiřazených majitelů, přidání existujícího nebo pozvání nového.
  Widget _buildTab3Owners(BuildContext context) {
    final ownersAsync = ref.watch(apartmentOwnersForApartmentProvider(widget.apartment.id));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.section_owners'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ownersAsync.when(
          data: (owners) {
            if (owners.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'admin.owners_empty'.tr(),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: owners.map((o) => _OwnerListTile(
                owner: o,
                onRemove: () => _removeOwner(context, o.id, o.name),
              )).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _showAddExistingOwnerDialog(context),
              icon: const Icon(Icons.person_add_outlined, size: 20),
              label: Text('admin.btn_add_existing_owner'.tr()),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showInviteNewOwnerDialog(context),
              icon: const Icon(Icons.mail_outline, size: 20),
              label: Text('admin.btn_invite_new_owner'.tr()),
            ),
          ],
        ),
      ],
    );
  }

  /// Odebere majitele z bytu (soft delete v apartment_owners).
  Future<void> _removeOwner(BuildContext context, String apartmentOwnersId, String ownerName) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
          title: Text('admin.owners_remove'.tr()),
          content: Text('admin.owners_remove_confirm'.tr(namedArgs: {'name': ownerName})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('admin.owners_remove'.tr()),
            ),
          ],
        ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApartmentOwnersRepository.removeOwner(apartmentOwnersId: apartmentOwnersId);
      if (!mounted) return;
      ref.invalidate(apartmentOwnersForApartmentProvider(widget.apartment.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.owners_remove_success'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddExistingOwnerDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddExistingOwnerDialog(
        ref: ref,
        apartmentId: widget.apartment.id,
        tenantId: ref.read(authNotifierProvider).tenantIdForData ?? '',
        onAdded: () {
          ref.invalidate(apartmentOwnersForApartmentProvider(widget.apartment.id));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.owners_add_success'.tr()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showInviteNewOwnerDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _InviteNewOwnerDialog(
        ref: ref,
        apartmentId: widget.apartment.id,
        tenantId: ref.read(authNotifierProvider).tenantIdForData ?? '',
        onInvited: (email) {
          ref.invalidate(apartmentOwnersForApartmentProvider(widget.apartment.id));
          ref.invalidate(propertyOwnersInTenantProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('admin.owners_invite_success'.tr(namedArgs: {'email': email})),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernAdminPanel(
      title: 'admin.apartments_edit'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: DefaultTabController(
          length: 3,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.info_outline), text: 'admin.tab_basic_info'.tr()),
                  Tab(icon: const Icon(Icons.room_service_outlined), text: 'admin.tab_services_pricing'.tr()),
                  Tab(icon: const Icon(Icons.person_outline), text: 'admin.tab_owners'.tr()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(child: _buildTab1Basic(context)),
                    SingleChildScrollView(child: _buildTab2Services(context)),
                    SingleChildScrollView(child: _buildTab3Owners(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Řádek seznamu majitele – jméno, e-mail, badge „Čeká“, tlačítko Odebrat.
class _OwnerListTile extends StatelessWidget {
  const _OwnerListTile({
    required this.owner,
    required this.onRemove,
  });

  final ApartmentOwnerRow owner;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, color: Colors.grey.shade600),
        ),
        title: Text(owner.name),
        subtitle: owner.email != null && owner.email!.isNotEmpty
            ? Text(owner.email!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (owner.isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'admin.owners_pending_badge'.tr(),
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade600),
              tooltip: 'admin.owners_remove'.tr(),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog pro přidání existujícího majitele – dropdown s profily role=property_owner.
class _AddExistingOwnerDialog extends ConsumerStatefulWidget {
  const _AddExistingOwnerDialog({
    required this.ref,
    required this.apartmentId,
    required this.tenantId,
    required this.onAdded,
  });

  final WidgetRef ref;
  final String apartmentId;
  final String tenantId;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddExistingOwnerDialog> createState() => _AddExistingOwnerDialogState();
}

class _AddExistingOwnerDialogState extends ConsumerState<_AddExistingOwnerDialog> {
  String? _selectedProfileId;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final ownersAsync = ref.watch(propertyOwnersInTenantProvider);
    final currentOwners = ref.watch(apartmentOwnersForApartmentProvider(widget.apartmentId)).valueOrNull ?? [];
    final currentOwnerIds = currentOwners.map((o) => o.ownerId).toSet();

    return AlertDialog(
      title: Text('admin.dialog_add_existing_owner'.tr()),
      content: SizedBox(
        width: 400,
        child: ownersAsync.when(
          data: (allOwners) {
            final available = allOwners.where((o) => !currentOwnerIds.contains(o.profileId)).toList();
            if (available.isEmpty) {
              return Text(
                'admin.owners_no_available'.tr(),
                style: TextStyle(color: Colors.grey.shade600),
              );
            }
            return DropdownButtonFormField<String>(
              initialValue: _selectedProfileId,
              decoration: InputDecoration(
                labelText: 'admin.owners_select_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              items: available
                  .map((o) => DropdownMenuItem(
                        value: o.profileId,
                        child: Text(o.name + (o.email != null ? ' (${o.email})' : '')),
                      ))
                  .toList(),
              onChanged: _isSaving ? null : (v) => setState(() => _selectedProfileId = v),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: (_isSaving || _selectedProfileId == null) ? null : () => _addOwner(),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('common.save'.tr()),
        ),
      ],
    );
  }

  Future<void> _addOwner() async {
    if (_selectedProfileId == null) return;
    setState(() => _isSaving = true);
    try {
      await ApartmentOwnersRepository.addOwner(
        apartmentId: widget.apartmentId,
        ownerId: _selectedProfileId!,
        tenantId: widget.tenantId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAdded();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.owners_add_error'.tr(namedArgs: {'error': e.message})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.owners_add_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Dialog pro pozvání nového majitele – e-mail, jméno, příjmení.
/// Vytvoření pozvánky pro majitele a okamžité provázání jeho ghost profilu s tímto bytem,
/// aby po registraci rovnou viděl svá data.
class _InviteNewOwnerDialog extends ConsumerStatefulWidget {
  const _InviteNewOwnerDialog({
    required this.ref,
    required this.apartmentId,
    required this.tenantId,
    required this.onInvited,
  });

  final WidgetRef ref;
  final String apartmentId;
  final String tenantId;
  final void Function(String email) onInvited;

  @override
  ConsumerState<_InviteNewOwnerDialog> createState() => _InviteNewOwnerDialogState();
}

class _InviteNewOwnerDialogState extends ConsumerState<_InviteNewOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('admin.dialog_invite_new_owner'.tr()),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'admin.team_field_email'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'admin.team_validation_email'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'admin.team_field_first_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'admin.team_validation_first_name'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'admin.team_field_last_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'admin.team_validation_last_name'.tr() : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _inviteOwner(),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('admin.btn_invite_new_owner'.tr()),
        ),
      ],
    );
  }

  Future<void> _inviteOwner() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    var displayName = '$firstName $lastName'.trim();
    if (displayName.isEmpty) displayName = email.split('@').first;
    if (displayName.isEmpty) displayName = email;

    setState(() => _isSaving = true);

    try {
      // Vytvoření pozvánky pro majitele a okamžité provázání jeho ghost profilu s tímto bytem,
      // aby po registraci rovnou viděl svá data.
      final profilePayload = <String, dynamic>{
        'tenant_id': widget.tenantId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName.isEmpty ? ' ' : lastName,
        'name': displayName,
        'status': 'pending',
        'role': 'property_owner',
        'roles': [],
      };
      final profileRes = await SupabaseService.client
          .from('profiles')
          .insert(profilePayload)
          .select('id')
          .single();
      final profileId = (profileRes as Map)['id']?.toString();
      if (profileId == null || profileId.isEmpty) {
        throw PostgrestException(message: 'Profil nebyl vytvořen', code: '500', details: 'internal');
      }

      final invPayload = <String, dynamic>{
        'tenant_id': widget.tenantId,
        'profile_id': profileId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'property_owner',
        'roles': [],
      };
      await SupabaseService.client.from('invitations').insert(invPayload);

      await ApartmentOwnersRepository.addOwner(
        apartmentId: widget.apartmentId,
        ownerId: profileId,
        tenantId: widget.tenantId,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onInvited(email);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.owners_invite_error'.tr(namedArgs: {'error': e.message})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.owners_invite_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
