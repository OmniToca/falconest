import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/models/zone_model.dart';
import 'package:falconest/features/admin/providers/zones_provider.dart';

/// Dialog pro přidání nebo úpravu oblasti (zóny). Vizualně sjednocený s ServiceEditorDialog –
/// stejný styl inputů (zaoblené rohy), stejná tlačítka Zrušit/Uložit.
class ZoneEditorDialog extends ConsumerStatefulWidget {
  const ZoneEditorDialog({
    super.key,
    this.existing,
  });

  /// Při editaci předaný záznam; při přidání null.
  final ZoneRow? existing;

  @override
  ConsumerState<ZoneEditorDialog> createState() => _ZoneEditorDialogState();
}

class _ZoneEditorDialogState extends ConsumerState<ZoneEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final name = _nameController.text.trim();
    try {
      if (_isEditing) {
        await ZonesRepository.update(
          widget.existing!.copyWith(name: name),
        );
      } else {
        final tenantId = ref.read(authNotifierProvider).tenantIdForData ?? '';
        if (tenantId.isEmpty) {
          setState(() => _isSaving = false);
          return;
        }
        await ZonesRepository.insert(
          ZoneRow(id: '', tenantId: tenantId, name: name),
        );
      }
      ref.invalidate(zonesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.zone_saved'.tr()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.zone_save_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red.shade700,
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
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing
                  ? 'admin.edit_zone'.tr()
                  : 'admin.add_zone'.tr(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'common.cancel'.tr(),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'admin.zone_name'.tr(),
              hintText: 'admin.zone_name_hint'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty)
                    ? 'admin.validation_zone_name_required'.tr()
                    : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
