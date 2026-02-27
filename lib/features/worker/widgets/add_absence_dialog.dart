import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';

/// Důvody nepřítomnosti – volby pro dropdown.
const _reasonVacation = 'vacation';
const _reasonSick = 'sick';
const _reasonOther = 'other';

/// Dialog pro přidání nové nepřítomnosti (dovolená, nemoc).
///
/// PROČ offline: Worker může hlásit nemoc i v bytě bez signálu. Při síťové chybě
/// se zápis uloží do MutationQueueService a odešle při obnovení připojení.
class AddAbsenceDialog extends ConsumerStatefulWidget {
  const AddAbsenceDialog({super.key, required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<AddAbsenceDialog> createState() => _AddAbsenceDialogState();
}

class _AddAbsenceDialogState extends ConsumerState<AddAbsenceDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _reason = _reasonVacation;
  bool _isSaving = false;

  Future<void> _pickStartDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final initial = _endDate ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  String _reasonLabel(String key) {
    switch (key) {
      case _reasonVacation:
        return 'worker.absence_reason_vacation'.tr();
      case _reasonSick:
        return 'worker.absence_reason_sick'.tr();
      case _reasonOther:
        return 'worker.absence_reason_other'.tr();
      default:
        return key;
    }
  }

  /// Vytvoření upozorňovacího úkolu pro dispečera – zobrazení v kalendáři při hlášení nepřítomnosti.
  /// Obsahuje lokalizovaný důvod, jméno pracovníka a rozsah dat.
  Map<String, dynamic> _buildAlertTaskPayload({
    required String tenantId,
    required String profileId,
    required String translatedReason,
    required String userName,
    required String formattedStart,
    required String formattedEnd,
    required String startIso,
  }) {
    final title = '$translatedReason: $userName ($formattedStart - $formattedEnd)';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'id': const Uuid().v4(),
      'tenant_id': tenantId,
      'reference_number': generateTaskRef(),
      'task_type': 'other',
      'status': 'pending',
      'title': title,
      'description': 'worker.absence_alert_task_description'.tr(),
      'created_by': profileId,
      'apartment_id': null,
      'assigned_to': null,
      'scheduled_start': startIso,
      'due_date': startIso,
      'local_updated_at': nowIso,
      'metadata': <String, dynamic>{},
    };
  }

  Future<void> _submit() async {
    if (_startDate == null) return;
    if (_endDate != null && _endDate!.isBefore(_startDate!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.absence_end_before_start'.tr()),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }
    if (_isSaving) return;

    final auth = ref.read(authNotifierProvider);
    final profileId = auth.state.profileId;
    final tenantId = auth.tenantIdForData;
    if (profileId == null || tenantId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.absence_save_error'.tr(namedArgs: {'error': 'Missing profile or tenant'})),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    // Načtení jména přihlášeného uživatele pro titul alert úkolu.
    final profile = await ref.read(currentUserProfileProvider.future);
    final userName = profile.name.trim().isNotEmpty ? profile.name.trim() : 'worker.drawer_my_profile'.tr();

    // Formát jako v Admin – ISO pro konzistenci s StaffAbsence.fromJson.
    final startStr = _startDate!.toIso8601String();
    final endStr = (_endDate ?? _startDate!).toIso8601String();
    final formattedStart = DateFormat('dd.MM.yyyy').format(_startDate!);
    final formattedEnd = DateFormat('dd.MM.yyyy').format(_endDate ?? _startDate!);
    final translatedReason = _reasonLabel(_reason);

    final payload = <String, dynamic>{
      'id': const Uuid().v4(),
      'tenant_id': tenantId,
      'profile_id': profileId,
      'start_date': startStr,
      'end_date': endStr,
      'reason': _reason,
    };

    // Vytvoření upozorňovacího úkolu pro dispečera – zobrazí se v kalendáři jako nepřiřazený.
    final alertTaskPayload = _buildAlertTaskPayload(
      tenantId: tenantId,
      profileId: profileId,
      translatedReason: translatedReason,
      userName: userName,
      formattedStart: formattedStart,
      formattedEnd: formattedEnd,
      startIso: startStr,
    );

    try {
      await SupabaseService.client.from('staff_absences').insert(payload);
      await SupabaseService.client.from('tasks').insert(alertTaskPayload);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.absence_saved'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      // Offline check – fronta mutací pro mobil bez Isar na webu nic nedělá.
      if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
        await ref.read(mutationQueueServiceProvider).enqueueMutation(
              table: 'staff_absences',
              action: 'INSERT',
              payload: payload,
            );
        await ref.read(mutationQueueServiceProvider).enqueueMutation(
              table: 'tasks',
              action: 'INSERT',
              payload: alertTaskPayload,
            );
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.absence_queued_offline'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('worker.absence_save_error'.tr(namedArgs: {'error': e.toString()})),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.event_busy, color: _primaryBlue),
          const SizedBox(width: 8),
          Text('worker.absence_add_title'.tr()),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('worker.absence_from'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _pickStartDate(context),
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_startDate != null ? DateFormat('dd.MM.yyyy').format(_startDate!) : 'worker.absence_select_date'.tr()),
            ),
            const SizedBox(height: 16),
            Text('worker.absence_to'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _pickEndDate(context),
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_endDate != null ? DateFormat('dd.MM.yyyy').format(_endDate!) : 'worker.absence_select_date'.tr()),
            ),
            const SizedBox(height: 16),
            Text('worker.absence_reason_label'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            InputDecorator(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reason,
                  isExpanded: true,
                  items: [_reasonVacation, _reasonSick, _reasonOther]
                      .map((k) => DropdownMenuItem(value: k, child: Text(_reasonLabel(k))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _reason = v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSaving || _startDate == null
              ? null
              : _submit,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('worker.absence_add_button'.tr()),
        ),
      ],
    );
  }
}

const _primaryBlue = Color(0xFF1565C0);
