import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/admin_reservation_forms.dart';
import 'package:falconest/features/admin/admin_reservation_utils.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/core/utils/read_file_bytes/read_file_bytes.dart';
import 'package:falconest/features/admin/services/reservation_import_service.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';

/// Barva Chipu podle životního cyklu: modrá, zelená, šedá, červená.
Color reservationStatusColor(String status) {
  switch (status) {
    case 'new':
      return Colors.blue;
    case 'confirmed':
      return Colors.green;
    case 'checked_in':
      return Colors.deepPurple;
    case 'checked_out':
      return Colors.grey;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.blue;
  }
}

/// Pastelové barvy bloků rezervace na Plachtě – svěží, čisté pastely pro Apple Vibe.
Color _timelineBlockColor(String status) {
  switch (status) {
    case 'new':
      return Colors.blue.shade100;
    case 'confirmed':
      return Colors.green.shade100;
    case 'checked_in':
      return Colors.orange.shade100;
    case 'checked_out':
      return Colors.grey.shade200;
    case 'cancelled':
      return Colors.red.shade100;
    default:
      return Colors.purple.shade100;
  }
}

/// Administrativní správa rezervací – stejným designovým jazykem jako Apartmány.
///
/// Top Bar: titulek, vyhledávání, tlačítko Přidat.
/// ListView kart s rezervacemi – host, termín, apartmán, štítek transferu.
class AdminReservationsScreen extends ConsumerStatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  ConsumerState<AdminReservationsScreen> createState() =>
      _AdminReservationsScreenState();

  /// Veřejná metoda pro otevření dialogu přidání rezervace.
  /// [initialApartmentId] – předvyplní apartmán (např. z kontextu Detailu klienta-majitele).
  static void showAddReservationDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialApartmentId,
    String? initialCheckIn,
    VoidCallback? onSaved,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AddReservationDialog(
        ref: ref,
        onSaved: onSaved ?? () => ref.invalidate(adminReservationsProvider),
        initialApartmentId: initialApartmentId,
        initialCheckIn: initialCheckIn,
      ),
    );
  }

  /// Veřejná metoda pro otevření dialogu úpravy rezervace.
  /// Voláno např. z kontextu úkolu (odkaz na rezervaci v task editoru).
  static void showEditReservationDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationRow reservation, {
    VoidCallback? onSaved,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditReservationDialog(
        ref: ref,
        reservation: reservation,
        onSaved: onSaved ?? () => ref.invalidate(adminReservationsProvider),
      ),
    );
  }
}

class _AdminReservationsScreenState extends ConsumerState<AdminReservationsScreen> {
  final _searchController = TextEditingController();
  late DateTime _timelineVisibleStartDate;

  @override
  void initState() {
    super.initState();
    // Plachta výchozí pohled: vždy 1. den aktuálního měsíce (měsíční zobrazení).
    final now = DateTime.now();
    _timelineVisibleStartDate = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReservationRow> _computeFiltered(List<ReservationRow> reservations) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return reservations;
    return reservations.where((r) {
      final guest = (r.guestName ?? '').toLowerCase();
      final apt = (r.apartmentName ?? '').toLowerCase();
      return guest.contains(query) || apt.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(adminReservationsProvider);

    return Scaffold(
      body: reservationsAsync.when(
        data: (reservations) {
          final filtered = _computeFiltered(reservations);
          return DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopActionBar(
                  searchController: _searchController,
                  onSearchChanged: () => setState(() {}),
                  onAdd: () => _showAddDialog(context, ref),
                  onDownloadTemplate: () => _downloadCsvTemplate(context),
                  onImportCsv: () => _importCsv(context, ref),
                ),
                Material(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade700,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.calendar_month, size: 20),
                        text: 'admin.reservations_tab_timeline'.tr(),
                      ),
                      Tab(
                        icon: const Icon(Icons.list, size: 20),
                        text: 'admin.reservations_tab_list'.tr(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Plachta vyplní dostupné místo (Expanded); vertikální scroll je uvnitř ReservationTimeline.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: ReservationTimeline(
                          visibleStartDate: _timelineVisibleStartDate,
                          onPrevious: () => setState(() {
                            _timelineVisibleStartDate = DateTime(_timelineVisibleStartDate.year, _timelineVisibleStartDate.month - 1, 1);
                          }),
                          onToday: () {
                            final now = DateTime.now();
                            setState(() {
                              _timelineVisibleStartDate = DateTime(now.year, now.month, 1);
                            });
                          },
                          onNext: () => setState(() {
                            _timelineVisibleStartDate = DateTime(_timelineVisibleStartDate.year, _timelineVisibleStartDate.month + 1, 1);
                          }),
                          onReservationTap: (r) => _showEditDialog(context, ref, r),
                          onEmptyCellTap: (apartmentId, date) {
                            final d = date;
                            final checkInStr = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
                            _showAddDialog(context, ref, initialApartmentId: apartmentId, initialCheckIn: checkInStr);
                          },
                        ),
                      ),
                      filtered.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.trim().isEmpty
                                    ? 'admin.reservations_empty'.tr()
                                    : 'admin.reservations_search_no_results'.tr(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            )
                          : _ReservationsKanbanBoard(
                              reservations: filtered,
                              onEdit: (r) => _showEditDialog(context, ref, r),
                              onDelete: (r) => _showDeleteConfirm(context, ref, r),
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
                'admin.reservations_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(adminReservationsProvider),
                child: Text('admin.tasks_retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialApartmentId,
    String? initialCheckIn,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AddReservationDialog(
        ref: ref,
        onSaved: () => ref.invalidate(adminReservationsProvider),
        initialApartmentId: initialApartmentId,
        initialCheckIn: initialCheckIn,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationRow reservation,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditReservationDialog(
        ref: ref,
        reservation: reservation,
        onSaved: () => ref.invalidate(adminReservationsProvider),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    ReservationRow reservation,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.reservations_delete'.tr()),
        content: Text('admin.reservations_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('admin.reservations_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => _doDelete(ctx, ref, reservation),
            child: Text('admin.reservations_delete'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(
    BuildContext dialogContext,
    WidgetRef ref,
    ReservationRow reservation,
  ) async {
    final id = reservation.id;
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(
              content: Text('common.error'.tr()),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.safeFrom('reservations', tenantId)
          .update({'deleted_at': deletedAt})
          .eq('id', id);
      final userId = SupabaseService.client.auth.currentUser?.id;
      final previousState = Map<String, dynamic>.from(reservation.toMap())
        ..['id'] = reservation.id
        ..['apartment_id'] = reservation.apartmentId;
      final shortId = reservation.id.length >= 8 ? reservation.id.substring(0, 8) : reservation.id;
      final recordName = reservation.guestName?.trim().isNotEmpty == true
          ? reservation.guestName!.trim()
          : 'super_admin.audit_log_reservation_fallback'.tr(namedArgs: {'id': shortId});
      await AuditLogService.logEnterprise(
        tenantId: tenantId,
        userId: userId,
        actionType: 'SOFT_DELETE',
        tableName: 'reservations',
        recordId: id,
        recordName: recordName,
        previousState: previousState,
        triggeredBy: AuditTriggeredBy.manual,
      );

      // Bezpečné soft-delete úkolů explicitně navázaných na tuto rezervaci (reservation_id).
      // Nahrazeno hádání podle apartment_id + data – mažeme pouze úkoly s přímou vazbou.
      if (tenantId.isNotEmpty) {
        try {
          final tasksRes = await SupabaseService.safeFrom('tasks', tenantId)
              .select('id')
              .eq('reservation_id', id)
              .isFilter('deleted_at', null);
          final taskList = tasksRes as List<dynamic>?;
          if (taskList != null && taskList.isNotEmpty) {
            for (final t in taskList) {
              final taskId = (t is Map ? t['id'] : null)?.toString();
              if (taskId == null || taskId.isEmpty) continue;
              await SupabaseService.safeFrom('tasks', tenantId)
                  .update({'deleted_at': deletedAt})
                  .eq('id', taskId);
              await AuditLogService.logEnterprise(
                tenantId: tenantId,
                userId: userId,
                actionType: 'SOFT_DELETE_CASCADE',
                tableName: 'tasks',
                recordId: taskId,
                triggeredBy: AuditTriggeredBy.cascade,
                extra: {'triggered_by': 'reservation', 'reservation_id': id},
              );
            }
          }
        } catch (_) {}
        ref.invalidate(adminTasksProvider);
        ref.invalidate(planningCalendarAllTasksProvider);
        ref.invalidate(planningCalendarAllTasksForMonthProvider);
      }

      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      ref.invalidate(adminReservationsProvider);
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
      print('--- CHYBA MAZÁNÍ REZERVACE: $e');
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_save_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Stáhne vzorový XLSX soubor – na webu Blob, na mobilu FilePicker dialog.
  Future<void> _downloadCsvTemplate(BuildContext context) async {
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData ?? '';
      if (tenantId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.import_no_tenant'.tr())),
          );
        }
        return;
      }
      final bytes = await ReservationImportService.generateExcelTemplate(tenantId);
      await downloadBytesAsFile(bytes, 'reservations_template.xlsx');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.import_template_downloaded'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.import_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    }
  }

  /// Otevře FilePicker, načte XLSX a předá do processImport.
  /// Během zpracování zobrazí celoobrazovkový loading; po dokončení výsledek v AlertDialogu (ne SnackBar).
  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    var loadingShown = false;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      List<int> bytes = result.files.single.bytes?.toList() ?? [];
      if (bytes.isEmpty && result.files.single.path != null) {
        final path = result.files.single.path!;
        bytes = await readFileBytes(path);
      }
      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.import_empty_csv'.tr())),
          );
        }
        return;
      }
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData ?? '';
      if (tenantId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.import_no_tenant'.tr())),
          );
        }
        return;
      }
      final apartments = await ref.read(apartmentsFullListProvider.future);
      final codeToApartmentId = <String, String>{};
      for (final a in apartments) {
        if (a.code != null && a.code!.trim().isNotEmpty) {
          codeToApartmentId[a.code!.trim()] = a.id;
        }
      }

      // Celá obrazovka: indikátor + text, zablokované pozadí – uživatel vidí, že se něco děje.
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'admin.import_processing_message'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        loadingShown = true;
      }

      final importResult = await ReservationImportService.processImport(
        bytes,
        tenantId,
        codeToApartmentId,
      );

      if (context.mounted) {
        if (loadingShown) Navigator.of(context, rootNavigator: true).pop();
        ref.invalidate(adminReservationsProvider);
        _showImportResultDialog(context, importResult);
      }
    } on ArgumentError catch (e) {
      if (context.mounted) {
        if (loadingShown) Navigator.of(context, rootNavigator: true).pop();
        final key = e.message?.toString() ?? 'admin.import_error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(key.startsWith('admin.') ? key.tr() : key)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (loadingShown) Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.import_error'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    }
  }

  /// Velký výsledkový dialog importu – úspěšně / služby s chybou / zcela selhalo (zelená / oranžová / červená).
  void _showImportResultDialog(BuildContext context, ReservationImportResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.import_dialog_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImportResultRow(
                label: 'admin.import_dialog_success'.tr(),
                count: result.successCount,
                color: Colors.green.shade700,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 12),
              _ImportResultRow(
                label: 'admin.import_dialog_services_error'.tr(),
                count: result.warningCount,
                color: Colors.orange.shade700,
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(height: 12),
              _ImportResultRow(
                label: 'admin.import_dialog_failed_rows'.tr(),
                count: result.errorCount,
                color: Colors.red.shade700,
                icon: Icons.error_outline,
              ),
              if (result.errorCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'admin.import_dialog_some_rows_failed'.tr(),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('admin.import_dialog_close'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Jeden řádek výsledku importu – ikona, tučný popis, počet v dané barvě.
class _ImportResultRow extends StatelessWidget {
  const _ImportResultRow({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 15,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// Top Action Bar – titulek, vyhledávání, tlačítko Přidat a menu CSV importu.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onDownloadTemplate,
    required this.onImportCsv,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onImportCsv;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Text(
            'admin.reservations_title'.tr(),
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
                hintText: 'admin.reservations_search_hint'.tr(),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file),
            tooltip: 'admin.import_reservations'.tr(),
            onSelected: (value) {
              if (value == 'download') onDownloadTemplate();
              if (value == 'import') onImportCsv();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 20),
                    const SizedBox(width: 8),
                    Text('admin.download_csv_template'.tr()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file, size: 20),
                    const SizedBox(width: 8),
                    Text('admin.import_reservations'.tr()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: Text('admin.fab_new_reservation'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Rezervační plachta (Gantt chart) – souvislé pruhy rezervací v mřížce dnů × apartmány.
/// [visibleStartDate] – 1. den zobrazeného měsíce; šipky posunují o celý měsíc, hlavička zobrazuje „Měsíc rok“.
/// [onEmptyCellTap] – tap na prázdnou buňku → nová rezervace s předvyplněním bytu a data.
class ReservationTimeline extends ConsumerStatefulWidget {
  const ReservationTimeline({
    super.key,
    required this.visibleStartDate,
    this.onPrevious,
    this.onToday,
    this.onNext,
    this.onReservationTap,
    this.onEmptyCellTap,
  });

  final DateTime visibleStartDate;
  final VoidCallback? onPrevious;
  final VoidCallback? onToday;
  final VoidCallback? onNext;
  final ValueChanged<ReservationRow>? onReservationTap;
  final void Function(String apartmentId, DateTime date)? onEmptyCellTap;

  static const double dayWidth = 85.0;
  static const double rowHeight = 80.0;
  static const double leftColumnWidth = 120.0;

  @override
  ConsumerState<ReservationTimeline> createState() => _ReservationTimelineState();
}

class _ReservationTimelineState extends ConsumerState<ReservationTimeline> {
  /// Controller pro horizontální posun časové osy; vynucujeme viditelný Scrollbar kvůli UX na webu (uživatelé bez trackpadu).
  late final ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(adminReservationsProvider);
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);

    if (reservationsAsync.isLoading || apartmentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final reservations = reservationsAsync.valueOrNull ?? [];
    final apartments = apartmentsAsync.valueOrNull ?? [];

    // Měsíční zobrazení: vždy 1. den měsíce a počet dní daného měsíce (28–31).
    final startDate = DateTime(widget.visibleStartDate.year, widget.visibleStartDate.month, 1);
    final lastDayOfMonth = DateTime(widget.visibleStartDate.year, widget.visibleStartDate.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final days = List<DateTime>.generate(
      totalDays,
      (i) => startDate.add(Duration(days: i)),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isCellEmpty(int rowIndex, int colIndex) {
      if (rowIndex >= apartments.length || colIndex >= days.length) return false;
      final apartmentId = apartments[rowIndex].id;
      final cellDate = days[colIndex];
      for (final r in reservations) {
        if (r.apartmentId != apartmentId) continue;
        final checkInDt = parseReservationCheckIn(r.checkIn);
        final checkOutDt = parseReservationCheckOut(r.checkOut);
        if (checkInDt == null || checkOutDt == null) continue;
        final checkInDate = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);
        final checkOutDate = DateTime(checkOutDt.year, checkOutDt.month, checkOutDt.day);
        if (!cellDate.isBefore(checkInDate) && !cellDate.isAfter(checkOutDate)) return false;
      }
      return true;
    }

    final totalWidth = days.length * ReservationTimeline.dayWidth;
    final gridHeight = apartments.length * ReservationTimeline.rowHeight;
    final apartmentIndexById = {for (var i = 0; i < apartments.length; i++) apartments[i].id: i};
    final locale = context.locale.toString();
    // Hlavička: název měsíce a rok (např. „Duben 2026“), lokalizovaně.
    final monthYearFormat = DateFormat.yMMMM(locale);
    final monthYearLabel = monthYearFormat.format(startDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horní ovládací lišta – navigace po měsících, název měsíce + rok, legenda.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: widget.onPrevious,
                    tooltip: 'admin.reservations_timeline_prev'.tr(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthYearLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: widget.onNext,
                    tooltip: 'admin.reservations_timeline_next'.tr(),
                  ),
                  const SizedBox(width: 24),
                  OutlinedButton(
                      onPressed: widget.onToday,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('admin.reservations_timeline_today'.tr()),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ReservationLegendPill(status: 'new', bg: Colors.blue.shade100, text: Colors.blue.shade900),
                      const SizedBox(width: 8),
                      _ReservationLegendPill(status: 'confirmed', bg: Colors.green.shade100, text: Colors.green.shade900),
                      const SizedBox(width: 8),
                      _ReservationLegendPill(status: 'checked_in', bg: Colors.orange.shade100, text: Colors.orange.shade900),
                      const SizedBox(width: 8),
                      _ReservationLegendPill(status: 'checked_out', bg: Colors.grey.shade200, text: Colors.grey.shade800),
                      const SizedBox(width: 8),
                      _ReservationLegendPill(status: 'cancelled', bg: Colors.red.shade100, text: Colors.red.shade900),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Kontejner „papír na stole“ – bílý box; uvnitř vertikální scroll, aby levý sloupec i mřížka rolovály společně.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  height: ReservationTimeline.rowHeight + gridHeight,
                  child: _ReservationTimelineGrid(
                    reservations: reservations,
                    apartments: apartments,
                    days: days,
                    startDate: startDate,
                    today: today,
                    dayWidth: ReservationTimeline.dayWidth,
                    rowHeight: ReservationTimeline.rowHeight,
                    leftColumnWidth: ReservationTimeline.leftColumnWidth,
                    totalWidth: totalWidth,
                    gridHeight: gridHeight,
                    apartmentIndexById: apartmentIndexById,
                    isCellEmpty: isCellEmpty,
                    onReservationTap: widget.onReservationTap,
                    onEmptyCellTap: widget.onEmptyCellTap,
                    horizontalScrollController: _horizontalScrollController,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pilulka v legendě Plachty – stav rezervace s pastelovým pozadím a tmavým textem.
class _ReservationLegendPill extends StatelessWidget {
  const _ReservationLegendPill({
    required this.status,
    required this.bg,
    required this.text,
  });

  final String status;
  final Color bg;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        reservationStatusLabelKey(status).tr(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

/// Prémiová mřížka Plachty rezervací (Gantt) – Apple Vibe. Levý sloupec apartmány, hlavička dny, bloky rezervací.
class _ReservationTimelineGrid extends StatelessWidget {
  const _ReservationTimelineGrid({
    required this.reservations,
    required this.apartments,
    required this.days,
    required this.startDate,
    required this.today,
    required this.dayWidth,
    required this.rowHeight,
    required this.leftColumnWidth,
    required this.totalWidth,
    required this.gridHeight,
    required this.apartmentIndexById,
    required this.isCellEmpty,
    required this.onReservationTap,
    required this.onEmptyCellTap,
    required this.horizontalScrollController,
  });

  final List<ReservationRow> reservations;
  final List<ApartmentRow> apartments;
  final List<DateTime> days;
  final DateTime startDate;
  final DateTime today;
  final double dayWidth;
  final double rowHeight;
  final double leftColumnWidth;
  final double totalWidth;
  final double gridHeight;
  final Map<String, int> apartmentIndexById;
  final bool Function(int rowIndex, int colIndex) isCellEmpty;
  final ValueChanged<ReservationRow>? onReservationTap;
  final void Function(String apartmentId, DateTime date)? onEmptyCellTap;
  final ScrollController horizontalScrollController;

  static const List<String> _dayKeys = [
    'planning_calendar.mon', 'planning_calendar.tue', 'planning_calendar.wed',
    'planning_calendar.thu', 'planning_calendar.fri', 'planning_calendar.sat',
    'planning_calendar.sun',
  ];

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final dateFormat = DateFormat('d.M.', locale);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReservationTimelineLeftColumn(
          apartments: apartments,
          rowHeight: rowHeight,
          leftColumnWidth: leftColumnWidth,
        ),
        Expanded(
          // Horizontální posuvník vždy viditelný kvůli UX na webu – uživatelé s myší (bez trackpadu) musí vědět, že lze rolovat dny.
          child: Scrollbar(
            controller: horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hlavička dnů s dolní hranicí (oddělení od mřížky)
                    Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: _ReservationTimelineHeader(
                      days: days,
                      today: today,
                      dayWidth: dayWidth,
                      rowHeight: rowHeight,
                      dateFormat: dateFormat,
                    ),
                  ),
                  SizedBox(
                    width: totalWidth,
                    height: gridHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ReservationTimelineGridBackground(
                          dayCount: days.length,
                          rowCount: apartments.length,
                          dayWidth: dayWidth,
                          rowHeight: rowHeight,
                        ),
                        if (onEmptyCellTap != null)
                          ...List.generate(apartments.length * days.length, (i) {
                            final rowIndex = i ~/ days.length;
                            final colIndex = i % days.length;
                            if (!isCellEmpty(rowIndex, colIndex)) return const SizedBox.shrink();
                            final apartmentId = apartments[rowIndex].id;
                            final date = days[colIndex];
                            return Positioned(
                              left: colIndex * dayWidth,
                              top: rowIndex * rowHeight,
                              width: dayWidth,
                              height: rowHeight,
                              child: InkWell(
                                onTap: () => onEmptyCellTap!(apartmentId, date),
                                child: const SizedBox.expand(),
                              ),
                            );
                          }),
                        ...reservations.map((r) => _ReservationTimelineBlock(
                              reservation: r,
                              startDate: startDate,
                              dayWidth: dayWidth,
                              rowHeight: rowHeight,
                              apartmentIndexById: apartmentIndexById,
                              onTap: () => onReservationTap?.call(r),
                            )),
                      ],
                    ),
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

/// Levý sloupec – názvy apartmánů. FontWeight.w600, šedá, pravý border odděluje od mřížky.
class _ReservationTimelineLeftColumn extends StatelessWidget {
  const _ReservationTimelineLeftColumn({
    required this.apartments,
    required this.rowHeight,
    required this.leftColumnWidth,
  });

  final List<ApartmentRow> apartments;
  final double rowHeight;
  final double leftColumnWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: leftColumnWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(2, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: rowHeight),
          ...apartments.map(
            (a) => SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
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

/// Hlavička Plachty – dny. Dnešní den v modrém kruhu, víkendy jemným šedým podbarvením.
class _ReservationTimelineHeader extends StatelessWidget {
  const _ReservationTimelineHeader({
    required this.days,
    required this.today,
    required this.dayWidth,
    required this.rowHeight,
    required this.dateFormat,
  });

  final List<DateTime> days;
  final DateTime today;
  final double dayWidth;
  final double rowHeight;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: days.map((d) {
        final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
        final weekday = d.weekday;
        final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
        return Container(
          width: dayWidth,
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? Colors.blue.shade50 : (isWeekend ? Colors.grey.shade50 : Colors.white),
            border: Border(
              right: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: isToday
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade600,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_ReservationTimelineGrid._dayKeys[d.weekday - 1].tr()} ${dateFormat.format(d)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  '${_ReservationTimelineGrid._dayKeys[d.weekday - 1].tr()} ${dateFormat.format(d)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        );
      }).toList(),
    );
  }
}

/// Jeden blok rezervace na Plachtě – Apple Vibe s jemným stínem, tmavým textem, ikonami.
class _ReservationTimelineBlock extends StatelessWidget {
  const _ReservationTimelineBlock({
    required this.reservation,
    required this.startDate,
    required this.dayWidth,
    required this.rowHeight,
    required this.apartmentIndexById,
    required this.onTap,
  });

  final ReservationRow reservation;
  final DateTime startDate;
  final double dayWidth;
  final double rowHeight;
  final Map<String, int> apartmentIndexById;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkInDt = parseReservationCheckIn(reservation.checkIn);
    final checkOutDt = parseReservationCheckOut(reservation.checkOut);
    if (checkInDt == null || checkOutDt == null) return const SizedBox.shrink();
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    // Výpočet v jednotkách dní (zlomky) – podpora same-day turnover (check-out 10:00, check-in 14:00).
    final exactStartDays = checkInDt.difference(startDateOnly).inMinutes / (24 * 60.0);
    final exactEndDays = checkOutDt.difference(startDateOnly).inMinutes / (24 * 60.0);
    final rawLeft = exactStartDays * dayWidth;
    final left = rawLeft < 0 ? 0.0 : rawLeft;
    final rawWidth = (exactEndDays - exactStartDays) * dayWidth;
    final width = rawLeft < 0 ? (rawWidth + rawLeft) : rawWidth;
    if (width <= 0) return const SizedBox.shrink();
    final aptIndex = apartmentIndexById[reservation.apartmentId] ?? 0;
    final top = aptIndex * rowHeight;
    final guestName = (reservation.guestName ?? '').trim().isEmpty ? 'admin.dashboard_guest_unknown'.tr() : reservation.guestName!;
    final totalGuests = reservation.guestAdults + reservation.guestChildren;
    final blockColor = _timelineBlockColor(reservation.status);

    return Positioned(
      left: left + 3,
      top: top + 3,
      child: SizedBox(
        width: width - 6,
        height: rowHeight - 6,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRect(
                child: SizedBox(
                  height: rowHeight - 6 - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              guestName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (reservation.referenceNumber != null && reservation.referenceNumber!.trim().isNotEmpty)
                            Flexible(
                              child: Text(
                                '#${reservation.referenceNumber!.trim()}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ),
                        ],
                      ),
                      // Responzivní druhý řádek: ikonky – Flexible aby při malé výšce řádku (menší monitor) nepřetekl.
                      if (width > 120)
                        Flexible(
                          child: ClipRect(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '👥 $totalGuests',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    if (reservation.needsTransfer == true) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.flight_land, size: 14, color: Colors.black54),
                                    ],
                                    if (reservation.internalNote != null && reservation.internalNote!.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.notes, size: 14, color: Colors.black54),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Jemná mřížka na pozadí Plachty – extrémně jemné čáry (alpha 0.1).
class _ReservationTimelineGridBackground extends StatelessWidget {
  const _ReservationTimelineGridBackground({
    required this.dayCount,
    required this.rowCount,
    required this.dayWidth,
    required this.rowHeight,
  });

  final int dayCount;
  final int rowCount;
  final double dayWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(dayCount * dayWidth, rowCount * rowHeight),
      painter: _ReservationTimelineGridPainter(
        dayCount: dayCount,
        rowCount: rowCount,
        dayWidth: dayWidth,
        rowHeight: rowHeight,
      ),
    );
  }
}

class _ReservationTimelineGridPainter extends CustomPainter {
  _ReservationTimelineGridPainter({
    required this.dayCount,
    required this.rowCount,
    required this.dayWidth,
    required this.rowHeight,
  });

  final int dayCount;
  final int rowCount;
  final double dayWidth;
  final double rowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (var i = 0; i <= dayCount; i++) {
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var i = 0; i <= rowCount; i++) {
      final y = i * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Konfigurace jednoho sloupce Kanbanu: cílový status při dropu a které stavy se v sloupci zobrazí.
class _KanbanColumnConfig {
  const _KanbanColumnConfig({
    required this.targetStatus,
    required this.displayStatuses,
    required this.labelKey,
  });
  final String targetStatus;
  final List<String> displayStatuses;
  final String labelKey;
}

const _kanbanColumns = [
  _KanbanColumnConfig(
    targetStatus: 'new',
    displayStatuses: ['new'],
    labelKey: 'admin.reservations_kanban_new',
  ),
  _KanbanColumnConfig(
    targetStatus: 'confirmed',
    displayStatuses: ['confirmed'],
    labelKey: 'admin.reservations_kanban_confirmed',
  ),
  _KanbanColumnConfig(
    targetStatus: 'checked_in',
    displayStatuses: ['checked_in'],
    labelKey: 'admin.reservations_kanban_in_progress',
  ),
  _KanbanColumnConfig(
    targetStatus: 'checked_out',
    displayStatuses: ['checked_out', 'cancelled'],
    labelKey: 'admin.reservations_kanban_completed',
  ),
];

/// Kanban board rezervací – 4 sloupce podle stavu, drag & drop s aktualizací v Supabase.
class _ReservationsKanbanBoard extends ConsumerStatefulWidget {
  const _ReservationsKanbanBoard({
    required this.reservations,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ReservationRow> reservations;
  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;

  @override
  ConsumerState<_ReservationsKanbanBoard> createState() =>
      _ReservationsKanbanBoardState();
}

class _ReservationsKanbanBoardState extends ConsumerState<_ReservationsKanbanBoard> {
  Future<void> _updateReservationStatus(ReservationRow r, String newStatus) async {
    try {
      final tenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) return;
      await SupabaseService.safeFrom('reservations', tenantId)
          .update({'status': newStatus})
          .eq('id', r.id);
      if (!mounted) return;
      ref.invalidate(adminReservationsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_save_error'.tr(namedArgs: {'error': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kanbanColumns.asMap().entries.map((entry) {
          final col = entry.value;
          final columnReservations = widget.reservations
              .where((r) => col.displayStatuses.contains(r.status))
              .toList();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DragTarget<ReservationRow>(
                onAcceptWithDetails: (d) {
                  final reservation = d.data;
                  if (reservation.status != col.targetStatus) {
                    _updateReservationStatus(reservation, col.targetStatus);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlight = candidateData.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: isHighlight
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          child: Text(
                            col.labelKey.tr(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
                            itemCount: columnReservations.length,
                            itemBuilder: (context, index) {
                              final r = columnReservations[index];
                              return _KanbanReservationCard(
                                reservation: r,
                                onEdit: widget.onEdit,
                                onDelete: widget.onDelete,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Kompaktní karta rezervace v Kanbanu – vizuálně shodná s _TaskCard (úkoly).
/// Draggable, celá karta klikatelná pro editaci, ikona koše vpravo.
class _KanbanReservationCard extends StatelessWidget {
  const _KanbanReservationCard({
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
  });

  final ReservationRow reservation;
  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Draggable<ReservationRow>(
        data: reservation,
        feedback: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
          child: SizedBox(
            width: 260,
            child: _KanbanCardContent(
              reservation: reservation,
              showDelete: false,
              onDelete: () {},
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: AppCard(
            child: _KanbanCardContent(
              reservation: reservation,
              showDelete: true,
              onDelete: () => onDelete(reservation),
            ),
          ),
        ),
        child: AppCard(
          onTap: () => onEdit(reservation),
          child: _KanbanCardContent(
            reservation: reservation,
            showDelete: true,
            onDelete: () => onDelete(reservation),
          ),
        ),
      ),
    );
  }
}

/// Obsah Kanban karty rezervace – struktura shodná s _TaskCard. Data z reservation modelu.
class _KanbanCardContent extends StatelessWidget {
  const _KanbanCardContent({
    required this.reservation,
    required this.showDelete,
    required this.onDelete,
  });

  final ReservationRow reservation;
  final bool showDelete;
  final VoidCallback onDelete;

  /// Barva ikony podle zdroje rezervace – Airbnb červená, Booking modrá, Direct zelená.
  static Color _sourceColor(String? source) {
    final s = (source ?? '').trim();
    if (s == 'Airbnb') return Colors.red.shade600;
    if (s == 'Booking') return Colors.blue.shade800;
    if (s == 'Direct') return Colors.green.shade700;
    return Colors.grey.shade600;
  }

  /// Ikona podle zdroje rezervace – Airbnb air, Booking language, Direct home.
  static IconData _sourceIcon(String? source) {
    final s = (source ?? '').trim();
    if (s == 'Airbnb') return Icons.air;
    if (s == 'Booking') return Icons.language;
    if (s == 'Direct') return Icons.home;
    return Icons.book_online;
  }

  /// Formátuje termín s volitelným časem z arrival_time/departure_time (např. "13.03. 14:00 → 17.03. 10:00").
  static String _formatDateRange(ReservationRow r) {
    final checkIn = r.checkIn ?? '–';
    final checkOut = r.checkOut ?? '–';
    String from = checkIn;
    String to = checkOut;
    if (r.arrivalTime != null) {
      from = '$checkIn ${r.arrivalTime!.hour.toString().padLeft(2, '0')}:${r.arrivalTime!.minute.toString().padLeft(2, '0')}';
    }
    if (r.departureTime != null) {
      to = '$checkOut ${r.departureTime!.hour.toString().padLeft(2, '0')}:${r.departureTime!.minute.toString().padLeft(2, '0')}';
    }
    return '$from → $to';
  }

  @override
  Widget build(BuildContext context) {
    final guestName = (reservation.guestName ?? '').trim().isEmpty ? '–' : reservation.guestName!;
    final apartmentName = (reservation.apartmentName ?? '').trim().isEmpty ? '–' : reservation.apartmentName!;
    // Celkový počet osob = dospělí + děti (pro at-a-glance přehled dispečera).
    final totalGuests = reservation.guestAdults + reservation.guestChildren;
    final contextLabel = reservation.reservationSource != null
        ? 'admin.reservation_source_${reservation.reservationSource}'.tr()
        : 'admin.menu_reservations'.tr();
    final statusColor = reservationStatusColor(reservation.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. řádek – kontext: barevná ikona podle zdroje (Airbnb/Booking/Direct)
                Row(
                  children: [
                    Icon(
                      _sourceIcon(reservation.reservationSource),
                      size: 16,
                      color: _sourceColor(reservation.reservationSource),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        contextLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: _sourceColor(reservation.reservationSource),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 2. řádek – hlavní nadpis: jméno hosta + referenční číslo + drobné ikony (transfer, poznámka)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        guestName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (reservation.referenceNumber != null && reservation.referenceNumber!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '#${reservation.referenceNumber!.trim()}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                    if (reservation.needsTransfer == true) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.flight_land, size: 14, color: Colors.blue.shade600),
                    ],
                    if (reservation.internalNote != null && reservation.internalNote!.trim().isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.notes, size: 14, color: Colors.orange.shade700),
                    ],
                  ],
                ),
                // Telefon na hosta – kritický pro dispečera
                if (reservation.guestPhone != null && reservation.guestPhone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        reservation.guestPhone!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                // 3. řádek – podnadpis: apartmán + počet osob
                Text(
                  totalGuests > 0 ? '$apartmentName • 👥 $totalGuests' : apartmentName,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // 4. řádek – pilulky: stav a termín (s časem při příjezdu/odjezdu)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reservationStatusLabelKey(reservation.status).tr(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDateRange(reservation),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Konzistence s Úkoly: u Odhlášeno zámeček místo koše (nelze mazat historické záznamy).
          if (reservation.status == 'checked_out') ...[
            const SizedBox(width: 4),
            Icon(Icons.lock, size: 16, color: Colors.grey),
          ] else if (showDelete) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Jedna kompaktní karta rezervace (připraveno pro případné znovupoužití).
// ignore: unused_element
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
  });

  final ReservationRow reservation;
  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;

  @override
  Widget build(BuildContext context) {
    final guestName = (reservation.guestName ?? '').trim().isEmpty
        ? '–'
        : reservation.guestName!;
    final checkIn = reservation.checkIn ?? '–';
    final checkOut = reservation.checkOut ?? '–';
    final apartmentName = (reservation.apartmentName ?? '').trim().isEmpty
        ? '–'
        : reservation.apartmentName!;
    final needsTransfer = reservation.needsTransfer == true;
    final statusLabel = reservationStatusLabelKey(reservation.status).tr();
    final statusColor = reservationStatusColor(reservation.status);
    final nights = reservationNights(reservation.checkIn, reservation.checkOut);
    final nightsText = nights != null && nights >= 0
        ? 'admin.reservations_nights'.tr(namedArgs: {'count': nights.toString()})
        : null;

    return AppCard(
      onTap: () => onEdit(reservation),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            guestName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (needsTransfer) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.flight_land, size: 18, color: Colors.amber.shade700),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      apartmentName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      checkIn,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            checkOut,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nightsText != null)
                            Text(
                              nightsText,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  statusLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: statusColor,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              // Konzistence s Úkoly: u Odhlášeno zámeček místo koše.
              reservation.status == 'checked_out'
                  ? Icon(Icons.lock, size: 16, color: Colors.grey)
                  : IconButton(
                      icon: const Icon(Icons.delete, size: 22),
                      color: Colors.red,
                      tooltip: 'admin.reservations_delete_reservation'.tr(),
                      onPressed: () => onDelete(reservation),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
            ],
          ),
    );
  }
}

