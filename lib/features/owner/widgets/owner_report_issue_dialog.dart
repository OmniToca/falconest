import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/features/owner/widgets/owner_read_only_gate.dart';

import 'package:falconest/core/utils/id_generator.dart';
import 'package:falconest/core/repositories/task/supabase_task_insert_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Dialog pro nahlášení závady majitelem (údržba, porucha).
///
/// Čistý StatefulWidget – žádný Riverpod ref uvnitř. Všechna data (apartmány,
/// profileId) se předávají z nadřazené obrazovky přes konstruktor.
///
/// Při odeslání: načte tenant_id z vybraného bytu, INSERT do tasks s
/// task_type=maintenance, status=pending, created_by=currentUserProfileId.
/// Po úspěchu zavře dialog (pop(true)); SnackBar zobrazí volající.
///
/// Pro otevření z obrazovky s ref volej [openOwnerReportIssueDialog].
void openOwnerReportIssueDialog(
  BuildContext context, {
  required WidgetRef ref,
  required List<OwnerApartmentWithStatus> apartments,
  required String profileId,
  String? preselectedApartmentId,
  VoidCallback? onSuccess,
}) {
  if (isOwnerPortalReadOnly(ref)) return;
  showDialog<bool>(
    context: context,
    builder: (ctx) => OwnerReportIssueDialog(
      apartments: apartments,
      currentUserProfileId: profileId,
      preselectedApartmentId: preselectedApartmentId,
    ),
  ).then((success) {
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.report_issue_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );
      onSuccess?.call();
    }
  });
}

class OwnerReportIssueDialog extends StatefulWidget {
  const OwnerReportIssueDialog({
    super.key,
    required this.apartments,
    required this.currentUserProfileId,
    this.preselectedApartmentId,
  });

  /// Seznam bytů majitele – předaný z rodiče (ref.read venku).
  final List<OwnerApartmentWithStatus> apartments;

  /// Předvybraný byt (např. z kontextu detailu bytu). Null = první v seznamu.
  final String? preselectedApartmentId;

  /// ID profilu přihlášeného majitele (profiles.id) – pro created_by v tasks.
  final String currentUserProfileId;

  @override
  State<OwnerReportIssueDialog> createState() => _OwnerReportIssueDialogState();
}

class _OwnerReportIssueDialogState extends State<OwnerReportIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedApartmentId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.apartments.isNotEmpty) {
      final preselected = widget.preselectedApartmentId;
      final validPreselected = preselected != null &&
          widget.apartments.any((a) => a.id == preselected);
      _selectedApartmentId = validPreselected
          ? preselected
          : widget.apartments.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Získá tenant_id pro vybraný byt z tabulky apartments (přímý dotaz, bez ref).
  Future<String?> _getTenantIdForApartment(String apartmentId) async {
    if (apartmentId.isEmpty) return null;
    try {
      final res = await SupabaseService.client
          .from('apartments')
          .select('tenant_id')
          .eq('id', apartmentId)
          .maybeSingle();
      if (res == null) return null;
      final tid = res['tenant_id']?.toString().trim();
      return (tid != null && tid.isNotEmpty) ? tid : null;
    } catch (e, st) {
      AppLogger.error('OwnerReportIssueDialog._getTenantIdForApartment selhalo', e, st);
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final apartmentId = _selectedApartmentId;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (apartmentId == null || apartmentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('owner.report_issue_validation_apartment'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final ownedIds = widget.apartments.map((a) => a.id).toSet();
    if (!ownedIds.contains(apartmentId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('owner.reservations_error_apartment_not_owned'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tenantId = await _getTenantIdForApartment(apartmentId);
      if (tenantId == null || tenantId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('owner.report_issue_error'.tr(namedArgs: {'error': 'Byt nemá přiřazenou agenturu'})),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // PROČ: INSERT výhradně přes [SupabaseTaskInsertRepository] – jednotná sanitizace
      // scheduled_start / due_date / metadata.estimated_minutes (Single Source of Truth).
      final nowUtc = DateTime.now().toUtc();
      final dueDate = nowUtc.add(const Duration(days: 3)).toIso8601String();
      final payload = <String, dynamic>{
        'id': const Uuid().v4(),
        'apartment_id': apartmentId,
        'tenant_id': tenantId,
        'reference_number': generateTaskRef(),
        'created_by': widget.currentUserProfileId,
        'title': title,
        'description': description.isEmpty ? null : description,
        'task_type': 'maintenance',
        'status': 'pending',
        'scheduled_start': nowUtc.toIso8601String(),
        'due_date': dueDate,
        'metadata': <String, dynamic>{},
        'local_updated_at': nowUtc.toIso8601String(),
      };
      await SupabaseTaskInsertRepository.createTask(payload); // návratové id zatím nepotřebujeme

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.generic_error_user_friendly'.tr(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartments = widget.apartments;

    return AlertDialog(
      title: Text('owner.report_issue_dialog_title'.tr()),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (apartments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'owner.apartments_empty'.tr(),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedApartmentId,
                  decoration: InputDecoration(
                    labelText: 'owner.report_issue_apartment_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: apartments
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ))
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _selectedApartmentId = v),
                  validator: (v) =>
                      (v == null || v.isEmpty)
                          ? 'owner.report_issue_validation_apartment'.tr()
                          : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'owner.report_issue_title_label'.tr(),
                  hintText: 'owner.report_issue_title_hint'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isLoading,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'owner.report_issue_validation_title'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'owner.report_issue_description_label'.tr(),
                  hintText: 'owner.report_issue_description_hint'.tr(),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                enabled: !_isLoading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isLoading || apartments.isEmpty ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('owner.report_issue_submit'.tr()),
        ),
      ],
    );
  }
}
