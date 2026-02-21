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
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_services_options_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';

/// Vrací i18n klíč pro štítek stavu rezervace (admin.reservation_status_*).
String reservationStatusLabelKey(String status) {
  if (reservationStatusValues.contains(status)) return 'admin.reservation_status_$status';
  return 'admin.reservation_status_new';
}

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

/// Normalizuje syrový task_type z DB na kanonickou hodnotu pro správný překlad a ikony.
String _normalizeTaskType(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'other';
  final s = raw.trim().toLowerCase();
  if (s == 'cleaning' || s == 'úklid' || s == 'uklid') return 'cleaning';
  if (s == 'transfer_in' || s.contains('příjezd') || s.contains('prijezd') || (s.contains('transfer') && s.contains('in'))) return 'transfer_in';
  if (s == 'transfer_out' || s.contains('odjezd') || (s.contains('transfer') && s.contains('out'))) return 'transfer_out';
  if (s == 'check_in' || s == 'check-in') return 'check_in';
  if (s == 'check_out' || s == 'check-out') return 'check_out';
  if (s == 'issue' || s.contains('závada') || s.contains('zavada')) return 'issue';
  if (s == 'material' || s.contains('materiál') || s.contains('material')) return 'material';
  if (s == 'other' || s == 'jiné' || s == 'jine' || s == 'other') return 'other';
  return 'other';
}

/// i18n klíč pro typ úkolu (použij vždy po _normalizeTaskType).
String _taskTypeLabelKey(String taskType) {
  final canonical = _normalizeTaskType(taskType);
  switch (canonical) {
    case 'cleaning':
      return 'admin.task_type_cleaning';
    case 'transfer_in':
      return 'admin.task_type_transfer_in';
    case 'transfer_out':
      return 'admin.task_type_transfer_out';
    case 'check_in':
      return 'admin.task_type_check_in';
    case 'check_out':
      return 'admin.task_type_check_out';
    case 'issue':
      return 'admin.task_type_issue';
    case 'material':
      return 'admin.task_type_material';
    default:
      return 'admin.task_type_other';
  }
}

/// Emoji pro typ úkolu (pro sekci Související úkoly).
String _taskTypeEmoji(String taskType) {
  switch (_normalizeTaskType(taskType)) {
    case 'cleaning':
      return '🧹';
    case 'transfer_in':
    case 'transfer_out':
      return '🚗';
    case 'check_in':
    case 'check_out':
      return '🔑';
    case 'issue':
      return '🔧';
    case 'material':
      return '📦';
    default:
      return '📋';
  }
}

/// Ikona podle typu úkolu (pro sekci Související úkoly) – používá normalizovaný typ.
IconData _taskTypeIcon(String taskType) {
  switch (_normalizeTaskType(taskType)) {
    case 'cleaning':
      return Icons.cleaning_services;
    case 'transfer_in':
    case 'transfer_out':
      return Icons.directions_car;
    case 'check_in':
      return Icons.key;
    case 'check_out':
      return Icons.key_off;
    case 'issue':
      return Icons.build;
    case 'material':
      return Icons.inventory_2;
    default:
      return Icons.task_alt;
  }
}

/// Barva Chipu pro stav úkolu (Návrh, Zadáno, Probíhá, Hotovo).
Color _taskStatusChipColor(String status) {
  final s = status.toLowerCase();
  if (s.contains('hotovo') || s.contains('completed') || s.contains('done')) return Colors.green;
  if (s.contains('probíhá') || s.contains('progress') || s.contains('in progress')) return Colors.blue;
  if (s.contains('zadáno') || s.contains('assigned')) return Colors.orange;
  return Colors.grey;
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

/// Typ kolize: koliduje začátek (check-in) nebo konec (check-out) rezervace.
enum CollisionSide { checkIn, checkOut }

/// Výjimka při detekci kolize rezervací – obsahuje návrh náhradního času a stranu kolize.
class ReservationCollisionException implements Exception {
  ReservationCollisionException(
    this.message, {
    this.suggestedTime,
    this.suggestedDateTime,
    this.collisionSide = CollisionSide.checkIn,
  });

  final String message;
  /// Čas ve formátu HH:mm pro zobrazení v chybové hlášce.
  final String? suggestedTime;
  /// Celý navržený čas (check-in nebo check-out) pro úpravu ve formuláři.
  final DateTime? suggestedDateTime;
  /// Zda koliduje příjezd (nejbližší check-in) nebo odjezd (nejzazší check-out).
  final CollisionSide collisionSide;

  @override
  String toString() => message;
}

/// Pro check-in bez času používá 15:00 (standardní příjezd).
DateTime? _parseReservationCheckIn(String? s) => _parseDateTime(s);

/// Pro check-out bez času používá 10:00 (standardní odjezd).
DateTime? _parseReservationCheckOut(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  if (parts.length == 1) {
    final d = _parseDateOnly(parts[0]);
    if (d != null) return DateTime(d.year, d.month, d.day, 10, 0);
  }
  return _parseDateTime(s);
}

/// Počet nocí mezi check-in a check-out (pro zobrazení v kartě rezervace).
int? _reservationNights(String? checkIn, String? checkOut) {
  final start = _parseReservationCheckIn(checkIn);
  final end = _parseReservationCheckOut(checkOut);
  if (start == null || end == null) return null;
  final startDate = DateTime(start.year, start.month, start.day);
  final endDate = DateTime(end.year, end.month, end.day);
  return endDate.difference(startDate).inDays;
}

DateTime? _parseDateOnly(String s) {
  final dParts = s.split('.');
  if (dParts.length >= 3) {
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
    );
  }
  return null;
}

/// Zkontroluje kolizi rezervací. Při kolizi vyhodí [ReservationCollisionException].
void _checkReservationCollision({
  required List<ReservationRow> existingReservations,
  required String apartmentId,
  required int standardCleaningDuration,
  required DateTime newCheckIn,
  required DateTime newCheckOut,
  String? excludeReservationId,
}) {
  final bufferMinutes = standardCleaningDuration + 60;

  for (final existing in existingReservations) {
    if (existing.apartmentId != apartmentId) continue;
    if (excludeReservationId != null && existing.id == excludeReservationId) {
      continue;
    }

    final existingCheckIn = _parseReservationCheckIn(existing.checkIn);
    final existingCheckOut = _parseReservationCheckOut(existing.checkOut);
    if (existingCheckIn == null || existingCheckOut == null) continue;

    final existingCheckOutWithBuffer =
        existingCheckOut.add(Duration(minutes: bufferMinutes));
    final newCheckOutWithBuffer =
        newCheckOut.add(Duration(minutes: bufferMinutes));

    final collides = newCheckIn.isBefore(existingCheckOutWithBuffer) &&
        newCheckOutWithBuffer.isAfter(existingCheckIn);

    if (collides) {
      final suggestedCheckIn =
          existingCheckOut.add(Duration(minutes: bufferMinutes));
      final suggestedCheckOut =
          existingCheckIn.subtract(Duration(minutes: bufferMinutes));
      // Kolize na začátku: jiná rezervace končí před námi → navrhnout posun check-in.
      // Kolize na konci: jiná rezervace začíná po nás → navrhnout posun check-out.
      final isCheckInCollision = existingCheckOut.isBefore(newCheckOut) ||
          existingCheckOut.isAtSameMomentAs(newCheckOut);
      final suggested = isCheckInCollision ? suggestedCheckIn : suggestedCheckOut;
      final suggestedTimeStr =
          '${suggested.hour.toString().padLeft(2, '0')}:${suggested.minute.toString().padLeft(2, '0')}';
      final side = isCheckInCollision ? CollisionSide.checkIn : CollisionSide.checkOut;
      final msg = isCheckInCollision
          ? 'Tento apartmán je v daném termínu již obsazen. '
            'S ohledem na úklid je nejbližší možný check-in v $suggestedTimeStr.'
          : 'Tento apartmán je v daném termínu již obsazen. '
            'S ohledem na další rezervaci je nejzazší možný check-out v $suggestedTimeStr (kvůli dalšímu úklidu).';
      throw ReservationCollisionException(
        msg,
        suggestedTime: suggestedTimeStr,
        suggestedDateTime: suggested,
        collisionSide: side,
      );
    }
  }
}

/// Formátuje rozsah dat pro pole termínu pobytu (DD.MM.YYYY - DD.MM.YYYY).
String _formatDateRangeDisplay(DateTimeRange range) {
  String d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  return '${d(range.start)} - ${d(range.end)}';
}

/// Formát DD.MM.YYYY HH:mm pro zobrazení uživateli.
String _formatDateTime(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Zobrazí interaktivní dialog při kolizi – pouze upraví čas ve formuláři, ukládání provede uživatel sám.
void _showCollisionDialog({
  required BuildContext context,
  required CollisionSide collisionSide,
  required DateTime suggestedDateTime,
  required VoidCallback onApplyTime,
}) {
  final navrhovanyCas = _formatDateTime(suggestedDateTime);
  final contentText = collisionSide == CollisionSide.checkIn
      ? 'admin.reservations_collision_check_in_message'.tr(namedArgs: {'time': navrhovanyCas})
      : 'admin.reservations_collision_check_out_message'.tr(namedArgs: {'time': navrhovanyCas});
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        'admin.reservations_collision_title'.tr(),
        style: TextStyle(color: Colors.red),
      ),
      content: Text(contentText),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('admin.reservations_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            onApplyTime();
          },
          child: Text('admin.reservations_collision_apply_time'.tr()),
        ),
      ],
    ),
  );
}

/// Parsuje string DD.MM.YYYY nebo DD.MM.YYYY HH:mm na DateTime.
DateTime? _parseDateTime(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final trimmed = s.trim();
  try {
    if (trimmed.contains(' ')) {
      final parts = trimmed.split(' ');
      final dParts = parts[0].split('.');
      final tParts = parts[1].split(':');
      if (dParts.length >= 3 && tParts.length >= 2) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          int.parse(tParts[0]),
          int.parse(tParts[1]),
        );
      }
    } else {
      final dParts = trimmed.split('.');
      if (dParts.length >= 3) {
        return DateTime(
          int.parse(dParts[2]),
          int.parse(dParts[1]),
          int.parse(dParts[0]),
          15,
          0,
        );
      }
    }
  } catch (_) {}
  return null;
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
      builder: (ctx) => _EditReservationDialog(
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
    final now = DateTime.now();
    _timelineVisibleStartDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
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
      backgroundColor: const Color(0xFFF5F5F5),
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
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'admin.reservations_timeline_title'.tr(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ReservationTimeline(
                              visibleStartDate: _timelineVisibleStartDate,
                              onPrevious: () => setState(() {
                                _timelineVisibleStartDate = _timelineVisibleStartDate.subtract(const Duration(days: 7));
                              }),
                              onToday: () {
                                final now = DateTime.now();
                                setState(() {
                                  _timelineVisibleStartDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
                                });
                              },
                              onNext: () => setState(() {
                                _timelineVisibleStartDate = _timelineVisibleStartDate.add(const Duration(days: 7));
                              }),
                              onReservationTap: (r) => _showEditDialog(context, ref, r),
                              onEmptyCellTap: (apartmentId, date) {
                                final d = date;
                                final checkInStr = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
                                _showAddDialog(context, ref, initialApartmentId: apartmentId, initialCheckIn: checkInStr);
                              },
                            ),
                          ],
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
      builder: (ctx) => _AddReservationDialog(
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
      builder: (ctx) => _EditReservationDialog(
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client
          .from('reservations')
          .update({'deleted_at': deletedAt})
          .eq('id', id);
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
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

      // Kaskáda: soft-delete úkolů navázaných na tuto rezervaci (stejný byt, termín v rozsahu rezervace).
      if (tenantId != null &&
          tenantId.isNotEmpty &&
          reservation.apartmentId.isNotEmpty) {
        final rangeStart = _parseDateTime(reservation.checkIn);
        final rangeEnd = _parseDateTime(reservation.checkOut);
        if (rangeStart != null && rangeEnd != null) {
          final endOfDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day, 23, 59, 59);
          final startIso = rangeStart.toUtc().toIso8601String();
          final endIso = endOfDay.toUtc().toIso8601String();
          try {
            final tasksRes = await SupabaseService.client
                .from('tasks')
                .select('id')
                .eq('tenant_id', tenantId)
                .eq('apartment_id', reservation.apartmentId)
                .isFilter('deleted_at', null)
                .gte('scheduled_start', startIso)
                .lte('scheduled_start', endIso);
            final taskList = tasksRes as List<dynamic>?;
            if (taskList != null && taskList.isNotEmpty) {
              for (final t in taskList) {
                final taskId = (t is Map ? t['id'] : null)?.toString();
                if (taskId == null || taskId.isEmpty) continue;
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
}

/// Top Action Bar – titulek, vyhledávání, tlačítko Přidat.
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
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: Text('admin.fab_new_reservation'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rezervační plachta (Gantt chart) – souvislé pruhy rezervací v mřížce dnů × apartmány.
/// [visibleStartDate] – první zobrazený den; [onPrevious]/[onToday]/[onNext] – navigace v čase.
/// [onEmptyCellTap] – tap na prázdnou buňku → nová rezervace s předvyplněním bytu a data.
class ReservationTimeline extends ConsumerWidget {
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

  static const int _totalDays = 38;
  static const double _timelineHeight = 480.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(adminReservationsProvider);
    final apartmentsAsync = ref.watch(apartmentsProvider);

    if (reservationsAsync.isLoading || apartmentsAsync.isLoading) {
      return SizedBox(
        height: _timelineHeight,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final reservations = reservationsAsync.valueOrNull ?? [];
    final apartments = apartmentsAsync.valueOrNull ?? [];

    final startDate = DateTime(visibleStartDate.year, visibleStartDate.month, visibleStartDate.day);
    final days = List<DateTime>.generate(
      _totalDays,
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
        final checkInDt = _parseReservationCheckIn(r.checkIn);
        final checkOutDt = _parseReservationCheckOut(r.checkOut);
        if (checkInDt == null || checkOutDt == null) continue;
        final checkInDate = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);
        final checkOutDate = DateTime(checkOutDt.year, checkOutDt.month, checkOutDt.day);
        if (!cellDate.isBefore(checkInDate) && !cellDate.isAfter(checkOutDate)) return false;
      }
      return true;
    }

    final totalWidth = days.length * dayWidth;
    final gridHeight = apartments.length * rowHeight;
    final apartmentIndexById = {for (var i = 0; i < apartments.length; i++) apartments[i].id: i};
    final locale = context.locale.toString();
    final dateFormat = DateFormat('d.M.', locale);
    final endDate = startDate.add(Duration(days: days.length - 1));

    return SizedBox(
      height: _timelineHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Horní ovládací lišta – přesný layout jako Plánovací kalendář
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrevious,
                  tooltip: 'admin.reservations_timeline_prev'.tr(),
                ),
                const SizedBox(width: 8),
                Text(
                  '${dateFormat.format(startDate)} – ${dateFormat.format(endDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                  tooltip: 'admin.reservations_timeline_next'.tr(),
                ),
                const SizedBox(width: 24),
                OutlinedButton(
                  onPressed: onToday,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('admin.reservations_timeline_today'.tr()),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ReservationLegendPill(status: 'new', bg: Colors.blue.shade100, text: Colors.blue.shade900),
                      _ReservationLegendPill(status: 'confirmed', bg: Colors.green.shade100, text: Colors.green.shade900),
                      _ReservationLegendPill(status: 'checked_in', bg: Colors.orange.shade100, text: Colors.orange.shade900),
                      _ReservationLegendPill(status: 'checked_out', bg: Colors.grey.shade200, text: Colors.grey.shade800),
                      _ReservationLegendPill(status: 'cancelled', bg: Colors.red.shade100, text: Colors.red.shade900),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Kontejner „papír na stole“ – bílý box se stínem a zaoblenými rohy (konzistence s Plánovacím kalendářem)
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
                child: _ReservationTimelineGrid(
              reservations: reservations,
              apartments: apartments,
              days: days,
              startDate: startDate,
              today: today,
              dayWidth: dayWidth,
              rowHeight: rowHeight,
              leftColumnWidth: leftColumnWidth,
              totalWidth: totalWidth,
              gridHeight: gridHeight,
              apartmentIndexById: apartmentIndexById,
              isCellEmpty: isCellEmpty,
              onReservationTap: onReservationTap,
              onEmptyCellTap: onEmptyCellTap,
            ),
              ),
            ),
          ),
        ],
      ),
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
          child: SingleChildScrollView(
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
    final checkInDt = _parseReservationCheckIn(reservation.checkIn);
    final checkOutDt = _parseReservationCheckOut(reservation.checkOut);
    if (checkInDt == null || checkOutDt == null) return const SizedBox.shrink();
    final checkInDate = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);
    final checkOutDate = DateTime(checkOutDt.year, checkOutDt.month, checkOutDt.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final daysFromStart = checkInDate.difference(startDateOnly).inDays;
    final left = daysFromStart < 0 ? 0.0 : daysFromStart * dayWidth;
    final nights = checkOutDate.difference(checkInDate).inDays;
    final width = nights * dayWidth;
    if (width <= 0) return const SizedBox.shrink();
    final aptIndex = apartmentIndexById[reservation.apartmentId] ?? 0;
    final top = aptIndex * rowHeight;
    final guestName = (reservation.guestName ?? '').trim().isEmpty ? 'Host' : reservation.guestName!;
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guestName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  // Responzivní druhý řádek: ikonky hostů/transfer/poznámky jen pro širší bloky (1 noc ≈ 85 px → ořezává se text)
                  if (width > 120) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '👥 $totalGuests',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
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
                ],
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
      await SupabaseService.client
          .from('reservations')
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
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            margin: EdgeInsets.zero,
            child: _KanbanCardContent(
              reservation: reservation,
              showDelete: true,
              onDelete: () => onDelete(reservation),
            ),
          ),
        ),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => onEdit(reservation),
            borderRadius: BorderRadius.circular(12),
            child: _KanbanCardContent(
              reservation: reservation,
              showDelete: true,
              onDelete: () => onDelete(reservation),
            ),
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
                // 2. řádek – hlavní nadpis: jméno hosta + drobné ikony (transfer, poznámka)
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
          if (showDelete) ...[
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
    final nights = _reservationNights(reservation.checkIn, reservation.checkOut);
    final nightsText = nights != null && nights >= 0
        ? 'admin.reservations_nights'.tr(namedArgs: {'count': nights.toString()})
        : null;

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => onEdit(reservation),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
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
              IconButton(
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
        ),
      ),
    );
  }
}

/// Dialog pro přidání nové rezervace. [initialApartmentId] a [initialCheckIn] předvyplní formulář (např. z Plachty).
class _AddReservationDialog extends ConsumerStatefulWidget {
  const _AddReservationDialog({
    required this.ref,
    required this.onSaved,
    this.initialApartmentId,
    this.initialCheckIn,
  });

  final WidgetRef ref;
  final VoidCallback onSaved;
  final String? initialApartmentId;
  final String? initialCheckIn;

  @override
  ConsumerState<_AddReservationDialog> createState() =>
      _AddReservationDialogState();
}

class _AddReservationDialogState extends ConsumerState<_AddReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestNameController;
  late final TextEditingController _guestPhoneController;
  late final TextEditingController _guestAdultsController;
  late final TextEditingController _guestChildrenController;
  late final TextEditingController _arrivalTimeController;
  late final TextEditingController _departureTimeController;
  /// Zobrazovaný text období pobytu ve formátu DD.MM.YYYY - DD.MM.YYYY (stejný vzhled jako ostatní pole).
  late final TextEditingController _stayPeriodController;
  late final TextEditingController _internalNoteController;
  /// Spojený výběr období pobytu (jeden rozsah místo dvou polí Check-in/Check-out).
  DateTimeRange? _dateRange;
  /// Zdroj rezervace: Booking, Airbnb, Direct, Other (pro dropdown).
  String _reservationSource = 'Other';
  late String? _selectedApartmentId;
  bool _isSaving = false;
  /// Tab 2: stav služeb (apartmentServiceId -> edit state). Naplní se z apartmentServicesOptionsProvider.
  Map<String, ReservationServiceEditState> _servicesState = {};

  @override
  void initState() {
    super.initState();
    _guestNameController = TextEditingController();
    _guestPhoneController = TextEditingController();
    _guestAdultsController = TextEditingController(text: '0');
    _guestChildrenController = TextEditingController(text: '0');
    _arrivalTimeController = TextEditingController();
    _departureTimeController = TextEditingController();
    _stayPeriodController = TextEditingController();
    _internalNoteController = TextEditingController();
    _selectedApartmentId = widget.initialApartmentId;
    // Předvyplnění období z Plachty: initialCheckIn (DD.MM.YYYY) -> start; konec +1 den jako výchozí.
    if (widget.initialCheckIn != null && widget.initialCheckIn!.trim().isNotEmpty) {
      final start = _parseDateTime(widget.initialCheckIn!.trim());
      if (start != null) {
        _dateRange = DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(start.year, start.month, start.day).add(const Duration(days: 1)),
        );
        _stayPeriodController.text = _formatDateRangeDisplay(_dateRange!);
      }
    }
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _guestAdultsController.dispose();
    _guestChildrenController.dispose();
    _arrivalTimeController.dispose();
    _departureTimeController.dispose();
    _stayPeriodController.dispose();
    _internalNoteController.dispose();
    super.dispose();
  }

  /// [successMessage] – při automatické opravě kolize se zobrazí tento text místo výchozího.
  Future<void> _onSave({String? successMessage}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    if (_selectedApartmentId == null || _selectedApartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_check_in_out'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final startDate = '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')}';
    final endDate = '${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}';

    // Složení UTC timestampů z data a časů: příjezd = start datum + arrival_time, odjezd = end datum + departure_time (pro kolize a DB).
    final arrivalParts = _arrivalTimeController.text.trim().split(':');
    final arrivalH = arrivalParts.length >= 2 ? (int.tryParse(arrivalParts[0]) ?? 15) : 15;
    final arrivalM = arrivalParts.length >= 2 ? (int.tryParse(arrivalParts[1]) ?? 0) : 0;
    final newCheckIn = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, arrivalH, arrivalM, 0);
    final depParts = _departureTimeController.text.trim().split(':');
    final depH = depParts.length >= 2 ? (int.tryParse(depParts[0]) ?? 10) : 10;
    final depM = depParts.length >= 2 ? (int.tryParse(depParts[1]) ?? 0) : 0;
    final newCheckOut = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, depH, depM, 0);

    if (newCheckOut.isBefore(newCheckIn) ||
        newCheckOut.isAtSameMomentAs(newCheckIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_departure_after_arrival'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final reservations =
          await ref.read(adminReservationsProvider.future);
      final apartments = await ref.read(apartmentsProvider.future);
      final apartmentList = apartments
          .where((a) => a.id == _selectedApartmentId)
          .toList();
      final apartment =
          apartmentList.isEmpty ? null : apartmentList.first;
      // Sčítáme základní čas úklidu bytu a extra čas přikoupených služeb – pro přesnou kontrolu kolizí.
      final options =
          await ref.read(apartmentServicesOptionsProvider(_selectedApartmentId!).future);
      int extraServiceMinutes = 0;
      for (final opt in options) {
        final state = _servicesState[opt.apartmentServiceId];
        if (state != null && state.enabled) {
          extraServiceMinutes += opt.durationMinutes;
        }
      }
      final totalCleaningDuration =
          (apartment?.standardCleaningDuration ?? 120) + extraServiceMinutes;

      _checkReservationCollision(
        existingReservations: reservations,
        apartmentId: _selectedApartmentId!,
        standardCleaningDuration: totalCleaningDuration,
        newCheckIn: newCheckIn,
        newCheckOut: newCheckOut,
      );

      final tenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('CRITICAL: tenantId is null before insert!');
      }

      if (_selectedApartmentId == null || _selectedApartmentId!.isEmpty) {
        throw Exception('CRITICAL: apartment_id is null or empty before insert!');
      }

      final guestAdults = int.tryParse(_guestAdultsController.text.trim()) ?? 0;
      final guestChildren = int.tryParse(_guestChildrenController.text.trim()) ?? 0;
      DateTime? arrivalTimeUtc;
      final arrivalStr = _arrivalTimeController.text.trim();
      if (arrivalStr.isNotEmpty) {
        final parts = arrivalStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          arrivalTimeUtc = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, h, m, 0).toUtc();
        }
      }
      DateTime? departureTimeUtc;
      final depStr = _departureTimeController.text.trim();
      if (depStr.isNotEmpty) {
        final parts = depStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          departureTimeUtc = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, h, m, 0).toUtc();
        }
      }

      // Dvoukrokové ukládání (Override Pattern Tier 3): nejdřív záznam v reservations,
      // potom služby rezervace v reservation_services (závisí na reservation_id).
      // KROK 1: Vložení rezervace a získání nového id (pro reservation_services).
      final payload = <String, dynamic>{
        'tenant_id': tenantId,
        'apartment_id': _selectedApartmentId,
        'start_date': startDate,
        'end_date': endDate,
        'guest_name': _guestNameController.text.trim().isEmpty
            ? null
            : _guestNameController.text.trim(),
        'guest_phone': _guestPhoneController.text.trim().isEmpty
            ? null
            : _guestPhoneController.text.trim(),
        'reservation_source': _reservationSource,
        'needs_transfer': false,
        'guest_adults': guestAdults,
        'guest_children': guestChildren,
        'arrival_time': arrivalTimeUtc?.toIso8601String(),
        'departure_time': departureTimeUtc?.toIso8601String(),
        'internal_note': _internalNoteController.text.trim().isEmpty
            ? null
            : _internalNoteController.text.trim(),
      };
      // ignore: avoid_print
      print('DEBUG RESERVATION PAYLOAD: $payload');

      final res = await SupabaseService.client
          .from('reservations')
          .insert(payload)
          .select('id')
          .single();
      final newId = res['id'] as String?;
      if (newId == null || newId.isEmpty) throw Exception('Insert reservations nevrátil id');

      // KROK 2: Uložení služeb rezervace (reservation_services) – delete + insert dle stavu Tabu 2 (charged_price v EUR, custom_note).
      await saveForReservation(
        reservationId: newId,
        tenantId: tenantId,
        states: _servicesState,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage ?? 'admin.reservations_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ReservationCollisionException catch (e) {
      if (!mounted) return;
      _showCollisionDialog(
        context: context,
        collisionSide: e.collisionSide,
        suggestedDateTime: e.suggestedDateTime!,
        onApplyTime: () {
          if (!mounted || _dateRange == null) return;
          setState(() {
            final t = e.suggestedDateTime!;
            if (e.collisionSide == CollisionSide.checkIn) {
              _dateRange = DateTimeRange(
                start: DateTime(t.year, t.month, t.day),
                end: _dateRange!.end,
              );
              _arrivalTimeController.text =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            } else {
              _dateRange = DateTimeRange(
                start: _dateRange!.start,
                end: DateTime(t.year, t.month, t.day),
              );
              _departureTimeController.text =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            }
          });
        },
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA UKLÁDÁNÍ REZERVACE: $e');
      if (e.code == '42703' || e.message.contains('column')) {
        // ignore: avoid_print
        print('>>> Chybí sloupce v tabulce reservations. Spusť: supabase/migrations/20250217_reservations_extended.sql');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chyba při ukládání: ${e.message}',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA UKLÁDÁNÍ REZERVACE: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chyba při ukládání: $e',
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

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);

    return ModernAdminPanel(
      title: 'admin.reservations_add'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: apartmentsAsync.when(
          data: (apartments) {
            if (apartments.isEmpty) {
              return Text(
                'admin.reservations_no_apartments'.tr(),
                style: TextStyle(color: Colors.grey.shade700),
              );
            }
            return DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    tabs: [
                      Tab(icon: const Icon(Icons.info_outline), text: 'admin.reservations_tab_stay_details'.tr()),
                      Tab(icon: const Icon(Icons.room_service_outlined), text: 'admin.reservations_tab_services_requests'.tr()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: _buildTab1StayDetails(context, apartments),
                        ),
                        SingleChildScrollView(
                          child: _buildTab2ServicesRequests(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(
            'admin.reservations_load_error'.tr(),
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('admin.reservations_cancel'.tr()),
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
              : Text('admin.reservations_save_button'.tr()),
        ),
      ],
    );
  }

  /// Tab 1: Byt, host (jméno, telefon), zdroj rezervace, počty, období pobytu (DateRangePicker), časy příjezdu/odjezdu.
  Widget _buildTab1StayDetails(BuildContext context, List<ApartmentRow> apartments) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.reservations_section_where_who'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedApartmentId != null && apartments.any((a) => a.id == _selectedApartmentId)
              ? _selectedApartmentId
              : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.list_alt_outlined),
            border: OutlineInputBorder(),
          ),
          hint: Text('admin.validation_apartment_required_short'.tr()),
          items: apartments
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (v) => setState(() => _selectedApartmentId = v),
          validator: (v) => v == null || (v.isEmpty) ? 'admin.validation_apartment_required_short'.tr() : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guestNameController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            labelText: 'admin.reservations_field_guest_name'.tr(),
            border: const OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'admin.validation_guest_name_required'.tr() : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guestPhoneController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_outlined),
            labelText: 'admin.reservations_field_guest_phone'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: reservationSourceValues.contains(_reservationSource) ? _reservationSource : 'Other',
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.source_outlined),
            labelText: 'admin.reservations_field_reservation_source'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: reservationSourceValues
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('admin.reservation_source_$s'.tr()),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _reservationSource = v);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _guestAdultsController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.people_alt_outlined),
                  labelText: 'admin.reservations_field_guest_adults'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _guestChildrenController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.numbers_outlined),
                  labelText: 'admin.reservations_field_guest_children'.tr(),
                  border: const OutlineInputBorder(),
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
          'admin.reservations_section_when'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _stayPeriodController,
          readOnly: true,
          onTap: () async {
            final now = DateTime.now();
            final initialStart = _dateRange?.start ?? now;
            final initialEnd = _dateRange?.end ?? now.add(const Duration(days: 1));
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
              builder: (context, child) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Material(
                    child: child,
                  ),
                ),
              ),
            );
            if (range != null && mounted) {
              setState(() {
                _dateRange = range;
                _stayPeriodController.text = _formatDateRangeDisplay(range);
              });
            }
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.calendar_today),
            labelText: 'admin.reservations_field_stay_period'.tr(),
            hintText: 'admin.reservations_hint_date_range'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _arrivalTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_arrival_time'.tr(),
                  hintText: 'HH:mm',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time_outlined),
                ),
                onTap: () async {
                  final parts = _arrivalTimeController.text.trim().split(':');
                  TimeOfDay initial = const TimeOfDay(hour: 15, minute: 0);
                  if (parts.length >= 2) {
                    initial = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 15,
                      minute: int.tryParse(parts[1]) ?? 0,
                    );
                  }
                  final picked = await showTimePicker(context: context, initialTime: initial);
                  if (picked != null && mounted) {
                    setState(() {
                      _arrivalTimeController.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                readOnly: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _departureTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_departure_time'.tr(),
                  hintText: 'HH:mm',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time_outlined),
                ),
                onTap: () async {
                  final parts = _departureTimeController.text.trim().split(':');
                  TimeOfDay initial = const TimeOfDay(hour: 10, minute: 0);
                  if (parts.length >= 2) {
                    initial = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 10,
                      minute: int.tryParse(parts[1]) ?? 0,
                    );
                  }
                  final picked = await showTimePicker(context: context, initialTime: initial);
                  if (picked != null && mounted) {
                    setState(() {
                      _departureTimeController.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                readOnly: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _internalNoteController,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.note_outlined),
            labelText: 'admin.reservations_field_internal_note'.tr(),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Tab 2: Služby bytu (apartment_services) – Checkbox + účtovaná cena a poznámka. Reaguje na vybraný byt.
  Widget _buildTab2ServicesRequests(BuildContext context) {
    final apartmentId = _selectedApartmentId ?? '';
    final optionsAsync = ref.watch(apartmentServicesOptionsProvider(apartmentId));
    final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    return optionsAsync.when(
      data: (options) {
        if (_servicesState.isEmpty && options.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _servicesState = {
                for (final o in options)
                  o.apartmentServiceId: ReservationServiceEditState(
                    apartmentServiceId: o.apartmentServiceId,
                    serviceName: o.serviceName,
                    defaultPriceEur: o.defaultPriceEur,
                    enabled: o.isMandatory,
                    chargedPriceEur: o.defaultPriceEur,
                    customNote: null,
                    payerType: o.payerType,
                  ),
              };
            });
          });
        }
        if (apartmentId.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'admin.reservations_select_apartment_first'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ),
          );
        }
        if (options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'admin.reservations_services_empty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final o = options[index];
            final state = _servicesState[o.apartmentServiceId] ??
                ReservationServiceEditState(
                  apartmentServiceId: o.apartmentServiceId,
                  serviceName: o.serviceName,
                  defaultPriceEur: o.defaultPriceEur,
                  enabled: o.isMandatory,
                  chargedPriceEur: o.defaultPriceEur,
                  customNote: null,
                  payerType: o.payerType,
                );
            final effectiveEnabled = state.enabled || o.isMandatory;
            final eurBase = (state.chargedPriceEur ?? state.defaultPriceEur);
            final displayPrice = CurrencyService.convert(eurBase, preferredCurrency, currencies);
            final displayPriceStr = displayPrice.toStringAsFixed(2);
            return ExpansionTile(
              initiallyExpanded: false,
              controlAffinity: ListTileControlAffinity.leading,
              title: GestureDetector(
                onTap: o.isMandatory
                    ? null
                    : () {
                        setState(() {
                          _servicesState[o.apartmentServiceId] =
                              state.copyWith(enabled: !effectiveEnabled);
                        });
                      },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Checkbox(
                      value: effectiveEnabled,
                      onChanged: o.isMandatory
                          ? null
                          : (v) {
                              setState(() {
                                _servicesState[o.apartmentServiceId] =
                                    state.copyWith(enabled: v ?? false);
                              });
                            },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.serviceName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (o.isMandatory)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'admin.service_mandatory_badge'.tr(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              children: effectiveEnabled
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
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey.shade500),
                                  labelText: 'admin.reservations_field_charged_price'.tr(namedArgs: {'code': preferredCurrency}),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) {
                                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                                  if (parsed == null) return;
                                  final eur = CurrencyService.toEur(parsed, preferredCurrency, currencies);
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] =
                                        state.copyWith(chargedPriceEur: eur);
                                  });
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24.0),
                              child: DropdownButtonFormField<String>(
                                initialValue: state.payerType,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.payment_outlined, color: Colors.grey.shade500),
                                  labelText: 'admin.payer_type_label'.tr(),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: [
                                  DropdownMenuItem(value: 'owner', child: Text('admin.payer_owner'.tr())),
                                  DropdownMenuItem(value: 'guest', child: Text('admin.payer_guest'.tr())),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] =
                                        state.copyWith(payerType: v);
                                  });
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24.0),
                              child: TextFormField(
                                initialValue: state.customNote ?? '',
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.notes_outlined, color: Colors.grey.shade500),
                                  labelText: 'admin.reservations_field_custom_note'.tr(),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 2,
                                onChanged: (v) {
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] =
                                        state.copyWith(customNote: v.isEmpty ? null : v);
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
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (_, _) => Center(
        child: Text(
          'admin.reservations_load_error'.tr(),
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }
}

/// Seznam úkolů souvisejících s rezervací – kompaktní ListTile s ikonou typu, tučným jménem a Chipem stavu.
class _RelatedTasksList extends StatelessWidget {
  const _RelatedTasksList({
    required this.reservation,
    required this.tasksAsync,
  });

  final ReservationRow reservation;
  final AsyncValue<List<TaskRow>> tasksAsync;

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      data: (tasks) {
        final checkInDt = _parseReservationCheckIn(reservation.checkIn);
        final checkOutDt = _parseReservationCheckOut(reservation.checkOut);
        if (checkInDt == null || checkOutDt == null) {
          return Text(
            'admin.reservations_no_tasks_yet'.tr(),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          );
        }
        // Priorita 1: úkoly s vazbou reservation_id == reservation.id.
        // Zpětná kompatibilita: úkoly bez reservation_id filtrujeme podle apartment_id a časového okna.
        final resStart = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);
        final resEnd = DateTime(checkOutDt.year, checkOutDt.month, checkOutDt.day, 23, 59, 59);
        final related = tasks.where((t) {
          if (t.reservationId != null && t.reservationId!.isNotEmpty) {
            return t.reservationId == reservation.id;
          }
          if (t.apartmentId != reservation.apartmentId) return false;
          return !t.dueDate.isBefore(resStart) && !t.dueDate.isAfter(resEnd);
        }).toList();
        if (related.isEmpty) {
          return Text(
            'admin.reservations_no_tasks_yet'.tr(),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: related
              .map(
                (t) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        _taskTypeIcon(t.taskType),
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          _taskTypeEmoji(t.taskType),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _taskTypeLabelKey(t.taskType).tr(),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.assignedToName ?? '–',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        t.status,
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: _taskStatusChipColor(t.status),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
      loading: () => const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Text(
        'admin.reservations_no_tasks_yet'.tr(),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }
}

/// Dialog pro úpravu existující rezervace.
class _EditReservationDialog extends ConsumerStatefulWidget {
  const _EditReservationDialog({
    required this.ref,
    required this.reservation,
    required this.onSaved,
  });

  final WidgetRef ref;
  final ReservationRow reservation;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditReservationDialog> createState() =>
      _EditReservationDialogState();
}

class _EditReservationDialogState extends ConsumerState<_EditReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestNameController;
  late final TextEditingController _guestPhoneController;
  late final TextEditingController _guestAdultsController;
  late final TextEditingController _guestChildrenController;
  late final TextEditingController _arrivalTimeController;
  late final TextEditingController _departureTimeController;
  late final TextEditingController _stayPeriodController;
  late final TextEditingController _internalNoteController;
  DateTimeRange? _dateRange;
  String _reservationSource = 'Other';
  late String _selectedApartmentId;
  late String _status;
  bool _isSaving = false;
  Map<String, ReservationServiceEditState> _servicesState = {};
  bool _servicesLoaded = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reservation;
    _guestNameController = TextEditingController(text: r.guestName ?? '');
    _guestPhoneController = TextEditingController(text: r.guestPhone ?? '');
    _guestAdultsController = TextEditingController(text: '${r.guestAdults}');
    _guestChildrenController = TextEditingController(text: '${r.guestChildren}');
    final at = r.arrivalTime?.toLocal();
    _arrivalTimeController = TextEditingController(
      text: at != null ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}' : '',
    );
    final dt = r.departureTime?.toLocal();
    _departureTimeController = TextEditingController(
      text: dt != null ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '',
    );
    _stayPeriodController = TextEditingController();
    _internalNoteController = TextEditingController(text: r.internalNote ?? '');
    _reservationSource = r.reservationSource != null && reservationSourceValues.contains(r.reservationSource)
        ? r.reservationSource!
        : 'Other';
    final startDt = _parseDateTime(r.checkIn);
    final endDt = _parseDateTime(r.checkOut);
    if (startDt != null && endDt != null) {
      _dateRange = DateTimeRange(
        start: DateTime(startDt.year, startDt.month, startDt.day),
        end: DateTime(endDt.year, endDt.month, endDt.day),
      );
      _stayPeriodController.text = _formatDateRangeDisplay(_dateRange!);
    }
    _selectedApartmentId = r.apartmentId;
    _status = reservationStatusValues.contains(r.status) ? r.status : 'new';
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _guestAdultsController.dispose();
    _guestChildrenController.dispose();
    _arrivalTimeController.dispose();
    _departureTimeController.dispose();
    _stayPeriodController.dispose();
    _internalNoteController.dispose();
    super.dispose();
  }

  /// Načtení služeb rezervace (Override Pattern Tier 3): načte záznamy z reservation_services
  /// pro tuto rezervaci a sloučí je s nabídkou apartment_services vybraného bytu do _servicesState pro předvyplnění Tabu 2.
  Future<void> _loadServicesState(List<ApartmentServiceOption> options) async {
    final rows = await fetchByReservationId(widget.reservation.id);
    final byApartmentServiceId = {for (final row in rows) row.apartmentServiceId: row};
    if (!mounted) return;
    setState(() {
      _servicesState = {
        for (final o in options)
          o.apartmentServiceId: () {
            final row = byApartmentServiceId[o.apartmentServiceId];
            if (row == null) {
              return ReservationServiceEditState(
                apartmentServiceId: o.apartmentServiceId,
                serviceName: o.serviceName,
                defaultPriceEur: o.defaultPriceEur,
                enabled: o.isMandatory,
                chargedPriceEur: o.defaultPriceEur,
                customNote: null,
                payerType: o.payerType,
              );
            }
            final payerType = (row.payerType == 'owner' || row.payerType == 'guest')
                ? row.payerType!
                : o.payerType;
            return ReservationServiceEditState(
              apartmentServiceId: o.apartmentServiceId,
              serviceName: o.serviceName,
              defaultPriceEur: o.defaultPriceEur,
              enabled: true,
              chargedPriceEur: row.chargedPrice?.toDouble(),
              customNote: row.customNote,
              payerType: payerType,
            );
          }(),
      };
      _servicesLoaded = true;
    });
  }

  /// [successMessage] – při automatické opravě kolize se zobrazí tento text místo výchozího.
  Future<void> _onSave({String? successMessage}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_check_in_out'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final startDate = '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')}';
    final endDate = '${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}';

    final arrivalParts = _arrivalTimeController.text.trim().split(':');
    final arrivalH = arrivalParts.length >= 2 ? (int.tryParse(arrivalParts[0]) ?? 15) : 15;
    final arrivalM = arrivalParts.length >= 2 ? (int.tryParse(arrivalParts[1]) ?? 0) : 0;
    final newCheckIn = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, arrivalH, arrivalM, 0);
    final depParts = _departureTimeController.text.trim().split(':');
    final depH = depParts.length >= 2 ? (int.tryParse(depParts[0]) ?? 10) : 10;
    final depM = depParts.length >= 2 ? (int.tryParse(depParts[1]) ?? 0) : 0;
    final newCheckOut = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, depH, depM, 0);

    if (newCheckOut.isBefore(newCheckIn) ||
        newCheckOut.isAtSameMomentAs(newCheckIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_departure_after_arrival'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Kontrola změny termínu: pokud se změnil check-in nebo check-out, smažeme návrhy úkolů
    final origStart = _parseDateTime(widget.reservation.checkIn);
    final origEnd = _parseDateTime(widget.reservation.checkOut);
    final origStartDay = origStart != null ? DateTime(origStart.year, origStart.month, origStart.day) : null;
    final origEndDay = origEnd != null ? DateTime(origEnd.year, origEnd.month, origEnd.day) : null;
    final newStartDay = DateTime(newCheckIn.year, newCheckIn.month, newCheckIn.day);
    final newEndDay = DateTime(newCheckOut.year, newCheckOut.month, newCheckOut.day);
    final datesChanged = origStartDay != newStartDay || origEndDay != newEndDay;

    if (datesChanged) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('admin.reservations_date_change_title'.tr()),
          content: Text('admin.reservations_date_change_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('admin.reservations_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('admin.reservations_delete_and_save'.tr()),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) return;

      // Soft Delete: Návrhy úkolů navázané na tuto rezervaci – místo tvrdého mazání nastavíme deleted_at
      // (Audit Log vyžaduje zachování historie; tvrdý DELETE by rozbil sledovatelnost).
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client
          .from('tasks')
          .update({'deleted_at': deletedAt})
          .eq('reservation_id', widget.reservation.id)
          .eq('status', 'Návrh');
      ref.invalidate(adminTasksProvider);
    }

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final reservations =
          await ref.read(adminReservationsProvider.future);
      final apartments = await ref.read(apartmentsProvider.future);
      final apartmentList = apartments
          .where((a) => a.id == _selectedApartmentId)
          .toList();
      final apartment =
          apartmentList.isEmpty ? null : apartmentList.first;
      // Sčítáme základní čas úklidu bytu a extra čas přikoupených služeb – pro přesnou kontrolu kolizí.
      final options =
          await ref.read(apartmentServicesOptionsProvider(_selectedApartmentId!).future);
      int extraServiceMinutes = 0;
      for (final opt in options) {
        final state = _servicesState[opt.apartmentServiceId];
        if (state != null && state.enabled) {
          extraServiceMinutes += opt.durationMinutes;
        }
      }
      final totalCleaningDuration =
          (apartment?.standardCleaningDuration ?? 120) + extraServiceMinutes;

      _checkReservationCollision(
        existingReservations: reservations,
        apartmentId: _selectedApartmentId,
        standardCleaningDuration: totalCleaningDuration,
        newCheckIn: newCheckIn,
        newCheckOut: newCheckOut,
        excludeReservationId: widget.reservation.id,
      );

      final guestAdults = int.tryParse(_guestAdultsController.text.trim()) ?? 0;
      final guestChildren = int.tryParse(_guestChildrenController.text.trim()) ?? 0;
      DateTime? arrivalTimeUtc;
      final arrivalStr = _arrivalTimeController.text.trim();
      if (arrivalStr.isNotEmpty) {
        final parts = arrivalStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          arrivalTimeUtc = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, h, m, 0).toUtc();
        }
      }
      DateTime? departureTimeUtc;
      final depStr = _departureTimeController.text.trim();
      if (depStr.isNotEmpty) {
        final parts = depStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          departureTimeUtc = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, h, m, 0).toUtc();
        }
      }

      // Dvoukrokové ukládání (Override Pattern Tier 3): nejdřív úprava rezervace, potom přepsání reservation_services.
      // KROK 1: Aktualizace záznamu rezervace (včetně guest_phone, reservation_source, departure_time).
      await SupabaseService.client.from('reservations').update({
        'apartment_id': _selectedApartmentId,
        'guest_name': _guestNameController.text.trim().isEmpty
            ? null
            : _guestNameController.text.trim(),
        'guest_phone': _guestPhoneController.text.trim().isEmpty
            ? null
            : _guestPhoneController.text.trim(),
        'reservation_source': _reservationSource,
        'start_date': startDate,
        'end_date': endDate,
        'needs_transfer': false,
        'status': _status,
        'guest_adults': guestAdults,
        'guest_children': guestChildren,
        'arrival_time': arrivalTimeUtc?.toIso8601String(),
        'departure_time': departureTimeUtc?.toIso8601String(),
        'internal_note': _internalNoteController.text.trim().isEmpty
            ? null
            : _internalNoteController.text.trim(),
      }).eq('id', widget.reservation.id);

      // KROK 2: Uložení služeb rezervace (reservation_services) – replace všech záznamů pro tuto rezervaci (delete + insert dle stavu Tabu 2).
      await saveForReservation(
        reservationId: widget.reservation.id,
        tenantId: tenantId,
        states: _servicesState,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage ?? 'admin.reservations_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ReservationCollisionException catch (e) {
      if (!mounted) return;
      _showCollisionDialog(
        context: context,
        collisionSide: e.collisionSide,
        suggestedDateTime: e.suggestedDateTime!,
        onApplyTime: () {
          if (!mounted || _dateRange == null) return;
          setState(() {
            final t = e.suggestedDateTime!;
            if (e.collisionSide == CollisionSide.checkIn) {
              _dateRange = DateTimeRange(
                start: DateTime(t.year, t.month, t.day),
                end: _dateRange!.end,
              );
              _arrivalTimeController.text =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            } else {
              _dateRange = DateTimeRange(
                start: _dateRange!.start,
                end: DateTime(t.year, t.month, t.day),
              );
              _departureTimeController.text =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            }
          });
        },
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA ÚPRAVY REZERVACE: $e');
      if (e.code == '42703' || e.message.contains('column')) {
        // ignore: avoid_print
        print('>>> Chybí sloupce. Spusť: supabase/migrations/20250217_reservations_extended.sql');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chyba při ukládání: ${e.message}',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA ÚPRAVY REZERVACE: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chyba při ukládání: $e',
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

  Widget _buildEditTab1StayDetails(BuildContext context, List<ApartmentRow> apartments, AsyncValue<List<TaskRow>> tasksAsync) {
    final validId = apartments.any((a) => a.id == _selectedApartmentId)
        ? _selectedApartmentId
        : (apartments.isNotEmpty ? apartments.first.id : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.reservations_section_where_who'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: validId,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.list_alt_outlined),
            border: OutlineInputBorder(),
          ),
          items: apartments
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedApartmentId = v);
          },
          validator: (v) => v == null ? 'admin.validation_apartment_required_short'.tr() : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: reservationStatusValues.contains(_status) ? _status : reservationStatusValues.first,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.list_alt_outlined),
            border: const OutlineInputBorder(),
            labelText: 'admin.reservations_status_label'.tr(),
          ),
          items: reservationStatusValues
              .map((s) => DropdownMenuItem(value: s, child: Text(reservationStatusLabelKey(s).tr())))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _status = v);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guestNameController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            labelText: 'admin.reservations_field_guest_name'.tr(),
            border: const OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'admin.validation_guest_name_required'.tr() : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guestPhoneController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_outlined),
            labelText: 'admin.reservations_field_guest_phone'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: reservationSourceValues.contains(_reservationSource) ? _reservationSource : 'Other',
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.source_outlined),
            labelText: 'admin.reservations_field_reservation_source'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: reservationSourceValues
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('admin.reservation_source_$s'.tr()),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _reservationSource = v);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _guestAdultsController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.people_alt_outlined),
                  labelText: 'admin.reservations_field_guest_adults'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _guestChildrenController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.numbers_outlined),
                  labelText: 'admin.reservations_field_guest_children'.tr(),
                  border: const OutlineInputBorder(),
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
          'admin.reservations_section_when'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _stayPeriodController,
          readOnly: true,
          onTap: () async {
            final now = DateTime.now();
            final initialStart = _dateRange?.start ?? now;
            final initialEnd = _dateRange?.end ?? now.add(const Duration(days: 1));
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
              builder: (context, child) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Material(
                    child: child,
                  ),
                ),
              ),
            );
            if (range != null && mounted) {
              setState(() {
                _dateRange = range;
                _stayPeriodController.text = _formatDateRangeDisplay(range);
              });
            }
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.calendar_today),
            labelText: 'admin.reservations_field_stay_period'.tr(),
            hintText: 'admin.reservations_hint_date_range'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _arrivalTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_arrival_time'.tr(),
                  hintText: 'HH:mm',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time_outlined),
                ),
                onTap: () async {
                  final parts = _arrivalTimeController.text.trim().split(':');
                  TimeOfDay initial = const TimeOfDay(hour: 15, minute: 0);
                  if (parts.length >= 2) {
                    initial = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 15,
                      minute: int.tryParse(parts[1]) ?? 0,
                    );
                  }
                  final picked = await showTimePicker(context: context, initialTime: initial);
                  if (picked != null && mounted) {
                    setState(() {
                      _arrivalTimeController.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                readOnly: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _departureTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_departure_time'.tr(),
                  hintText: 'HH:mm',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time_outlined),
                ),
                onTap: () async {
                  final parts = _departureTimeController.text.trim().split(':');
                  TimeOfDay initial = const TimeOfDay(hour: 10, minute: 0);
                  if (parts.length >= 2) {
                    initial = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 10,
                      minute: int.tryParse(parts[1]) ?? 0,
                    );
                  }
                  final picked = await showTimePicker(context: context, initialTime: initial);
                  if (picked != null && mounted) {
                    setState(() {
                      _departureTimeController.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
                readOnly: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _internalNoteController,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.note_outlined),
            labelText: 'admin.reservations_field_internal_note'.tr(),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'admin.reservations_related_tasks'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        _RelatedTasksList(
          reservation: widget.reservation,
          tasksAsync: tasksAsync,
        ),
      ],
    );
  }

  Widget _buildEditTab2ServicesRequests(BuildContext context) {
    final apartmentId = _selectedApartmentId;
    final optionsAsync = ref.watch(apartmentServicesOptionsProvider(apartmentId));
    final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    return optionsAsync.when(
      data: (options) {
        if (!_servicesLoaded && options.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadServicesState(options);
          });
        }
        if (options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'admin.reservations_services_empty'.tr(),
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
          itemCount: options.length,
          itemBuilder: (context, index) {
            final o = options[index];
            final state = _servicesState[o.apartmentServiceId] ??
                ReservationServiceEditState(
                  apartmentServiceId: o.apartmentServiceId,
                  serviceName: o.serviceName,
                  defaultPriceEur: o.defaultPriceEur,
                  enabled: o.isMandatory,
                  chargedPriceEur: o.defaultPriceEur,
                  customNote: null,
                  payerType: o.payerType,
                );
            final effectiveEnabled = state.enabled || o.isMandatory;
            final eurBase = (state.chargedPriceEur ?? state.defaultPriceEur);
            final displayPrice = CurrencyService.convert(eurBase, preferredCurrency, currencies);
            final displayPriceStr = displayPrice.toStringAsFixed(2);
            return ExpansionTile(
              initiallyExpanded: false,
              controlAffinity: ListTileControlAffinity.leading,
              title: GestureDetector(
                onTap: o.isMandatory
                    ? null
                    : () {
                        setState(() {
                          _servicesState[o.apartmentServiceId] =
                              state.copyWith(enabled: !effectiveEnabled);
                        });
                      },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Checkbox(
                      value: effectiveEnabled,
                      onChanged: o.isMandatory
                          ? null
                          : (v) {
                              setState(() {
                                _servicesState[o.apartmentServiceId] =
                                    state.copyWith(enabled: v ?? false);
                              });
                            },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.serviceName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (o.isMandatory)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                'admin.service_mandatory_badge'.tr(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              children: effectiveEnabled
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
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey.shade500),
                                  labelText: 'admin.reservations_field_charged_price'.tr(namedArgs: {'code': preferredCurrency}),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) {
                                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                                  if (parsed == null) return;
                                  final eur = CurrencyService.toEur(parsed, preferredCurrency, currencies);
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = state.copyWith(chargedPriceEur: eur);
                                  });
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24.0),
                              child: DropdownButtonFormField<String>(
                                initialValue: state.payerType,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.payment_outlined, color: Colors.grey.shade500),
                                  labelText: 'admin.payer_type_label'.tr(),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: [
                                  DropdownMenuItem(value: 'owner', child: Text('admin.payer_owner'.tr())),
                                  DropdownMenuItem(value: 'guest', child: Text('admin.payer_guest'.tr())),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] =
                                        state.copyWith(payerType: v);
                                  });
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24.0),
                              child: TextFormField(
                                initialValue: state.customNote ?? '',
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.notes_outlined, color: Colors.grey.shade500),
                                  labelText: 'admin.reservations_field_custom_note'.tr(),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 2,
                                onChanged: (v) {
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = state.copyWith(customNote: v.isEmpty ? null : v);
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
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (_, _) => Center(
        child: Text(
          'admin.reservations_load_error'.tr(),
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsProvider);
    final tasksAsync = ref.watch(adminTasksProvider);

    return ModernAdminPanel(
      title: 'admin.reservations_edit'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: apartmentsAsync.when(
          data: (apartments) {
            if (apartments.isEmpty) {
              return Text(
                'admin.reservations_no_apartments'.tr(),
                style: TextStyle(color: Colors.grey.shade700),
              );
            }
            return DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    tabs: [
                      Tab(icon: const Icon(Icons.info_outline), text: 'admin.reservations_tab_stay_details'.tr()),
                      Tab(icon: const Icon(Icons.room_service_outlined), text: 'admin.reservations_tab_services_requests'.tr()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: _buildEditTab1StayDetails(context, apartments, tasksAsync),
                        ),
                        SingleChildScrollView(
                          child: _buildEditTab2ServicesRequests(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(
            'admin.reservations_load_error'.tr(),
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('admin.reservations_cancel'.tr()),
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
              : Text('admin.reservations_save_button'.tr()),
        ),
      ],
    );
  }
}
