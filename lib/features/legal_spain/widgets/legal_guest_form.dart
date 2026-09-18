import 'dart:convert';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/models/reservation_guest.dart';
import 'package:falconest/features/legal_spain/utils/document_validators.dart';
import 'package:falconest/features/worker/widgets/signature_pad.dart';

/// Formulář jedné osoby k pobytu (admin / majitel / veřejný check-in / worker).
///
/// PROČ: Stejná pole RD 933/2021 na všech cestách zápisu, aby SOAP dostal konzistentní XML.
class LegalGuestForm extends StatefulWidget {
  const LegalGuestForm({
    super.key,
    required this.guest,
    required this.onSave,
    this.onSign,
    this.readOnly = false,
  });

  final ReservationGuest guest;
  final Future<void> Function(ReservationGuest guest) onSave;
  final Future<void> Function(String pngBase64)? onSign;
  final bool readOnly;

  @override
  State<LegalGuestForm> createState() => _LegalGuestFormState();
}

class _LegalGuestFormState extends State<LegalGuestForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _second;
  late final TextEditingController _nationality;
  late final TextEditingController _docNumber;
  late final TextEditingController _docSupport;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  DateTime? _birth;
  String? _sex;
  String? _docType;
  bool _minor = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.guest;
    _first = TextEditingController(text: g.firstName);
    _last = TextEditingController(text: g.lastName);
    _second = TextEditingController(text: g.secondLastName ?? '');
    _nationality = TextEditingController(text: g.nationality ?? '');
    _docNumber = TextEditingController(text: g.documentNumber ?? '');
    _docSupport = TextEditingController(text: g.documentSupport ?? '');
    _address = TextEditingController(text: g.addressLine ?? '');
    _city = TextEditingController(text: g.addressCity ?? '');
    _country = TextEditingController(text: g.addressCountry ?? '');
    _phone = TextEditingController(text: g.phone ?? '');
    _email = TextEditingController(text: g.email ?? '');
    _birth = g.birthDate;
    _sex = g.sex;
    _docType = g.documentType;
    _minor = g.isMinorUnder14;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _second.dispose();
    _nationality.dispose();
    _docNumber.dispose();
    _docSupport.dispose();
    _address.dispose();
    _city.dispose();
    _country.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  ReservationGuest _collect() {
    return ReservationGuest(
      id: widget.guest.id,
      tenantId: widget.guest.tenantId,
      reservationId: widget.guest.reservationId,
      firstName: _first.text,
      lastName: _last.text,
      secondLastName: _second.text.trim().isEmpty ? null : _second.text.trim(),
      birthDate: _birth,
      nationality: _nationality.text.trim().isEmpty ? null : _nationality.text.trim().toUpperCase(),
      sex: _sex,
      documentType: _docType,
      documentNumber: _docNumber.text.trim().isEmpty ? null : LegalDocumentValidators.normalize(_docNumber.text),
      documentSupport: _docSupport.text.trim().isEmpty ? null : _docSupport.text.trim(),
      addressLine: _address.text.trim().isEmpty ? null : _address.text.trim(),
      addressCity: _city.text.trim().isEmpty ? null : _city.text.trim(),
      addressCountry: _country.text.trim().isEmpty ? null : _country.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      isMinorUnder14: _minor,
      signedAt: widget.guest.signedAt,
      signaturePngBase64: widget.guest.signaturePngBase64,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_collect());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sign() async {
    if (widget.onSign == null || _minor) return;
    final png = await showDialog<Uint8List>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('legal_spain.sign_title'.tr()),
        content: SizedBox(
          width: 520,
          child: SignaturePad(onConfirm: (bytes) => Navigator.of(ctx).pop(bytes)),
        ),
      ),
    );
    if (png == null || png.isEmpty) return;
    await widget.onSign!(base64Encode(png));
  }

  @override
  Widget build(BuildContext context) {
    final ro = widget.readOnly;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('legal_spain.minor_under_14'.tr()),
            value: _minor,
            onChanged: ro ? null : (v) => setState(() => _minor = v),
          ),
          TextFormField(
            controller: _first,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_first_name'.tr()),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'legal_spain.required'.tr() : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _last,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_last_name'.tr()),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'legal_spain.required'.tr() : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _second,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_second_last_name'.tr()),
            validator: (v) {
              if (LegalDocumentValidators.requiresSecondLastName(_docType) &&
                  (v == null || v.trim().isEmpty)) {
                return 'legal_spain.second_last_required'.tr();
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _birth == null
                  ? 'legal_spain.field_birth_date'.tr()
                  : DateFormat.yMMMd(context.locale.toString()).format(_birth!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: ro
                ? null
                : () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _birth ?? DateTime(now.year - 30),
                      firstDate: DateTime(1900),
                      lastDate: now,
                    );
                    if (picked != null) setState(() => _birth = picked);
                  },
          ),
          DropdownButtonFormField<String>(
            initialValue: kLegalSexValues.contains(_sex) ? _sex : null,
            decoration: InputDecoration(labelText: 'legal_spain.field_sex'.tr()),
            items: kLegalSexValues
                .map((s) => DropdownMenuItem(value: s, child: Text('legal_spain.sex_$s'.tr())))
                .toList(),
            onChanged: ro ? null : (v) => setState(() => _sex = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nationality,
            readOnly: ro,
            decoration: InputDecoration(
              labelText: 'legal_spain.field_nationality'.tr(),
              hintText: 'ESP',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.length != 3) return 'legal_spain.nationality_iso3'.tr();
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: kLegalDocumentTypes.contains(_docType) ? _docType : null,
            decoration: InputDecoration(labelText: 'legal_spain.field_document_type'.tr()),
            items: kLegalDocumentTypes
                .map((s) => DropdownMenuItem(value: s, child: Text('legal_spain.doc_$s'.tr())))
                .toList(),
            onChanged: ro ? null : (v) => setState(() => _docType = v),
            validator: (v) => v == null ? 'legal_spain.required'.tr() : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _docNumber,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_document_number'.tr()),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'legal_spain.required'.tr();
              if (!LegalDocumentValidators.isValidForType(_docType, v)) {
                return 'legal_spain.invalid_document'.tr();
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _docSupport,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_document_support'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _address,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_address'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _city,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_city'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _country,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_country'.tr()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _phone,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_phone'.tr()),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _email,
            readOnly: ro,
            decoration: InputDecoration(labelText: 'legal_spain.field_email'.tr()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!ro)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('common.save'.tr()),
            ),
          if (!_minor && widget.onSign != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: widget.guest.isSigned ? null : _sign,
              icon: Icon(widget.guest.isSigned ? Icons.check : Icons.draw_outlined),
              label: Text(
                widget.guest.isSigned
                    ? 'legal_spain.already_signed'.tr()
                    : 'legal_spain.sign_cta'.tr(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
