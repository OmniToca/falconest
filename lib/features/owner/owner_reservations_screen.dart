import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart'
    show
        parseFlightFromCustomNote,
        ApartmentServiceOption,
        ReservationServiceEditState;
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_dashboard_metrics_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservations_provider.dart';

/// Přehled rezervací majitele – Kanban board podle stavu a možnost přidat rezervaci.
///
/// Používá [ownerReservationsProvider] pro načtení rezervací ze Supabase.
/// FAB otevře vycentrovaný dialog s formulářem pro novou rezervaci.
class OwnerReservationsScreen extends ConsumerStatefulWidget {
  const OwnerReservationsScreen({super.key});

  @override
  ConsumerState<OwnerReservationsScreen> createState() =>
      _OwnerReservationsScreenState();
}

class _OwnerReservationsScreenState
    extends ConsumerState<OwnerReservationsScreen> {
  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(ownerReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('owner.reservations_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'owner.reservations_block_owner_stay'.tr(),
            icon: const Icon(Icons.event_busy_outlined),
            onPressed: () => _showBlockOwnerStayDialog(context, ref),
          ),
        ],
      ),
      body: reservationsAsync.when(
        data: (reservations) => _OwnerReservationsKanbanBoard(
          reservations: reservations,
          ref: ref,
          onEditReservation: (r) => _showEditReservationDialog(context, ref, r),
          onDeleteOwnerStay: (r) => _confirmDeleteOwnerStay(context, ref, r),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'owner.reservations_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(ownerReservationsProvider);
                  ref.invalidate(ownerReservationsForPlanningCalendarProvider);
                },
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewReservationDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text('owner.reservations_new'.tr()),
      ),
    );
  }

  /// UI: Otevře vycentrovaný dialog s formulářem pro novou rezervaci.
  void _showNewReservationDialog(BuildContext context, WidgetRef ref) {
    final apartments = ref.read(ownerApartmentsProvider).value ?? [];
    if (apartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.apartments_empty'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 900),
          child: SingleChildScrollView(
            child: _NewReservationForm(
              apartments: apartments,
              onSaved: () {
                Navigator.of(dialogContext).pop();
                ref.invalidate(ownerReservationsProvider);
                ref.invalidate(ownerReservationsForPlanningCalendarProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('owner.reservations_saved'.tr()),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              onError: (String error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'owner.reservations_save_error'.tr(
                        namedArgs: {'error': error},
                      ),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// FEATURE: Editace rezervace povolena pouze ve stavu 'new'.
  /// SECURITY: Uzamčení rezervace po předání agentuře (stav 'confirmed').
  void _showEditReservationDialog(
    BuildContext context,
    WidgetRef ref,
    OwnerReservation reservation,
  ) {
    if (reservation.status != 'new') {
      return; // Read-only pro confirmed a pozdější stavy
    }
    final apartments = ref.read(ownerApartmentsProvider).value ?? [];
    if (apartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.apartments_empty'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 900),
          child: SingleChildScrollView(
            child: _NewReservationForm(
              apartments: apartments,
              existingReservation: reservation,
              onSaved: () {
                Navigator.of(dialogContext).pop();
                ref.invalidate(ownerReservationsProvider);
                ref.invalidate(ownerReservationsForPlanningCalendarProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('owner.reservations_saved'.tr()),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              onError: (String error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'owner.reservations_save_error'.tr(
                        namedArgs: {'error': error},
                      ),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Jednoduchý dialog „od–do“ pro blokaci termínu (vlastní pobyt); zápis [metadata.is_owner_stay].
  void _showBlockOwnerStayDialog(BuildContext context, WidgetRef ref) {
    final apartments = ref.read(ownerApartmentsProvider).value ?? [];
    if (apartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.apartments_empty'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => _OwnerBlockStayDialog(
        apartments: apartments,
        onSaved: () {
          Navigator.of(ctx).pop();
          ref.invalidate(ownerReservationsProvider);
          ref.invalidate(ownerReservationsForPlanningCalendarProvider);
          ref.invalidate(ownerDashboardMetricsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('owner.owner_stay_saved'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        },
      ),
    );
  }

  /// Soft-delete rezervace vlastního pobytu (jen [OwnerReservation.isOwnerStay]).
  Future<void> _confirmDeleteOwnerStay(
    BuildContext context,
    WidgetRef ref,
    OwnerReservation r,
  ) async {
    if (!r.isOwnerStay) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('owner.owner_stay_delete_title'.tr()),
        content: Text('owner.owner_stay_delete_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('owner.owner_stay_delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      await SupabaseService.safeFrom('reservations', tenantId).update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', r.id);
      ref.invalidate(ownerReservationsProvider);
      ref.invalidate(ownerReservationsForPlanningCalendarProvider);
      ref.invalidate(ownerDashboardMetricsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('owner.owner_stay_deleted'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'owner.reservations_save_error'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// FEATURE: Zobrazení rezervací majitele pomocí Kanban boardu (nahrazuje původní kalendář).
/// Sloupce podle stavu: Nové, Potvrzené, Ubytováno, Odhlášeno (včetně zrušených).
class _OwnerReservationsKanbanBoard extends StatelessWidget {
  const _OwnerReservationsKanbanBoard({
    required this.reservations,
    required this.ref,
    required this.onEditReservation,
    required this.onDeleteOwnerStay,
  });

  final List<OwnerReservation> reservations;
  final WidgetRef ref;
  final void Function(OwnerReservation) onEditReservation;
  final void Function(OwnerReservation) onDeleteOwnerStay;

  static const _columns = [
    _ColConfig(displayStatuses: ['new'], labelKey: 'owner.kanban_new'),
    _ColConfig(
      displayStatuses: ['confirmed'],
      labelKey: 'owner.kanban_confirmed',
    ),
    _ColConfig(
      displayStatuses: ['checked_in'],
      labelKey: 'owner.kanban_checked_in',
    ),
    _ColConfig(
      displayStatuses: ['checked_out', 'cancelled'],
      labelKey: 'owner.kanban_checked_out',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight - 120,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _columns.map((col) {
            final columnReservations = reservations
                .where((r) => col.displayStatuses.contains(r.status))
                .toList();
            return SizedBox(
              width: 280,
              height: screenHeight - 160,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        child: Text(
                          col.labelKey.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(
                            left: 8,
                            right: 8,
                            bottom: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: columnReservations
                                .map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _OwnerKanbanCard(
                                      reservation: r,
                                      onEdit: onEditReservation,
                                      onDeleteOwnerStay: onDeleteOwnerStay,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ColConfig {
  const _ColConfig({required this.displayStatuses, required this.labelKey});
  final List<String> displayStatuses;
  final String labelKey;
}

/// Karta rezervace v Kanbanu. FEATURE: Editace povolena pouze při status=='new'.
/// SECURITY: Uzamčení rezervace po předání agentuře (stav 'confirmed').
class _OwnerKanbanCard extends StatelessWidget {
  const _OwnerKanbanCard({
    required this.reservation,
    required this.onEdit,
    required this.onDeleteOwnerStay,
  });

  final OwnerReservation reservation;
  final void Function(OwnerReservation) onEdit;
  final void Function(OwnerReservation) onDeleteOwnerStay;

  static Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'checked_in':
        return Colors.deepPurple;
      case 'checked_out':
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  static String _statusLabelKey(String status) {
    return 'admin.reservation_status_$status';
  }

  static String _formatDateRange(OwnerReservation r) {
    final from =
        '${r.startDate.day.toString().padLeft(2, '0')}.${r.startDate.month.toString().padLeft(2, '0')}.${r.startDate.year}';
    final to =
        '${r.endDate.day.toString().padLeft(2, '0')}.${r.endDate.month.toString().padLeft(2, '0')}.${r.endDate.year}';
    String fromTime = '';
    String toTime = '';
    if (r.arrivalTime != null) {
      final local = r.arrivalTime!.toLocal();
      fromTime =
          ' ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (r.departureTime != null) {
      final local = r.departureTime!.toLocal();
      toTime =
          ' ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '$from$fromTime → $to$toTime';
  }

  @override
  Widget build(BuildContext context) {
    final guestName = (reservation.guestName ?? '').trim().isEmpty
        ? 'owner.unknown_guest'.tr()
        : reservation.guestName!;
    final apartmentName = (reservation.apartmentName ?? '').trim().isEmpty
        ? '–'
        : reservation.apartmentName!;
    final statusColor = _statusColor(reservation.status);
    final canEdit = reservation.status == 'new';

    Widget cardContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
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
              if (reservation.isOwnerStay)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'owner.owner_stay_delete_tooltip'.tr(),
                  onPressed: () => onDeleteOwnerStay(reservation),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              if (!canEdit && !reservation.isOwnerStay) ...[
                const SizedBox(width: 4),
                Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
              ],
            ],
          ),
          if (!canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'owner.managed_by_agency'.tr(),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            reservation.totalGuests > 0
                ? '$apartmentName • ${reservation.totalGuests} ${'owner.kanban_guests'.tr()}'
                : apartmentName,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabelKey(reservation.status).tr(),
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
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      margin: EdgeInsets.zero,
      child: canEdit
          ? InkWell(
              onTap: () => onEdit(reservation),
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            )
          : cardContent,
    );
  }
}

/// Formulář pro novou rezervaci nebo editaci – používá se v Dialogu (vycentrovaný).
/// Při [existingReservation] != null jde o editaci (pouze status=='new').
class _NewReservationForm extends ConsumerStatefulWidget {
  const _NewReservationForm({
    required this.apartments,
    this.existingReservation,
    required this.onSaved,
    required this.onError,
  });

  /// Už načtený seznam bytů majitele – dialog je na Riverpodu nezávislý (žádný ref.watch/ref.read v build).
  final List<OwnerApartmentWithStatus> apartments;
  final OwnerReservation? existingReservation;

  final VoidCallback onSaved;
  final void Function(String error) onError;

  @override
  ConsumerState<_NewReservationForm> createState() =>
      _NewReservationFormState();
}

class _NewReservationFormState extends ConsumerState<_NewReservationForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedApartmentId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _specialRequestsController = TextEditingController();
  final _arrivalTimeController = TextEditingController(text: '15:00');
  final _departureTimeController = TextEditingController(text: '10:00');
  final _guestAdultsController = TextEditingController(text: '0');
  final _guestChildrenController = TextEditingController(text: '0');

  /// UI: Doplnění polí pro jméno a telefon hosta.
  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  bool _isSaving = false;
  bool _servicesLoadedForEdit = false;

  /// Lokální stav služeb – načítáme jednou přes _loadServices (bez Riverpod provideru).
  List<ApartmentServiceOption>? _loadedServiceOptions;
  bool _isLoadingServices = false;

  /// FEATURE: Rozšířený formulář rezervace pro majitele (časy, hosté, služby).
  Map<String, ReservationServiceEditState> _servicesState = {};

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReservation;
    if (existing != null) {
      _selectedApartmentId = existing.apartmentId;
      _dateFrom = existing.startDate;
      _dateTo = existing.endDate;
      _guestNameController.text = existing.guestName ?? '';
      _guestPhoneController.text = existing.guestPhone ?? '';
      _guestAdultsController.text = existing.guestAdults.toString();
      _guestChildrenController.text = existing.guestChildren.toString();
      _specialRequestsController.text = existing.specialRequests ?? '';
      if (existing.arrivalTime != null) {
        final local = existing.arrivalTime!.toLocal();
        _arrivalTimeController.text =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      if (existing.departureTime != null) {
        final local = existing.departureTime!.toLocal();
        _departureTimeController.text =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      _loadServices(existing.apartmentId);
    }
  }

  @override
  void dispose() {
    _specialRequestsController.dispose();
    _arrivalTimeController.dispose();
    _departureTimeController.dispose();
    _guestAdultsController.dispose();
    _guestChildrenController.dispose();
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  /// Ukládá rezervaci do Supabase (reservations + reservation_services).
  ///
  /// Logika:
  /// 1. Kontrola času (express úklid): Pokud je Datum OD dříve než za 24 h,
  ///    zobrazí se dialog s varováním. Uživatel může ukládání zrušit nebo potvrdit.
  /// 2. Zápis do reservations a reservation_services. BUGFIX: Žádný automatický úkol.
  /// 3. Při úspěchu: zavření modalu, invalidace provideru, zelený SnackBar.
  ///    Při chybě: červený SnackBar s výpisem.
  Future<void> _saveReservation({bool confirmAndHandOver = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartmentId == null || _dateFrom == null || _dateTo == null) {
      return;
    }

    // -------------------------------------------------------------------------
    // KROK 1: Kontrola času – Express úklid (< 24 h od teď)
    // -------------------------------------------------------------------------
    final now = DateTime.now();
    final startOfReservation = DateTime(
      _dateFrom!.year,
      _dateFrom!.month,
      _dateFrom!.day,
    );
    final diff = startOfReservation.difference(now);
    final isExpress = !diff.isNegative && diff.inHours < 24;

    if (isExpress) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('owner.reservations_new'.tr()),
          content: Text('owner.express_warning'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('owner.express_dialog_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('owner.express_dialog_confirm'.tr()),
            ),
          ],
        ),
      );
      // Uživatel zavřel dialog nebo zrušil – nic neukládáme
      if (confirmed != true) return;
    }

    // SECURITY: Zablokování zápisu, pokud vybraný byt nepatří majiteli (data předaná z rodiče).
    final ownedIds = widget.apartments
        .map((a) => a.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (_selectedApartmentId == null ||
        !ownedIds.contains(_selectedApartmentId!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('owner.reservations_error_apartment_not_owned'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Nepřihlášený uživatel');
      }

      final dataTenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (dataTenantId == null || dataTenantId.isEmpty) {
        throw Exception('Chybí kontext agentury (tenant)');
      }

      // BUGFIX: Zajištění správného tenant_id z apartmánu, aby rezervace patřila
      // pod agenturu, nikoliv pod auth účet majitele.
      // Bezpečnostní vynucení tenant_id klauzule přes safeFrom (kontext majitele v agentuře).
      final aptRes = await SupabaseService.safeFrom(
        'apartments',
        dataTenantId,
      ).select('tenant_id').eq('id', _selectedApartmentId!).maybeSingle();
      final tenantId = aptRes?['tenant_id']?.toString();
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('Byt nemá přiřazenou agenturu (tenant_id)');
      }

      final specialRequests = _specialRequestsController.text.trim();
      final specialRequestsOrNull = specialRequests.isEmpty
          ? null
          : specialRequests;
      final guestName = _guestNameController.text.trim();
      final guestNameOrNull = guestName.isEmpty ? null : guestName;
      final guestPhone = _guestPhoneController.text.trim();
      final guestPhoneOrNull = guestPhone.isEmpty ? null : guestPhone;
      final guestAdults = int.tryParse(_guestAdultsController.text.trim()) ?? 0;
      final guestChildren =
          int.tryParse(_guestChildrenController.text.trim()) ?? 0;

      // Časy příjezdu/odjezdu – parsování HH:mm, výchozí 15:00 a 10:00
      final arrivalParts = _arrivalTimeController.text.trim().split(':');
      final arrivalH = arrivalParts.length >= 2
          ? (int.tryParse(arrivalParts[0]) ?? 15)
          : 15;
      final arrivalM = arrivalParts.length >= 2
          ? (int.tryParse(arrivalParts[1]) ?? 0)
          : 0;
      final arrivalTimeUtc = DateTime(
        _dateFrom!.year,
        _dateFrom!.month,
        _dateFrom!.day,
        arrivalH,
        arrivalM,
        0,
      ).toUtc();
      final depParts = _departureTimeController.text.trim().split(':');
      final depH = depParts.length >= 2
          ? (int.tryParse(depParts[0]) ?? 10)
          : 10;
      final depM = depParts.length >= 2 ? (int.tryParse(depParts[1]) ?? 0) : 0;
      final departureTimeUtc = DateTime(
        _dateTo!.year,
        _dateTo!.month,
        _dateTo!.day,
        depH,
        depM,
        0,
      ).toUtc();

      // -----------------------------------------------------------------------
      // KROK 2a: Zápis rezervace do tabulky reservations (insert nebo update)
      // SECURITY: Při update posíláme pouze pole, která majitel vidí a smí měnit.
      // BUGFIX: Oprava scope pro ID rezervace při ukládání (rozdělení pro insert a update).
      // -----------------------------------------------------------------------
      final existing = widget.existingReservation;
      String
      reservationId; // cílové ID: u update = existing.id, u insert = vrácené id z DB
      if (existing != null) {
        reservationId = existing.id;
        final updatePayload = <String, dynamic>{
          'apartment_id': _selectedApartmentId,
          'start_date': _formatDate(_dateFrom!),
          'end_date': _formatDate(_dateTo!),
          'guest_name': guestNameOrNull,
          'guest_phone': guestPhoneOrNull,
          'special_requests': specialRequestsOrNull,
          'guest_adults': guestAdults,
          'guest_children': guestChildren,
          'arrival_time': arrivalTimeUtc.toIso8601String(),
          'departure_time': departureTimeUtc.toIso8601String(),
        };
        if (confirmAndHandOver) {
          updatePayload['status'] = 'confirmed';
        }
        await SupabaseService.safeFrom(
          'reservations',
          tenantId,
        ).update(updatePayload).eq('id', reservationId);
      } else {
        final res = await SupabaseService.safeFrom('reservations', tenantId)
            .insert(
              SupabaseService.safeInsertPayload(tenantId, {
                'apartment_id': _selectedApartmentId,
                'reference_number': generateReservationRef(),
                'start_date': _formatDate(_dateFrom!),
                'end_date': _formatDate(_dateTo!),
                'guest_name': guestNameOrNull,
                'guest_phone': guestPhoneOrNull,
                'special_requests': specialRequestsOrNull,
                'guest_adults': guestAdults,
                'guest_children': guestChildren,
                'arrival_time': arrivalTimeUtc.toIso8601String(),
                'departure_time': departureTimeUtc.toIso8601String(),
                'status': 'new',
              }),
            )
            .select('id')
            .single();
        reservationId = res['id'] as String? ?? '';
        if (reservationId.isEmpty) {
          throw Exception('Insert reservations nevrátil id');
        }
      }

      // -----------------------------------------------------------------------
      // KROK 2a2: Uložení služeb rezervace (reservation_services)
      // -----------------------------------------------------------------------
      await saveForReservation(
        reservationId: reservationId,
        tenantId: tenantId,
        states: _servicesState,
      );
      await ensureMandatoryServicesForReservation(
        reservationId: reservationId,
        tenantId: tenantId,
        apartmentId: _selectedApartmentId!,
      );

      // BUGFIX: Odstraněno automatické generování prázdného úkolu.
      // Majitelská rezervace ukládá pouze záznam do reservations a reservation_services.

      if (!mounted) return;
      widget.onSaved();
    } on PostgrestException catch (e) {
      if (mounted) widget.onError(e.message);
    } catch (e) {
      if (mounted) widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _initServicesState(List<ApartmentServiceOption> options) {
    if (_servicesState.isNotEmpty) return;
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
            flightNumber: null,
            payerType: o.payerType,
          ),
      };
    });
  }

  /// Načte služby pro daný byt napřímo (bez Riverpod provideru) a uloží do _loadedServiceOptions.
  /// Volá se z initState (editace) a z onChanged dropdownu (nová rezervace).
  Future<void> _loadServices(String apartmentId) async {
    if (apartmentId.isEmpty) return;
    setState(() => _isLoadingServices = true);
    try {
      final dataTenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (dataTenantId == null || dataTenantId.isEmpty) {
        if (mounted) setState(() => _isLoadingServices = false);
        return;
      }
      final aptRes = await SupabaseService.safeFrom(
        'apartments',
        dataTenantId,
      ).select('tenant_id').eq('id', apartmentId).maybeSingle();
      final tenantId = aptRes?['tenant_id']?.toString();
      if (tenantId == null || tenantId.isEmpty) {
        if (mounted) setState(() => _isLoadingServices = false);
        return;
      }
      final tenantServices = await TenantServicesRepository.fetchList(tenantId);
      final rows = await fetchByApartmentId(apartmentId, tenantId);
      final serviceById = {for (final s in tenantServices) s.id: s};
      final options = rows.map((r) {
        final ts = serviceById[r.serviceId];
        final name = ts?.name ?? 'Služba';
        final defaultPrice =
            r.customPrice?.toDouble() ?? ts?.defaultPrice?.toDouble() ?? 0.0;
        final durationMinutes = ts?.durationMinutes ?? 0;
        return ApartmentServiceOption(
          apartmentServiceId: r.id,
          serviceId: r.serviceId,
          serviceName: name,
          defaultPriceEur: defaultPrice,
          serviceType: ts?.serviceType.trim().toLowerCase() ?? 'extra',
          isMandatory: r.isMandatory,
          payerType: r.payerType,
          durationMinutes: durationMinutes,
          requiresPhotoFromApartment: r.requiresPhoto,
          requiresPhotoFromCatalog: ts?.requiresPhoto ?? false,
          triggerType: r.triggerType,
          checklistTemplateId: r.checklistTemplateId,
        );
      }).toList();
      options.sort((a, b) {
        final orderA = serviceById[a.serviceId]?.orderIndex ?? 0;
        final orderB = serviceById[b.serviceId]?.orderIndex ?? 0;
        return orderA.compareTo(orderB);
      });
      if (mounted) {
        setState(() {
          _loadedServiceOptions = options;
          _isLoadingServices = false;
        });
        _initServicesState(options);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
      // ignore: avoid_print
      print('Chyba při načítání služeb: $e');
    }
  }

  /// Načte stav služeb z existující rezervace a sloučí s options (pro editaci).
  /// Pro teď nepoužito – editace zobrazuje výchozí stav služeb (jako nová rezervace), aby nedošlo k rebuild smyčce.
  /// Pro budoucí použití: až se reservation_services načtou před otevřením dialogu (např. v OwnerReservation).
  // ignore: unused_element
  Future<void> _initServicesStateFromExisting(
    List<ApartmentServiceOption> options,
    String reservationId,
    String apartmentId,
  ) async {
    if (_servicesLoadedForEdit) return;
    final dataTenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (dataTenantId == null || dataTenantId.isEmpty) return;
    final aptRes = await SupabaseService.safeFrom(
      'apartments',
      dataTenantId,
    ).select('tenant_id').eq('id', apartmentId).maybeSingle();
    final tenantId = aptRes?['tenant_id']?.toString();
    if (tenantId == null || tenantId.isEmpty) return;
    final existingServices = await fetchByReservationId(
      reservationId,
      tenantId,
    );
    final byApartmentServiceId = {
      for (final s in existingServices) s.apartmentServiceId: s,
    };
    if (!mounted) return;
    setState(() {
      _servicesLoadedForEdit = true;
      _servicesState = {
        for (final o in options)
          o.apartmentServiceId: () {
            final existing = byApartmentServiceId[o.apartmentServiceId];
            if (existing != null) {
              final flight =
                  existing.flightNumber ??
                  (parseFlightFromCustomNote(existing.customNote).$1);
              final noteRest =
                  existing.flightNumber != null &&
                      existing.flightNumber!.isNotEmpty
                  ? existing.customNote
                  : (parseFlightFromCustomNote(existing.customNote).$2);
              return ReservationServiceEditState(
                apartmentServiceId: o.apartmentServiceId,
                serviceName: o.serviceName,
                defaultPriceEur: o.defaultPriceEur,
                enabled: true,
                chargedPriceEur:
                    existing.chargedPrice?.toDouble() ?? o.defaultPriceEur,
                customNote: noteRest,
                flightNumber: flight,
                payerType:
                    (existing.payerType == 'owner' ||
                        existing.payerType == 'guest')
                    ? existing.payerType!
                    : o.payerType,
              );
            }
            return ReservationServiceEditState(
              apartmentServiceId: o.apartmentServiceId,
              serviceName: o.serviceName,
              defaultPriceEur: o.defaultPriceEur,
              enabled: o.isMandatory,
              chargedPriceEur: o.defaultPriceEur,
              customNote: null,
              flightNumber: null,
              payerType: o.payerType,
            );
          }(),
      };
    });
  }

  /// Dropdown pro výběr bytu – používá pouze widget.apartments (žádný ref v build).
  Widget _buildApartmentDropdown() {
    if (widget.apartments.isEmpty) {
      return Text(
        'owner.apartments_empty'.tr(),
        style: TextStyle(color: Colors.grey.shade700),
      );
    }
    final safeValue = widget.apartments.any((a) => a.id == _selectedApartmentId)
        ? _selectedApartmentId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: 'owner.reservations_apartment_hint'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: widget.apartments
          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _selectedApartmentId = v;
          _servicesState = {};
          _loadedServiceOptions = null;
        });
        _loadServices(v);
      },
      validator: (v) =>
          v == null ? 'owner.validation_apartment_required'.tr() : null,
    );
  }

  /// Vykreslí sekci Služby podle lokálního stavu (_loadedServiceOptions, _isLoadingServices).
  Widget _buildServicesSection(String apartmentId) {
    if (apartmentId.isEmpty) {
      return Text(
        'owner.reservations_select_apartment_first'.tr(),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }
    if (_isLoadingServices) {
      return const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_loadedServiceOptions == null || _loadedServiceOptions!.isEmpty) {
      return Text(
        'owner.reservations_services_empty'.tr(),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );
    }
    final options = _loadedServiceOptions!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((o) {
        final state =
            _servicesState[o.apartmentServiceId] ??
            ReservationServiceEditState(
              apartmentServiceId: o.apartmentServiceId,
              serviceName: o.serviceName,
              defaultPriceEur: o.defaultPriceEur,
              enabled: o.isMandatory,
              chargedPriceEur: o.defaultPriceEur,
              customNote: null,
              flightNumber: null,
              payerType: o.payerType,
            );
        final effectiveEnabled = state.enabled || o.isMandatory;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              value: effectiveEnabled,
              onChanged: o.isMandatory
                  ? null
                  : (v) {
                      setState(() {
                        _servicesState[o.apartmentServiceId] = state.copyWith(
                          enabled: v ?? false,
                        );
                      });
                    },
              title: Text(o.serviceName),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (effectiveEnabled)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue:
                          (state.payerType == 'owner' ||
                              state.payerType == 'guest')
                          ? state.payerType
                          : 'owner',
                      decoration: InputDecoration(
                        labelText: 'owner.payer_type_label'.tr(),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text('owner.payer_owner'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'guest',
                          child: Text('owner.payer_guest'.tr()),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _servicesState[o.apartmentServiceId] = state
                                .copyWith(payerType: v);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: state.customNote ?? '',
                      decoration: InputDecoration(
                        labelText: 'owner.reservations_field_custom_note'.tr(),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 1,
                      onChanged: (v) {
                        setState(() {
                          _servicesState[o.apartmentServiceId] = state.copyWith(
                            customNote: v.isEmpty ? null : v,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentId = _selectedApartmentId ?? '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingReservation != null
                    ? 'owner.reservations_edit'.tr()
                    : 'owner.reservations_new'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _buildApartmentDropdown(),
              const SizedBox(height: 16),
              ListTile(
                title: Text('owner.reservations_date_from'.tr()),
                subtitle: Text(
                  _dateFrom != null
                      ? _formatDate(_dateFrom!)
                      : 'admin.date_pick_hint'.tr(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateFrom ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => _dateFrom = picked);
                },
              ),
              ListTile(
                title: Text('owner.reservations_date_to'.tr()),
                subtitle: Text(
                  _dateTo != null
                      ? _formatDate(_dateTo!)
                      : 'admin.date_pick_hint'.tr(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
                    firstDate: _dateFrom ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => _dateTo = picked);
                },
              ),
              const SizedBox(height: 16),
              // UI: Doplnění polí pro jméno a telefon hosta.
              TextFormField(
                controller: _guestNameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  labelText: 'owner.reservations_field_guest_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestPhoneController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined),
                  labelText: 'owner.reservations_field_guest_phone'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              // UI: Vizuální vykreslení rozšířených polí pro majitele (časy, hosté, služby) dle vzoru z administrace.
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'admin.reservations_section_when'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
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
                        labelText: 'owner.reservations_field_arrival_time'.tr(),
                        hintText: 'HH:mm',
                        border: const OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final parts = _arrivalTimeController.text.trim().split(
                          ':',
                        );
                        TimeOfDay initial = const TimeOfDay(
                          hour: 15,
                          minute: 0,
                        );
                        if (parts.length >= 2) {
                          initial = TimeOfDay(
                            hour: int.tryParse(parts[0]) ?? 15,
                            minute: int.tryParse(parts[1]) ?? 0,
                          );
                        }
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _arrivalTimeController.text =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _departureTimeController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.access_time_outlined),
                        labelText: 'owner.reservations_field_departure_time'
                            .tr(),
                        hintText: 'HH:mm',
                        border: const OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final parts = _departureTimeController.text
                            .trim()
                            .split(':');
                        TimeOfDay initial = const TimeOfDay(
                          hour: 10,
                          minute: 0,
                        );
                        if (parts.length >= 2) {
                          initial = TimeOfDay(
                            hour: int.tryParse(parts[0]) ?? 10,
                            minute: int.tryParse(parts[1]) ?? 0,
                          );
                        }
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial,
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _departureTimeController.text =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'owner.reservations_section_guests'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // UI: Rozšířená pole rezervačního formuláře – vizuální čítače (+/-) pro hosty.
              Row(
                children: [
                  Expanded(
                    child: _GuestCounter(
                      label: 'owner.reservations_field_guest_adults'.tr(),
                      icon: Icons.people_alt_outlined,
                      value:
                          int.tryParse(_guestAdultsController.text.trim()) ?? 0,
                      onChanged: (v) {
                        _guestAdultsController.text = v.toString();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GuestCounter(
                      label: 'owner.reservations_field_guest_children'.tr(),
                      icon: Icons.child_care_outlined,
                      value:
                          int.tryParse(_guestChildrenController.text.trim()) ??
                          0,
                      onChanged: (v) {
                        _guestChildrenController.text = v.toString();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'owner.reservations_section_services'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildServicesSection(apartmentId),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specialRequestsController,
                decoration: InputDecoration(
                  labelText: 'owner.reservations_special_requests'.tr(),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (widget.existingReservation != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : () => _confirmAndHandOver(),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: Text('owner.confirm_and_hand_over'.tr()),
                  ),
                ),
              FilledButton(
                onPressed: _isSaving ? null : () => _validateAndSave(),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('owner.reservations_save'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Uloží změny a nastaví status na 'confirmed' – předání agentuře.
  Future<void> _confirmAndHandOver() async {
    await _saveReservation(confirmAndHandOver: true);
  }

  void _validateAndSave() {
    if (_dateTo != null && _dateFrom != null && _dateTo!.isBefore(_dateFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.validation_date_to_before_from'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_dateFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.validation_date_from_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.validation_date_to_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _saveReservation();
  }
}

/// UI: Čítač hostů s tlačítky +/- pro rychlou změnu hodnoty.
class _GuestCounter extends StatelessWidget {
  const _GuestCounter({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                    backgroundColor: value > 0 ? null : Colors.grey.shade300,
                  ),
                  onPressed: value > 0 ? () => onChanged(value - 1) : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const SizedBox(width: 16),
                Text(
                  value.toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                  onPressed: () => onChanged(value + 1),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog pro zablokování termínu „vlastní pobyt“ – insert do [reservations] s [metadata.is_owner_stay].
class _OwnerBlockStayDialog extends ConsumerStatefulWidget {
  const _OwnerBlockStayDialog({
    required this.apartments,
    required this.onSaved,
    required this.onError,
  });

  final List<OwnerApartmentWithStatus> apartments;
  final VoidCallback onSaved;
  final void Function(String message) onError;

  @override
  ConsumerState<_OwnerBlockStayDialog> createState() =>
      _OwnerBlockStayDialogState();
}

class _OwnerBlockStayDialogState extends ConsumerState<_OwnerBlockStayDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _apartmentId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.apartments.length == 1) {
      _apartmentId = widget.apartments.first.id;
    }
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final initial = _dateFrom ?? now;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: initial,
    );
    if (d != null) setState(() => _dateFrom = d);
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final initial = _dateTo ?? _dateFrom ?? now;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: initial,
    );
    if (d != null) setState(() => _dateTo = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_apartmentId == null || _dateFrom == null || _dateTo == null) {
      widget.onError('owner.owner_stay_validation_incomplete'.tr());
      return;
    }
    final from = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
    final to = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day);
    if (to.isBefore(from)) {
      widget.onError('owner.validation_date_to_before_from'.tr());
      return;
    }
    setState(() => _saving = true);
    try {
      final dataTenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (dataTenantId == null || dataTenantId.isEmpty) {
        throw Exception('tenant');
      }
      final aptRes = await SupabaseService.safeFrom(
        'apartments',
        dataTenantId,
      ).select('tenant_id').eq('id', _apartmentId!).maybeSingle();
      final tenantId = aptRes?['tenant_id']?.toString();
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('apartment tenant');
      }

      final arrivalTimeUtc = DateTime(
        from.year,
        from.month,
        from.day,
        15,
        0,
      ).toUtc();
      final departureTimeUtc = DateTime(
        to.year,
        to.month,
        to.day,
        10,
        0,
      ).toUtc();

      await SupabaseService.safeFrom('reservations', tenantId).insert(
        SupabaseService.safeInsertPayload(tenantId, {
          'apartment_id': _apartmentId,
          'reference_number': generateReservationRef(),
          'start_date': DateFormat('yyyy-MM-dd').format(from),
          'end_date': DateFormat('yyyy-MM-dd').format(to),
          'guest_name': kOwnerStayGuestNameDb,
          'guest_adults': 1,
          'guest_children': 0,
          'status': 'confirmed',
          'metadata': <String, dynamic>{'is_owner_stay': true},
          'arrival_time': arrivalTimeUtc.toIso8601String(),
          'departure_time': departureTimeUtc.toIso8601String(),
        }),
      );
      widget.onSaved();
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd(context.locale.toString());
    return AlertDialog(
      title: Text('owner.owner_stay_dialog_title'.tr()),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormField<String>(
                initialValue: _apartmentId,
                validator: (v) => v == null || v.isEmpty
                    ? 'owner.reservations_select_apartment_first'.tr()
                    : null,
                builder: (state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'owner.report_issue_apartment_hint'.tr(),
                          border: const OutlineInputBorder(),
                          errorText: state.errorText,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: state.value,
                            items: widget.apartments
                                .map(
                                  (a) => DropdownMenuItem<String>(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              state.didChange(v);
                              setState(() => _apartmentId = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('owner.reservations_date_from'.tr()),
                subtitle: Text(
                  _dateFrom != null ? df.format(_dateFrom!) : '–',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _saving ? null : _pickFrom,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('owner.reservations_date_to'.tr()),
                subtitle: Text(_dateTo != null ? df.format(_dateTo!) : '–'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: _saving ? null : _pickTo,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('owner.owner_stay_save'.tr()),
        ),
      ],
    );
  }
}
