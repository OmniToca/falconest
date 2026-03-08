import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';

/// Hodnoty client_type v DB – mapování na lokalizované labely.
const _clientTypeOptions = [
  ('owner', 'clients.type_owner'),
  ('external', 'clients.type_external'),
  ('agency', 'clients.type_agency'),
];

/// Dropdown výběr doporučující agentury – pouze klienti s typem agency.
///
/// PROČ oddělený widget: Načítá clientsProvider a filtruje na agency. Zobrazuje se
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
          value: selectedAgencyId != null && selectedAgencyId!.isNotEmpty
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
        'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
        style: TextStyle(color: Colors.red.shade700),
      ),
    );
  }
}

/// Dialog pro vytvoření nebo úpravu klienta.
///
/// Pole: Jméno (povinné), Email, Telefon, Typ klienta (Majitel/Externí/Agentura).
/// Pro typ Externí navíc: Doporučující agentura (dropdown). Validace: jméno nesmí
/// být prázdné. Při úspěchu invaliduje clientsProvider.
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
  String? _selectedClientType;
  /// Doporučující agentura – pouze pro typ external. ID klienta (agency).
  String? _selectedAgencyId;

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
    _selectedClientType = widget.client?.clientType;
    // PROČ: agency_id platí pouze pro external – při editaci předvyplníme.
    _selectedAgencyId = widget.client?.clientType?.toLowerCase() == 'external'
        ? widget.client?.agencyId
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
                DropdownButtonFormField<String>(
                  value: _selectedClientType,
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
            content: Text('common.error_with_message'.tr(
              namedArgs: {'message': 'common.error_no_tenant'.tr()},
            )),
            backgroundColor: Colors.red.shade700,
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
          agencyId: agencyIdOpt,
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
          agencyId: agencyIdOpt,
        );
        await ref.read(addClientProvider)(newClient);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.saved'.tr()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error_with_message'.tr(
              namedArgs: {'message': e.toString()},
            )),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
