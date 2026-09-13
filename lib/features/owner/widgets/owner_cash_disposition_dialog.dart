import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';
import 'package:falconest/features/owner/models/owner_cash_transit_settlement.dart';
import 'package:falconest/features/owner/providers/owner_cash_providers.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/utils/owner_vault_pickup_picker.dart';
import 'package:falconest/features/owner/widgets/owner_read_only_gate.dart';

/// Modální formulář: majitel zvolí typ dispozice, settlement řádek, částku a poznámku pro agenturu.
///
/// PROČ: Jedna žádost vždy vázaná na konkrétní [OwnerCashTransitSettlement] (FK v DB);
/// částka nesmí překročit uznanou hodnotu řádku.
class OwnerCashDispositionDialog extends ConsumerStatefulWidget {
  const OwnerCashDispositionDialog({super.key});

  @override
  ConsumerState<OwnerCashDispositionDialog> createState() => _OwnerCashDispositionDialogState();
}

/// Otevře dialog nad aktuálním kontextem (musí být pod [ProviderScope]).
Future<void> showOwnerCashDispositionDialog(BuildContext context, WidgetRef ref) {
  if (isOwnerPortalReadOnly(ref)) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) => const OwnerCashDispositionDialog(),
  );
}

class _OwnerCashDispositionDialogState extends ConsumerState<OwnerCashDispositionDialog> {
  String _dispositionType = OwnerCashDispositionTypeValues.bankTransfer;
  OwnerCashTransitSettlement? _selectedSettlement;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _ibanController = TextEditingController();
  String? _amountErrorKey;
  bool _submitting = false;
  /// UTC – termín vyzvednutí u vault_pickup (povinný před odesláním).
  DateTime? _vaultPickupUtc;

  /// Po načtení settlementů nastaví výchozí řádek a předvyplní částku (max. pro daný řádek).
  void _ensureSelection(List<OwnerCashTransitSettlement> list) {
    if (list.isEmpty) return;
    final sel = _selectedSettlement;
    if (sel != null && list.any((e) => e.id == sel.id)) return;
    setState(() {
      _selectedSettlement = list.first;
      _syncAmountToSettlement(list.first);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  void _syncAmountToSettlement(OwnerCashTransitSettlement? s) {
    if (s == null) {
      _amountController.text = '';
      return;
    }
    _amountController.text = _formatAmount(s.amountForDisposition);
    _amountErrorKey = null;
  }

  static String _formatAmount(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  /// Lidský popis řádku settlementu v dropdownu – termín pobytu a volitelně jméno hosta.
  ///
  /// Vylepšení UX: Přidání jména hosta k datům pobytu pro lepší orientaci majitele.
  String _settlementDropdownLabel(BuildContext context, OwnerCashTransitSettlement e) {
    final locale = context.locale.toString();
    final start = e.reservationStayStart;
    final end = e.reservationStayEnd;
    if (start != null && end != null) {
      final df = DateFormat('d.M.', locale);
      final guest = e.guestName?.trim();
      if (guest != null && guest.isNotEmpty) {
        return 'owner.cash_disposition_settlement_option_stay_dates_guest'.tr(
          namedArgs: {
            'from': df.format(start),
            'to': df.format(end),
            'guest': guest,
          },
        );
      }
      return 'owner.cash_disposition_settlement_option_stay_dates_only'.tr(
        namedArgs: {
          'from': df.format(start),
          'to': df.format(end),
        },
      );
    }
    return 'owner.cash_disposition_settlement_option_fallback'.tr(
      namedArgs: {
        'amount': _formatAmount(e.amountForDisposition),
        'currency': e.currency,
      },
    );
  }

  double? _parseAmount(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Výběr data/času vyzvednutí; min. 48 h od „teď“ (sdílená logika s úpravou žádosti).
  Future<void> _pickVaultPickup(BuildContext context) async {
    final utc = await pickOwnerVaultPickupDateTime(
      context,
      initialUtc: _vaultPickupUtc,
    );
    if (utc == null || !mounted) return;
    setState(() => _vaultPickupUtc = utc);
  }

  String _formatPickupSummary(DateTime utc) {
    final local = utc.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.${local.year} $h:$min';
  }

  Future<void> _submit(double maxAmount) async {
    final auth = ref.read(authNotifierProvider);
    final tenantId = auth.tenantIdForData;
    final profileId = ref.read(effectiveProfileIdProvider);
    final settlement = _selectedSettlement;

    if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty || settlement == null) {
      return;
    }

    final parsed = _parseAmount(_amountController.text);
    if (parsed == null || parsed <= 0) {
      setState(() => _amountErrorKey = 'owner.cash_disposition_amount_error_invalid');
      return;
    }
    if (parsed > maxAmount + 1e-9) {
      setState(() => _amountErrorKey = 'owner.cash_disposition_amount_error_max');
      return;
    }

    setState(() {
      _amountErrorKey = null;
      _submitting = true;
    });

    try {
      await OwnerCashDispositionRepository.createRequest(
        tenantId: tenantId,
        ownerProfileId: profileId,
        settlementId: settlement.id,
        dispositionType: _dispositionType,
        amount: parsed,
        noteForAgency: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        iban: _dispositionType == OwnerCashDispositionTypeValues.bankTransfer
            ? _ibanController.text
            : null,
        pickupDate: _dispositionType == OwnerCashDispositionTypeValues.vaultPickup
            ? _vaultPickupUtc
            : null,
      );
      ref.invalidate(ownerAvailableBalanceProvider);
      ref.invalidate(ownerAvailableSettlementsProvider);
      ref.invalidate(ownerCashRequestsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('owner.cash_request_sent_snack'.tr())),
        );
      }
    } on OwnerDispositionValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.l10nKey.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlementsAsync = ref.watch(ownerAvailableSettlementsProvider);

    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Icon(Icons.payments_outlined, color: cs.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'owner.cash_disposition_dialog_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: settlementsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'owner.cash_disposition_no_settlements'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }

            final selectedId = _selectedSettlement?.id;
            final validSelected =
                selectedId != null && list.any((e) => e.id == selectedId);
            final displayRow =
                validSelected ? list.firstWhere((e) => e.id == selectedId) : list.first;

            if (!validSelected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _ensureSelection(list);
              });
            }

            final maxAmount = displayRow.amountForDisposition;
            final cur = displayRow.currency;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'owner.cash_disposition_type_label'.tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _dispositionType,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: OwnerCashDispositionTypeValues.bankTransfer,
                          child: Text('owner.cash_disposition_type_bank_transfer'.tr()),
                        ),
                        DropdownMenuItem(
                          value: OwnerCashDispositionTypeValues.invoiceCredit,
                          child: Text('owner.cash_disposition_type_invoice_credit'.tr()),
                        ),
                        DropdownMenuItem(
                          value: OwnerCashDispositionTypeValues.vaultPickup,
                          child: Text('owner.cash_disposition_type_vault_pickup'.tr()),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _dispositionType = v;
                          if (v != OwnerCashDispositionTypeValues.vaultPickup) {
                            _vaultPickupUtc = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'owner.cash_disposition_settlement_label'.tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<OwnerCashTransitSettlement>(
                      value: displayRow,
                      isExpanded: true,
                      items: list
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                _settlementDropdownLabel(context, e),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedSettlement = v;
                          _syncAmountToSettlement(v);
                        });
                      },
                    ),
                  ),
                ),
                if (_dispositionType == OwnerCashDispositionTypeValues.bankTransfer) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ibanController,
                    decoration: InputDecoration(
                      labelText: 'owner.cash_disposition_iban_label'.tr(),
                      hintText: 'owner.cash_disposition_iban_hint'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                  ),
                ],
                if (_dispositionType == OwnerCashDispositionTypeValues.vaultPickup) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'owner.cash_disposition_pickup_label'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _pickVaultPickup(context),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _vaultPickupUtc == null
                          ? 'owner.cash_disposition_pickup_pick_button'.tr()
                          : _formatPickupSummary(_vaultPickupUtc!),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'owner.cash_disposition_amount_label'.tr(),
                    hintText: 'owner.cash_disposition_amount_hint'.tr(
                      namedArgs: {'max': _formatAmount(maxAmount), 'currency': cur},
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: _amountErrorKey?.tr(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(() => _amountErrorKey = null),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'owner.cash_disposition_note_label'.tr(),
                    hintText: 'owner.cash_disposition_note_hint'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text('common.generic_error_user_friendly'.tr()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submitting || settlementsAsync.valueOrNull?.isEmpty != false
              ? null
              : () {
                  final list = settlementsAsync.valueOrNull;
                  final s = _selectedSettlement ?? (list != null && list.isNotEmpty ? list.first : null);
                  if (s == null) return;
                  _submit(s.amount);
                },
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('owner.cash_disposition_submit'.tr()),
        ),
      ],
    );
  }
}
