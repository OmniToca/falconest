import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/constants/app_languages.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/utils/geo_json_point.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';

/// Hodnoty client_type v DB – mapování na lokalizované labely.
const _clientTypeOptions = [
  ('owner', 'clients.type_owner'),
  ('external', 'clients.type_external'),
  ('agency', 'clients.type_agency'),
];

/// Dropdown výběr doporučující agentury – pouze klienti s typem agency.
///
/// PROČ oddělený widget: Načítá clientsFullListProvider a filtruje na agency. Zobrazuje se
/// pouze v formuláři při výběru typu "Externí" – externí klient může být evidován
/// s odkazem na agenturu, která nám ho doporučila.
class _AgencyDropdown extends ConsumerWidget {
  const _AgencyDropdown({
    required this.selectedAgencyId,
    this.currentClientId,
    required this.onChanged,
  });

  final String? selectedAgencyId;
  /// Při editaci vynecháme aktuálního klienta (nemůže být sám sobě agenturou).
  final String? currentClientId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsFullListProvider);
    return clientsAsync.when(
      data: (allClients) {
        final agencies = allClients
            .where((c) =>
                (c.clientType?.toLowerCase() ?? '') == 'agency' &&
                c.id != (currentClientId ?? ''))
            .toList();
        return DropdownButtonFormField<String>(
          initialValue: selectedAgencyId != null && selectedAgencyId!.isNotEmpty
              ? (agencies.any((a) => a.id == selectedAgencyId)
                  ? selectedAgencyId
                  : null)
              : null,
          decoration: InputDecoration(
            labelText: 'clients.recommended_by_agency'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('clients.recommended_by_agency_none'.tr()),
            ),
            ...agencies.map((a) => DropdownMenuItem<String>(
                  value: a.id,
                  child: Text(a.name),
                )),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'common.generic_error_user_friendly'.tr(),
        style: TextStyle(color: context.colors.error),
      ),
    );
  }
}

/// Dialog pro vytvoření nebo úpravu klienta.
///
/// Pole: Jméno (povinné), Email, Telefon, Typ klienta (Majitel/Externí/Agentura).
/// Pro typ Externí navíc: Doporučující agentura (dropdown). Validace: jméno nesmí
/// být prázdné. Při úspěchu volá onSaved (obrazovka invaliduje stránkované záložky a cache).
class ClientFormDialog extends ConsumerStatefulWidget {
  const ClientFormDialog({
    super.key,
    required this.ref,
    this.client,
    required this.onSaved,
  });

  final WidgetRef ref;
  /// Null = nový klient, jinak úprava existujícího.
  final ClientModel? client;
  final VoidCallback onSaved;

  @override
  ConsumerState<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _gpsController;
  String? _selectedClientType;
  String _selectedLanguageCode = 'en';
  /// Doporučující agentura – pouze pro typ external. ID klienta (agency).
  String? _selectedAgencyId;
  /// Hybridní B2B partner – zobrazí se v roletce externích úkolů (faktura přes stejné clients.id).
  bool _canBillExternalTasks = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.client?.name ?? '',
    );
    _emailController = TextEditingController(
      text: widget.client?.email ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.client?.phone ?? '',
    );
    final c = widget.client;
    final gpsInitial = (c?.latitude != null && c?.longitude != null)
        ? '${c!.latitude}, ${c.longitude}'
        : '';
    _gpsController = TextEditingController(text: gpsInitial);
    _selectedClientType = widget.client?.clientType;
    _selectedLanguageCode = widget.client?.languageCode?.trim().isNotEmpty == true
        ? widget.client!.languageCode!.trim().toLowerCase()
        : 'en';
    // PROČ: agency_id platí pouze pro external – při editaci předvyplníme.
    _selectedAgencyId = widget.client?.clientType?.toLowerCase() == 'external'
        ? widget.client?.agencyId
        : null;
    _canBillExternalTasks = widget.client?.canBillExternalTasks ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _gpsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.client != null;

    return AlertDialog(
      title: Text(
        isEdit
            ? 'admin.apartments_edit'.tr()
            : 'clients.add_new'.tr(),
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
                    labelText: 'clients.name'.tr(),
                    hintText: 'clients.name'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'clients.validation_name_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'clients.email'.tr(),
                    hintText: 'clients.email'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'clients.phone'.tr(),
                    hintText: 'clients.phone'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gpsController,
                  decoration: InputDecoration(
                    labelText: 'admin.geo_smart_gps_field'.tr(),
                    hintText: 'admin.geo_smart_gps_hint'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.explore_outlined),
                  ),
                  keyboardType: TextInputType.text,
                  maxLines: 2,
                  validator: (_) => GeoJsonPoint.validateOptionalSmartGpsText(
                        _gpsController.text,
                      )
                      ?.tr(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedClientType,
                  decoration: InputDecoration(
                    labelText: 'clients.type'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: _clientTypeOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt.$1,
                      child: Text(opt.$2.tr()),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedClientType = v;
                      // PROČ: agency_id má smysl pouze u external. Při změně na owner/agency vynulujeme.
                      if (v?.toLowerCase() != 'external') {
                        _selectedAgencyId = null;
                      } else if (widget.client?.agencyId != null) {
                        _selectedAgencyId = widget.client!.agencyId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguageCode,
                  decoration: InputDecoration(
                    labelText: 'clients.communication_language'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: SupportedLanguages.all
                      .where((lang) => lang.code != null)
                      .map((lang) => DropdownMenuItem<String>(
                            value: lang.code,
                            child: Text(lang.labelKey.tr()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null || value.trim().isEmpty) return;
                    setState(() {
                      _selectedLanguageCode = value.trim().toLowerCase();
                    });
                  },
                ),
                // PROČ: Pole "Doporučující agentura" se zobrazuje JEN pro external –
                // u majitele a agentury nemá smysl evidovat, kdo klienta doporučil.
                if (_selectedClientType?.toLowerCase() == 'external') ...[
                  const SizedBox(height: 16),
                  _AgencyDropdown(
                    selectedAgencyId: _selectedAgencyId,
                    currentClientId: widget.client?.id,
                    onChanged: (v) => setState(() => _selectedAgencyId = v),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('clients.can_bill_external_tasks'.tr()),
                  value: _canBillExternalTasks,
                  onChanged: (v) => setState(() => _canBillExternalTasks = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('clients.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => _save(context),
          child: Text('clients.save'.tr()),
        ),
      ],
    );
  }

  /// Validace formuláře, sestavení modelu a volání add/update provideru.
  ///
  /// Při úpravě zachováváme id a tenant_id. Při novém záznamu bereme tenant_id
  /// z authNotifier – RLS stejně ověří, že uživatel smí vkládat pouze pro svůj tenant.
  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // PROČ: Konkrétní lokalizovaná příčina – není potřeba obalovat do error_with_message.
            content: Text('common.error_no_tenant'.tr()),
            // PROČ: chybový snackbar musí být navázaný na centrální error barvu.
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final emailOpt = email.isEmpty ? null : email;
    final phoneOpt = phone.isEmpty ? null : phone;
    final geoPair = GeoJsonPoint.tryParseSmartGpsText(_gpsController.text);

    try {
      // PROČ: agency_id posíláme pouze u external – u owner/agency v DB má být NULL.
      final agencyIdOpt = _selectedClientType?.toLowerCase() == 'external'
          ? _selectedAgencyId
          : null;

      if (widget.client != null) {
        final updated = widget.client!.copyWith(
          name: name,
          email: emailOpt,
          phone: phoneOpt,
          clientType: _selectedClientType,
          languageCode: _selectedLanguageCode,
          agencyId: agencyIdOpt,
          canBillExternalTasks: _canBillExternalTasks,
          latitude: geoPair?.latitude,
          longitude: geoPair?.longitude,
        );
        await ref.read(updateClientProvider)(updated);
      } else {
        final newClient = ClientModel(
          id: '',
          tenantId: tenantId,
          name: name,
          email: emailOpt,
          phone: phoneOpt,
          clientType: _selectedClientType,
          languageCode: _selectedLanguageCode,
          agencyId: agencyIdOpt,
          canBillExternalTasks: _canBillExternalTasks,
          latitude: geoPair?.latitude,
          longitude: geoPair?.longitude,
        );
        await ref.read(addClientProvider)(newClient);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.saved'.tr()),
            backgroundColor: context.customColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.generic_error_user_friendly'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
