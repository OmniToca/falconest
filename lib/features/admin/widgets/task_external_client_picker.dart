import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';

/// Filtr klientů pro výběr u externí služby (agency / external / hybrid B2B).
bool isClientEligibleForExternalTask(ClientModel c) {
  final t = c.clientType?.toLowerCase() ?? '';
  return t == 'agency' || t == 'external' || c.canBillExternalTasks;
}

/// Vyhledávací výběr klienta pro formulář úkolu (Externí služba) + rychlé vytvoření.
///
/// PROČ: Klasický [DropdownButtonFormField] neumožňuje pohodlné hledání při stovkách
/// CRM záznamů ani založení klienta bez opuštění rozdělaného formuláře úkolu.
class TaskExternalClientPicker extends ConsumerStatefulWidget {
  const TaskExternalClientPicker({
    super.key,
    required this.selectedClientId,
    required this.onChanged,
    this.enabled = true,
    this.allowOrphanLabel = false,
  });

  final String? selectedClientId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  /// Editace úkolu: pokud vybrané ID není v seznamu, zobrazí štítek „neplatný klient“.
  final bool allowOrphanLabel;

  @override
  ConsumerState<TaskExternalClientPicker> createState() =>
      _TaskExternalClientPickerState();
}

class _TaskExternalClientPickerState
    extends ConsumerState<TaskExternalClientPicker> {
  /// Klíč Autocomplete – při výběru / vytvoření klienta vynutí přestavbu s novým textem.
  int _fieldEpoch = 0;

  String _labelFor(ClientModel c) {
    final phone = c.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return '${c.name} ($phone)';
    }
    return c.name;
  }

  List<ClientModel> _eligibleSorted(List<ClientModel> all) {
    final clients = all.where(isClientEligibleForExternalTask).toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return clients;
  }

  List<ClientModel> _filter(List<ClientModel> clients, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients.where((c) {
      final name = c.name.toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _openQuickCreate() async {
    if (!widget.enabled) return;
    final created = await showQuickCreateExternalClientDialog(context, ref);
    if (!mounted || created == null) return;
    widget.onChanged(created.id);
    setState(() => _fieldEpoch++);
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsFullListProvider);

    return clientsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('common.generic_error_user_friendly'.tr()),
      data: (allClients) {
        final clients = _eligibleSorted(allClients);
        final selectedId = widget.selectedClientId?.trim();
        final selected = (selectedId != null && selectedId.isNotEmpty)
            ? clients.where((c) => c.id == selectedId).firstOrNull
            : null;
        final isOrphan = widget.allowOrphanLabel &&
            selectedId != null &&
            selectedId.isNotEmpty &&
            selected == null;

        final initialText = selected != null
            ? _labelFor(selected)
            : (isOrphan
                ? 'tasks.client_orphan_label'.tr(
                    namedArgs: {
                      'id': selectedId.length > 8
                          ? selectedId.substring(0, 8)
                          : selectedId,
                    },
                  )
                : '');

        return FormField<String>(
          key: ValueKey('client-picker-$_fieldEpoch-$selectedId'),
          initialValue: selectedId,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'tasks.validation_client_required'.tr()
              : null,
          builder: (field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Autocomplete<ClientModel>(
                        key: ValueKey('ac-$_fieldEpoch-$initialText'),
                        displayStringForOption: _labelFor,
                        optionsBuilder: (textEditingValue) {
                          return _filter(clients, textEditingValue.text);
                        },
                        onSelected: (c) {
                          field.didChange(c.id);
                          widget.onChanged(c.id);
                          setState(() => _fieldEpoch++);
                        },
                        fieldViewBuilder: (
                          context,
                          textController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          // PROČ post-frame: Autocomplete vytvoří prázdný controller; po výběru/epoch
                          // nastavíme label vybraného klienta bez setState uprostřed buildu.
                          if (initialText.isNotEmpty &&
                              textController.text != initialText) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (textController.text != initialText) {
                                textController.value = TextEditingValue(
                                  text: initialText,
                                  selection: TextSelection.collapsed(
                                    offset: initialText.length,
                                  ),
                                );
                              }
                            });
                          }
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            enabled: widget.enabled,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_search),
                              labelText: 'tasks.form_client'.tr(),
                              hintText: 'tasks.client_search_hint'.tr(),
                              border: const OutlineInputBorder(),
                              errorText: field.errorText,
                            ),
                            onChanged: (text) {
                              // Mazání textu = zrušení výběru, dokud uživatel znovu nevybere.
                              if (text.trim().isEmpty) {
                                field.didChange(null);
                                widget.onChanged(null);
                              }
                            },
                            onSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final opts = options.toList();
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 280,
                                  minWidth: 280,
                                ),
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: [
                                    if (opts.isEmpty)
                                      ListTile(
                                        dense: true,
                                        title: Text(
                                          clients.isEmpty
                                              ? 'tasks.no_clients_hint'.tr()
                                              : 'tasks.client_no_matches'.tr(),
                                          style: context.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: context
                                                .colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    for (final c in opts)
                                      ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.person_outline,
                                          color: context.colors.primary,
                                        ),
                                        title: Text(c.name),
                                        subtitle: (c.phone != null &&
                                                c.phone!.trim().isNotEmpty)
                                            ? Text(c.phone!)
                                            : null,
                                        onTap: () => onSelected(c),
                                      ),
                                    const Divider(height: 1),
                                    ListTile(
                                      dense: true,
                                      leading: Icon(
                                        Icons.person_add_alt_1,
                                        color: context.colors.primary,
                                      ),
                                      title: Text(
                                        'tasks.client_create_new'.tr(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.primary,
                                        ),
                                      ),
                                      onTap: () async {
                                        // Zavřít overlay Autocomplete – unfocus.
                                        FocusScope.of(context).unfocus();
                                        await _openQuickCreate();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton.filledTonal(
                        tooltip: 'tasks.client_create_new'.tr(),
                        onPressed: widget.enabled ? _openQuickCreate : null,
                        icon: const Icon(Icons.person_add_alt_1),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Jednoduchý dialog: jméno (povinné) + telefon → insert `clients` typu external.
///
/// PROČ: Dispečer založí CRM záznam přímo z formuláře úkolu bez ztráty kontextu.
Future<ClientModel?> showQuickCreateExternalClientDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var saving = false;

  try {
    return await showDialog<ClientModel>(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text('tasks.client_quick_create_title'.tr()),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'tasks.client_quick_create_name'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'tasks.client_quick_create_name_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'tasks.client_quick_create_phone'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final tenantId =
                              ref.read(authNotifierProvider).tenantIdForData;
                          if (tenantId == null || tenantId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('common.error_no_tenant'.tr()),
                                backgroundColor: context.colors.error,
                              ),
                            );
                            return;
                          }
                          setLocal(() => saving = true);
                          try {
                            final phone = phoneController.text.trim();
                            final created = await ref.read(addClientProvider)(
                              ClientModel(
                                id: '',
                                tenantId: tenantId,
                                name: nameController.text.trim(),
                                phone: phone.isEmpty ? null : phone,
                                clientType: 'external',
                              ),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(created);
                          } catch (e, st) {
                            AppLogger.error(
                              'showQuickCreateExternalClientDialog: insert klienta selhal',
                              e,
                              st,
                            );
                            setLocal(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'common.generic_error_user_friendly'.tr(),
                                  ),
                                  backgroundColor: context.colors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('tasks.client_quick_create_save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameController.dispose();
    phoneController.dispose();
  }
}
