import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/offline/network_error_helper.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/services/media_service.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';

/// Modul pro MediaService.uploadMedia – účtenky firemních výdajů.
/// Cesta v Storage: tenantId/expenses/uuid.jpg
const _storageModuleExpenses = 'expenses';

/// Dialog pro zadání firemního výdaje (nákup materiálu, účtenka).
///
/// PROČ fotky jen online: Verze 1.0 nenahrává fotky do offline fronty – při offline
/// zobrazíme upozornění a nepokračujeme. Zápis výdaje do DB má offline podporu
/// (MutationQueueService), ale fotka účtenky vyžaduje Supabase Storage.
class AddCompanyExpenseDialog extends ConsumerStatefulWidget {
  const AddCompanyExpenseDialog({super.key});

  @override
  ConsumerState<AddCompanyExpenseDialog> createState() =>
      _AddCompanyExpenseDialogState();

  /// Otevře dialog. Po úspěšném uložení zavře a volající může invalidovat providery.
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const AddCompanyExpenseDialog(),
    );
  }
}

class _AddCompanyExpenseDialogState extends ConsumerState<AddCompanyExpenseDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  File? _receiptFile;
  bool _isSaving = false;
  /// Volitelně vybraný apartmán – pro stržení nákladů ve faktuře majitele.
  String? _selectedApartmentId;
  /// Volitelně vybraný klient – pro výdaje vázané na konkrétního klienta (např. externí).
  String? _selectedClientId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    final t = _amountController.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Sestaví Dropdown pro volitelný výběr klienta.
  /// Vazba na klienta umožňuje evidovat výdaje vázané na konkrétního klienta (např. externí platby).
  Widget _buildClientDropdown(List<ClientModel> clients) {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedClientId,
      decoration: InputDecoration(
        labelText: 'admin.finance.select_client'.tr(),
        hintText: 'admin.finance.select_client_hint'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        ...clients.map((c) => DropdownMenuItem<String?>(
              value: c.id,
              child: Text(_clientDisplayName(c)),
            )),
      ],
      onChanged: (v) => setState(() => _selectedClientId = v),
    );
  }

  /// Zobrazovací jméno klienta v dropdownu – název + volitelně lokalizovaný typ.
  String _clientDisplayName(ClientModel c) {
    final type = c.clientType?.toLowerCase();
    if (type == null || type.isEmpty) return c.name;
    String typeLabel;
    switch (type) {
      case 'owner':
        typeLabel = 'clients.type_owner'.tr();
        break;
      case 'agency':
        typeLabel = 'clients.type_agency'.tr();
        break;
      case 'external':
        typeLabel = 'clients.type_external'.tr();
        break;
      default:
        typeLabel = type;
    }
    return '${c.name} ($typeLabel)';
  }

  /// Sestaví Dropdown pro volitelný výběr apartmánu.
  /// Přiřazení apartmánu k výdaji je nezbytné pro automatické strhávání nákladů ve finální faktuře majitele.
  Widget _buildApartmentDropdown(List<ApartmentRow> apartments) {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedApartmentId,
      decoration: InputDecoration(
        labelText: 'worker.expense_apartment'.tr(),
        hintText: 'worker.expense_apartment_hint'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('worker.expense_apartment_none'.tr()),
        ),
        ...apartments
            .map((a) => DropdownMenuItem<String?>(
                  value: a.id,
                  child: Text(
                    (a.code?.isNotEmpty == true) ? '${a.name} (${a.code})' : a.name,
                  ),
                )),
      ],
      onChanged: (v) => setState(() => _selectedApartmentId = v),
    );
  }

  Future<void> _takeReceiptPhoto() async {
    if (kIsWeb) return;
    final file = await MediaService.instance.pickAndCompressImage(
      source: ImageSource.camera,
    );
    if (file != null && mounted) {
      setState(() => _receiptFile = file);
    }
  }

  Future<void> _onSave() async {
    final amount = _parseAmount();
    final note = _noteController.text.trim();

    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.expense_validation_amount'.tr())),
        );
      }
      return;
    }
    if (note.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.expense_validation_note'.tr())),
        );
      }
      return;
    }

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.expense_validation_amount'.tr())),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    String? receiptImageUrl;

    // KROK 1: Nahrání fotky účtenky na Supabase Storage (pouze online).
    // PROČ: Fotky se v současné verzi ukládají pouze při dostupném připojení.
    // Offline fronta pro média není implementována – nechceme zahltit telefon
    // lokálními soubory. Při síťové chybě zobrazíme upozornění a neukládáme výdaj.
    if (_receiptFile != null) {
      try {
        receiptImageUrl = await MediaService.instance.uploadMedia(
          _receiptFile!,
          tenantId: tenantId,
          moduleName: _storageModuleExpenses,
        );
        if (receiptImageUrl == null && mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('worker.expense_photo_upload_error'.tr())),
          );
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          final msg = isNetworkError(e)
              ? 'worker.expense_photo_required_online'.tr()
              : 'worker.expense_photo_upload_error'.tr();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }
    }

    // KROK 2: Zápis výdaje do DB (s offline podporou přes recordCompanyExpense).
    try {
      await CashWalletRepository.instance.recordCompanyExpense(
        tenantId: tenantId,
        profileId: profileId,
        amount: amount.abs(),
        note: note,
        receiptImageUrl: receiptImageUrl,
        apartmentId: _selectedApartmentId,
        clientId: _selectedClientId,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.expense_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.expense_save_error'.tr(namedArgs: {'error': e.toString()})),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    final clientsAsync = ref.watch(clientsFullListProvider);
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    return AlertDialog(
      title: Text('worker.expense_dialog_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'worker.expense_amount'.tr(),
                border: const OutlineInputBorder(),
                suffixText: currency,
              ),
            ),
            const SizedBox(height: 16),
            // Volitelný výběr klienta – pro výdaje vázané na konkrétního klienta.
            clientsAsync.when(
              data: (clients) => _buildClientDropdown(clients),
              loading: () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => _buildClientDropdown([]),
            ),
            const SizedBox(height: 16),
            // Přiřazení apartmánu k výdaji je nezbytné pro automatické strhávání nákladů ve finální faktuře majitele.
            apartmentsAsync.when(
              data: (apartments) => _buildApartmentDropdown(apartments),
              loading: () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => _buildApartmentDropdown([]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'worker.expense_note'.tr(),
                hintText: 'worker.expense_note_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: kIsWeb ? null : _takeReceiptPhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text('worker.take_photo'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_receiptFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _receiptFile!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('worker.expense_save'.tr()),
        ),
      ],
    );
  }
}
