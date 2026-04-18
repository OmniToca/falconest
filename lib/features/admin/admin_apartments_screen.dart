import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/constants/apartment_rental_constants.dart';
import 'package:falconest/core/utils/geo_json_point.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/services/geocoding_service.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/repositories/apartment/apartment_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/models/apartment_service_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';
import 'package:falconest/features/admin/providers/ical_sync_provider.dart';
import 'package:falconest/features/admin/services/ical_sync_service.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/admin/providers/checklist_templates_list_provider.dart';
import 'package:falconest/features/admin/providers/admin_apartments_repository.dart';
import 'package:falconest/features/admin/providers/calendar_feed_tokens_provider.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';
import 'package:falconest/features/admin/repositories/calendar_feed_tokens_repository.dart';
import 'package:falconest/features/admin/models/calendar_feed_token_row.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/owner/repositories/owner_apartment_pnl_repository.dart';
import 'package:falconest/features/admin/providers/apartment_live_context_provider.dart';
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

/// Parsuje měsíční poplatek ze vstupu (desetinná čísla s tečkou nebo čárkou). Null/prázdné → 0.0.
double _parseMonthlyFee(String v) {
  final trimmed = v.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return 0.0;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || parsed < 0) return 0.0;
  return parsed;
}

/// Datum platnosti smlouvy do payloadu pro Supabase (`date` YYYY-MM-DD).
String? _apartmentLeaseDateToPayload(DateTime? d) {
  if (d == null) return null;
  final u = DateTime.utc(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}

/// Zobrazení kalendářního dne bez posunu časové zóny (hodnoty držíme jako UTC půlnoc dne).
String _formatApartmentLeaseDay(BuildContext context, DateTime d) {
  final cal = DateTime(d.year, d.month, d.day);
  return DateFormat.yMMMd(context.locale.toString()).format(cal);
}

/// Formát inputu transit price v měně UI; interně držíme EUR pro konzistentní ukládání.
String _formatServiceTransitPriceForInput(
  double? transitPriceEur, {
  required String preferredCurrency,
  required List<CurrencyRow> currencies,
}) {
  if (transitPriceEur == null || transitPriceEur <= 0) return '';
  final value = CurrencyService.convert(
    transitPriceEur,
    preferredCurrency,
    currencies,
  );
  return value.toStringAsFixed(2);
}

/// Mapování manuálních stavů z DB (edit dialog) na i18n klíče.
const _statusKeys = {
  'Uklizeno': 'admin.status_cleaned',
  'K úklidu': 'admin.status_to_clean',
  'Obsazeno hosty': 'admin.status_occupied',
  'Probíhá úklid': 'admin.status_cleaning',
  'Rekonstrukce': 'admin.status_renovation',
};

/// Barvy štítků stavu – odvozené z [ColorScheme] / [CustomColors], ne z natvrdo Material Colors.*.
/// Podporuje i18n klíče z apartmentStatusProvider i legacy české stringy z DB.
(Color, Color) _statusChipColors(BuildContext context, String? status) {
  final s = (status == null || status.isEmpty) ? apartmentStatusClean : status;
  final cs = context.colors;
  final cc = context.customColors;
  switch (s) {
    case apartmentStatusClean:
    case 'Uklizeno':
      return (cs.secondaryContainer, cs.onSecondaryContainer);
    case apartmentStatusNeedsCleaning:
    case 'K úklidu':
      return (cs.errorContainer, cs.onErrorContainer);
    case apartmentStatusOccupied:
    case 'Obsazeno hosty':
      return (cs.primaryContainer, cs.onPrimaryContainer);
    case 'Probíhá úklid':
      return (cc.warning.withValues(alpha: 0.18), cc.warning);
    case 'Rekonstrukce':
      return (cs.surfaceContainerHighest, cs.onSurfaceVariant);
    default:
      return (cs.secondaryContainer, cs.onSecondaryContainer);
  }
}

/// Štítek stavu bytu – čistá pilulka (jemné barevné pozadí, tučný text), bez ostrého ohraničení.
/// [status] je buď i18n klíč od apartmentStatusProvider (apartments.status.*), nebo legacy string z DB.
Widget _buildStatusBadge(BuildContext context, String? status) {
  final s = (status == null || status.isEmpty) ? apartmentStatusClean : status;
  final (bgColor, textColor) = _statusChipColors(context, s);
  final label = _statusKeys.containsKey(s) ? (_statusKeys[s]!).tr() : s.tr();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
  );
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
    // PROČ: Po křížové navigaci z úkolu/rezervace otevřeme stejný dialog jako při kliknutí na řádek v seznamu.
    ref.listen<AdminCrossNavPending>(adminCrossNavPendingProvider, (previous, next) {
      final id = next.apartmentId;
      if (id == null || id.isEmpty) return;
      final full = ref.read(apartmentsFullListProvider).valueOrNull;
      ApartmentRow? row;
      if (full != null) {
        for (final a in full) {
          if (a.id == id) {
            row = a;
            break;
          }
        }
      }
      if (row == null) {
        final paginated = ref.read(apartmentsProvider).valueOrNull;
        if (paginated != null) {
          for (final a in paginated) {
            if (a.id == id) {
              row = a;
              break;
            }
          }
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(adminCrossNavPendingProvider.notifier).clear();
        if (row != null) {
          _showEditDialog(context, ref, row);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.cross_nav_apartment_not_found'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    });
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final loadingMore = ref.watch(apartmentsLoadingMoreProvider);
    return Scaffold(
      backgroundColor: context.colors.surface,
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
                        child: AppEmptyState(
                          icon: Icons.apartment_outlined,
                          title: _searchController.text.trim().isEmpty
                              ? 'admin.apartments_empty'.tr()
                              : 'admin.apartments_search_no_results'.tr(),
                          subtitle: _searchController.text.trim().isEmpty
                              ? null
                              : 'admin.general.search_empty_subtitle'.tr(),
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
              Icon(Icons.error_outline, size: 48, color: context.colors.error),
              SizedBox(height: AppSpacing.md),
              Text(
                'admin.apartments_load_error'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(color: context.colors.error),
              ),
              SizedBox(height: AppSpacing.md),
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
    return AdminApartmentsRepository.hasActiveFutureReservations(
      tenantId: tenantId,
      apartmentId: apartmentId,
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
    BuildContext context,
    WidgetRef ref,
    List<ApartmentRow> apartments,
  ) async {
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      final userId = SupabaseService.client.auth.currentUser?.id;
      final cascadeReason = 'super_admin.audit_log_cascade_reason_apartment_deleted'.tr();

      await AdminApartmentsRepository.softDeleteApartmentsCascade(
        tenantId: tenantId,
        userId: userId,
        apartments: apartments,
        cascadeReason: cascadeReason,
      );

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
          backgroundColor: context.customColors.success,
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
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
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
                fillColor: context.colors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
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

/// Jedna karta apartmánu – prémiová dekorace [premiumCardDecoration], stav úklidu z [apartmentStatusProvider],
/// obsazenost z [currentMonthReservationsProvider] (měsíční řez v Supabase).
///
/// PROČ: Karta záměrně neukazuje „health“ upozornění ani dlouhý provozní metadata blok –
/// falešné alarmy rušily UI; detail (keybox, parkování, …) zůstává v editačním dialogu.
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

    final reservationsAsync = ref.watch(currentMonthReservationsProvider);
    final status = ref.watch(apartmentStatusProvider(apartment.id));
    final radius = BorderRadius.circular(AppSpacing.md);

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onEdit(apartment),
          borderRadius: radius,
          child: Ink(
            decoration: premiumCardDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Avatar – kruhový jako u _MemberCard
          CircleAvatar(
            radius: 28,
            backgroundColor: context.colors.tertiaryContainer,
            child: Icon(Icons.apartment, size: 28, color: context.colors.onTertiaryContainer),
          ),
          SizedBox(width: AppSpacing.md),
          // 2. Střední sloupec – hlavička, metadata, progress bar, poznámky
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        apartment.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (apartment.investmentTrackingEnabled) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'admin.apartments_investment_tracking_badge_tooltip'.tr(),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.show_chart_rounded,
                            size: 22,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: addr.isEmpty ? '–' : addr,
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
                    // Jemné barvy: nízká obsazenost = error, střední = warning, vysoká = success (téma).
                    final barColor = ratio < 0.3
                        ? context.colors.error
                        : ratio < 0.7
                            ? context.customColors.warning
                            : context.customColors.success;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'admin.apartments_occupancy_this_month'.tr(),
                              style: context.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'admin.apartments_occupancy_days'.tr(
                                namedArgs: {
                                  'occupied': '$occupied',
                                  'total': '$total',
                                },
                              ),
                              style: context.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceContainerHighest,
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
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.customColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: context.customColors.warning,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              apartment.ownerNotes!.trim(),
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.customColors.warning,
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
              _buildStatusBadge(context, status),
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => onDelete(apartment),
                icon: Icon(
                  Icons.delete_outline,
                  color: context.colors.error,
                ),
                tooltip: 'admin.apartments_delete'.tr(),
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.errorContainer,
                ),
              ),
            ],
          ),
        ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sekce „Prémiové funkce“ na konci záložky základních údajů v dialozích bytu.
///
/// PROČ: Příznak investičního modulu je volitelná nadstavba; na konci formuláře neruší
/// povinná pole (název, adresa) a dispečink vidí jasně oddělený prémiový blok.
Widget _apartmentPremiumFeaturesBlock(
  BuildContext context, {
  required bool investmentTrackingEnabled,
  required ValueChanged<bool> onInvestmentTrackingChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 8),
      Text(
        'admin.apartments_section_premium'.tr(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        value: investmentTrackingEnabled,
        onChanged: onInvestmentTrackingChanged,
        title: Text('admin.apartments_investment_tracking_switch'.tr()),
        secondary: Icon(
          Icons.show_chart_rounded,
          color: context.colors.primary,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    ],
  );
}

/// Odpovědný za úkol výběru nájmu: jen řádky s `profiles.id` (FK na bytě), bez majitelů.
///
/// PROČ: Dříve se filtrovalo `role == worker`, takže účty admin/manager (běžné u malé agentury)
/// zmizely z dropdownu → prázdná nabídka. Stejná logika jako u úkolů: personál ≠ property_owner.
List<TeamMember> _rentTaskAssigneeCandidates(List<TeamMember> members) {
  return members
      .where(
        (m) =>
            !m.isFromInvitation &&
            (m.profileId?.trim().isNotEmpty ?? false) &&
            m.role != 'property_owner',
      )
      .toList();
}

/// Režim pronájmu (STR vs. dlouhodobý), smlouva od–do a nastavení automatizace nájmu.
///
/// PROČ: Společný widget pro dialog Přidat i Upravit byt; při přepnutí na krátkodobý režim
/// rodič vymaže datumy a sjednotí pole nájmu na výchozí hodnoty pro Supabase.
class _ApartmentRentalLeaseFormSection extends StatelessWidget {
  const _ApartmentRentalLeaseFormSection({
    required this.rentalMode,
    required this.leaseStart,
    required this.leaseEnd,
    required this.onRentalModeChanged,
    required this.onPickLeaseStart,
    required this.onPickLeaseEnd,
    required this.onClearLeaseDates,
    required this.rentAmountController,
    required this.rentDueDay,
    required this.onRentDueDayChanged,
    required this.rentCollectionMode,
    required this.onRentCollectionModeChanged,
    required this.rentTaskAssigneeId,
    required this.onRentTaskAssigneeChanged,
    required this.workerAssigneeOptions,
    this.teamListLoading = false,
    this.teamListLoadFailed = false,
  });

  final String rentalMode;
  final DateTime? leaseStart;
  final DateTime? leaseEnd;
  final ValueChanged<String> onRentalModeChanged;
  final VoidCallback onPickLeaseStart;
  final VoidCallback onPickLeaseEnd;
  final VoidCallback onClearLeaseDates;
  /// Měsíční nájem – ukládá se jen u dlouhodobého režimu (jinak rodič pošle 0).
  final TextEditingController rentAmountController;
  final int rentDueDay;
  final ValueChanged<int> onRentDueDayChanged;
  final String rentCollectionMode;
  final ValueChanged<String> onRentCollectionModeChanged;
  final String? rentTaskAssigneeId;
  final ValueChanged<String?> onRentTaskAssigneeChanged;
  /// Aktivní členové týmu s `profiles.id` pro dropdown při režimu úkolu (vč. admin/manager).
  final List<TeamMember> workerAssigneeOptions;
  /// Načítá se [teamFullListProvider] – zobrazíme indikátor místo prázdné roletky.
  final bool teamListLoading;
  /// Chyba načtení týmu – text místo slepého prázdného dropdownu.
  final bool teamListLoadFailed;

  @override
  Widget build(BuildContext context) {
    final onVar = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.apartments_section_rental'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: onVar,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'admin.apartments_rental_mode_hint'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onVar),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            ButtonSegment<String>(
              value: kApartmentRentalModeShortTerm,
              label: Text('admin.apartments_rental_short'.tr()),
              icon: const Icon(Icons.luggage_outlined),
            ),
            ButtonSegment<String>(
              value: kApartmentRentalModeLongTerm,
              label: Text('admin.apartments_rental_long'.tr()),
              icon: const Icon(Icons.home_work_outlined),
            ),
          ],
          selected: {rentalMode},
          onSelectionChanged: (Set<String> next) => onRentalModeChanged(next.first),
        ),
        if (rentalMode == kApartmentRentalModeLongTerm) ...[
          const SizedBox(height: 16),
          Text(
            'admin.apartments_lease_section'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'admin.apartments_lease_hint'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onVar),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickLeaseStart,
                  icon: const Icon(Icons.event_available_outlined, size: 20),
                  label: Text(
                    leaseStart != null
                        ? _formatApartmentLeaseDay(context, leaseStart!)
                        : 'admin.apartments_lease_start'.tr(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickLeaseEnd,
                  icon: const Icon(Icons.event_busy_outlined, size: 20),
                  label: Text(
                    leaseEnd != null
                        ? _formatApartmentLeaseDay(context, leaseEnd!)
                        : 'admin.apartments_lease_end'.tr(),
                  ),
                ),
              ),
            ],
          ),
          if (leaseStart != null || leaseEnd != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClearLeaseDates,
                child: Text('admin.apartments_lease_clear'.tr()),
              ),
            ),
        ],
      ],
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
      borderSide: BorderSide(color: context.colors.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.colors.outlineVariant),
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
        Icon(icon, size: 16, color: context.colors.onSurfaceVariant),
        SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Potvrzení příjmu nájmu (P&L) v editaci bytu – jen long_term + notification + investiční modul.
///
/// PROČ: Admin má nově RLS INSERT/UPDATE na income řádek u tohoto režimu; UI zrcadlí majitelský portál.
class _AdminEditApartmentLongTermRentPnlSection extends ConsumerStatefulWidget {
  const _AdminEditApartmentLongTermRentPnlSection({
    required this.apartmentId,
    required this.rentAmount,
    required this.currencyCode,
  });

  final String apartmentId;
  final double rentAmount;
  final String currencyCode;

  @override
  ConsumerState<_AdminEditApartmentLongTermRentPnlSection> createState() =>
      _AdminEditApartmentLongTermRentPnlSectionState();
}

class _AdminEditApartmentLongTermRentPnlSectionState extends ConsumerState<_AdminEditApartmentLongTermRentPnlSection> {
  bool _checking = true;
  bool _hasIncomeRow = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshIncomeFlag();
  }

  Future<void> _refreshIncomeFlag() async {
    setState(() => _checking = true);
    try {
      final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
      final res = await SupabaseService.client
          .from('apartment_investment_pnl_entries')
          .select('id')
          .eq('apartment_id', widget.apartmentId)
          .eq('entry_month', OwnerApartmentPnlRepository.monthFirstDayToApiDate(month))
          .eq('entry_type', 'income')
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _hasIncomeRow = res != null;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasIncomeRow = false;
        _checking = false;
      });
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final month = OwnerApartmentPnlRepository.firstDayOfMonthUtc(DateTime.now());
      await OwnerApartmentPnlRepository.upsertIncomeEntry(
        apartmentId: widget.apartmentId,
        entryMonthFirstDayUtc: month,
        amount: widget.rentAmount,
        description: OwnerApartmentPnlRepository.kDbDescriptionRentTransferConfirmed,
      );
      if (!mounted) return;
      await _refreshIncomeFlag();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.apartments_long_term_rent_pnl_confirmed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amt = widget.rentAmount.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.apartments_long_term_rent_pnl_section_title'.tr(),
            style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'admin.apartments_long_term_rent_expected'.tr(namedArgs: {'amount': '$amt ${widget.currencyCode}'}),
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_checking)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_hasIncomeRow)
            Text(
              'admin.apartments_long_term_rent_pnl_paid'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('admin.apartments_confirm_long_term_rent_pnl'.tr()),
            ),
        ],
      ),
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
  /// Jedno pole: vložený text z Mapy.cz / Google (viz [parseSmartGpsString]).
  final _gpsController = TextEditingController();
  final _codeController = TextEditingController();
  final _keyboxController = TextEditingController();
  final _parkingInstructionsController = TextEditingController();
  final _reviewLinkController = TextEditingController();
  final _checkInController = TextEditingController(text: '15:00');
  final _checkOutController = TextEditingController(text: '10:00');
  final _cleaningDurationController = TextEditingController(text: '120');
  final _ownerNotesController = TextEditingController();
  final _monthlyManagementFeeController = TextEditingController(text: '0');
  bool _isSaving = false;
  /// Probíhá dotaz na Nominatim (geokódování adresy → GPS).
  bool _isGeocodingAddress = false;
  /// Vybraná oblast (zone_id). null = Žádná oblast.
  String? _selectedZoneId;
  /// Začátek fakturace paušálu – první den měsíce. Oba null = neúčtovat od konkrétního data (zpětná kompatibilita).
  int? _managedFromMonth;
  int? _managedFromYear;
  /// Služby a ceník (Tab 2): serviceId -> stav. Naplní se z tenantServicesProvider, uživatel zapíná a vyplňuje.
  Map<String, ApartmentServiceEditState> _servicesState = {};
  /// Prémiový modul investiční kalkulačky / P&L majitele (`apartments.investment_tracking_enabled`).
  bool _investmentTrackingEnabled = false;
  /// Krátkodobý / dlouhodobý pronájem (`apartments.rental_mode`).
  String _rentalMode = kApartmentRentalModeShortTerm;
  /// Platnost smlouvy – pouze u [kApartmentRentalModeLongTerm], nullable.
  DateTime? _leaseStart;
  DateTime? _leaseEnd;
  /// Měsíční nájem a splatnost – jen smysl u dlouhodobého režimu (denní rent-monitor).
  final _rentAmountController = TextEditingController(text: '0');
  int _rentDueDay = 1;
  String _rentCollectionMode = kApartmentRentCollectionModeNotification;
  String? _rentTaskAssigneeId;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _gpsController.dispose();
    _codeController.dispose();
    _keyboxController.dispose();
    _parkingInstructionsController.dispose();
    _reviewLinkController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _cleaningDurationController.dispose();
    _ownerNotesController.dispose();
    _monthlyManagementFeeController.dispose();
    _rentAmountController.dispose();
    super.dispose();
  }

  /// Doplní lat/lon z textové adresy (OSM Nominatim) – tlačítko vedle pole adresy.
  Future<void> _fetchGpsFromAddress() async {
    final addr = _addressController.text.trim();
    if (addr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_no_address'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGeocodingAddress = true);
    try {
      final ll = await GeocodingService().getCoordinatesFromAddress(addr);
      if (!mounted) return;
      if (ll == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_no_result'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _gpsController.text = '${ll.latitude}, ${ll.longitude}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_success'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_error'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeocodingAddress = false);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final geoPair = GeoJsonPoint.tryParseSmartGpsText(_gpsController.text);
    final geoJson = GeoJsonPoint.toPostgrestJson(geoPair?.latitude, geoPair?.longitude);
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (_rentalMode == kApartmentRentalModeLongTerm &&
        _leaseStart != null &&
        _leaseEnd != null &&
        _leaseEnd!.isBefore(_leaseStart!)) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.apartments_lease_invalid_range'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
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
        'parking_instructions': _parkingInstructionsController.text.trim().isEmpty
            ? null
            : _parkingInstructionsController.text.trim(),
        'review_link': _reviewLinkController.text.trim().isEmpty
            ? null
            : _reviewLinkController.text.trim(),
        'check_in_time': _checkInController.text.trim().isEmpty ? '15:00' : _checkInController.text.trim(),
        'check_out_time': _checkOutController.text.trim().isEmpty ? '10:00' : _checkOutController.text.trim(),
        'standard_cleaning_duration': duration,
        'owner_notes': _ownerNotesController.text.trim().isEmpty ? null : _ownerNotesController.text.trim(),
        'monthly_management_fee': _parseMonthlyFee(_monthlyManagementFeeController.text),
        'managed_from': _managedFromMonth != null && _managedFromYear != null
            ? '$_managedFromYear-${_managedFromMonth!.toString().padLeft(2, '0')}-01'
            : null,
        'geo_location': geoJson,
        'investment_tracking_enabled': _investmentTrackingEnabled,
        'rental_mode': _rentalMode,
        'lease_start_date': _rentalMode == kApartmentRentalModeLongTerm
            ? _apartmentLeaseDateToPayload(_leaseStart)
            : null,
        'lease_end_date': _rentalMode == kApartmentRentalModeLongTerm
            ? _apartmentLeaseDateToPayload(_leaseEnd)
            : null,
      };
      final newId = await ApartmentRepository.insertApartment(tenantId, insertPayload);

      // KROK 1b: Pokud byl předán prefilledClient (owner), přiřaď ho jako majitele bytu.
      final prefilled = widget.prefilledClient;
      if (prefilled != null &&
          (prefilled.clientType?.toLowerCase() ?? '') == 'owner' &&
          prefilled.profileId != null &&
          prefilled.profileId!.trim().isNotEmpty) {
        // PROČ safeFrom: tenant_id na řádku (migrace) + safeInsertPayload – stejná Frontend Firewall jako jinde.
        await SupabaseService.safeFrom('apartment_owners', tenantId).insert({
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
          backgroundColor: context.customColors.success,
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
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
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
      final content = (e is StateError && e.message == 'admin.apartments_error_insert_no_id')
          ? 'admin.apartments_error_insert_no_id'.tr()
          : 'common.generic_error_user_friendly'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(content),
          backgroundColor: context.colors.error,
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
    final teamAsync = ref.watch(teamFullListProvider);
    final workerAssignees = teamAsync.maybeWhen(
      data: _rentTaskAssigneeCandidates,
      orElse: () => <TeamMember>[],
    );
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
                  color: context.colors.onSurface,
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isGeocodingAddress
                ? null
                : () => _fetchGpsFromAddress(),
            icon: _isGeocodingAddress
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text('admin.geocoding_fetch_gps'.tr()),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _gpsController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.explore_outlined),
            labelText: 'admin.geo_smart_gps_field'.tr(),
            hintText: 'admin.geo_smart_gps_hint'.tr(),
          ),
          keyboardType: TextInputType.text,
          maxLines: 2,
          validator: (_) => GeoJsonPoint.validateOptionalSmartGpsText(
                _gpsController.text,
              )
              ?.tr(),
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
        TextFormField(
          controller: _parkingInstructionsController,
          minLines: 2,
          maxLines: 3,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.local_parking_outlined),
            labelText: 'admin.field_parking_instructions'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _reviewLinkController,
          keyboardType: TextInputType.url,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.reviews_outlined),
            labelText: 'admin.field_review_link'.tr(),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: _monthlyManagementFeeController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.monetization_on_outlined),
            labelText: 'admin.apartments_monthly_management_fee'.tr(),
            hintText: 'admin.apartments_monthly_management_fee_hint'.tr(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        Text(
          'admin.apartments_managed_from'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _managedFromMonth,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                  labelText: 'admin.apartments_managed_from'.tr(),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('admin.apartments_managed_from_empty'.tr()),
                  ),
                  ...List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem<int?>(
                    value: m,
                    child: Text(DateFormat('MMMM', context.locale.toString()).format(DateTime(2000, m, 1))),
                  )),
                ],
                onChanged: (v) {
                  setState(() {
                    _managedFromMonth = v;
                    if (v == null) _managedFromYear = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _managedFromYear,
                decoration: _appleVibeInputDecoration(
                  context,
                  labelText: 'admin.apartments_managed_from_year'.tr(),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('admin.general.dash_placeholder'.tr()),
                  ),
                  ...List.generate(15, (i) => DateTime.now().year - 5 + i).map((y) => DropdownMenuItem<int?>(
                    value: y,
                    child: Text(
                      'admin.general.year_format'.tr(namedArgs: {'year': y.toString()}),
                    ),
                  )),
                ],
                onChanged: _managedFromMonth == null ? null : (v) => setState(() => _managedFromYear = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'admin.apartments_managed_from_hint'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        _ApartmentRentalLeaseFormSection(
          rentalMode: _rentalMode,
          leaseStart: _leaseStart,
          leaseEnd: _leaseEnd,
          onRentalModeChanged: (m) {
            setState(() {
              _rentalMode = m;
              if (m == kApartmentRentalModeShortTerm) {
                _leaseStart = null;
                _leaseEnd = null;
              }
            });
          },
          onPickLeaseStart: _pickLeaseStart,
          onPickLeaseEnd: _pickLeaseEnd,
          onClearLeaseDates: () => setState(() {
            _leaseStart = null;
            _leaseEnd = null;
          }),
          rentAmountController: _rentAmountController,
          rentDueDay: _rentDueDay,
          onRentDueDayChanged: (d) => setState(() => _rentDueDay = d),
          rentCollectionMode: _rentCollectionMode,
          onRentCollectionModeChanged: (mode) => setState(() {
            _rentCollectionMode = mode;
            if (mode == kApartmentRentCollectionModeNotification) {
              _rentTaskAssigneeId = null;
            }
          }),
          rentTaskAssigneeId: _rentTaskAssigneeId,
          onRentTaskAssigneeChanged: (id) => setState(() => _rentTaskAssigneeId = id),
          workerAssigneeOptions: workerAssignees,
          teamListLoading: teamAsync.isLoading,
          teamListLoadFailed: teamAsync.hasError,
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.section_schedule'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
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
                color: context.colors.onSurfaceVariant,
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
        _apartmentPremiumFeaturesBlock(
          context,
          investmentTrackingEnabled: _investmentTrackingEnabled,
          onInvestmentTrackingChanged: (v) => setState(() => _investmentTrackingEnabled = v),
        ),
        ],
      ),
    );
  }

  Future<void> _pickLeaseStart() async {
    final initial = _leaseStart != null
        ? DateTime(_leaseStart!.year, _leaseStart!.month, _leaseStart!.day)
        : DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _leaseStart = DateTime.utc(d.year, d.month, d.day));
  }

  Future<void> _pickLeaseEnd() async {
    final initial = _leaseEnd != null
        ? DateTime(_leaseEnd!.year, _leaseEnd!.month, _leaseEnd!.day)
        : (_leaseStart != null
            ? DateTime(_leaseStart!.year, _leaseStart!.month, _leaseStart!.day)
            : DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _leaseEnd = DateTime.utc(d.year, d.month, d.day));
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
                transitPriceEur: null,
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
                    color: context.colors.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin.apartment_services_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
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
                  color: context.colors.onSurface,
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
          transitPriceEur: null,
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
                              prefixIcon: Icon(Icons.payments_outlined, color: context.colors.outline),
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
                            initialValue: _formatServiceTransitPriceForInput(
                              state.transitPriceEur,
                              preferredCurrency: preferredCurrency,
                              currencies: currencies,
                            ),
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.currency_exchange_outlined),
                              labelText: 'admin.field_transit_price_apartment'
                                  .tr(namedArgs: {'code': preferredCurrency}),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              final parsed = double.tryParse(v.replaceAll(',', '.'));
                              final eur = parsed == null
                                  ? null
                                  : CurrencyService.toEur(parsed, preferredCurrency, currencies);
                              setState(() {
                                _servicesState[s.id] = state.copyWith(
                                  transitPriceEur: eur,
                                  clearTransitPriceEur: eur == null,
                                );
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
                        // PROČ: Šablona checklistu z katalogu (jen aktivní) – vázaná na tuto službu u tohoto bytu (apartment_services.checklist_template_id).
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: ref.watch(checklistTemplatesListProvider).when(
                            data: (templates) {
                              final active = templates.where((t) => t.isActive).toList();
                              final validIds = active.map((t) => t.id).toSet();
                              final raw = state.checklistTemplateId;
                              final validValue =
                                  raw != null && raw.isNotEmpty && validIds.contains(raw) ? raw : null;
                              return DropdownButtonFormField<String?>(
                                initialValue: validValue,
                                decoration: _appleVibeInputDecoration(
                                  context,
                                  prefixIcon: const Icon(Icons.checklist_rtl_outlined),
                                  labelText: 'apartments.assign_checklist'.tr(),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('checklists.no_checklist'.tr()),
                                  ),
                                  ...active.map(
                                    (t) => DropdownMenuItem<String?>(
                                      value: t.id,
                                      child: Text(t.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _servicesState[s.id] = state.copyWith(
                                      checklistTemplateId: v,
                                      clearChecklistTemplateId: v == null,
                                    );
                                  });
                                },
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                            error: (_, _) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'checklists.templates_load_error'.tr(),
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
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
  /// Jedno pole GPS (paste z map) – viz [parseSmartGpsString].
  late final TextEditingController _gpsController;
  late final TextEditingController _codeController;
  late final TextEditingController _keyboxController;
  late final TextEditingController _parkingInstructionsController;
  late final TextEditingController _reviewLinkController;
  late final TextEditingController _checkInController;
  late final TextEditingController _checkOutController;
  late final TextEditingController _cleaningDurationController;
  late final TextEditingController _ownerNotesController;
  late final TextEditingController _monthlyManagementFeeController;
  bool _isSaving = false;
  /// Probíhá dotaz na Nominatim (geokódování adresy → GPS).
  bool _isGeocodingAddress = false;
  /// Začátek fakturace paušálu – první den měsíce. Oba null = neúčtovat od konkrétního data.
  int? _managedFromMonth;
  int? _managedFromYear;
  /// Tab 2: stav služeb načtený z apartment_services + katalog (tenant_services).
  Map<String, ApartmentServiceEditState> _servicesState = {};
  bool _servicesLoaded = false;
  /// Vybraná oblast (zone_id). null = Žádná oblast.
  String? _selectedZoneId;
  /// Prémiový modul investiční kalkulačky / P&L majitele.
  late bool _investmentTrackingEnabled;
  /// Krátkodobý / dlouhodobý pronájem (`apartments.rental_mode`).
  late String _rentalMode;
  DateTime? _leaseStart;
  DateTime? _leaseEnd;
  /// Dlouhodobý nájem – částka, splatnost, režim připomínky vs. úkol (rent-monitor).
  late final TextEditingController _rentAmountController;
  late int _rentDueDay;
  late String _rentCollectionMode;
  String? _rentTaskAssigneeId;

  @override
  void initState() {
    super.initState();
    final a = widget.apartment;
    _investmentTrackingEnabled = a.investmentTrackingEnabled;
    _rentalMode = a.rentalMode;
    _leaseStart = a.leaseStartDate;
    _leaseEnd = a.leaseEndDate;
    _selectedZoneId = a.zoneId;
    _nameController = TextEditingController(text: a.name);
    _addressController = TextEditingController(text: a.address ?? '');
    final gpsInitial = (a.latitude != null && a.longitude != null)
        ? '${a.latitude}, ${a.longitude}'
        : '';
    _gpsController = TextEditingController(text: gpsInitial);
    _codeController = TextEditingController(text: a.code ?? '');
    _keyboxController = TextEditingController(text: a.keybox ?? '');
    _parkingInstructionsController = TextEditingController(text: a.parkingInstructions ?? '');
    _reviewLinkController = TextEditingController(text: a.reviewLink ?? '');
    _checkInController = TextEditingController(text: a.checkInTime ?? '15:00');
    _checkOutController = TextEditingController(text: a.checkOutTime ?? '10:00');
    _cleaningDurationController =
        TextEditingController(text: '${a.standardCleaningDuration ?? 120}');
    _ownerNotesController = TextEditingController(text: a.ownerNotes ?? '');
    _monthlyManagementFeeController = TextEditingController(
      text: a.monthlyManagementFee == 0 ? '0' : a.monthlyManagementFee.toString(),
    );
    _rentAmountController = TextEditingController(
      text: a.rentAmount == 0 ? '0' : a.rentAmount.toString(),
    );
    _rentDueDay = a.rentDueDay.clamp(1, 31);
    _rentCollectionMode = a.rentCollectionMode;
    _rentTaskAssigneeId = a.rentTaskAssigneeId;
    if (a.managedFrom != null) {
      _managedFromMonth = a.managedFrom!.month;
      _managedFromYear = a.managedFrom!.year;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _gpsController.dispose();
    _codeController.dispose();
    _keyboxController.dispose();
    _parkingInstructionsController.dispose();
    _reviewLinkController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _cleaningDurationController.dispose();
    _ownerNotesController.dispose();
    _monthlyManagementFeeController.dispose();
    _rentAmountController.dispose();
    super.dispose();
  }

  /// Doplní lat/lon z textové adresy (OSM Nominatim) – tlačítko vedle pole adresy.
  Future<void> _fetchGpsFromAddress() async {
    final addr = _addressController.text.trim();
    if (addr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_no_address'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGeocodingAddress = true);
    try {
      final ll = await GeocodingService().getCoordinatesFromAddress(addr);
      if (!mounted) return;
      if (ll == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_no_result'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _gpsController.text = '${ll.latitude}, ${ll.longitude}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.geocoding_success'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.geocoding_error'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeocodingAddress = false);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final geoPair = GeoJsonPoint.tryParseSmartGpsText(_gpsController.text);
    final geoJson = GeoJsonPoint.toPostgrestJson(geoPair?.latitude, geoPair?.longitude);
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (_rentalMode == kApartmentRentalModeLongTerm &&
        _leaseStart != null &&
        _leaseEnd != null &&
        _leaseEnd!.isBefore(_leaseStart!)) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.apartments_lease_invalid_range'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final duration = int.tryParse(_cleaningDurationController.text) ?? 120;
    try {
      // Dvoukrokové ukládání (Override Pattern Tier 2): nejdřív úprava bytu, potom přepsání apartment_services.
      // KROK 1: Aktualizace záznamu bytu přes repozitář (jednotné místo pro PATCH).
      await ApartmentRepository.updateApartment(tenantId, widget.apartment.id, {
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
        'parking_instructions': _parkingInstructionsController.text.trim().isEmpty
            ? null
            : _parkingInstructionsController.text.trim(),
        'review_link': _reviewLinkController.text.trim().isEmpty
            ? null
            : _reviewLinkController.text.trim(),
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
        'monthly_management_fee': _parseMonthlyFee(_monthlyManagementFeeController.text),
        'managed_from': _managedFromMonth != null && _managedFromYear != null
            ? '$_managedFromYear-${_managedFromMonth!.toString().padLeft(2, '0')}-01'
            : null,
        'geo_location': geoJson,
        'investment_tracking_enabled': _investmentTrackingEnabled,
        'rental_mode': _rentalMode,
        'lease_start_date': _rentalMode == kApartmentRentalModeLongTerm
            ? _apartmentLeaseDateToPayload(_leaseStart)
            : null,
        'lease_end_date': _rentalMode == kApartmentRentalModeLongTerm
            ? _apartmentLeaseDateToPayload(_leaseEnd)
            : null,
      });

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
          backgroundColor: context.customColors.success,
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
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
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
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
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
                transitPriceEur: null,
                customDescription: null,
                triggerType: 'on_demand',
                scheduleInterval: null,
                isMandatory: false,
                payerType: 'guest',
                requiresPhoto: null,
              );
            }
            final rowTransitRaw = row.metadata?['transit_price'];
            final rowTransit = rowTransitRaw == null
                ? null
                : (rowTransitRaw is num
                    ? rowTransitRaw.toDouble()
                    : double.tryParse(rowTransitRaw.toString()));
            return ApartmentServiceEditState(
              serviceId: s.id,
              serviceName: s.name,
              defaultPriceEur: s.defaultPrice?.toDouble(),
              enabled: true,
              customPriceEur: row.customPrice?.toDouble(),
              transitPriceEur: rowTransit,
              customDescription: row.customDescription,
              triggerType: row.triggerType,
              scheduleInterval: row.scheduleInterval,
              isMandatory: row.isMandatory,
              payerType: row.payerType,
              requiresPhoto: row.requiresPhoto,
              checklistTemplateId: row.checklistTemplateId,
            );
          }(),
      };
      _servicesLoaded = true;
    });
  }

  Widget _buildTab1Basic(BuildContext context) {
    final teamAsync = ref.watch(teamFullListProvider);
    final workerAssignees = teamAsync.maybeWhen(
      data: _rentTaskAssigneeCandidates,
      orElse: () => <TeamMember>[],
    );
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
                  color: context.colors.onSurface,
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isGeocodingAddress
                ? null
                : () => _fetchGpsFromAddress(),
            icon: _isGeocodingAddress
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text('admin.geocoding_fetch_gps'.tr()),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _gpsController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.explore_outlined),
            labelText: 'admin.geo_smart_gps_field'.tr(),
            hintText: 'admin.geo_smart_gps_hint'.tr(),
          ),
          keyboardType: TextInputType.text,
          maxLines: 2,
          validator: (_) => GeoJsonPoint.validateOptionalSmartGpsText(
                _gpsController.text,
              )
              ?.tr(),
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
        TextFormField(
          controller: _parkingInstructionsController,
          minLines: 2,
          maxLines: 3,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.local_parking_outlined),
            labelText: 'admin.field_parking_instructions'.tr(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _reviewLinkController,
          keyboardType: TextInputType.url,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.reviews_outlined),
            labelText: 'admin.field_review_link'.tr(),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: _monthlyManagementFeeController,
          decoration: _appleVibeInputDecoration(
            context,
            prefixIcon: const Icon(Icons.monetization_on_outlined),
            labelText: 'admin.apartments_monthly_management_fee'.tr(),
            hintText: 'admin.apartments_monthly_management_fee_hint'.tr(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        Text(
          'admin.apartments_managed_from'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _managedFromMonth,
                decoration: _appleVibeInputDecoration(
                  context,
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                  labelText: 'admin.apartments_managed_from'.tr(),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('admin.apartments_managed_from_empty'.tr()),
                  ),
                  ...List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem<int?>(
                    value: m,
                    child: Text(DateFormat('MMMM', context.locale.toString()).format(DateTime(2000, m, 1))),
                  )),
                ],
                onChanged: (v) {
                  setState(() {
                    _managedFromMonth = v;
                    if (v == null) _managedFromYear = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _managedFromYear,
                decoration: _appleVibeInputDecoration(
                  context,
                  labelText: 'admin.apartments_managed_from_year'.tr(),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('admin.general.dash_placeholder'.tr()),
                  ),
                  ...List.generate(15, (i) => DateTime.now().year - 5 + i).map((y) => DropdownMenuItem<int?>(
                    value: y,
                    child: Text(
                      'admin.general.year_format'.tr(namedArgs: {'year': y.toString()}),
                    ),
                  )),
                ],
                onChanged: _managedFromMonth == null ? null : (v) => setState(() => _managedFromYear = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'admin.apartments_managed_from_hint'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        _ApartmentRentalLeaseFormSection(
          rentalMode: _rentalMode,
          leaseStart: _leaseStart,
          leaseEnd: _leaseEnd,
          onRentalModeChanged: (m) {
            setState(() {
              _rentalMode = m;
              if (m == kApartmentRentalModeShortTerm) {
                _leaseStart = null;
                _leaseEnd = null;
              }
            });
          },
          onPickLeaseStart: _pickLeaseStart,
          onPickLeaseEnd: _pickLeaseEnd,
          onClearLeaseDates: () => setState(() {
            _leaseStart = null;
            _leaseEnd = null;
          }),
          rentAmountController: _rentAmountController,
          rentDueDay: _rentDueDay,
          onRentDueDayChanged: (d) => setState(() => _rentDueDay = d),
          rentCollectionMode: _rentCollectionMode,
          onRentCollectionModeChanged: (mode) => setState(() {
            _rentCollectionMode = mode;
            if (mode == kApartmentRentCollectionModeNotification) {
              _rentTaskAssigneeId = null;
            }
          }),
          rentTaskAssigneeId: _rentTaskAssigneeId,
          onRentTaskAssigneeChanged: (id) => setState(() => _rentTaskAssigneeId = id),
          workerAssigneeOptions: workerAssignees,
          teamListLoading: teamAsync.isLoading,
          teamListLoadFailed: teamAsync.hasError,
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.section_schedule'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
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
                color: context.colors.onSurfaceVariant,
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
        _apartmentPremiumFeaturesBlock(
          context,
          investmentTrackingEnabled: _investmentTrackingEnabled,
          onInvestmentTrackingChanged: (v) => setState(() => _investmentTrackingEnabled = v),
        ),
        ],
      ),
    );
  }

  Future<void> _pickLeaseStart() async {
    final initial = _leaseStart != null
        ? DateTime(_leaseStart!.year, _leaseStart!.month, _leaseStart!.day)
        : DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _leaseStart = DateTime.utc(d.year, d.month, d.day));
  }

  Future<void> _pickLeaseEnd() async {
    final initial = _leaseEnd != null
        ? DateTime(_leaseEnd!.year, _leaseEnd!.month, _leaseEnd!.day)
        : (_leaseStart != null
            ? DateTime(_leaseStart!.year, _leaseStart!.month, _leaseStart!.day)
            : DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() => _leaseEnd = DateTime.utc(d.year, d.month, d.day));
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
                    color: context.colors.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin.apartment_services_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
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
                    color: context.colors.onSurface,
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
                  color: context.colors.onSurface,
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
          transitPriceEur: null,
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
                              prefixIcon: Icon(Icons.payments_outlined, color: context.colors.outline),
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
                            initialValue: _formatServiceTransitPriceForInput(
                              state.transitPriceEur,
                              preferredCurrency: preferredCurrency,
                              currencies: currencies,
                            ),
                            decoration: _appleVibeInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.currency_exchange_outlined),
                              labelText: 'admin.field_transit_price_apartment'
                                  .tr(namedArgs: {'code': preferredCurrency}),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) {
                              final parsed = double.tryParse(v.replaceAll(',', '.'));
                              final eur = parsed == null
                                  ? null
                                  : CurrencyService.toEur(parsed, preferredCurrency, currencies);
                              setState(() {
                                _servicesState[s.id] = state.copyWith(
                                  transitPriceEur: eur,
                                  clearTransitPriceEur: eur == null,
                                );
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
                        // PROČ: Šablona checklistu z katalogu (jen aktivní) – vázaná na tuto službu u tohoto bytu (apartment_services.checklist_template_id).
                        Container(
                          margin: const EdgeInsets.only(bottom: 24.0),
                          child: ref.watch(checklistTemplatesListProvider).when(
                            data: (templates) {
                              final active = templates.where((t) => t.isActive).toList();
                              final validIds = active.map((t) => t.id).toSet();
                              final raw = state.checklistTemplateId;
                              final validValue =
                                  raw != null && raw.isNotEmpty && validIds.contains(raw) ? raw : null;
                              return DropdownButtonFormField<String?>(
                                initialValue: validValue,
                                decoration: _appleVibeInputDecoration(
                                  context,
                                  prefixIcon: const Icon(Icons.checklist_rtl_outlined),
                                  labelText: 'apartments.assign_checklist'.tr(),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('checklists.no_checklist'.tr()),
                                  ),
                                  ...active.map(
                                    (t) => DropdownMenuItem<String?>(
                                      value: t.id,
                                      child: Text(t.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _servicesState[s.id] = state.copyWith(
                                      checklistTemplateId: v,
                                      clearChecklistTemplateId: v == null,
                                    );
                                  });
                                },
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                            error: (_, _) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'checklists.templates_load_error'.tr(),
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
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
                            initialValue: _requiresPhotoToKey(state.requiresPhoto),
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

  /// Formát inputu transit price v měně UI; interně držíme EUR pro konzistentní ukládání.
  String _formatServiceTransitPriceForInput(
    double? transitPriceEur, {
    required String preferredCurrency,
    required List<CurrencyRow> currencies,
  }) {
    if (transitPriceEur == null || transitPriceEur <= 0) return '';
    final value = CurrencyService.convert(
      transitPriceEur,
      preferredCurrency,
      currencies,
    );
    return value.toStringAsFixed(2);
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
                  color: context.colors.onSurface,
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
                  style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: owners.map((o) => _OwnerListTile(
                owner: o,
                onRemove: () => _removeOwner(context, o.id, o.name),
                onSetPrimaryBilling: () => _setPrimaryBillingOwner(context, o.id),
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
              'common.generic_error_user_friendly'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(color: context.colors.error),
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

  /// Nastaví majitele jako hlavního plátce pro tento byt (is_primary_billing).
  /// Ostatní majitelé téhož bytu se automaticky přepnou na false.
  Future<void> _setPrimaryBillingOwner(BuildContext context, String apartmentOwnersRecordId) async {
    final messenger = ScaffoldMessenger.of(context);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      await ApartmentOwnersRepository.setPrimaryBillingOwner(
        tenantId: tenantId,
        apartmentId: widget.apartment.id,
        apartmentOwnersRecordId: apartmentOwnersRecordId,
      );
      if (!mounted) return;
      ref.invalidate(apartmentOwnersForApartmentProvider(widget.apartment.id));
      // PROČ: Po await musí být kontrola stejného BuildContextu jako u theme extensions – ne jen State.mounted.
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.owners_primary_billing_set'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      await ApartmentOwnersRepository.removeOwner(
        apartmentOwnersId: apartmentOwnersId,
        tenantId: tenantId,
      );
      if (!mounted) return;
      ref.invalidate(apartmentOwnersForApartmentProvider(widget.apartment.id));
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.owners_remove_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
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
          invalidatePaginatedClientTabs(ref);
          ref.invalidate(clientsFullListProvider);
          ref.invalidate(agencyNamesMapProvider);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.owners_add_success'.tr()),
              backgroundColor: context.customColors.success,
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

  /// PROČ: Surový tajný token není v DB – po obnovení stránky ho nelze znovu vypsat.
  /// Pamatujeme si ho jen v paměti této obrazovky pro řádky vytvořené v aktuální session (kopírování URL).
  final Map<String, String> _sessionPlainTokensByRowId = {};

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
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: context.colors.error,
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
      if (kDebugMode) {
        // ignore: avoid_print
        print('iCal sync error: ${result.error}');
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.insertedCount > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.ical_sync_success'.tr(namedArgs: {'count': '${result.insertedCount}'})),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.ical_sync_no_new'.tr()),
          backgroundColor: context.colors.inverseSurface,
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

  /// Dialog: zadání popisku a volba „jen tento apartmán“ → INSERT tokenu, jednorázové zobrazení URL.
  Future<void> _onGenerateExportToken() async {
    final labelController = TextEditingController();
    var restrictToApartment = true;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text('admin.calendar_generate_link'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(
                      labelText: 'admin.calendar_token_label'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('admin.calendar_restrict_to_apartment'.tr()),
                    subtitle: Text(
                      'admin.calendar_restrict_to_apartment_subtitle'.tr(),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    value: restrictToApartment,
                    onChanged: (v) => setLocal(() => restrictToApartment = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('admin.calendar_generate_link'.tr()),
              ),
            ],
          );
        },
      ),
    );
    final labelText = labelController.text.trim();
    labelController.dispose();
    if (submitted != true || !mounted) return;

    try {
      final created = await CalendarFeedTokensRepository.createToken(
        tenantId: widget.tenantId,
        label: labelText,
        apartmentId: restrictToApartment ? widget.apartmentId : null,
      );
      if (!mounted) return;
      setState(() {
        _sessionPlainTokensByRowId[created.row.id] = created.plainToken;
      });
      ref.invalidate(
        calendarFeedExportTokensProvider(
          (tenantId: widget.tenantId, apartmentId: widget.apartmentId),
        ),
      );
      final url = CalendarFeedTokensRepository.buildExportCalendarUrl(created.plainToken);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('admin.calendar_export_token_show_once_title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'admin.calendar_export_token_show_once_body'.tr(),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  url,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.close'.tr()),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('admin.calendar_export_link_copied'.tr()),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link, size: 18),
              label: Text('admin.calendar_copy_link'.tr()),
            ),
          ],
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      // PROČ: Diagnostika RLS / PostgREST při insertu tokenu; Edge se při generování nevolá.
      debugPrint('CalendarFeedTokensRepository.createToken failed: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onCopyExportLink(CalendarFeedTokenRow row) async {
    final storedUrl = row.ownerVisibleCalendarUrl?.trim();
    final plain = _sessionPlainTokensByRowId[row.id];
    final url = (storedUrl != null && storedUrl.isNotEmpty)
        ? storedUrl
        : (plain != null && plain.isNotEmpty
            ? CalendarFeedTokensRepository.buildExportCalendarUrl(plain)
            : null);
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.calendar_export_link_unavailable'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin.calendar_export_link_copied'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onRevokeExportToken(CalendarFeedTokenRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.calendar_revoke_token'.tr()),
        content: Text('admin.calendar_revoke_confirm_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('admin.calendar_revoke_token'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CalendarFeedTokensRepository.revokeToken(
        tenantId: widget.tenantId,
        tokenRowId: row.id,
      );
      if (!mounted) return;
      setState(() => _sessionPlainTokensByRowId.remove(row.id));
      ref.invalidate(
        calendarFeedExportTokensProvider(
          (tenantId: widget.tenantId, apartmentId: widget.apartmentId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Sekce EXPORT ICS – pod importem; tokeny v DB, odkaz s `export_token` pro Edge [export_calendar].
  Widget _buildIcalExportSection(BuildContext context) {
    final scope = (tenantId: widget.tenantId, apartmentId: widget.apartmentId);
    final tokensAsync = ref.watch(calendarFeedExportTokensProvider(scope));
    // PROČ: Formát data podle jazyka UI (easy_localization + intl).
    final dateFmt = DateFormat.yMMMd(context.locale.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          'admin.calendar_ical_export_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'admin.calendar_ical_export_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _onGenerateExportToken,
          icon: const Icon(Icons.add_link_outlined, size: 20),
          label: Text('admin.calendar_generate_link'.tr()),
        ),
        const SizedBox(height: 16),
        tokensAsync.when(
          data: (tokens) {
            if (tokens.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'admin.calendar_export_empty'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              );
            }
            return Column(
              children: tokens.map((row) {
                final createdLocal = row.createdAt.toLocal();
                final subParts = <String>[
                  dateFmt.format(createdLocal),
                  if (row.apartmentId == null || row.apartmentId!.isEmpty)
                    'admin.calendar_export_scope_tenant'.tr()
                  else
                    'admin.calendar_export_scope_apartment'.tr(),
                ];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      (row.label != null && row.label!.trim().isNotEmpty)
                          ? row.label!.trim()
                          : 'admin.calendar_export_unlabeled'.tr(),
                    ),
                    subtitle: Text(subParts.join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'admin.calendar_copy_link'.tr(),
                          onPressed: () => _onCopyExportLink(row),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'admin.calendar_revoke_token'.tr(),
                          onPressed: () => _onRevokeExportToken(row),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'common.generic_error_user_friendly'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(color: context.colors.error),
            ),
          ),
        ),
      ],
    );
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
                  color: context.colors.onSurface,
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
                    style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
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
                        style: context.textTheme.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
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
                'common.generic_error_user_friendly'.tr(),
                style: context.textTheme.bodyMedium?.copyWith(color: context.colors.error),
              ),
            ),
          ),
          _buildIcalExportSection(context),
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
  } catch (e, st) {
    AppLogger.error('_parseReservationStartDateForApartment: parsování check_in selhalo', e, st);
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
                      color: context.colors.onSurface,
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
                  child: AppEmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'admin.apartments_no_reservations'.tr(),
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
                            child: AppEmptyState(
                              icon: Icons.event_available_outlined,
                              title: 'admin.apartments_no_reservations'.tr(),
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
                                  leading: Icon(Icons.calendar_month, color: context.colors.primary),
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
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.colors.error),
                    const SizedBox(height: 16),
                    Text(
                      'common.generic_error_user_friendly'.tr(),
                      textAlign: TextAlign.center,
                      style: context.textTheme.labelLarge?.copyWith(color: context.colors.error),
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
                      color: context.colors.onSurface,
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
                  child: AppEmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'admin.apartments_no_tasks'.tr(),
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
                            child: AppEmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'admin.apartments_no_tasks'.tr(),
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
                                  leading: Icon(Icons.task_alt, color: context.colors.primary),
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
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.colors.error),
                    const SizedBox(height: 16),
                    Text(
                      'common.generic_error_user_friendly'.tr(),
                      textAlign: TextAlign.center,
                      style: context.textTheme.labelLarge?.copyWith(color: context.colors.error),
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

/// Řádek seznamu majitele – jméno, e-mail, badge „Čeká“, hlavní plátce (hvězda), tlačítko Odebrat.
class _OwnerListTile extends StatelessWidget {
  const _OwnerListTile({
    required this.owner,
    required this.onRemove,
    required this.onSetPrimaryBilling,
  });

  final ApartmentOwnerRow owner;
  final VoidCallback onRemove;
  final VoidCallback onSetPrimaryBilling;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.colors.surfaceContainerHighest,
          child: Icon(Icons.person, color: context.colors.onSurfaceVariant),
        ),
        title: Text(owner.name),
        subtitle: owner.email != null && owner.email!.isNotEmpty
            ? Text(
                owner.email!,
                style: context.textTheme.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'admin.owners_primary_billing'.tr(),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: owner.isPrimaryBilling ? null : onSetPrimaryBilling,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    owner.isPrimaryBilling ? Icons.star : Icons.star_border,
                    size: 24,
                    color: owner.isPrimaryBilling
                        ? context.customColors.warning
                        : context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (owner.isPending) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.customColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'admin.owners_pending_badge'.tr(),
                  style: context.textTheme.labelSmall?.copyWith(color: context.customColors.warning),
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: context.colors.error),
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
    final clientsAsync = ref.watch(clientsFullListProvider);
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
                style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              );
            }
            return DropdownButtonFormField<ClientModel>(
              initialValue: _selectedClient,
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
              Text('common.generic_error_user_friendly'.tr()),
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
      if (kDebugMode) {
        // ignore: avoid_print
        print('owners assign Postgrest: ${e.message}');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final displayError = (e is StateError && e.message == 'admin.owners_error_profile_not_created')
          ? 'admin.owners_error_profile_not_created'.tr()
          : (e is StateError && e.message == 'admin.owners_error_invitation_not_created')
              ? 'admin.owners_error_invitation_not_created'.tr()
              : 'common.generic_error_user_friendly'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayError),
          backgroundColor: context.colors.error,
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
            style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SelectableText(
            inviteLink,
            style: context.textTheme.labelLarge?.copyWith(
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

