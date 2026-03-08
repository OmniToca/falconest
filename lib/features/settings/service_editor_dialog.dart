import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Dialog pro přidání nebo úpravu služby v katalogu agentury (tenant_services).
///
/// Při [existing] == null jde o novou službu; jinak o editaci. Ukládání volá
/// TenantServicesRepository.insert/update a invaliduje [tenantServicesProvider].
class ServiceEditorDialog extends ConsumerStatefulWidget {
  const ServiceEditorDialog({
    super.key,
    this.existing,
  });

  /// Při editaci předaný záznam; při přidání null.
  final TenantServiceModel? existing;

  @override
  ConsumerState<ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends ConsumerState<ServiceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _defaultPriceController;
  late TextEditingController _orderIndexController;
  late TextEditingController _durationMinutesController;

  String _serviceType = 'cleaning';
  String _requiredRole = 'any';
  bool _isActive = true;
  bool _requiresPhoto = false;
  bool _isSaving = false;
  /// Zda už byl do pole ceny nastaven přepočet z EUR na lokální měnu (pouze při editaci).
  bool _initialPriceSet = false;

  /// Možnosti pro požadovanou profesi (kdo službu vykonává). any = kdokoliv.
  static const List<String> _requiredRoleValues = ['any', 'cleaner', 'driver', 'maintenance', 'checkin_agent'];

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    // Při editaci se hodnota pro zobrazení nastaví v build() po načtení kurzů (_loadPriceForDisplay).
    _defaultPriceController = TextEditingController(text: '');
    _orderIndexController = TextEditingController(
      text: s?.orderIndex.toString() ?? '0',
    );
    _durationMinutesController = TextEditingController(
      text: s?.durationMinutes?.toString() ?? '60',
    );
    _serviceType = s?.serviceType ?? 'cleaning';
    _requiredRole = (s?.requiredRole != null && _requiredRoleValues.contains(s!.requiredRole))
        ? s.requiredRole!
        : 'any';
    _isActive = s?.isActive ?? true;
    _requiresPhoto = s?.requiresPhoto ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _defaultPriceController.dispose();
    _orderIndexController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  /// Načte cenu z DB (v EUR), přepočte na uživatelovu měnu a vrátí ji jako řetězec do textového pole.
  /// Používá se při otevření dialogu pro editaci – uživatel vidí a edituje cenu v lokální měně.
  void _loadPriceForDisplay() {
    final s = widget.existing;
    if (s?.defaultPrice == null || _initialPriceSet) return;
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final preferredCurrency = ref.read(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final effectiveCurrencies = currencies.isEmpty
        ? [const CurrencyRow(code: 'EUR', symbol: '€', rate: 1.0)]
        : currencies;
    final localAmount = CurrencyService.convert(
      s!.defaultPrice!.toDouble(),
      preferredCurrency,
      effectiveCurrencies,
    );
    _defaultPriceController.text = _formatPriceForInput(localAmount);
    _initialPriceSet = true;
  }

  /// Zformátuje částku pro zobrazení v inputu (bez symbolu; uživatel zadává číslo v lokální měně).
  static String _formatPriceForInput(double amount) {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// Z textového pole přečte číslo (čárka → tečka, ignorace nečíselných znaků), přepočte z lokální měny do EUR a vrátí hodnotu pro uložení do DB.
  /// Při chybějícím kurzu se použije fallback 1.0 (zadaná hodnota = EUR).
  static double? _parsePriceForSave(
    String input,
    String preferredCurrency,
    List<CurrencyRow> currencies,
  ) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null) return null;
    final effectiveCurrencies = currencies.isEmpty
        ? [const CurrencyRow(code: 'EUR', symbol: '€', rate: 1.0)]
        : currencies;
    return CurrencyService.toEur(parsed, preferredCurrency, effectiveCurrencies);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final tenantId = ref.read(authNotifierProvider).tenantIdForData ?? '';
    final preferredCurrency = ref.read(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
    final priceInEur = _parsePriceForSave(
      _defaultPriceController.text,
      preferredCurrency,
      currencies,
    );
    num? price = priceInEur;
    int orderIndex = 0;
    final orderStr = _orderIndexController.text.trim();
    if (orderStr.isNotEmpty) {
      orderIndex = int.tryParse(orderStr) ?? 0;
    }
    final durationStr = _durationMinutesController.text.trim();
    final durationMinutes = durationStr.isEmpty ? 60 : (int.tryParse(durationStr) ?? 60);
    final model = TenantServiceModel(
      id: widget.existing?.id ?? '',
      tenantId: tenantId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      serviceType: _serviceType,
      defaultPrice: price,
      isActive: _isActive,
      orderIndex: orderIndex,
      requiredRole: _requiredRole == 'any' ? null : _requiredRole,
      durationMinutes: durationMinutes,
      requiresPhoto: _requiresPhoto,
    );
    try {
      if (_isEditing) {
        await TenantServicesRepository.update(model);
      } else {
        await TenantServicesRepository.insert(model);
      }
      ref.invalidate(tenantServicesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.service_saved'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.service_save_error'.tr(namedArgs: {'error': e.toString()})),
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
    // Při editaci naplníme pole ceny přepočtem EUR → lokální měna (jednorázově).
    _loadPriceForDisplay();
    final userCurrencyCode = ref.read(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final categoriesAsync = ref.watch(taskCategoriesProvider);
    final categoriesByCode = categoriesAsync.valueOrNull ?? {};
    // Položky dropdownu z DB – seřazeno podle order_index.
    final sortedCategories = categoriesByCode.values.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final categoryCodes = sortedCategories.map((c) => c.code).toList();
    final effectiveCodes = List<String>.from(categoryCodes);
    // Fallback: stará hodnota (např. 'transfer') která v categories není – přidáme, aby dropdown nepadl.
    if (_serviceType.isNotEmpty && !effectiveCodes.contains(_serviceType)) {
      effectiveCodes.add(_serviceType);
    }
    if (effectiveCodes.isEmpty) effectiveCodes.add('cleaning');
    final validServiceType = effectiveCodes.contains(_serviceType) ? _serviceType : effectiveCodes.first;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing
                  ? 'settings.editor_title_edit_service'.tr()
                  : 'settings.editor_title_new_service'.tr(),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'settings.field_name'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'settings.validation_key_required'.tr() : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: validServiceType,
                  decoration: InputDecoration(
                    labelText: 'settings.field_service_type'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: effectiveCodes
                      .map((code) => DropdownMenuItem(
                            value: code,
                            child: Text('admin.task_type_$code'.tr()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _serviceType = v ?? 'cleaning'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _requiredRoleValues.contains(_requiredRole) ? _requiredRole : 'any',
                  decoration: InputDecoration(
                    labelText: 'settings.field_required_role'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _requiredRoleValues.map((r) {
                    final key = 'settings.required_role_$r';
                    return DropdownMenuItem(value: r, child: Text(key.tr()));
                  }).toList(),
                  onChanged: (v) => setState(() => _requiredRole = v ?? 'any'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'settings.field_description'.tr(),
                    hintText: 'settings.service_description_hint'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _defaultPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${'settings.field_default_price'.tr()} ($userCurrencyCode)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _orderIndexController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'settings.field_order_index'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'settings.field_duration_minutes'.tr(),
                    hintText: 'settings.service_duration_minutes_hint'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('settings.field_requires_photo'.tr()),
                  subtitle: Text(
                    'settings.field_requires_photo_hint'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: _requiresPhoto,
                  onChanged: (v) => setState(() => _requiresPhoto = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('settings.field_active'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 12),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ],
            ),
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
