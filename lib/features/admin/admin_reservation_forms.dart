import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/constants/app_languages.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/admin_reservation_utils.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_services_options_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/widgets/admin_entity_cross_links.dart';
import 'package:falconest/features/admin/widgets/reservation_cash_transit_admin_card.dart';
import 'package:falconest/features/admin/widgets/reservation_communication_history_section.dart';
import 'package:falconest/features/admin/widgets/reservation_service_row_widget.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/features/communication/models/message_template_selector_context.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/features/communication/services/whatsapp_sender_service.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';

/// Zda je typ služby transfer – pro zobrazení pole Číslo letu v rezervaci.
bool _isTransferServiceType(String? type) {
  if (type == null || type.trim().isEmpty) return false;
  return [
    'transfer_in',
    'transfer_out',
    'transfer',
  ].contains(type.trim().toLowerCase());
}

/// Barva textu na barevném chipu podle luminance pozadí.
///
/// PROČ: Nahrazuje hardcoded `Colors.white` u [reservationTaskStatusChipColor] tak,
/// aby byl dostatečný kontrast i při změně palety (M3 / dark mode).
Color _chipLabelOnBackground(Color background, BuildContext context) {
  return background.computeLuminance() > 0.5
      ? context.colors.onSurface
      : context.colors.surface;
}

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

class _AddReservationDialogState extends ConsumerState<AddReservationDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _guestNameController;
  late final TextEditingController _guestPhoneController;
  late final TextEditingController _guestEmailController;
  late final TextEditingController _guestAdultsController;
  late final TextEditingController _guestChildrenController;
  late final TextEditingController _arrivalTimeController;
  late final TextEditingController _departureTimeController;

  /// Zobrazovaný text období pobytu ve formátu DD.MM.YYYY - DD.MM.YYYY (stejný vzhled jako ostatní pole).
  late final TextEditingController _stayPeriodController;
  late final TextEditingController _internalNoteController;
  /// PROČ: `special_requests` z DB – host / worker je potřebuje vidět; dříve Admin formulář pole neměl.
  late final TextEditingController _specialRequestsController;

  /// Spojený výběr období pobytu (jeden rozsah místo dvou polí Check-in/Check-out).
  DateTimeRange? _dateRange;

  /// Zdroj rezervace: Booking, Airbnb, Direct, Other (pro dropdown).
  String _reservationSource = 'Other';
  late String? _selectedApartmentId;
  bool _isSaving = false;

  /// Progressive Save: po prvním uložení (při přepnutí na záložku Služby) má rezervace ID – tab 2 pak načte reservation_services.
  String? _savedReservationId;

  /// Explicitní TabController – umožňuje odchytit onTap a programaticky přepnout po uložení.
  late TabController _tabController;

  /// Tab 2: stav služeb; naplní se až po _savedReservationId z _loadServicesStateForSavedReservation.
  Map<String, ReservationServiceEditState> _servicesState = {};
  bool _servicesLoaded = false;

  /// PROČ: Zabrání vícenásobnému spuštění loadu (build by jinak mohl spamovat DB).
  bool _servicesLoadInProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _guestNameController = TextEditingController();
    _guestPhoneController = TextEditingController();
    _guestEmailController = TextEditingController();
    _guestAdultsController = TextEditingController(text: '0');
    _guestChildrenController = TextEditingController(text: '0');
    _arrivalTimeController = TextEditingController();
    _departureTimeController = TextEditingController();
    _stayPeriodController = TextEditingController();
    _internalNoteController = TextEditingController();
    _specialRequestsController = TextEditingController();
    _selectedApartmentId = widget.initialApartmentId;
    // Předvyplnění období z Plachty: initialCheckIn (DD.MM.YYYY) -> start; konec +1 den jako výchozí.
    if (widget.initialCheckIn != null &&
        widget.initialCheckIn!.trim().isNotEmpty) {
      final start = parseReservationDateTime(widget.initialCheckIn!.trim());
      if (start != null) {
        _dateRange = DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(
            start.year,
            start.month,
            start.day,
          ).add(const Duration(days: 1)),
        );
        _stayPeriodController.text = formatReservationDateRangeDisplay(
          _dateRange!,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _guestEmailController.dispose();
    _guestAdultsController.dispose();
    _guestChildrenController.dispose();
    _arrivalTimeController.dispose();
    _departureTimeController.dispose();
    _stayPeriodController.dispose();
    _internalNoteController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  /// Načte služby uložené rezervace (reservation_services) a sloučí s nabídkou bytu do _servicesState.
  /// Volá se z Tabu 2 po Progressive Save, když už máme _savedReservationId.
  /// PROČ try/catch/finally: Při výjimce nebo timeoutu musí finally vždy nastavit _servicesLoaded = true,
  /// aby se kolečko přestalo točit a dispečer mohl služby doplnit ručně (fallback formulář).
  Future<void> _loadServicesStateForSavedReservation(
    List<ApartmentServiceOption> options,
  ) async {
    if (mounted) setState(() => _servicesLoadInProgress = true);
    try {
      final tenantId = widget.ref.read(
        authNotifierProvider.select((s) => s.tenantIdForData),
      );
      if (tenantId == null || tenantId.isEmpty || _savedReservationId == null) {
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
                flightNumber: null,
                payerType: o.payerType,
                requiresPhoto: null,
              ),
          };
          _servicesLoaded = true;
          _servicesLoadInProgress = false;
        });
        return;
      }
      const loadTimeout = Duration(seconds: 10);
      final rows = await fetchByReservationId(
        _savedReservationId!,
        tenantId,
      ).timeout(loadTimeout, onTimeout: () => <ReservationServiceRow>[]);
      final byApartmentServiceId = {
        for (final row in rows) row.apartmentServiceId: row,
      };
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
                  flightNumber: null,
                  payerType: o.payerType,
                  requiresPhoto: null,
                );
              }
              final payerType =
                  (row.payerType == 'owner' || row.payerType == 'guest')
                  ? row.payerType!
                  : o.payerType;
              final (parsedFlight, parsedNoteRest) = parseFlightFromCustomNote(
                row.customNote,
              );
              final flight = row.flightNumber ?? parsedFlight;
              final noteRest =
                  row.flightNumber != null && row.flightNumber!.isNotEmpty
                  ? row.customNote
                  : parsedNoteRest;
              return ReservationServiceEditState(
                apartmentServiceId: o.apartmentServiceId,
                serviceName: o.serviceName,
                defaultPriceEur: o.defaultPriceEur,
                enabled: true,
                chargedPriceEur: row.chargedPrice?.toDouble(),
                transitCashToCollectEur: row.transitCashToCollect?.toDouble(),
                customNote: noteRest,
                flightNumber: flight,
                payerType: payerType,
                requiresPhoto: row.requiresPhoto,
              );
            }(),
        };
        _servicesLoaded = true;
      });
    } catch (e, st) {
      debugPrint('_loadServicesStateForSavedReservation ERROR: $e');
      debugPrint('_loadServicesStateForSavedReservation STACK: $st');
    } finally {
      if (mounted) {
        setState(() {
          _servicesLoaded = true;
          _servicesLoadInProgress = false;
        });
      }
    }
  }

  /// Provede validaci, vložení rezervace a uložení služeb. Vrací newId při úspěchu, null při chybě (chyby zobrazí SnackBar).
  /// Používá se z _onSave (pak se zavře dialog) i z _saveAndThenGoToTab1 (pak se přepne na záložku Služby).
  Future<String?> _performInsertReservation() async {
    if (!_formKey.currentState!.validate()) return null;
    if (_isSaving) return null;
    if (_selectedApartmentId == null || _selectedApartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_check_in_out'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
    final startDate =
        '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')}';
    final endDate =
        '${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}';

    final arrivalParts = _arrivalTimeController.text.trim().split(':');
    final arrivalH = arrivalParts.length >= 2
        ? (int.tryParse(arrivalParts[0]) ?? 15)
        : 15;
    final arrivalM = arrivalParts.length >= 2
        ? (int.tryParse(arrivalParts[1]) ?? 0)
        : 0;
    final newCheckIn = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
      arrivalH,
      arrivalM,
      0,
    );
    final depParts = _departureTimeController.text.trim().split(':');
    final depH = depParts.length >= 2 ? (int.tryParse(depParts[0]) ?? 10) : 10;
    final depM = depParts.length >= 2 ? (int.tryParse(depParts[1]) ?? 0) : 0;
    final newCheckOut = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      depH,
      depM,
      0,
    );

    if (newCheckOut.isBefore(newCheckIn) ||
        newCheckOut.isAtSameMomentAs(newCheckIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.reservations_validation_departure_after_arrival'.tr(),
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final reservations = await widget.ref.read(
        adminReservationsProvider.future,
      );
      final apartments = await widget.ref.read(
        apartmentsFullListProvider.future,
      );
      final apartmentList = apartments
          .where((a) => a.id == _selectedApartmentId)
          .toList();
      final apartment = apartmentList.isEmpty ? null : apartmentList.first;
      final options = await widget.ref.read(
        apartmentServicesOptionsProvider(_selectedApartmentId!).future,
      );
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
        throw Exception(
          'CRITICAL: apartment_id is null or empty before insert!',
        );
      }

      final guestAdults = int.tryParse(_guestAdultsController.text.trim()) ?? 0;
      final guestChildren =
          int.tryParse(_guestChildrenController.text.trim()) ?? 0;
      DateTime? arrivalTimeUtc;
      final arrivalStr = _arrivalTimeController.text.trim();
      if (arrivalStr.isNotEmpty) {
        final parts = arrivalStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          arrivalTimeUtc = DateTime(
            _dateRange!.start.year,
            _dateRange!.start.month,
            _dateRange!.start.day,
            h,
            m,
            0,
          ).toUtc();
        }
      }
      DateTime? departureTimeUtc;
      final depStr = _departureTimeController.text.trim();
      if (depStr.isNotEmpty) {
        final parts = depStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          departureTimeUtc = DateTime(
            _dateRange!.end.year,
            _dateRange!.end.month,
            _dateRange!.end.day,
            h,
            m,
            0,
          ).toUtc();
        }
      }
      arrivalTimeUtc ??= DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
        15,
        0,
        0,
      ).toUtc();
      departureTimeUtc ??= DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        10,
        0,
        0,
      ).toUtc();

      final payload = <String, dynamic>{
        'tenant_id': tenantId,
        'apartment_id': _selectedApartmentId,
        'reference_number': generateReservationRef(),
        'start_date': startDate,
        'end_date': endDate,
        'status': 'new',
        'guest_name': _guestNameController.text.trim().isEmpty
            ? null
            : _guestNameController.text.trim(),
        'guest_phone': _guestPhoneController.text.trim().isEmpty
            ? null
            : _guestPhoneController.text.trim(),
        'guest_email': _guestEmailController.text.trim().isEmpty
            ? null
            : _guestEmailController.text.trim(),
        'reservation_source': _reservationSource,
        'guest_adults': guestAdults,
        'guest_children': guestChildren,
        'arrival_time': arrivalTimeUtc.toIso8601String(),
        'departure_time': departureTimeUtc.toIso8601String(),
        'internal_note': _internalNoteController.text.trim().isEmpty
            ? null
            : _internalNoteController.text.trim(),
        'special_requests': _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
      };

      final res = await SupabaseService.safeFrom(
        'reservations',
        tenantId,
      ).insert(payload).select('id').single();
      final newId = res['id'] as String?;
      if (newId == null || newId.isEmpty) {
        throw Exception('Insert reservations nevrátil id');
      }

      await saveForReservation(
        reservationId: newId,
        tenantId: tenantId,
        states: _servicesState,
      );
      await ensureMandatoryServicesForReservation(
        reservationId: newId,
        tenantId: tenantId,
        apartmentId: _selectedApartmentId!,
      );
      return newId;
    } on ReservationCollisionException catch (e) {
      if (!mounted) return null;
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
      return null;
    } on PostgrestException catch (e) {
      if (kDebugMode) debugPrint('reservations_save Postgrest: ${e.message}');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('reservations_save: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Po Progressive Save máme _savedReservationId – hlavní „Uložit“ pak updatuje existující záznam místo druhého INSERTu.
  /// Kontrola kolize používá [excludeReservationId], aby se ignorovala sama sebe. Vrací true při úspěchu.
  Future<bool> _performUpdateReservation() async {
    if (!_formKey.currentState!.validate()) return false;
    if (_isSaving) return false;
    if (_savedReservationId == null || _savedReservationId!.isEmpty) {
      return false;
    }
    if (_selectedApartmentId == null || _selectedApartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.validation_apartment_required_short'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_check_in_out'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    final startDate =
        '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')}';
    final endDate =
        '${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}';
    final arrivalParts = _arrivalTimeController.text.trim().split(':');
    final arrivalH = arrivalParts.length >= 2
        ? (int.tryParse(arrivalParts[0]) ?? 15)
        : 15;
    final arrivalM = arrivalParts.length >= 2
        ? (int.tryParse(arrivalParts[1]) ?? 0)
        : 0;
    final newCheckIn = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
      arrivalH,
      arrivalM,
      0,
    );
    final depParts = _departureTimeController.text.trim().split(':');
    final depH = depParts.length >= 2 ? (int.tryParse(depParts[0]) ?? 10) : 10;
    final depM = depParts.length >= 2 ? (int.tryParse(depParts[1]) ?? 0) : 0;
    final newCheckOut = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      depH,
      depM,
      0,
    );
    if (newCheckOut.isBefore(newCheckIn) ||
        newCheckOut.isAtSameMomentAs(newCheckIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.reservations_validation_departure_after_arrival'.tr(),
          ),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final reservations = await widget.ref.read(
        adminReservationsProvider.future,
      );
      final apartments = await widget.ref.read(
        apartmentsFullListProvider.future,
      );
      final apartmentList = apartments
          .where((a) => a.id == _selectedApartmentId)
          .toList();
      final apartment = apartmentList.isEmpty ? null : apartmentList.first;
      final options = await widget.ref.read(
        apartmentServicesOptionsProvider(_selectedApartmentId!).future,
      );
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
        excludeReservationId: _savedReservationId,
      );

      final tenantId = widget.ref.read(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('CRITICAL: tenantId is null before update!');
      }

      final guestAdults = int.tryParse(_guestAdultsController.text.trim()) ?? 0;
      final guestChildren =
          int.tryParse(_guestChildrenController.text.trim()) ?? 0;
      DateTime? arrivalTimeUtc;
      final arrivalStr = _arrivalTimeController.text.trim();
      if (arrivalStr.isNotEmpty) {
        final parts = arrivalStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          arrivalTimeUtc = DateTime(
            _dateRange!.start.year,
            _dateRange!.start.month,
            _dateRange!.start.day,
            h,
            m,
            0,
          ).toUtc();
        }
      }
      DateTime? departureTimeUtc;
      final depStr = _departureTimeController.text.trim();
      if (depStr.isNotEmpty) {
        final parts = depStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          departureTimeUtc = DateTime(
            _dateRange!.end.year,
            _dateRange!.end.month,
            _dateRange!.end.day,
            h,
            m,
            0,
          ).toUtc();
        }
      }
      arrivalTimeUtc ??= DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
        15,
        0,
        0,
      ).toUtc();
      departureTimeUtc ??= DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        10,
        0,
        0,
      ).toUtc();

      await SupabaseService.safeFrom('reservations', tenantId)
          .update({
            'apartment_id': _selectedApartmentId,
            'guest_name': _guestNameController.text.trim().isEmpty
                ? null
                : _guestNameController.text.trim(),
            'guest_phone': _guestPhoneController.text.trim().isEmpty
                ? null
                : _guestPhoneController.text.trim(),
            'guest_email': _guestEmailController.text.trim().isEmpty
                ? null
                : _guestEmailController.text.trim(),
            'reservation_source': _reservationSource,
            'start_date': startDate,
            'end_date': endDate,
            'needs_transfer': false,
            'status': 'new',
            'guest_adults': guestAdults,
            'guest_children': guestChildren,
            'arrival_time': arrivalTimeUtc.toIso8601String(),
            'departure_time': departureTimeUtc.toIso8601String(),
            'internal_note': _internalNoteController.text.trim().isEmpty
                ? null
                : _internalNoteController.text.trim(),
            'special_requests': _specialRequestsController.text.trim().isEmpty
                ? null
                : _specialRequestsController.text.trim(),
          })
          .eq('id', _savedReservationId!);

      await saveForReservation(
        reservationId: _savedReservationId!,
        tenantId: tenantId,
        states: _servicesState,
      );
      await ensureMandatoryServicesForReservation(
        reservationId: _savedReservationId!,
        tenantId: tenantId,
        apartmentId: _selectedApartmentId!,
      );
      widget.ref.invalidate(adminReservationsProvider);
      widget.ref.invalidate(adminTasksProvider);
      widget.ref.invalidate(planningCalendarAllTasksProvider);
      widget.ref.invalidate(planningCalendarAllTasksForMonthProvider);
      return true;
    } on ReservationCollisionException catch (e) {
      if (!mounted) return false;
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
      return false;
    } on PostgrestException catch (e) {
      if (kDebugMode) debugPrint('reservations_update Postgrest: ${e.message}');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('reservations_update: $e');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// [successMessage] – při automatické opravě kolize se zobrazí tento text místo výchozího.
  Future<void> _onSave({String? successMessage}) async {
    if (_savedReservationId != null && _savedReservationId!.isNotEmpty) {
      final ok = await _performUpdateReservation();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage ?? 'admin.reservations_saved'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final newId = await _performInsertReservation();
    if (!mounted) return;
    if (newId != null && newId.isNotEmpty) {
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage ?? 'admin.reservations_saved'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = widget.ref.watch(apartmentsFullListProvider);

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
                style: TextStyle(color: context.colors.onSurfaceVariant),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  onTap: (index) {
                    // PROČ bez Progressive Save: Při nové rezervaci (bez _savedReservationId) jen přepneme na záložku 2.
                    // Dříve se volalo _saveAndThenGoToTab1(), což vytvářelo fantomové záznamy v DB při zrušení formuláře.
                    // Tab 2 zobrazí early-return widget s instrukcemi (uložte rezervaci, pak ji otevřete pro úpravu).
                    _tabController.animateTo(index);
                  },
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.info_outline),
                      text: 'admin.reservations_tab_stay_details'.tr(),
                    ),
                    Tab(
                      icon: const Icon(Icons.room_service_outlined),
                      text: 'admin.reservations_tab_services_requests'.tr(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(
            'admin.reservations_load_error'.tr(),
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('admin.reservations_cancel'.tr()),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: AppSpacing.lg,
                  height: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('admin.reservations_save_button'.tr()),
        ),
      ],
    );
  }

  /// Tab 1: Byt, host (jméno, telefon), zdroj rezervace, počty, období pobytu (DateRangePicker), časy příjezdu/odjezdu.
  Widget _buildTab1StayDetails(
    BuildContext context,
    List<ApartmentRow> apartments,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.reservations_section_where_who'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue:
              _selectedApartmentId != null &&
                  apartments.any((a) => a.id == _selectedApartmentId)
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
          validator: (v) => v == null || (v.isEmpty)
              ? 'admin.validation_apartment_required_short'.tr()
              : null,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _guestNameController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            labelText: 'admin.reservations_field_guest_name'.tr(),
            border: const OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'admin.validation_guest_name_required'.tr()
              : null,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _guestPhoneController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_outlined),
            labelText: 'admin.reservations_field_guest_phone'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _guestEmailController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined),
            labelText: 'admin.reservations_field_guest_email'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        if (_savedReservationId != null && _selectedApartmentId != null) ...[
          ReservationLegalSection(
            reservationId: _savedReservationId!,
            apartmentId: _selectedApartmentId!,
            guestPhone: _guestPhoneController.text,
            guestEmail: _guestEmailController.text,
            showSesRetry: true,
          ),
        ],
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: reservationSourceValues.contains(_reservationSource)
              ? _reservationSource
              : 'Other',
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.source_outlined),
            labelText: 'admin.reservations_field_reservation_source'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: reservationSourceValues
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text('admin.reservation_source_$s'.tr()),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _reservationSource = v);
          },
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
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
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
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
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'admin.reservations_section_when'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _stayPeriodController,
          readOnly: true,
          onTap: () async {
            final now = DateTime.now();
            final initialStart = _dateRange?.start ?? now;
            final initialEnd =
                _dateRange?.end ?? now.add(const Duration(days: 1));
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              initialDateRange: DateTimeRange(
                start: initialStart,
                end: initialEnd,
              ),
              builder: (context, child) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Material(child: child),
                ),
              ),
            );
            if (range != null && mounted) {
              setState(() {
                _dateRange = range;
                _stayPeriodController.text = formatReservationDateRangeDisplay(
                  range,
                );
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
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _arrivalTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_arrival_time'.tr(),
                  hintText: 'admin.forms.time_hint'.tr(),
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
                readOnly: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: _departureTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_departure_time'.tr(),
                  hintText: 'admin.forms.time_hint'.tr(),
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
                readOnly: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
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
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _specialRequestsController,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.room_service_outlined),
            labelText: 'admin.reservations_special_requests'.tr(),
            hintText: 'admin.reservations_special_requests_hint'.tr(),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
      ],
    );
  }

  /// Tab 2: Služby a požadavky. Zobrazuje se až po Progressive Save (máme _savedReservationId).
  /// Načte reservation_services pro uloženou rezervaci a sloučí s nabídkou bytu.
  ///
  /// PROČ early return při chybějícím _savedReservationId: U nové rezervace (Add) ještě nemáme ID v DB.
  /// Volání ref.watch(apartmentServicesOptionsProvider(...)) by vedlo k nekonečnému loading spinneru
  /// (provider čeká na data vázaná na rezervaci). Zároveň se vyhýbáme „Progressive Save“ na pozadí –
  /// ten by vytvářel fantomové záznamy v DB, pokud uživatel formulář zruší. Při úpravě (Edit) máme
  /// vždy widget.reservation.id, takže tento blok se nepoužívá – viz _buildEditTab2ServicesRequests.
  Widget _buildTab2ServicesRequests(BuildContext context) {
    if (_savedReservationId == null || _savedReservationId!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: AppSpacing.xxl,
                color: context.colors.outline,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'admin.reservation_services_after_save'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final apartmentId = _selectedApartmentId ?? '';
    final optionsAsync = widget.ref.watch(
      apartmentServicesOptionsProvider(apartmentId),
    );
    final preferredCurrency =
        widget.ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = widget.ref.watch(currenciesProvider).valueOrNull ?? [];

    return optionsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'common.error'.tr(),
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ),
      data: (options) {
        if (_savedReservationId != null &&
            !_servicesLoaded &&
            !_servicesLoadInProgress &&
            options.isNotEmpty) {
          // PROČ: Nastavíme progress hned, aby další build nenaplánoval druhý load (zabrání dvojímu volání DB).
          setState(() => _servicesLoadInProgress = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadServicesStateForSavedReservation(options);
          });
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'admin.reservations_services_empty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
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
            final state =
                _servicesState[o.apartmentServiceId] ??
                ReservationServiceEditState(
                  apartmentServiceId: o.apartmentServiceId,
                  serviceName: o.serviceName,
                  defaultPriceEur: o.defaultPriceEur,
                  enabled: o.isMandatory,
                  chargedPriceEur: o.defaultPriceEur,
                  customNote: null,
                  payerType: o.payerType,
                  requiresPhoto: null,
                );
            final effectiveEnabled = state.enabled || o.isMandatory;
            final eurBase = (state.chargedPriceEur ?? state.defaultPriceEur);
                final displayPrice = CurrencyService.convert(
                  eurBase,
                  preferredCurrency,
                  currencies,
                );
                final displayPriceStr = displayPrice.toStringAsFixed(2);
                final transitEur = state.transitCashToCollectEur ?? 0;
                final displayTransit = CurrencyService.convert(
                  transitEur,
                  preferredCurrency,
                  currencies,
                );
                final displayTransitStr =
                    transitEur > 0 ? displayTransit.toStringAsFixed(2) : '';
                return ExpansionTile(
                  initiallyExpanded: false,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: GestureDetector(
                    onTap: o.isMandatory
                    ? null
                    : () {
                        setState(() {
                          _servicesState[o.apartmentServiceId] = state.copyWith(
                            enabled: !effectiveEnabled,
                          );
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
                                _servicesState[o.apartmentServiceId] = state
                                    .copyWith(enabled: v ?? false);
                              });
                            },
                    ),
                    const SizedBox(width: AppSpacing.sm),
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
                              padding: const EdgeInsets.only(
                                left: AppSpacing.sm,
                              ),
                              child: Text(
                                'admin.service_mandatory_badge'.tr(),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: TextFormField(
                                initialValue: displayPriceStr,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.payments_outlined,
                                    color: context.colors.outline,
                                  ),
                                  labelText:
                                      'admin.reservations_field_agency_service_price'
                                          .tr(
                                            namedArgs: {
                                              'code': preferredCurrency,
                                            },
                                          ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (v) {
                                  final parsed = double.tryParse(
                                    v.replaceAll(',', '.'),
                                  );
                                  if (parsed == null) return;
                                  final eur = CurrencyService.toEur(
                                    parsed,
                                    preferredCurrency,
                                    currencies,
                                  );
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = state
                                        .copyWith(chargedPriceEur: eur);
                                  });
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: TextFormField(
                                initialValue: displayTransitStr,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.home_work_outlined,
                                    color: context.colors.outline,
                                  ),
                                  labelText:
                                      'admin.reservations_field_transit_accommodation_cash'
                                          .tr(
                                            namedArgs: {
                                              'code': preferredCurrency,
                                            },
                                          ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (v) {
                                  final parsed = double.tryParse(
                                    v.replaceAll(',', '.'),
                                  );
                                  if (parsed == null) return;
                                  final eur = CurrencyService.toEur(
                                    parsed,
                                    preferredCurrency,
                                    currencies,
                                  );
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = eur > 0
                                        ? state.copyWith(
                                            transitCashToCollectEur: eur,
                                          )
                                        : state.copyWith(
                                            clearTransitCashToCollect: true,
                                          );
                                  });
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: DropdownButtonFormField<String>(
                                initialValue: state.payerType,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.payment_outlined,
                                    color: context.colors.outline,
                                  ),
                                  labelText: 'admin.payer_type_label'.tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'owner',
                                    child: Text('admin.payer_owner'.tr()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'guest',
                                    child: Text('admin.payer_guest'.tr()),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = state
                                        .copyWith(payerType: v);
                                  });
                                },
                              ),
                            ),
                            ReservationServiceRowWidget(option: o),
                            Container(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              child: TextFormField(
                                initialValue: state.customNote ?? '',
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.notes_outlined,
                                    color: context.colors.outline,
                                  ),
                                  labelText:
                                      'admin.reservations_field_custom_note'
                                          .tr(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: context.colors.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 2,
                                onChanged: (v) {
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = state
                                        .copyWith(
                                          customNote: v.isEmpty ? null : v,
                                        );
                                  });
                                },
                              ),
                            ),
                            if (_isTransferServiceType(o.serviceType))
                              Container(
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                child: TextFormField(
                                  initialValue: state.flightNumber ?? '',
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.flight_takeoff_outlined,
                                      color: context.colors.outline,
                                    ),
                                    labelText: 'tasks.flight_number_label'.tr(),
                                    hintText: 'tasks.flight_number_hint'.tr(),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.sm,
                                      ),
                                      borderSide: BorderSide(
                                        color: context.colors.outlineVariant,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.sm,
                                      ),
                                      borderSide: BorderSide(
                                        color: context.colors.outlineVariant,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.sm,
                                      ),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _servicesState[o.apartmentServiceId] =
                                          state.copyWith(
                                            flightNumber: v.trim().isEmpty
                                                ? null
                                                : v.trim(),
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
        );
      },
    );
  }
}

/// Seznam úkolů souvisejících s rezervací – kompaktní ListTile s ikonou typu, tučným jménem a Chipem stavu.
/// Data mohou pocházet z [tasksForReservationProvider] (bez měsíčního filtru), aby byly vidět i check-out úkoly v dalším měsíci.
class RelatedTasksList extends StatelessWidget {
  const RelatedTasksList({
    super.key,
    required this.ref,
    required this.reservation,
    required this.tasksAsync,
    this.onTaskSaved,
  });

  final WidgetRef ref;
  final ReservationRow reservation;
  final AsyncValue<List<TaskRow>> tasksAsync;

  /// Voláno po uložení úkolu v dialogu úpravy – typicky invalidace [tasksForReservationProvider], aby se seznam znovu načetl.
  final VoidCallback? onTaskSaved;

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      data: (tasks) {
        final checkInDt = parseReservationCheckIn(reservation.checkIn);
        final checkOutDt = parseReservationCheckOut(reservation.checkOut);
        if (checkInDt == null || checkOutDt == null) {
          return Text(
            'admin.reservations_no_tasks_yet'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          );
        }
        // Priorita 1: úkoly s vazbou reservation_id == reservation.id.
        // Zpětná kompatibilita: úkoly bez reservation_id filtrujeme podle apartment_id a časového okna.
        final resStart = DateTime(
          checkInDt.year,
          checkInDt.month,
          checkInDt.day,
        );
        final resEnd = DateTime(
          checkOutDt.year,
          checkOutDt.month,
          checkOutDt.day,
          23,
          59,
          59,
        );
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
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: related
              .map(
                (t) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    // Otevření plného dialogu úkolu pro zobrazení metadat a financí.
                    onTap: () => AdminTasksScreen.showEditTaskDialog(
                      context,
                      ref,
                      t,
                      onSaved: onTaskSaved,
                      onReservationTap: null,
                    ),
                    leading: CircleAvatar(
                      radius: AppSpacing.sm + AppSpacing.sm + AppSpacing.xs,
                      backgroundColor: context.colors.primaryContainer,
                      child: Icon(
                        reservationTaskTypeIcon(t.taskType),
                        size: AppSpacing.md + AppSpacing.xs,
                        color: context.colors.onPrimaryContainer,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          reservationTaskTypeEmoji(t.taskType),
                          style: context.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          reservationTaskTypeLabelKey(t.taskType).tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            t.assignedToName ??
                                'planning_calendar.unknown'.tr(),
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Výpis používá skutečný naplánovaný začátek úkolu, aby se shodoval s kalendářem.
                    subtitle: Text(
                      DateFormat(
                        'dd.MM.yyyy HH:mm',
                        context.locale.languageCode,
                      ).format((t.scheduledStart ?? t.dueDate).toLocal()),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    trailing: Chip(
                      label: Text(
                        reservationTaskStatusLabelKey(t.status).tr(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: _chipLabelOnBackground(
                            reservationTaskStatusChipColor(t.status),
                            context,
                          ),
                        ),
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
      loading: () => SizedBox(
        height: AppSpacing.lg,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Text(
        'admin.reservations_no_tasks_yet'.tr(),
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
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
  late final TextEditingController _guestEmailController;
  late final TextEditingController _guestAdultsController;
  late final TextEditingController _guestChildrenController;
  late final TextEditingController _arrivalTimeController;
  late final TextEditingController _departureTimeController;
  late final TextEditingController _stayPeriodController;
  late final TextEditingController _internalNoteController;
  /// PROČ: Parita s tabulkou `reservations.special_requests` – dispečer doplní požadavky hosta.
  late final TextEditingController _specialRequestsController;
  DateTimeRange? _dateRange;
  String _reservationSource = 'Other';
  late String _selectedApartmentId;
  late String _status;
  bool _isSaving = false;
  Map<String, ReservationServiceEditState> _servicesState = {};

  /// Snapshot původního stavu služeb při načtení dialogu.
  ///
  /// PROČ: potřebujeme detekovat jen uživatelské „odškrtnutí“ dříve uložené služby,
  /// abychom mohli bezpečně soft-delete úkolů. Nesmíme dělat bidirectional sync.
  Map<String, bool> _initialServicesEnabledByApartmentServiceId = {};
  bool _servicesLoaded = false;

  /// PROČ: Zabrání vícenásobnému spuštění loadu (build by jinak mohl spamovat DB).
  bool _servicesLoadInProgress = false;

  /// UI override pro indikaci „odesláno/vygenerováno“ bez nutnosti zavírat a znovu otevírat dialog.
  String? _lastCommunicationTemplateIdUi;
  DateTime? _lastCommunicationAtUi;
  late String _guestLanguage;

  @override
  void initState() {
    super.initState();
    final r = widget.reservation;
    _guestNameController = TextEditingController(text: r.guestName ?? '');
    _guestPhoneController = TextEditingController(text: r.guestPhone ?? '');
    _guestEmailController = TextEditingController(text: r.guestEmail ?? '');
    _guestAdultsController = TextEditingController(text: '${r.guestAdults}');
    _guestChildrenController = TextEditingController(
      text: '${r.guestChildren}',
    );
    final at = r.arrivalTime?.toLocal();
    _arrivalTimeController = TextEditingController(
      text: at != null
          ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
          : '',
    );
    final dt = r.departureTime?.toLocal();
    _departureTimeController = TextEditingController(
      text: dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '',
    );
    _stayPeriodController = TextEditingController();
    _internalNoteController = TextEditingController(text: r.internalNote ?? '');
    _specialRequestsController = TextEditingController(text: r.specialRequests ?? '');
    _reservationSource =
        r.reservationSource != null &&
            reservationSourceValues.contains(r.reservationSource)
        ? r.reservationSource!
        : 'Other';
    final startDt = parseReservationDateTime(r.checkIn);
    final endDt = parseReservationDateTime(r.checkOut);
    if (startDt != null && endDt != null) {
      _dateRange = DateTimeRange(
        start: DateTime(startDt.year, startDt.month, startDt.day),
        end: DateTime(endDt.year, endDt.month, endDt.day),
      );
      _stayPeriodController.text = formatReservationDateRangeDisplay(
        _dateRange!,
      );
    }
    _selectedApartmentId = r.apartmentId;
    _status = reservationStatusValues.contains(r.status) ? r.status : 'new';
    _lastCommunicationTemplateIdUi = r.lastCommunicationTemplateId;
    _lastCommunicationAtUi = r.lastCommunicationAt;
    _guestLanguage = r.guestLanguage?.trim().isNotEmpty == true
        ? r.guestLanguage!.trim().toLowerCase()
        : 'en';
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _guestEmailController.dispose();
    _guestAdultsController.dispose();
    _guestChildrenController.dispose();
    _arrivalTimeController.dispose();
    _departureTimeController.dispose();
    _stayPeriodController.dispose();
    _internalNoteController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  /// Načtení služeb rezervace (Override Pattern Tier 3): načte záznamy z reservation_services
  /// pro tuto rezervaci a sloučí je s nabídkou apartment_services vybraného bytu do _servicesState pro předvyplnění Tabu 2.
  /// tenant_id: Admin použije tenantIdForData, Owner získá z apartmánu (V1_RELEASE_AUDIT).
  /// PROČ try/catch/finally: Při výjimce nebo timeoutu musí finally vždy nastavit _servicesLoaded = true,
  /// aby se kolečko přestalo točit a dispečer mohl služby doplnit ručně.
  Future<void> _loadServicesState(List<ApartmentServiceOption> options) async {
    if (mounted) setState(() => _servicesLoadInProgress = true);
    try {
      var tenantId = widget.ref.read(
        authNotifierProvider.select((s) => s.tenantIdForData),
      );
      if (tenantId == null || tenantId.isEmpty) {
        // Owner flow: tenant_id z apartmánu rezervace. safeFrom(null) = stejné jako client.from; RLS + eq(id) zužuje řádek.
        final aptRes = await SupabaseService.safeFrom('apartments', null)
            .select('tenant_id')
            .eq('id', widget.reservation.apartmentId)
            .maybeSingle();
        tenantId = aptRes?['tenant_id']?.toString();
      }
      if (tenantId == null || tenantId.isEmpty) {
        // PROČ: Bez tenantId nelze načíst reservation_services. Nastavíme _servicesLoaded = true
        // a vyplníme _servicesState z options, aby se neukazovalo nekonečné kolečko.
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
                flightNumber: null,
                payerType: o.payerType,
                requiresPhoto: null,
              ),
          };
          _initialServicesEnabledByApartmentServiceId = {
            for (final e in _servicesState.entries) e.key: e.value.enabled,
          };
          _servicesLoaded = true;
          _servicesLoadInProgress = false;
        });
        return;
      }
      const loadTimeout = Duration(seconds: 10);
      final rows = await fetchByReservationId(
        widget.reservation.id,
        tenantId,
      ).timeout(loadTimeout, onTimeout: () => <ReservationServiceRow>[]);
      final byApartmentServiceId = {
        for (final row in rows) row.apartmentServiceId: row,
      };
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
                  flightNumber: null,
                  payerType: o.payerType,
                  requiresPhoto: null,
                );
              }
              final payerType =
                  (row.payerType == 'owner' || row.payerType == 'guest')
                  ? row.payerType!
                  : o.payerType;
              final (parsedFlight, parsedNoteRest) = parseFlightFromCustomNote(
                row.customNote,
              );
              final flight = row.flightNumber ?? parsedFlight;
              final noteRest =
                  row.flightNumber != null && row.flightNumber!.isNotEmpty
                  ? row.customNote
                  : parsedNoteRest;
              return ReservationServiceEditState(
                apartmentServiceId: o.apartmentServiceId,
                serviceName: o.serviceName,
                defaultPriceEur: o.defaultPriceEur,
                enabled: true,
                chargedPriceEur: row.chargedPrice?.toDouble(),
                transitCashToCollectEur: row.transitCashToCollect?.toDouble(),
                customNote: noteRest,
                flightNumber: flight,
                payerType: payerType,
                requiresPhoto: row.requiresPhoto,
              );
            }(),
        };
        _initialServicesEnabledByApartmentServiceId = {
          for (final e in _servicesState.entries) e.key: e.value.enabled,
        };
        _servicesLoaded = true;
      });
    } catch (e, st) {
      debugPrint('_loadServicesState (Edit) ERROR: $e');
      debugPrint('_loadServicesState (Edit) STACK: $st');
    } finally {
      if (mounted) {
        setState(() {
          _servicesLoaded = true;
          _servicesLoadInProgress = false;
        });
      }
    }
  }

  /// [successMessage] – při automatické opravě kolize se zobrazí tento text místo výchozího.
  Future<void> _onSave({String? successMessage}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.reservations_validation_check_in_out'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final startDate =
        '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')}';
    final endDate =
        '${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}';

    final arrivalParts = _arrivalTimeController.text.trim().split(':');
    final arrivalH = arrivalParts.length >= 2
        ? (int.tryParse(arrivalParts[0]) ?? 15)
        : 15;
    final arrivalM = arrivalParts.length >= 2
        ? (int.tryParse(arrivalParts[1]) ?? 0)
        : 0;
    final newCheckIn = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
      arrivalH,
      arrivalM,
      0,
    );
    final depParts = _departureTimeController.text.trim().split(':');
    final depH = depParts.length >= 2 ? (int.tryParse(depParts[0]) ?? 10) : 10;
    final depM = depParts.length >= 2 ? (int.tryParse(depParts[1]) ?? 0) : 0;
    final newCheckOut = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      depH,
      depM,
      0,
    );

    if (newCheckOut.isBefore(newCheckIn) ||
        newCheckOut.isAtSameMomentAs(newCheckIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.reservations_validation_departure_after_arrival'.tr(),
          ),
          backgroundColor: context.colors.error,
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
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Detekce změny stavu na Zrušeno: uživatel musí potvrdit, pak soft-delete nesplněných úkolů rezervace.
    final originalStatus = widget.reservation.status;
    final statusChangeToCancelled =
        (originalStatus != _status && _status == 'cancelled');
    if (statusChangeToCancelled) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('admin.reservations_cancel_to_cancelled_title'.tr()),
          content: Text('admin.reservations_cancel_to_cancelled_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('admin.reservations_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'admin.reservations_cancel_reservation_and_delete_tasks'.tr(),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) return;

      // Soft-delete úkolů navázaných na rezervaci – stejná logika jako při změně termínu.
      // Odstraníme pouze úkoly, které nejsou „Probíhá“ ani „Hotovo“.
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      final protectedStatuses = [
        'in_progress',
        'completed',
        'probíhá',
        'hotovo',
        'done',
        'dokončeno',
      ];
      await SupabaseService.safeFrom('tasks', tenantId)
          .update({'deleted_at': deletedAt})
          .eq('reservation_id', widget.reservation.id)
          .not('status', 'in', protectedStatuses);
      ref.invalidate(adminTasksProvider);
      ref.invalidate(planningCalendarAllTasksProvider);
      ref.invalidate(planningCalendarAllTasksForMonthProvider);
    }

    // PROČ: Po jakémkoli await výše musíme ověřit context před dalším použitím BuildContextu.
    if (!context.mounted) return;

    // Kontrola změny termínu: pokud se změnil check-in nebo check-out, smažeme návrhy úkolů
    final origStart = parseReservationDateTime(widget.reservation.checkIn);
    final origEnd = parseReservationDateTime(widget.reservation.checkOut);
    final origStartDay = origStart != null
        ? DateTime(origStart.year, origStart.month, origStart.day)
        : null;
    final origEndDay = origEnd != null
        ? DateTime(origEnd.year, origEnd.month, origEnd.day)
        : null;
    final newStartDay = DateTime(
      newCheckIn.year,
      newCheckIn.month,
      newCheckIn.day,
    );
    final newEndDay = DateTime(
      newCheckOut.year,
      newCheckOut.month,
      newCheckOut.day,
    );
    final datesChanged = origStartDay != newStartDay || origEndDay != newEndDay;

    if (datesChanged) {
      if (!context.mounted) return;
      // PROČ: Těsně před dialogem je kontrola context.mounted (ř. 2172); analyzer nepropaguje větev z předchozího await.
      final confirmed = await showDialog<bool>(
        // ignore: use_build_context_synchronously
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

      // Soft Delete: Všechny nesplněné úkoly navázané na rezervaci (ne jen Návrh, ale i Zadáno/Přiřazeno).
      // Nepřesahujeme úkoly „Probíhá“ a „Hotovo“ – jde o hotovou práci k fakturaci (Variant A z analýzy).
      // Zachováváme deleted_at místo tvrdého DELETE kvůli auditu a sledovatelnosti.
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      final protectedStatuses = [
        'in_progress',
        'completed',
        'probíhá',
        'hotovo',
        'done',
        'dokončeno',
      ];
      await SupabaseService.safeFrom('tasks', tenantId)
          .update({'deleted_at': deletedAt})
          .eq('reservation_id', widget.reservation.id)
          .not('status', 'in', protectedStatuses);
      ref.invalidate(adminTasksProvider);
    }

    setState(() => _isSaving = true);

    try {
      final reservations = await ref.read(adminReservationsProvider.future);
      final apartments = await ref.read(apartmentsFullListProvider.future);
      final apartmentList = apartments
          .where((a) => a.id == _selectedApartmentId)
          .toList();
      final apartment = apartmentList.isEmpty ? null : apartmentList.first;
      // Sčítáme základní čas úklidu bytu a extra čas přikoupených služeb – pro přesnou kontrolu kolizí.
      final options = await ref.read(
        apartmentServicesOptionsProvider(_selectedApartmentId).future,
      );
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
      final guestChildren =
          int.tryParse(_guestChildrenController.text.trim()) ?? 0;
      DateTime? arrivalTimeUtc;
      final arrivalStr = _arrivalTimeController.text.trim();
      if (arrivalStr.isNotEmpty) {
        final parts = arrivalStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          arrivalTimeUtc = DateTime(
            _dateRange!.start.year,
            _dateRange!.start.month,
            _dateRange!.start.day,
            h,
            m,
            0,
          ).toUtc();
        }
      }
      DateTime? departureTimeUtc;
      final depStr = _departureTimeController.text.trim();
      if (depStr.isNotEmpty) {
        final parts = depStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          departureTimeUtc = DateTime(
            _dateRange!.end.year,
            _dateRange!.end.month,
            _dateRange!.end.day,
            h,
            m,
            0,
          ).toUtc();
        }
      }

      // Dvoukrokové ukládání (Override Pattern Tier 3): nejdřív úprava rezervace, potom přepsání reservation_services.
      // KROK 1: Aktualizace záznamu rezervace (včetně guest_phone, reservation_source, departure_time).
      await SupabaseService.safeFrom('reservations', tenantId)
          .update({
            'apartment_id': _selectedApartmentId,
            'guest_name': _guestNameController.text.trim().isEmpty
                ? null
                : _guestNameController.text.trim(),
            'guest_phone': _guestPhoneController.text.trim().isEmpty
                ? null
                : _guestPhoneController.text.trim(),
            'guest_email': _guestEmailController.text.trim().isEmpty
                ? null
                : _guestEmailController.text.trim(),
            'guest_language': _guestLanguage,
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
            'special_requests': _specialRequestsController.text.trim().isEmpty
                ? null
                : _specialRequestsController.text.trim(),
          })
          .eq('id', widget.reservation.id);

      // KROK 2: Uložení služeb rezervace (reservation_services) – replace všech záznamů pro tuto rezervaci (delete + insert dle stavu Tabu 2).
      await saveForReservation(
        reservationId: widget.reservation.id,
        tenantId: tenantId,
        states: _servicesState,
      );
      await ensureMandatoryServicesForReservation(
        reservationId: widget.reservation.id,
        tenantId: tenantId,
        apartmentId: _selectedApartmentId,
      );

      // KROK 1 (bezpečný cleanup úkolů): pokud uživatel odškrtl dříve uloženou službu,
      // soft-delete příslušných úkolů pouze v povolených (new/draft/pending) stavech.
      //
      // PROČ NE DIRECTIONAL SYNC: odškrtnutí = zrušení objednávky služby, ale úkoly se generují později tlačítkem.
      // Tady tedy nikdy „nezpětně“ neodškrtáváme/nezapínáme služby dle existence úkolů.
      final removedApartmentServiceIds =
          _initialServicesEnabledByApartmentServiceId.entries
              .where((e) => e.value == true)
              .where((e) => !(_servicesState[e.key]?.enabled ?? false))
              .map((e) => e.key)
              .toList();
      if (removedApartmentServiceIds.isNotEmpty) {
        final optionsByApartmentServiceId = {
          for (final opt in options) opt.apartmentServiceId: opt,
        };
        final removedTenantServiceIds = removedApartmentServiceIds
            .map((id) => optionsByApartmentServiceId[id]?.serviceId)
            .whereType<String>()
            .toSet()
            .toList();
        if (removedTenantServiceIds.isNotEmpty) {
          final deletedAt = DateTime.now().toUtc().toIso8601String();
          final allowedStatuses = <String>[
            'new',
            'nový',
            'Návrh',
            'NÁVRH',
            'Nový',
            'pending',
            'draft',
            'návrh',
          ];
          try {
            // PROČ SE TÍMTO ZPŮSOBEM: filtry typu `inFilter` používáme pro SELECT,
            // a update provedeme po konkrétních `id` (bez rizika nekompatibilních metod).
            for (final serviceId in removedTenantServiceIds) {
              final tasksToDelete =
                  await SupabaseService.safeFrom('tasks', tenantId)
                      .select('id')
                      .eq('reservation_id', widget.reservation.id)
                      .eq('service_id', serviceId)
                      .inFilter('status', allowedStatuses)
                      .isFilter('deleted_at', null);

              for (final row in tasksToDelete) {
                final taskId = row['id']?.toString();
                if (taskId == null || taskId.isEmpty) continue;
                await SupabaseService.safeFrom(
                  'tasks',
                  tenantId,
                ).update({'deleted_at': deletedAt}).eq('id', taskId);
              }
            }
          } catch (e) {
            debugPrint('Task cleanup (reservation service uncheck) failed: $e');
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage ?? 'admin.reservations_saved'.tr()),
          backgroundColor: context.customColors.success,
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
      if (kDebugMode) {
        debugPrint('--- CHYBA ÚPRAVY REZERVACE: $e');
        if (e.code == '42703' || e.message.contains('column')) {
          debugPrint(
            '>>> Chybí sloupce. Spusť: supabase/migrations/20250217_reservations_extended.sql',
          );
        }
        debugPrint('reservations_edit Postgrest: ${e.message}');
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
      if (kDebugMode) debugPrint('--- CHYBA ÚPRAVY REZERVACE: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildEditTab1StayDetails(
    BuildContext context,
    List<ApartmentRow> apartments,
    AsyncValue<List<TaskRow>> tasksAsync,
    bool isReadOnly,
  ) {
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
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: validId,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.list_alt_outlined),
            border: OutlineInputBorder(),
          ),
          items: apartments
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: isReadOnly
              ? null
              : (v) {
                  if (v != null) setState(() => _selectedApartmentId = v);
                },
          validator: (v) => v == null
              ? 'admin.validation_apartment_required_short'.tr()
              : null,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: reservationStatusValues.contains(_status)
              ? _status
              : reservationStatusValues.first,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.list_alt_outlined),
            border: const OutlineInputBorder(),
            labelText: 'admin.reservations_status_label'.tr(),
          ),
          items: reservationStatusValues
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(reservationStatusLabelKey(s).tr()),
                ),
              )
              .toList(),
          onChanged: isReadOnly
              ? null
              : (v) {
                  if (v != null) setState(() => _status = v);
                },
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _guestNameController,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline),
            labelText: 'admin.reservations_field_guest_name'.tr(),
            border: const OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'admin.validation_guest_name_required'.tr()
              : null,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _guestPhoneController,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_outlined),
            labelText: 'admin.reservations_field_guest_phone'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _guestEmailController,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.email_outlined),
            labelText: 'admin.reservations_field_guest_email'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        ReservationLegalSection(
          reservationId: widget.reservation.id,
          apartmentId: _selectedApartmentId,
          guestPhone: _guestPhoneController.text,
          guestEmail: _guestEmailController.text,
          readOnly: isReadOnly,
          showSesRetry: true,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: _guestLanguage,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.translate_outlined),
            labelText: 'admin.reservation_guest_language'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: SupportedLanguages.all.where((lang) => lang.code != null).map((
            lang,
          ) {
            final code = lang.code!;
            return DropdownMenuItem<String>(
              value: code,
              child: Text(lang.labelKey.tr()),
            );
          }).toList(),
          onChanged: isReadOnly
              ? null
              : (v) {
                  if (v == null) return;
                  setState(() => _guestLanguage = v.trim().toLowerCase());
                },
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: reservationSourceValues.contains(_reservationSource)
              ? _reservationSource
              : 'Other',
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.source_outlined),
            labelText: 'admin.reservations_field_reservation_source'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: reservationSourceValues
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text('admin.reservation_source_$s'.tr()),
                ),
              )
              .toList(),
          onChanged: isReadOnly
              ? null
              : (v) {
                  if (v != null) setState(() => _reservationSource = v);
                },
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _guestAdultsController,
                readOnly: isReadOnly,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.people_alt_outlined),
                  labelText: 'admin.reservations_field_guest_adults'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: _guestChildrenController,
                readOnly: isReadOnly,
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
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'admin.reservations_section_when'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _stayPeriodController,
          readOnly: true,
          onTap: isReadOnly
              ? null
              : () async {
                  final now = DateTime.now();
                  final initialStart = _dateRange?.start ?? now;
                  final initialEnd =
                      _dateRange?.end ?? now.add(const Duration(days: 1));
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDateRange: DateTimeRange(
                      start: initialStart,
                      end: initialEnd,
                    ),
                    builder: (context, child) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Material(child: child),
                      ),
                    ),
                  );
                  if (range != null && mounted) {
                    setState(() {
                      _dateRange = range;
                      _stayPeriodController.text =
                          formatReservationDateRangeDisplay(range);
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
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _arrivalTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_arrival_time'.tr(),
                  hintText: 'admin.forms.time_hint'.tr(),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time_outlined),
                ),
                onTap: isReadOnly
                    ? null
                    : () async {
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
                readOnly: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: _departureTimeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  labelText: 'admin.reservations_field_departure_time'.tr(),
                  hintText: 'admin.forms.time_hint'.tr(),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time_outlined),
                ),
                onTap: isReadOnly
                    ? null
                    : () async {
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
                readOnly: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
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
          readOnly: isReadOnly,
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        TextFormField(
          controller: _specialRequestsController,
          keyboardType: TextInputType.multiline,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.room_service_outlined),
            labelText: 'admin.reservations_special_requests'.tr(),
            hintText: 'admin.reservations_special_requests_hint'.tr(),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: AppSpacing.lg),
        ReservationCashTransitAdminCard(reservationId: widget.reservation.id),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'admin.reservations_related_tasks'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: isReadOnly
                  ? null
                  : () {
                      final r = widget.reservation;
                      final guest = r.guestName?.trim().isNotEmpty == true
                          ? r.guestName!.trim()
                          : '?';
                      final start = parseReservationCheckIn(r.checkIn);
                      final end = parseReservationCheckOut(r.checkOut);
                      String? reservationInfo;
                      if (start != null && end != null) {
                        reservationInfo =
                            '$guest (${formatReservationDateRangeDisplay(DateTimeRange(start: start, end: end))})';
                      } else {
                        reservationInfo = guest;
                      }
                      AdminTasksScreen.showAddTaskDialog(
                        context,
                        ref,
                        initialApartmentId: r.apartmentId,
                        initialReservationId: r.id,
                        initialReservationInfo: reservationInfo,
                        onSaved: () {
                          ref.invalidate(adminTasksProvider);
                          ref.invalidate(adminTasksStreamProvider);
                          ref.invalidate(
                            tasksForReservationProvider(widget.reservation.id),
                          );
                          ref.invalidate(
                            reservationCashTransitProvider(widget.reservation.id),
                          );
                        },
                      );
                    },
              icon: const Icon(Icons.add, size: 18),
              label: Text('admin.add_related_task'.tr()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        RelatedTasksList(
          ref: ref,
          reservation: widget.reservation,
          tasksAsync: tasksAsync,
          onTaskSaved: () {
            ref.invalidate(tasksForReservationProvider(widget.reservation.id));
            ref.invalidate(
              reservationCashTransitProvider(widget.reservation.id),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditTab2ServicesRequests(BuildContext context, bool isReadOnly) {
    final apartmentId = _selectedApartmentId;
    final optionsAsync = ref.watch(
      apartmentServicesOptionsProvider(apartmentId),
    );
    final preferredCurrency =
        ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    if (apartmentId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'admin.reservations_services_select_apartment_to_load'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return optionsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'common.error'.tr(),
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ),
      data: (options) {
        if (!_servicesLoaded &&
            !_servicesLoadInProgress &&
            options.isNotEmpty) {
          // PROČ: Nastavíme progress hned, aby další build nenaplánoval druhý load (zabrání dvojímu volání DB).
          setState(() => _servicesLoadInProgress = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadServicesState(options);
          });
        }
        if (options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'admin.reservations_services_empty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        if (!_servicesLoaded) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final o = options[index];
                final state =
                    _servicesState[o.apartmentServiceId] ??
                    ReservationServiceEditState(
                      apartmentServiceId: o.apartmentServiceId,
                      serviceName: o.serviceName,
                      defaultPriceEur: o.defaultPriceEur,
                      enabled: o.isMandatory,
                      chargedPriceEur: o.defaultPriceEur,
                      customNote: null,
                      payerType: o.payerType,
                      requiresPhoto: null,
                    );
                final effectiveEnabled = state.enabled || o.isMandatory;
                final eurBase =
                    (state.chargedPriceEur ?? state.defaultPriceEur);
                final displayPrice = CurrencyService.convert(
                  eurBase,
                  preferredCurrency,
                  currencies,
                );
                final displayPriceStr = displayPrice.toStringAsFixed(2);
                final transitEurEdit = state.transitCashToCollectEur ?? 0;
                final displayTransitEdit = CurrencyService.convert(
                  transitEurEdit,
                  preferredCurrency,
                  currencies,
                );
                final displayTransitStrEdit =
                    transitEurEdit > 0 ? displayTransitEdit.toStringAsFixed(2) : '';
                return ExpansionTile(
                  initiallyExpanded: false,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: GestureDetector(
                    // Auditing: Zámek editace - při isReadOnly nelze měnit výběr služeb
                    onTap: o.isMandatory || isReadOnly
                        ? null
                        : () {
                            setState(() {
                              _servicesState[o.apartmentServiceId] = state
                                  .copyWith(enabled: !effectiveEnabled);
                            });
                          },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Checkbox(
                          value: effectiveEnabled,
                          onChanged: o.isMandatory || isReadOnly
                              ? null
                              : (v) {
                                  setState(() {
                                    _servicesState[o.apartmentServiceId] = state
                                        .copyWith(enabled: v ?? false);
                                  });
                                },
                        ),
                        const SizedBox(width: AppSpacing.sm),
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
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    'admin.service_mandatory_badge'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
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
                  children: effectiveEnabled && !isReadOnly
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  child: TextFormField(
                                    initialValue: displayPriceStr,
                                    readOnly: isReadOnly,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.payments_outlined,
                                        color: context.colors.outline,
                                      ),
                                      labelText:
                                          'admin.reservations_field_agency_service_price'
                                              .tr(
                                                namedArgs: {
                                                  'code': preferredCurrency,
                                                },
                                              ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
                                          ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: isReadOnly
                                        ? null
                                        : (v) {
                                            final parsed = double.tryParse(
                                              v.replaceAll(',', '.'),
                                            );
                                            if (parsed == null) return;
                                            final eur = CurrencyService.toEur(
                                              parsed,
                                              preferredCurrency,
                                              currencies,
                                            );
                                            setState(() {
                                              _servicesState[o
                                                  .apartmentServiceId] = state
                                                  .copyWith(
                                                    chargedPriceEur: eur,
                                                  );
                                            });
                                          },
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  child: TextFormField(
                                    initialValue: displayTransitStrEdit,
                                    readOnly: isReadOnly,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.home_work_outlined,
                                        color: context.colors.outline,
                                      ),
                                      labelText:
                                          'admin.reservations_field_transit_accommodation_cash'
                                              .tr(
                                                namedArgs: {
                                                  'code': preferredCurrency,
                                                },
                                              ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
                                          ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: isReadOnly
                                        ? null
                                        : (v) {
                                            final parsed = double.tryParse(
                                              v.replaceAll(',', '.'),
                                            );
                                            if (parsed == null) return;
                                            final eur = CurrencyService.toEur(
                                              parsed,
                                              preferredCurrency,
                                              currencies,
                                            );
                                            setState(() {
                                              _servicesState[o
                                                  .apartmentServiceId] = eur > 0
                                                  ? state.copyWith(
                                                      transitCashToCollectEur:
                                                          eur,
                                                    )
                                                  : state.copyWith(
                                                      clearTransitCashToCollect:
                                                          true,
                                                    );
                                            });
                                          },
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: state.payerType,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.payment_outlined,
                                        color: context.colors.outline,
                                      ),
                                      labelText: 'admin.payer_type_label'.tr(),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
                                          ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'owner',
                                        child: Text('admin.payer_owner'.tr()),
                                      ),
                                      DropdownMenuItem(
                                        value: 'guest',
                                        child: Text('admin.payer_guest'.tr()),
                                      ),
                                    ],
                                    onChanged: isReadOnly
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(() {
                                              _servicesState[o
                                                  .apartmentServiceId] = state
                                                  .copyWith(payerType: v);
                                            });
                                          },
                                  ),
                                ),
                                ReservationServiceRowWidget(option: o),
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  child: TextFormField(
                                    initialValue: state.customNote ?? '',
                                    readOnly: isReadOnly,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.notes_outlined,
                                        color: context.colors.outline,
                                      ),
                                      labelText:
                                          'admin.reservations_field_custom_note'
                                              .tr(),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: context.colors.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
                                          ),
                                      alignLabelWithHint: true,
                                    ),
                                    maxLines: 2,
                                    onChanged: isReadOnly
                                        ? null
                                        : (v) {
                                            setState(() {
                                              _servicesState[o
                                                  .apartmentServiceId] = state
                                                  .copyWith(
                                                    customNote: v.isEmpty
                                                        ? null
                                                        : v,
                                                  );
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _buildReservationServiceMessagesSection(
                                  context,
                                  serviceTriggerCode: o.serviceType,
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
        );
      },
    );
  }

  /// Sekce „Zprávy k této službě“ v záložce Služby (inside `ExpansionTile`).
  ///
  /// PROČ: na Webu chceme zprávy přímo u konkrétní služby (viz unification UX),
  /// zatímco mobilní Worker flow zůstává zachovaný přes Bottom Sheet.
  Widget _buildReservationServiceMessagesSection(
    BuildContext context, {
    required String serviceTriggerCode,
  }) {
    final templatesAsync = ref.watch(messageTemplatesAdminProvider);
    final apartments =
        ref.watch(apartmentsFullListProvider).valueOrNull ?? <ApartmentRow>[];
    final apt = apartments
        .where((a) => a.id == _selectedApartmentId)
        .firstOrNull;
    final aptCtx = apt != null
        ? ApartmentPlaceholderContext(
            name: apt.name,
            address: apt.address,
            keybox: apt.keybox,
            parkingInstructions: apt.parkingInstructions,
            reviewLink: apt.reviewLink,
            ownerNotes: apt.ownerNotes,
          )
        : null;
    final ctx = MessageTemplateSelectorContext.fromReservation(
      widget.reservation,
      apartment: aptCtx,
      tenantIanaTimezone: ref.read(authNotifierProvider).state.effectiveTenantTimezone,
    );

    final normalizedServiceCode = serviceTriggerCode.trim().toLowerCase();
    final lastTemplateId =
        _lastCommunicationTemplateIdUi ??
        widget.reservation.lastCommunicationTemplateId;
    final lastAt =
        _lastCommunicationAtUi ?? widget.reservation.lastCommunicationAt;

    return templatesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: AppSpacing.lg,
          height: AppSpacing.lg,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (Object? err, StackTrace? stackTrace) {
        if (kDebugMode) {
          debugPrint('WhatsApp templates load: $err');
          debugPrint('$stackTrace');
        }
        return const SizedBox.shrink();
      },
      data: (allTemplates) {
        final guestLangLower = _guestLanguage.trim().isNotEmpty
            ? _guestLanguage.trim().toLowerCase()
            : 'en';
        final filtered = allTemplates.where((t) {
          if (t.channel != 'whatsapp') return false;
          final body = t.resolvedBodyForGuest(guestLangLower);
          if (body.trim().isEmpty) return false;

          final trig = t.triggerContext?.trim().toLowerCase();
          if (trig == null || trig.isEmpty) return true; // general template
          return trig == normalizedServiceCode;
        }).toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'communication.service_messages_title'.tr(),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              ...filtered.map((template) {
                final isSent = lastTemplateId == template.id;
                final dateStr = lastAt != null
                    ? DateFormat('d.M.').format(lastAt.toLocal())
                    : null;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    template.name,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSent && lastAt != null) ...[
                        Icon(
                          Icons.check_circle,
                          color: context.customColors.success,
                          size: AppSpacing.lg,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'communication.message_generated_label'.tr(
                            namedArgs: {'date': dateStr ?? ''},
                          ),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                      ],
                      IconButton(
                        icon: Icon(
                          Icons.chat,
                          color: context.customColors.success,
                          size: AppSpacing.lg,
                        ),
                        tooltip:
                            'communication.template_selector_whatsapp_tooltip'
                                .tr(),
                        onPressed: () async {
                          final ok = await WhatsAppSenderService.send(
                            context,
                            ref,
                            ctx,
                            WhatsAppTemplateData(
                              name: template.name,
                              body: template.resolvedBodyForGuest(
                                guestLangLower,
                              ),
                              triggerContext: template.triggerContext,
                              templateId: template.id,
                            ),
                          );
                          if (!mounted) return;
                          if (ok) {
                            setState(() {
                              _lastCommunicationTemplateIdUi = template.id;
                              _lastCommunicationAtUi = DateTime.now().toUtc();
                            });
                            ref.invalidate(adminReservationsProvider);
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    // Související úkoly: načítáme VŠECHNY úkoly s reservation_id == tato rezervace (bez měsíčního filtru),
    // aby se zobrazily i check-out úkoly v dalším měsíci. [adminTasksStreamProvider] je omezen na vybraný měsíc.
    final tasksAsync = ref.watch(
      tasksForReservationProvider(widget.reservation.id),
    );

    // Auditing: Zámek editace pro ukončené rezervace – neměnnost historie pro účetní audit.
    final isReadOnly =
        widget.reservation.status == 'checked_out' ||
        widget.reservation.status == 'cancelled';

    final refNum = widget.reservation.referenceNumber?.trim();
    final title = refNum != null && refNum.isNotEmpty
        ? '${'admin.reservations_edit'.tr()} • #$refNum'
        : 'admin.reservations_edit'.tr();
    return ModernAdminPanel(
      title: title,
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: apartmentsAsync.when(
          data: (apartments) {
            if (apartments.isEmpty) {
              return Text(
                'admin.reservations_no_apartments'.tr(),
                style: TextStyle(color: context.colors.onSurfaceVariant),
              );
            }
            return DefaultTabController(
              length: 3,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminReservationCrossLinkRow(reservation: widget.reservation),
                  if (isReadOnly) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + AppSpacing.xs,
                      ),
                      margin: const EdgeInsets.only(
                        bottom: AppSpacing.sm + AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(
                          color: context.colors.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: context.colors.onPrimaryContainer,
                            size: AppSpacing.lg,
                          ),
                          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'admin.reservations_reservation_locked_info'.tr(),
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colors.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TabBar(
                    labelColor: context.colors.primary,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.info_outline),
                        text: 'admin.reservations_tab_stay_details'.tr(),
                      ),
                      Tab(
                        icon: const Icon(Icons.room_service_outlined),
                        text: 'admin.reservations_tab_services_requests'.tr(),
                      ),
                      Tab(
                        icon: const Icon(Icons.history_outlined),
                        text: 'admin.reservations_tab_communication_history'.tr(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: _buildEditTab1StayDetails(
                            context,
                            apartments,
                            tasksAsync,
                            isReadOnly,
                          ),
                        ),
                        SingleChildScrollView(
                          child: _buildEditTab2ServicesRequests(
                            context,
                            isReadOnly,
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: ReservationCommunicationHistorySection(
                            reservationId: widget.reservation.id,
                          ),
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
            style: TextStyle(color: context.colors.error),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(
            isReadOnly ? 'common.close'.tr() : 'admin.reservations_cancel'.tr(),
          ),
        ),
        if (!isReadOnly) ...[
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _isSaving ? null : _onSave,
            child: _isSaving
                ? const SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('admin.reservations_save_button'.tr()),
          ),
        ],
      ],
    );
  }
}
