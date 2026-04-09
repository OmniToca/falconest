import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/providers/hq_team_providers.dart';

/// Modální dialog pro přidání dovolené (absence) HQ člena do [staff_absences].
///
/// PROČ: U HQ členů ukládáme řádek s [tenant_id] = null, aby absence nepatřila k žádné
/// agentuře. Po uložení invalidujeme [hqStaffAbsencesProvider], aby záložka Dovolené
/// okamžitě zobrazila nový záznam.
/// Používá [showAppModal] pro jednotný vizuál (blur, animace) s Nastavením a Fakturačním modalem.
class AddHqAbsenceDialog extends ConsumerStatefulWidget {
  const AddHqAbsenceDialog({super.key, required this.profileId});

  final String profileId;

  /// Otevře dialog. Po úspěšném uložení invaliduje [hqStaffAbsencesProvider(profileId)].
  static Future<void> show(BuildContext context, WidgetRef ref, String profileId) {
    return showAppModal<void>(
      context: context,
      barrierLabel: 'super_admin.barrier_hq_absence'.tr(),
      maxWidth: 420,
      child: AddHqAbsenceDialog(profileId: profileId),
    );
  }

  @override
  ConsumerState<AddHqAbsenceDialog> createState() => _AddHqAbsenceDialogState();
}

class _AddHqAbsenceDialogState extends ConsumerState<AddHqAbsenceDialog> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_fromDate == null || _toDate == null) return;
    if (_toDate!.isBefore(_fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.hq_absence_date_range'.tr()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'profile_id': widget.profileId,
        'tenant_id': null,
        'start_date': _fromDate!.toUtc().toIso8601String(),
        'end_date': _toDate!.toUtc().toIso8601String(),
        'reason': _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      };
      await SupabaseService.client.from('staff_absences').insert(payload);
      if (!mounted) return;
      ref.invalidate(hqStaffAbsencesProvider(widget.profileId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.hq_absence_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.generic_error_user_friendly'.tr()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('super_admin.hq_absence_add_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('super_admin.hq_absence_from'.tr()),
            subtitle: Text(_fromDate != null ? '${_fromDate!.day}.${_fromDate!.month}.${_fromDate!.year}' : 'common.placeholder_dash'.tr()),
            trailing: TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fromDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _fromDate = d);
              },
              child: Text('super_admin.hq_absence_pick'.tr()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('super_admin.hq_absence_to'.tr()),
            subtitle: Text(_toDate != null ? '${_toDate!.day}.${_toDate!.month}.${_toDate!.year}' : 'common.placeholder_dash'.tr()),
            trailing: TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                  firstDate: _fromDate ?? DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _toDate = d);
              },
              child: Text('super_admin.hq_absence_pick'.tr()),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'super_admin.hq_absence_reason'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('common.save'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
