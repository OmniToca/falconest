import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';

/// Formulář pro přidání nebo úpravu modulu v katalogu (Super Admin).
///
/// Lze otevřít jako celoobrazovkovou stránku (route) nebo jako modální dialog ([asDialog] = true).
/// Key je při editaci read-only.
class ModuleEditorScreen extends ConsumerStatefulWidget {
  const ModuleEditorScreen({
    super.key,
    this.existingModule,
    this.asDialog = false,
  });

  /// Předaný modul při editaci (např. z GoRouter state.extra).
  final ModuleModel? existingModule;
  /// true = zobrazit jako dialog (zaoblený, s X), false = celá stránka se Scaffold.
  final bool asDialog;

  @override
  ConsumerState<ModuleEditorScreen> createState() => _ModuleEditorScreenState();
}

class _ModuleEditorScreenState extends ConsumerState<ModuleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _keyController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _orderIndexController;

  String _pricingType = 'fixed';
  bool _isSaving = false;
  /// Zobrazit v levém menu (show_in_menu). Výchozí true.
  bool _showInMenu = true;
  /// Klíč nadřazeného modulu (sub-modul). Null = hlavní modul.
  String? _parentModuleKey;

  @override
  void initState() {
    super.initState();
    final m = widget.existingModule;
    _nameController = TextEditingController(text: m?.name ?? '');
    _keyController = TextEditingController(text: m?.key ?? '');
    _descriptionController = TextEditingController(text: m?.description ?? '');
    _priceController = TextEditingController(
      text: m?.price != null ? m!.price.toString() : '',
    );
    _orderIndexController = TextEditingController(
      text: m?.orderIndex != null ? m!.orderIndex.toString() : '99',
    );
    _pricingType = m?.pricingType ?? 'fixed';
    _showInMenu = m?.showInMenu ?? true;
    _parentModuleKey = m?.parentModuleKey?.isEmpty == true ? null : m?.parentModuleKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _orderIndexController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingModule != null;

  /// Hlavička dialogu: titulek + tlačítko Zavřít (X).
  Widget _buildDialogHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing
                  ? 'settings.editor_title_edit'.tr()
                  : 'settings.editor_title_new'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'common.cancel'.tr(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formContent = Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildFormFields(context),
        ),
      ),
    );

    if (widget.asDialog) {
      final maxHeight = MediaQuery.of(context).size.height * 0.85;
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600, maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(context),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: formContent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'settings.editor_title_edit'.tr()
              : 'settings.editor_title_new'.tr(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: formContent,
          ),
        ),
      ),
    );
  }

  /// Seznam widgetů formuláře (pole + tlačítko Uložit).
  List<Widget> _buildFormFields(BuildContext context) {
    return [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'settings.field_name'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'admin.validation_name_required'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _keyController,
              readOnly: _isEditing,
              decoration: InputDecoration(
                labelText: 'settings.field_key'.tr(),
                hintText: 'settings.field_key_hint'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: _isEditing,
                fillColor: _isEditing ? Colors.grey.shade200 : null,
                helperText: _isEditing ? 'settings.field_key_edit_hint'.tr() : null,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'settings.validation_key_required'.tr();
                }
                if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                  return 'settings.validation_key_format'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'settings.field_description'.tr(),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'settings.field_price_eur'.tr(),
                hintText: 'settings.field_price_eur_hint'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _pricingType,
              decoration: InputDecoration(
                labelText: 'settings.field_pricing_type'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: [
                DropdownMenuItem(
                  value: 'fixed',
                  child: Text('settings.pricing_fixed'.tr()),
                ),
                DropdownMenuItem(
                  value: 'per_apartment',
                  child: Text('settings.pricing_per_apartment'.tr()),
                ),
                DropdownMenuItem(
                  value: 'per_user',
                  child: Text('settings.pricing_per_user'.tr()),
                ),
              ],
              onChanged: (v) => setState(() => _pricingType = v ?? 'fixed'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _orderIndexController,
              decoration: InputDecoration(
                labelText: 'settings.field_order_index'.tr(),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) {
                  return 'settings.validation_order_index_non_negative'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: Text('settings.field_show_in_menu'.tr()),
              value: _showInMenu,
              onChanged: (v) => setState(() => _showInMenu = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final modulesAsync = ref.watch(allModulesProvider);
                return modulesAsync.when(
                  data: (modules) {
                    final parentOptions = [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('settings.parent_module_none'.tr()),
                      ),
                      ...modules
                          .where((m) => m.key != _keyController.text.trim())
                          .map((m) => DropdownMenuItem<String?>(
                                value: m.key,
                                child: Text(m.name),
                              )),
                    ];
                    return DropdownButtonFormField<String?>(
                      initialValue: _parentModuleKey,
                      decoration: InputDecoration(
                        labelText: 'settings.field_parent_module'.tr(),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: parentOptions,
                      onChanged: (v) => setState(() => _parentModuleKey = v),
                    );
                  },
                  loading: () => const SizedBox(height: 48),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 24),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ),
    ];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final key = _keyController.text.trim();
    final description = _descriptionController.text.trim();
    final priceRaw = _priceController.text.trim();
    final price = priceRaw.isEmpty ? null : num.tryParse(priceRaw);
    final orderIndex =
        int.tryParse(_orderIndexController.text.trim()) ?? 99;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final existing = widget.existingModule!;
        final updated = ModuleModel(
          id: existing.id,
          key: existing.key,
          name: name,
          sortOrder: existing.sortOrder,
          orderIndex: orderIndex,
          price: price,
          pricingType: _pricingType,
          description: description.isEmpty ? null : description,
          showInMenu: _showInMenu,
          parentModuleKey: _parentModuleKey?.isEmpty == true ? null : _parentModuleKey,
        );
        await SuperAdminService.updateModule(updated);
      } else {
        final newModule = ModuleModel(
          id: '',
          key: key,
          name: name,
          sortOrder: 0,
          orderIndex: orderIndex,
          price: price,
          pricingType: _pricingType,
          description: description.isEmpty ? null : description,
          showInMenu: _showInMenu,
          parentModuleKey: _parentModuleKey?.isEmpty == true ? null : _parentModuleKey,
        );
        await SuperAdminService.createModule(newModule);
      }
      ref.invalidate(allModulesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.module_saved'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'common.generic_error_user_friendly'.tr(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
