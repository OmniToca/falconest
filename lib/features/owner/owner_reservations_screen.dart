import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_reservations_provider.dart';

/// Přehled rezervací majitele – kalendář s vizuálními značkami a možností přidat rezervaci.
///
/// Používá [ownerReservationsProvider] pro načtení rezervací ze Supabase.
/// Dny spadající do rezervace mají marker v kalendáři. FAB otevře Modal Bottom
/// Sheet s formulářem pro novou rezervaci.
class OwnerReservationsScreen extends ConsumerStatefulWidget {
  const OwnerReservationsScreen({super.key});

  @override
  ConsumerState<OwnerReservationsScreen> createState() =>
      _OwnerReservationsScreenState();
}

class _OwnerReservationsScreenState extends ConsumerState<OwnerReservationsScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(ownerReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('owner.reservations_title'.tr()),
      ),
      body: reservationsAsync.when(
        data: (reservations) => _CalendarBody(
          reservations: reservations,
          focusedDay: _focusedDay,
          onPageChanged: (day) => setState(() => _focusedDay = day),
          onFocusedDayChanged: (day) => setState(() => _focusedDay = day),
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
                onPressed: () => ref.invalidate(ownerReservationsProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewReservationSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text('owner.reservations_new'.tr()),
      ),
    );
  }

  /// Otevře Modal Bottom Sheet s formulářem pro novou rezervaci.
  void _showNewReservationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _NewReservationForm(
        ref: ref,
        onSaved: () {
          Navigator.of(sheetContext).pop();
          ref.invalidate(ownerReservationsProvider);
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
              content: Text('owner.reservations_save_error'.tr(namedArgs: {'error': error})),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }
}

/// Tělo kalendáře s TableCalendar a tlačítkem pro novou rezervaci.
class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.reservations,
    required this.focusedDay,
    required this.onPageChanged,
    required this.onFocusedDayChanged,
  });

  final List<OwnerReservation> reservations;
  final DateTime focusedDay;
  final void Function(DateTime) onPageChanged;
  final void Function(DateTime) onFocusedDayChanged;

  /// Vrací rezervace, které obsahují daný den (pro eventLoader).
  List<OwnerReservation> _getEventsForDay(DateTime day) {
    return reservations.where((r) => r.containsDay(day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar<OwnerReservation>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            locale: context.locale.toString(),
            eventLoader: _getEventsForDay,
            onPageChanged: onPageChanged,
            onDaySelected: (_, focused) => onFocusedDayChanged(focused),
            calendarBuilders: CalendarBuilders<OwnerReservation>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulář pro novou rezervaci v Modal Bottom Sheet.
class _NewReservationForm extends ConsumerStatefulWidget {
  const _NewReservationForm({
    required this.ref,
    required this.onSaved,
    required this.onError,
  });

  final WidgetRef ref;
  final VoidCallback onSaved;
  final void Function(String error) onError;

  @override
  ConsumerState<_NewReservationForm> createState() => _NewReservationFormState();
}

class _NewReservationFormState extends ConsumerState<_NewReservationForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedApartmentId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _specialRequestsController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  /// Ukládá rezervaci do Supabase včetně automatického vytvoření úkolu.
  ///
  /// Logika:
  /// 1. Kontrola času (express úklid): Pokud je Datum OD dříve než za 24 h,
  ///    zobrazí se dialog s varováním. Uživatel může ukládání zrušit nebo potvrdit.
  /// 2. Dvojitý zápis: Do tabulky reservations se zapíše rezervace; souběžně
  ///    se vytvoří úkol v tasks (pending, scheduled_start = Datum OD, description
  ///    = speciální požadavky, created_by = ID majitele).
  /// 3. Při úspěchu: zavření modalu, invalidace provideru, zelený SnackBar.
  ///    Při chybě: červený SnackBar s výpisem.
  Future<void> _saveReservation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartmentId == null || _dateFrom == null || _dateTo == null) return;

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

    setState(() => _isSaving = true);

    try {
      // ID přihlášeného majitele – pro created_by a případný tenant_id
      final client = SupabaseService.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Nepřihlášený uživatel');
      }
      final ownerId = currentUser.id;
      final specialRequests = _specialRequestsController.text.trim();
      final specialRequestsOrNull =
          specialRequests.isEmpty ? null : specialRequests;

      // -----------------------------------------------------------------------
      // KROK 2a: Zápis rezervace do tabulky reservations
      // -----------------------------------------------------------------------
      await client.from('reservations').insert({
        'apartment_id': _selectedApartmentId,
        'start_date': _formatDate(_dateFrom!),
        'end_date': _formatDate(_dateTo!),
        'special_requests': specialRequestsOrNull,
      });

      // -----------------------------------------------------------------------
      // KROK 2b: Zápis nového úkolu do tabulky tasks (souvisí s rezervací)
      // -----------------------------------------------------------------------
      final scheduledStart = DateTime(
        _dateFrom!.year,
        _dateFrom!.month,
        _dateFrom!.day,
        9,
        0,
      );
      await client.from('tasks').insert({
        'tenant_id': ownerId,
        'apartment_id': _selectedApartmentId,
        'scheduled_start': scheduledStart.toIso8601String(),
        'status': 'pending',
        'description': specialRequestsOrNull,
        'created_by': ownerId,
      });

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

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = widget.ref.watch(ownerApartmentsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'owner.reservations_new'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                apartmentsAsync.when(
                  data: (apartments) {
                    if (apartments.isEmpty) {
                      return Text(
                        'owner.apartments_empty'.tr(),
                        style: TextStyle(color: Colors.grey.shade700),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedApartmentId,
                      decoration: InputDecoration(
                        labelText: 'owner.reservations_apartment_hint'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: apartments
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedApartmentId = v),
                      validator: (v) =>
                          v == null ? 'owner.validation_apartment_required'.tr() : null,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Text(
                    'owner.apartments_load_error'.tr(),
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('owner.reservations_date_from'.tr()),
                  subtitle: Text(
                    _dateFrom != null ? _formatDate(_dateFrom!) : 'admin.date_pick_hint'.tr(),
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
                    _dateTo != null ? _formatDate(_dateTo!) : 'admin.date_pick_hint'.tr(),
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
                const SizedBox(height: 8),
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
      ),
    );
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
