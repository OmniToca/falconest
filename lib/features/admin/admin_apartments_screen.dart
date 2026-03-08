import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/apartment_service_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/providers/ical_sync_provider.dart';
import 'package:falconest/features/admin/services/ical_sync_service.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/apartment_status_provider.dart';
import 'package:falconest/features/admin/providers/zones_provider.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:flutter/foundation.dart';

/// Otevře dialog pro úpravu apartmánu. Volá se z AdminApartmentsScreen i z ClientDetailDialog.
void showApartmentEditDialog(
  BuildContext context,
  WidgetRef ref,
  ApartmentRow apartment, {
  VoidCallback? onSaved,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => _EditApartmentDialog(
      ref: ref,
      apartment: apartment,
      onSaved: onSaved ?? () {
        ref.invalidate(apartmentsProvider);
        ref.invalidate(apartmentsFullListProvider);
      },
    ),
  );
}

/// Otevře dialog pro přidání nového apartmánu.
/// [prefilledClient] – pokud owner s profileId, po vytvoření bytu se automaticky
/// přiřadí jako majitel (apartment_owners). Z kontextu Detailu klienta.
void showAddApartmentDialog(
  BuildContext context,
  WidgetRef ref, {
  ClientModel? prefilledClient,
  VoidCallback? onSaved,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => _AddApartmentDialog(
      ref: ref,
      onSaved: onSaved ?? () {
        ref.invalidate(apartmentsProvider);
        ref.invalidate(apartmentsFullListProvider);
      },
      prefilledClient: prefilledClient,
    ),
  );
}

/// Mapování manuálních stavů z DB (edit dialog) na i18n klíče.
const _statusKeys = {
  'Uklizeno': 'admin.status_cleaned',
  'K úklidu': 'admin.status_to_clean',
  'Obsazeno hosty': 'admin.status_occupied',
  'Probíhá úklid': 'admin.status_cleaning',
  'Rekonstrukce': 'admin.status_renovation',
};

/// Barvy štítků stavu – ladí s Kanbanem úkolů (zelená/červená/modrá).
/// Podporuje i18n klíče z apartmentStatusProvider i legacy české stringy z DB.
(Color, Color) _statusChipColors(String? status) {
  final s = (status == null || status.isEmpty) ? apartmentStatusClean : status;
  switch (s) {
    case apartmentStatusClean:
    case 'Uklizeno':
      return (Colors.green.shade100, Colors.green.shade800);
    case apartmentStatusNeedsCleaning:
    case 'K úklidu':
      return (Colors.red.shade100, Colors.red.shade800);
    case apartmentStatusOccupied:
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
/// [status] je buď i18n klíč od apartmentStatusProvider (apartments.status.*), nebo legacy string z DB.
Widget _buildStatusBadge(String? status) {
  final s = (status == null || status.isEmpty) ? apartmentStatusClean : status;
  final (bgColor, textColor) = _statusChipColors(s);
  final label = _statusKeys.containsKey(s) ? (_statusKeys[s]!).tr() : s.tr();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
  Timer? _searchDebounce;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Při scrollu ke konci (90 % maxScrollExtent) načte další stránku.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.9) {
      ref.read(apartmentsProvider.notifier).loadMore();
    }
  }

  /// Server-side vyhledávání s debounce 500 ms – neposílá dotaz při každém stisku.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      ref.read(apartmentsProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final loadingMore = ref.watch(apartmentsLoadingMoreProvider);

    return Scaffold(
      body: apartmentsAsync.when(
        data: (apartments) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopActionBar(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onAdd: () => _showAddDialog(context, ref),
              ),
              Expanded(
                child: apartments.isEmpty && !loadingMore
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'admin.apartments_empty'.tr()
                              : 'admin.apartments_search_no_results'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : _ApartmentsCardList(
                        apartments: apartments,
                        scrollController: _scrollController,
                        isLoadingMore: loadingMore,
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
                onPressed: () {
                    ref.invalidate(apartmentsProvider);
                    ref.invalidate(apartmentsFullListProvider);
                  },
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showAddApartmentDialog(context, ref, onSaved: () {
      ref.invalidate(apartmentsProvider);
      ref.invalidate(apartmentsFullListProvider);
    });
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ApartmentRow apartment,
  ) {
    showApartmentEditDialog(context, ref, apartment);
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              final blocked = await _hasActiveFutureReservations(ref, apartment.id);
              if (!context.mounted) return;
              if (blocked) {
                await showDialog<void>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: Text('admin.apartment_delete_blocked_title'.tr()),
                    content: Text('admin.apartment_delete_blocked_message'.tr()),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.of(ctx2).pop(),
                        child: Text('common.ok'.tr()),
                      ),
                    ],
                  ),
                );
                return;
              }
              await _doDelete(context, ref, [apartment]);
            },
            child: Text('admin.apartments_delete'.tr()),
          ),
        ],
      ),
    );
  }

  /// Ochranný štít: Vrací true, pokud na byt existují aktivní budoucí rezervace
  /// (end_date >= dnes, status != 'cancelled'). V takovém případě byt nesmí jít smazat.
  Future<bool> _hasActiveFutureReservations(WidgetRef ref, String apartmentId) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty || apartmentId.isEmpty) return false;
    final today = DateTime.now();
    final todayIso = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await SupabaseService.client
        .from('reservations')
        .select('id')
        .eq('apartment_id', apartmentId)
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .neq('status', 'cancelled')
        .gte('end_date', todayIso)
        .limit(1);
    final list = res is List ? res : <dynamic>[];
    return list.isNotEmpty;
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
    BuildContext context,
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

      if (!context.mounted) return;
      ref.invalidate(apartmentsProvider);
      ref.invalidate(apartmentsFullListProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminTasksStreamProvider);
      ref.invalidate(planningCalendarAllTasksProvider);
      ref.invalidate(planningCalendarAllTasksForMonthProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      if (kDebugMode) {
        // ignore: avoid_print
        print('Apartment delete error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.apartments_delete_error'.tr(namedArgs: {'error': e.toString()})),
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
          ),
        ],
      ),
    );
  }
}

/// Responzivní mřížka karet – 3 sloupce na desktopu, 2 na notebooku, 1 na mobilu (Apple Vibe).
/// [scrollController] slouží pro nekonečný scroll (loadMore při dosažení 90 %).
class _ApartmentsCardList extends StatelessWidget {
  const _ApartmentsCardList({
    required this.apartments,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ApartmentRow> apartments;
  final ScrollController scrollController;
  final bool isLoadingMore;
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

        // 2. Logika sloupců – shodná s Personálem: 2 karty vedle sebe na široké obrazovce.
        final bool isWide = constraints.maxWidth > 800;
        final double cardWidth =
            isWide ? (availableWidth - spacing) / 2 : availableWidth;

        // Responzivní mřížka využívající 95 % šířky obrazovky bez zbytečných prázdných pruhů.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
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

    return AppCard(
      onTap: () => onEdit(apartment),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Avatar – kruhový jako u _MemberCard
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.purple.shade100,
            child: Icon(Icons.apartment, size: 28, color: Colors.purple.shade800),
          ),
          const SizedBox(width: 16),
          // 2. Střední sloupec – hlavička, metadata, progress bar, poznámky
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apartment.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: addr.isEmpty ? '–' : addr,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.vpn_key_outlined,
                  text: keyboxLabel,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  text: cleaningLabel,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  text: 'admin.apartments_times_in_out'.tr(
                    namedArgs: {
                      'checkIn': apartment.checkInTime ?? '15:00',
                      'checkOut': apartment.checkOutTime ?? '10:00',
                    },
                  ),
                ),
                const SizedBox(height: 10),
                reservationsAsync.when(
                  data: (reservations) {
                    final now = DateTime.now();
                    final (occupied, total) = _computeMonthlyOccupancy(
                      reservations,
                      apartment.id,
                      now,
                    );
                    final ratio = total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;
                    // Jemné barvy: < 0.3 červená, < 0.7 oranžová, >= 0.7 zelená
                    final barColor = ratio < 0.3
                        ? Colors.red.shade300
                        : ratio < 0.7
                            ? Colors.orange.shade300
                            : Colors.green.shade400;
                    return Column(
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
                    );
                  },
                  loading: () => const SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                ),
                if (apartment.ownerNotes != null &&
                    apartment.ownerNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              apartment.ownerNotes!.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 3. Pravý sloupec – status pilulka a tlačítko smazání
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
/// [prefilledClient] – pokud owner s profileId, po vytvoření bytu se automaticky
/// přiřadí jako majitel (apartment_owners). Volitelné – z hlavního menu se volá bez.
class _AddApartmentDialog extends ConsumerStatefulWidget {
  const _AddApartmentDialog({
    required this.ref,
    required this.onSaved,
    this.prefilledClient,
  });

  final WidgetRef ref;
  final VoidCallback onSaved;
  final ClientModel? prefilledClient;

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
  final _codeController = TextEditingController();
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
    _codeController.dispose();
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
        'code': _codeController.text.trim().isEmpty
            ? null
            : _codeController.text.trim(),
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
      if (newId == null || newId.isEmpty) {
        throw StateError('admin.apartments_error_insert_no_id');
      }

      // KROK 1b: Pokud byl předán prefilledClient (owner), přiřaď ho jako majitele bytu.
      final prefilled = widget.prefilledClient;
      if (prefilled != null &&
          (prefilled.clientType?.toLowerCase() ?? '') == 'owner' &&
          prefilled.profileId != null &&
          prefilled.profileId!.trim().isNotEmpty) {
        await SupabaseService.client.from('apartment_owners').insert({
          'apartment_id': newId,
          'owner_id': prefilled.profileId!.trim(),
        });
      }

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
      if (kDebugMode) {
        // ignore: avoid_print
        print('Apartment save error (Postgrest): $e');
        if (e.message.contains('column') || e.code == '42703') {
          // ignore: avoid_print
          print('Missing columns? Run supabase/migrations/20250216_apartments_extended.sql');
        }
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
      if (kDebugMode) {
        // ignore: avoid_print
        print('Apartment add save error: $e');
      }
      final errorMsg = (e is StateError && e.message == 'admin.apartments_error_insert_no_id')
          ? 'admin.apartments_error_insert_no_id'.tr()
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.apartments_save_error'.tr(namedArgs: {'error': errorMsg}),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_basic_info'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
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
          controller: _codeController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.tag_outlined),
            labelText: 'admin.field_apartment_code'.tr(),
            hintText: 'admin.apartments_code_hint'.tr(),
          ),
          textCapitalization: TextCapitalization.characters,
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
      ),
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
                payerType: 'guest',
              ),
          };
        });
      });
    }

    if (tenantServices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.tab_services_pricing'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin.apartment_services_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_services_pricing'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
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
          payerType: 'guest',
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
    ),
        ],
      ),
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
  late final TextEditingController _codeController;
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
    _codeController = TextEditingController(text: a.code ?? '');
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
    _codeController.dispose();
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
        'code': _codeController.text.trim().isEmpty
            ? null
            : _codeController.text.trim(),
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
      if (kDebugMode) {
        // ignore: avoid_print
        print('Apartment edit error (Postgrest): $e');
        if (e.message.contains('column') || e.code == '42703') {
          // ignore: avoid_print
          print('Missing columns? Run supabase/migrations/20250216_apartments_extended.sql');
        }
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
      if (kDebugMode) {
        // ignore: avoid_print
        print('Apartment edit error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.apartments_save_error'.tr(namedArgs: {'error': e.toString()}),
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
                requiresPhoto: null,
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
              requiresPhoto: row.requiresPhoto,
            );
          }(),
      };
      _servicesLoaded = true;
    });
  }

  Widget _buildTab1Basic(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_basic_info'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
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
          controller: _codeController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.tag_outlined),
            labelText: 'admin.field_apartment_code'.tr(),
            hintText: 'admin.apartments_code_hint'.tr(),
          ),
          textCapitalization: TextCapitalization.characters,
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
      ),
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.tab_services_pricing'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin.apartment_services_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_servicesLoaded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.tab_services_pricing'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 16),
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_services_pricing'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
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
          payerType: 'guest',
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
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: DropdownButtonFormField<String>(
                            value: _requiresPhotoToKey(state.requiresPhoto),
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.camera_alt_outlined),
                              labelText: 'admin.field_requires_photo'.tr(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'inherit', child: Text('admin.requires_photo_inherit'.tr())),
                              DropdownMenuItem(value: 'require', child: Text('admin.requires_photo_require'.tr())),
                              DropdownMenuItem(value: 'forbid', child: Text('admin.requires_photo_forbid'.tr())),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _servicesState[s.id] = state.copyWith(
                                  requiresPhoto: v == 'inherit' ? null : (v == 'require'),
                                  clearRequiresPhoto: v == 'inherit',
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : [],
        );
      },
    ),
        ],
      ),
    );
  }

  /// Převede bool? requiresPhoto na klíč pro dropdown: inherit | require | forbid.
  String _requiresPhotoToKey(bool? v) {
    if (v == null) return 'inherit';
    return v ? 'require' : 'forbid';
  }

  /// Tab 3: Sekce Majitelé – výpis přiřazených majitelů, přidání existujícího nebo pozvání nového.
  Widget _buildTab3Owners(BuildContext context) {
    final ownersAsync = ref.watch(apartmentOwnersForApartmentProvider(widget.apartment.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_owners'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
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
        OutlinedButton.icon(
          onPressed: () => _showAssignOwnerFromClientsDialog(context),
          icon: const Icon(Icons.person_add_outlined, size: 20),
          label: Text('admin.btn_assign_owner_from_clients'.tr()),
        ),
        ],
      ),
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

  void _showAssignOwnerFromClientsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AssignOwnerFromClientsDialog(
        ref: ref,
        apartmentId: widget.apartment.id,
        tenantId: ref.read(authNotifierProvider).tenantIdForData ?? '',
        onAssigned: (inviteLink) {
          ref.invalidate(apartmentOwnersForApartmentProvider(widget.apartment.id));
          ref.invalidate(clientsProvider);
          ref.invalidate(clientsFullListProvider);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.owners_add_success'.tr()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (inviteLink != null && inviteLink.isNotEmpty) {
            _showInviteLinkCopyDialog(context, inviteLink);
          }
        },
      ),
    );
  }

  void _showInviteLinkCopyDialog(BuildContext context, String inviteLink) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _InviteLinkCopyDialog(inviteLink: inviteLink),
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
          length: 6,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.info_outline), text: 'admin.tab_basic_info'.tr()),
                  Tab(icon: const Icon(Icons.room_service_outlined), text: 'admin.tab_services_pricing'.tr()),
                  Tab(icon: const Icon(Icons.person_outline), text: 'admin.tab_owners'.tr()),
                  Tab(icon: const Icon(Icons.calendar_month), text: 'admin.tab_reservations'.tr()),
                  Tab(icon: const Icon(Icons.task_alt), text: 'admin.tab_tasks'.tr()),
                  Tab(icon: const Icon(Icons.calendar_today_outlined), text: 'admin.tab_ical_sync'.tr()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(child: _buildTab1Basic(context)),
                    SingleChildScrollView(child: _buildTab2Services(context)),
                    SingleChildScrollView(child: _buildTab3Owners(context)),
                    _ApartmentReservationsTab(
                      ref: ref,
                      apartment: widget.apartment,
                    ),
                    _ApartmentTasksTab(
                      ref: ref,
                      apartment: widget.apartment,
                    ),
                    SingleChildScrollView(
                      child: _IcalSyncTabContent(
                        ref: ref,
                        apartmentId: widget.apartment.id,
                        tenantId: widget.apartment.tenantId,
                      ),
                    ),
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

/// Tab 4: iCal synchronizace – seznam zdrojů, přidání odkazu, tlačítko Synchronizovat.
class _IcalSyncTabContent extends ConsumerStatefulWidget {
  const _IcalSyncTabContent({
    required this.ref,
    required this.apartmentId,
    required this.tenantId,
  });

  final WidgetRef ref;
  final String apartmentId;
  final String tenantId;

  @override
  ConsumerState<_IcalSyncTabContent> createState() => _IcalSyncTabContentState();
}

class _IcalSyncTabContentState extends ConsumerState<_IcalSyncTabContent> {
  late final TextEditingController _urlController;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _onAddSource() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final label = _labelController.text.trim().isEmpty ? 'iCal' : _labelController.text.trim();
    final error = await ref.read(icalSyncNotifierProvider.notifier).addSource(
      apartmentId: widget.apartmentId,
      url: url,
      label: label,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (error == null) {
      _urlController.clear();
      _labelController.clear();
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.ical_add_success'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onSync(IcalSourceRow source) async {
    final result = await ref.read(icalSyncNotifierProvider.notifier).syncUrl(
      apartmentId: widget.apartmentId,
      tenantId: widget.tenantId,
      icalUrl: source.icalUrl,
      sourceId: source.id,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.ical_sync_error'.tr(namedArgs: {'error': result.error!})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.insertedCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.ical_sync_success'.tr(namedArgs: {'count': '${result.insertedCount}'})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.ical_sync_no_new'.tr()),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onRemoveSource(IcalSourceRow source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.ical_remove_source'.tr()),
        content: Text('admin.ical_remove_confirm'.tr(namedArgs: {'label': source.sourceLabel})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('admin.ical_remove_source'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(icalSyncNotifierProvider.notifier).removeSource(widget.apartmentId, source.id);
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(icalSourcesProvider(widget.apartmentId));
    final syncState = ref.watch(icalSyncNotifierProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_ical_sync'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          // Formulář pro přidání zdroje
          TextFormField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'admin.ical_url_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'admin.ical_source_label'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: syncState.isAddingSource ? null : _onAddSource,
            icon: syncState.isAddingSource
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_link, size: 20),
            label: Text('admin.ical_add_source'.tr()),
          ),
          const SizedBox(height: 24),
          // Seznam zdrojů
          sourcesAsync.when(
            data: (sources) {
              if (sources.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'admin.ical_sources_empty'.tr(),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sources.map((s) {
                  final isSyncing = syncState.syncingSourceId == s.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(s.sourceLabel),
                      subtitle: Text(
                        s.icalUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            onPressed: isSyncing ? null : () => _onSync(s),
                            child: isSyncing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text('admin.ical_sync_btn'.tr()),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _onRemoveSource(s),
                            tooltip: 'admin.ical_remove_source'.tr(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Pomocné funkce pro záložky Rezervace a Úkoly (stejná logika jako v ClientDetailDialog) ---

DateTime? _parseReservationStartDateForApartment(String? checkIn) {
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
  } catch (_) {
    return null;
  }
}

bool _isReservationCompletedForApartment(ReservationRow r) {
  final s = r.status.trim().toLowerCase();
  return s == 'checked_out' || s == 'cancelled';
}

List<ReservationRow> _sortReservationsForApartmentTab(List<ReservationRow> list) {
  final sorted = List<ReservationRow>.from(list);
  sorted.sort((a, b) {
    final aDate = _parseReservationStartDateForApartment(a.checkIn);
    final bDate = _parseReservationStartDateForApartment(b.checkIn);
    final aEnd = _isReservationCompletedForApartment(a) ? 1 : 0;
    final bEnd = _isReservationCompletedForApartment(b) ? 1 : 0;
    if (aEnd != bEnd) return aEnd.compareTo(bEnd);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return sorted;
}

String _taskStatusKeyForApartment(String? status) {
  if (status == null || status.trim().isEmpty) return 'task_status.pending';
  final s = status.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') return 'task_status.pending';
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') return 'task_status.assigned';
  if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress';
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') return 'task_status.completed';
  if (s == 'problém' || s == 'problem' || s == 'issue') return 'task_status.problem';
  return 'task_status.pending';
}

bool _isTaskCompletedOrCancelledForApartment(TaskRow t) {
  final s = t.status.trim().toLowerCase();
  return s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno' || s == 'cancelled';
}

DateTime _taskSortDateForApartment(TaskRow t) {
  final start = t.scheduledStart;
  if (start != null) return start;
  return t.dueDate;
}

List<TaskRow> _sortTasksForApartmentTab(List<TaskRow> list) {
  final sorted = List<TaskRow>.from(list);
  sorted.sort((a, b) {
    final aEnd = _isTaskCompletedOrCancelledForApartment(a) ? 1 : 0;
    final bEnd = _isTaskCompletedOrCancelledForApartment(b) ? 1 : 0;
    if (aEnd != bEnd) return aEnd.compareTo(bEnd);
    return _taskSortDateForApartment(a).compareTo(_taskSortDateForApartment(b));
  });
  return sorted;
}

/// Záložka Rezervace v detailu apartmánu – seznam rezervací pro tento byt.
///
/// Řazení a tlačítko „Zobrazit historii dokončených“ stejné jako v ClientDetailDialog.
class _ApartmentReservationsTab extends ConsumerStatefulWidget {
  const _ApartmentReservationsTab({
    required this.ref,
    required this.apartment,
  });

  final WidgetRef ref;
  final ApartmentRow apartment;

  @override
  ConsumerState<_ApartmentReservationsTab> createState() => _ApartmentReservationsTabState();
}

class _ApartmentReservationsTabState extends ConsumerState<_ApartmentReservationsTab> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(reservationsForApartmentProvider(widget.apartment.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'admin.tab_reservations'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('clients.btn_add_reservation_context'.tr()),
                onPressed: () {
                  AdminReservationsScreen.showAddReservationDialog(
                    context,
                    ref,
                    initialApartmentId: widget.apartment.id,
                    onSaved: () {
                      ref.invalidate(reservationsForApartmentProvider(widget.apartment.id));
                      ref.invalidate(adminReservationsProvider);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
          child: reservationsAsync.when(
            data: (reservations) {
              if (reservations.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'admin.apartments_no_reservations'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final sorted = _sortReservationsForApartmentTab(reservations);
              final completed = sorted.where(_isReservationCompletedForApartment).toList();
              final active = sorted.where((r) => !_isReservationCompletedForApartment(r)).toList();
              final visible = _showHistory ? sorted : active;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'admin.apartments_no_reservations'.tr(),
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final r = visible[index];
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
                                      onSaved: () {
                                        ref.invalidate(reservationsForApartmentProvider(widget.apartment.id));
                                        ref.invalidate(adminReservationsProvider);
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  if (completed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextButton.icon(
                        icon: Icon(
                          _showHistory ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        label: Text(
                          _showHistory
                              ? 'common.hide_history'.tr()
                              : 'common.show_history_count'.tr(namedArgs: {'count': '${completed.length}'}),
                        ),
                        onPressed: () => setState(() => _showHistory = !_showHistory),
                      ),
                    ),
                ],
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
                      'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
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
      ),
    );
  }
}

/// Záložka Úkoly v detailu apartmánu – seznam úkolů pro tento byt.
///
/// Řazení a tlačítko „Zobrazit historii dokončených“ stejné jako v ClientDetailDialog.
class _ApartmentTasksTab extends ConsumerStatefulWidget {
  const _ApartmentTasksTab({
    required this.ref,
    required this.apartment,
  });

  final WidgetRef ref;
  final ApartmentRow apartment;

  @override
  ConsumerState<_ApartmentTasksTab> createState() => _ApartmentTasksTabState();
}

class _ApartmentTasksTabState extends ConsumerState<_ApartmentTasksTab> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksForApartmentProvider(widget.apartment.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'admin.tab_tasks'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('clients.btn_add_task_context'.tr()),
                onPressed: () {
                  AdminTasksScreen.showAddTaskDialog(
                    context,
                    ref,
                    initialApartmentId: widget.apartment.id,
                    onSaved: () {
                      ref.invalidate(tasksForApartmentProvider(widget.apartment.id));
                      ref.invalidate(adminTasksProvider);
                      ref.invalidate(adminTasksStreamProvider);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'admin.apartments_no_tasks'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final sorted = _sortTasksForApartmentTab(tasks);
              final completed = sorted.where(_isTaskCompletedOrCancelledForApartment).toList();
              final active = sorted.where((t) => !_isTaskCompletedOrCancelledForApartment(t)).toList();
              final visible = _showHistory ? sorted : active;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'admin.apartments_no_tasks'.tr(),
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final t = visible[index];
                              final displayTitle = (t.customTitle ?? t.title).trim().isNotEmpty
                                  ? (t.customTitle ?? t.title)
                                  : (t.apartmentName ?? t.apartmentId);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(Icons.task_alt, color: Colors.teal.shade700),
                                  title: Text(displayTitle, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    _taskStatusKeyForApartment(t.status).tr(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    AdminTasksScreen.showEditTaskDialog(
                                      context,
                                      ref,
                                      t,
                                      onSaved: () {
                                        ref.invalidate(tasksForApartmentProvider(widget.apartment.id));
                                        ref.invalidate(adminTasksProvider);
                                        ref.invalidate(adminTasksStreamProvider);
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  if (completed.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextButton.icon(
                        icon: Icon(
                          _showHistory ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        label: Text(
                          _showHistory
                              ? 'common.hide_history'.tr()
                              : 'common.show_history_count'.tr(namedArgs: {'count': '${completed.length}'}),
                        ),
                        onPressed: () => setState(() => _showHistory = !_showHistory),
                      ),
                    ),
                ],
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
                      'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
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
      ),
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

/// Dialog pro přiřazení majitele z modulu Klienti – dropdown s klienty typu owner.
class _AssignOwnerFromClientsDialog extends ConsumerStatefulWidget {
  const _AssignOwnerFromClientsDialog({
    required this.ref,
    required this.apartmentId,
    required this.tenantId,
    required this.onAssigned,
  });

  final WidgetRef ref;
  final String apartmentId;
  final String tenantId;
  final void Function(String? inviteLink) onAssigned;

  @override
  ConsumerState<_AssignOwnerFromClientsDialog> createState() =>
      _AssignOwnerFromClientsDialogState();
}

class _AssignOwnerFromClientsDialogState extends ConsumerState<_AssignOwnerFromClientsDialog> {
  ClientModel? _selectedClient;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final currentOwners =
        ref.watch(apartmentOwnersForApartmentProvider(widget.apartmentId)).valueOrNull ?? [];
    final currentOwnerIds = currentOwners.map((o) => o.ownerId).toSet();

    return AlertDialog(
      title: Text('admin.dialog_assign_owner_from_clients'.tr()),
      content: SizedBox(
        width: 400,
        child: clientsAsync.when(
          data: (allClients) {
            final owners = allClients
                .where((c) =>
                    (c.clientType?.toLowerCase() ?? '') == 'owner' &&
                    (c.profileId == null || !currentOwnerIds.contains(c.profileId)))
                .toList();
            if (owners.isEmpty) {
              return Text(
                'admin.owners_no_clients_available'.tr(),
                style: TextStyle(color: Colors.grey.shade600),
              );
            }
            return DropdownButtonFormField<ClientModel>(
              value: _selectedClient,
              decoration: InputDecoration(
                labelText: 'admin.owners_select_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              items: owners
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.name + (c.email != null ? ' (${c.email})' : ''),
                        ),
                      ))
                  .toList(),
              onChanged: _isSaving ? null : (v) => setState(() => _selectedClient = v),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: (_isSaving || _selectedClient == null) ? null : () => _assignOwner(),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('common.save'.tr()),
        ),
      ],
    );
  }

  Future<void> _assignOwner() async {
    if (_selectedClient == null) return;
    setState(() => _isSaving = true);
    try {
      final inviteLink = await ApartmentOwnersRepository.assignClientToApartment(
        apartmentId: widget.apartmentId,
        tenantId: widget.tenantId,
        client: _selectedClient!,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAssigned(inviteLink);
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
      final displayError = (e is StateError && e.message == 'admin.owners_error_profile_not_created')
          ? 'admin.owners_error_profile_not_created'.tr()
          : 'admin.owners_add_error'.tr(namedArgs: {'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayError),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Dialog pro kopírování pozvánkového odkazu – zobrazení po přiřazení nového majitele.
class _InviteLinkCopyDialog extends StatelessWidget {
  const _InviteLinkCopyDialog({required this.inviteLink});

  final String inviteLink;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('admin.owners_invite_link_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.owners_invite_link_message'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          SelectableText(
            inviteLink,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: inviteLink));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('admin.owners_invite_link_copied'.tr()),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text('admin.owners_invite_link_copy'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.ok'.tr()),
        ),
      ],
    );
  }
}

