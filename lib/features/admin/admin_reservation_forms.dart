import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/admin_reservation_utils.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_services_options_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';

/// Dialog pro přidání nové rezervace. [initialApartmentId] a [initialCheckIn] předvyplní formulář (např. z Plachty).
class AddReservationDialog extends ConsumerStatefulWidget {
  const AddReservationDialog({
    super.key,
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
  ConsumerState<AddReservationDialog> createState() =>
      _AddReservationDialogState();
}

class _AddReservationDialogState extends ConsumerState<AddReservationDialog> {
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
      final start = parseReservationDateTime(widget.initialCheckIn!.trim());
      if (start != null) {
        _dateRange = DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(start.year, start.month, start.day).add(const Duration(days: 1)),
        );
        _stayPeriodController.text = formatReservationDateRangeDisplay(_dateRange!);
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
          await widget.ref.read(adminReservationsProvider.future);
      final apartments = await widget.ref.read(apartmentsProvider.future);
      final apartmentList = apartments
          .where((a) => a.id == _selectedApartmentId)
          .toList();
      final apartment =
          apartmentList.isEmpty ? null : apartmentList.first;
      // Sčítáme základní čas úklidu bytu a extra čas přikoupených služeb – pro přesnou kontrolu kolizí.
      final options =
          await widget.ref.read(apartmentServicesOptionsProvider(_selectedApartmentId!).future);
      int extraServiceMinutes = 0;
      for (final opt in options) {
        final state = _servicesState[opt.apartmentServiceId];
        if (state != null && state.enabled) {
          extraServiceMinutes += opt.durationMinutes;
        }
      }
      final totalCleaningDuration =
          (apartment?.standardCleaningDuration ?? 120) + extraServiceMinutes;

      checkReservationCollision(
        existingReservations: reservations,
        apartmentId: _selectedApartmentId!,
        standardCleaningDuration: totalCleaningDuration,
        newCheckIn: newCheckIn,
        newCheckOut: newCheckOut,
      );

      final tenantId = widget.ref.read(authNotifierProvider).tenantIdForData;
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

      // Pokud není čas vyplněn, použijeme standardní hotelové časy 15:00 a 10:00.
      // Do payloadu nesmí jít null – generátor úkolů očekává platné timestamptz.
      if (arrivalTimeUtc == null) {
        arrivalTimeUtc = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day, 15, 0, 0).toUtc();
      }
      if (departureTimeUtc == null) {
        departureTimeUtc = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day, 10, 0, 0).toUtc();
      }

      // Dvoukrokové ukládání (Override Pattern Tier 3): nejdřív záznam v reservations,
      // potom služby rezervace v reservation_services (závisí na reservation_id).
      // KROK 1: Vložení rezervace a získání nového id (pro reservation_services).
      final payload = <String, dynamic>{
        'tenant_id': tenantId,
        'apartment_id': _selectedApartmentId,
        'start_date': startDate,
        'end_date': endDate,
        'status': 'new',
        'guest_name': _guestNameController.text.trim().isEmpty
            ? null
            : _guestNameController.text.trim(),
        'guest_phone': _guestPhoneController.text.trim().isEmpty
            ? null
            : _guestPhoneController.text.trim(),
        'reservation_source': _reservationSource,
        'guest_adults': guestAdults,
        'guest_children': guestChildren,
        'arrival_time': arrivalTimeUtc.toIso8601String(),
        'departure_time': departureTimeUtc.toIso8601String(),
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
      showReservationCollisionDialog(
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
    final apartmentsAsync = widget.ref.watch(apartmentsProvider);

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
                _stayPeriodController.text = formatReservationDateRangeDisplay(range);
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
    final optionsAsync = widget.ref.watch(apartmentServicesOptionsProvider(apartmentId));
    final preferredCurrency = widget.ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = widget.ref.watch(currenciesProvider).valueOrNull ?? [];

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
class RelatedTasksList extends StatelessWidget {
  const RelatedTasksList({
    super.key,
    required this.reservation,
    required this.tasksAsync,
  });

  final ReservationRow reservation;
  final AsyncValue<List<TaskRow>> tasksAsync;

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      data: (tasks) {
        final checkInDt = parseReservationCheckIn(reservation.checkIn);
        final checkOutDt = parseReservationCheckOut(reservation.checkOut);
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
                        reservationTaskTypeIcon(t.taskType),
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          reservationTaskTypeEmoji(t.taskType),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          reservationTaskTypeLabelKey(t.taskType).tr(),
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
                      backgroundColor: reservationTaskStatusChipColor(t.status),
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
class EditReservationDialog extends ConsumerStatefulWidget {
  const EditReservationDialog({
    super.key,
    required this.ref,
    required this.reservation,
    required this.onSaved,
  });

  final WidgetRef ref;
  final ReservationRow reservation;
  final VoidCallback onSaved;

  @override
  ConsumerState<EditReservationDialog> createState() =>
      _EditReservationDialogState();
}

class _EditReservationDialogState extends ConsumerState<EditReservationDialog> {
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
    final startDt = parseReservationDateTime(r.checkIn);
    final endDt = parseReservationDateTime(r.checkOut);
    if (startDt != null && endDt != null) {
      _dateRange = DateTimeRange(
        start: DateTime(startDt.year, startDt.month, startDt.day),
        end: DateTime(endDt.year, endDt.month, endDt.day),
      );
      _stayPeriodController.text = formatReservationDateRangeDisplay(_dateRange!);
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

    // Kontrola změny termínu: pokud se změnil check-in nebo check-out, smažeme návrhy úkolů
    final origStart = parseReservationDateTime(widget.reservation.checkIn);
    final origEnd = parseReservationDateTime(widget.reservation.checkOut);
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
          .eq('status', 'Návrh')
          .eq('tenant_id', tenantId);
      ref.invalidate(adminTasksProvider);
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
          await ref.read(apartmentServicesOptionsProvider(_selectedApartmentId).future);
      int extraServiceMinutes = 0;
      for (final opt in options) {
        final state = _servicesState[opt.apartmentServiceId];
        if (state != null && state.enabled) {
          extraServiceMinutes += opt.durationMinutes;
        }
      }
      final totalCleaningDuration =
          (apartment?.standardCleaningDuration ?? 120) + extraServiceMinutes;

      checkReservationCollision(
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
      }).eq('id', widget.reservation.id).eq('tenant_id', tenantId);

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
      showReservationCollisionDialog(
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
                _stayPeriodController.text = formatReservationDateRangeDisplay(range);
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
        RelatedTasksList(
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
