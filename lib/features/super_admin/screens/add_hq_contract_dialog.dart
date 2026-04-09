import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/providers/hq_team_providers.dart';

/// Modální dialog pro přidání nové smlouvy do [hq_staff_contracts].
///
/// PROČ: Samostatný widget umožňuje znovupoužití a čitelnost; po uložení invalidujeme
/// [hqStaffActiveContractProvider], aby záložka Smlouva okamžitě zobrazila nová data.
/// Používá [showAppModal] pro jednotný vizuál (blur, animace) s Nastavením a Fakturačním modalem.
class AddHqContractDialog extends ConsumerStatefulWidget {
  const AddHqContractDialog({super.key, required this.profileId});

  final String profileId;

  /// Otevře dialog. Po úspěšném uložení invaliduje [hqStaffActiveContractProvider(profileId)].
  static Future<void> show(BuildContext context, WidgetRef ref, String profileId) {
    return showAppModal<void>(
      context: context,
      barrierLabel: 'super_admin.barrier_hq_contract'.tr(),
      maxWidth: 480,
      child: AddHqContractDialog(profileId: profileId),
    );
  }

  @override
  ConsumerState<AddHqContractDialog> createState() => _AddHqContractDialogState();
}

class _AddHqContractDialogState extends ConsumerState<AddHqContractDialog> {
  final _formKey = GlobalKey<FormState>();
  final _positionController = TextEditingController();
  final _fixedSalaryController = TextEditingController();
  final _bonusController = TextEditingController();
  final _commissionController = TextEditingController();

  String _employmentType = 'hpp';
  DateTime _validFrom = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _positionController.dispose();
    _fixedSalaryController.dispose();
    _bonusController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(hqStaffContractRepositoryProvider);
      await repo.createContract(
        profileId: widget.profileId,
        employmentType: _employmentType,
        positionLabel: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
        fixedSalaryMonthly: _parseNum(_fixedSalaryController.text),
        bonusPerAcquiredAgency: _parseNum(_bonusController.text),
        commissionPercentManaged: _parseNum(_commissionController.text),
        validFrom: _validFrom,
      );
      if (!mounted) return;
      ref.invalidate(hqStaffActiveContractProvider(widget.profileId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.hq_contract_saved'.tr()),
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

  num? _parseNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t.replaceFirst(',', '.'));
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
              Text('super_admin.hq_contract_add_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _employmentType,
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_staff_contract_label_employment'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        DropdownMenuItem(value: 'hpp', child: Text('super_admin.hq_staff_employment_hpp'.tr())),
                        DropdownMenuItem(value: 'ico', child: Text('super_admin.hq_staff_employment_ico'.tr())),
                      ],
                      onChanged: (v) => setState(() => _employmentType = v ?? 'hpp'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _positionController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_staff_contract_label_position'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fixedSalaryController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_staff_contract_label_fixed_salary'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bonusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_staff_contract_label_bonus_acquired'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _commissionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_staff_contract_label_commission'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        final n = _parseNum(v ?? '');
                        if (n != null && (n < 0 || n > 100)) {
                          return 'super_admin.hq_contract_commission_range'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('super_admin.hq_staff_contract_label_validity'.tr()),
                      subtitle: Text(DateFormat('d.M.yyyy').format(_validFrom)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _validFrom,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _validFrom = d);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
