import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/models/apartment_legal_settings.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';

/// Formulář SES kódů u bytu. Heslo WS jen admin/manager (nikoli majitel).
class ApartmentLegalSettingsForm extends ConsumerStatefulWidget {
  const ApartmentLegalSettingsForm({
    super.key,
    required this.apartmentId,
    this.showWsSecrets = true,
  });

  final String apartmentId;
  final bool showWsSecrets;

  @override
  ConsumerState<ApartmentLegalSettingsForm> createState() =>
      _ApartmentLegalSettingsFormState();
}

class _ApartmentLegalSettingsFormState
    extends ConsumerState<ApartmentLegalSettingsForm> {
  final _est = TextEditingController();
  final _landlord = TextEditingController();
  final _license = TextEditingController();
  final _house = TextEditingController();
  final _origin = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String _authority = 'ses';
  String _pay = 'EFECTIVO';
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _est.dispose();
    _landlord.dispose();
    _license.dispose();
    _house.dispose();
    _origin.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _fill(ApartmentLegalSettings s) {
    _est.text = s.sesEstablishmentCode ?? '';
    _landlord.text = s.sesLandlordCode ?? '';
    _license.text = s.touristLicense ?? '';
    _house.text = s.houseRules ?? '';
    _origin.text = s.publicWebOrigin ?? '';
    _user.text = s.wsUsername ?? '';
    _authority = s.legalAuthority;
    _pay = s.defaultPaymentType;
  }

  Future<void> _save() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData ?? '';
    setState(() => _saving = true);
    try {
      await ref.read(legalSpainRepositoryProvider).saveApartmentSettings(
            settings: ApartmentLegalSettings(
              apartmentId: widget.apartmentId,
              tenantId: tenantId,
              sesEstablishmentCode: _est.text.trim().isEmpty ? null : _est.text.trim(),
              sesLandlordCode: _landlord.text.trim().isEmpty ? null : _landlord.text.trim(),
              legalAuthority: _authority,
              touristLicense: _license.text.trim().isEmpty ? null : _license.text.trim(),
              defaultPaymentType: _pay,
              houseRules: _house.text.trim().isEmpty ? null : _house.text.trim(),
              publicWebOrigin: _origin.text.trim().isEmpty ? null : _origin.text.trim(),
              wsUsername: _user.text.trim().isEmpty ? null : _user.text.trim(),
            ),
            wsPassword: widget.showWsSecrets && _pass.text.isNotEmpty ? _pass.text : null,
          );
      ref.invalidate(apartmentLegalSettingsProvider(widget.apartmentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('legal_spain.settings_saved'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(apartmentLegalSettingsProvider(widget.apartmentId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (s) {
        if (s != null && !_loaded) {
          _loaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _fill(s));
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _est,
              decoration: InputDecoration(labelText: 'legal_spain.ses_establishment'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _landlord,
              decoration: InputDecoration(labelText: 'legal_spain.ses_landlord'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _authority,
              decoration: InputDecoration(labelText: 'legal_spain.legal_authority'.tr()),
              items: [
                DropdownMenuItem(value: 'ses', child: Text('legal_spain.authority_ses'.tr())),
                DropdownMenuItem(value: 'mossos', child: Text('legal_spain.authority_mossos'.tr())),
                DropdownMenuItem(value: 'ertzaintza', child: Text('legal_spain.authority_ertzaintza'.tr())),
              ],
              onChanged: (v) => setState(() => _authority = v ?? 'ses'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _license,
              decoration: InputDecoration(labelText: 'legal_spain.tourist_license'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: kLegalPaymentTypes.contains(_pay) ? _pay : 'EFECTIVO',
              decoration: InputDecoration(labelText: 'legal_spain.payment_type'.tr()),
              items: kLegalPaymentTypes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _pay = v ?? 'EFECTIVO'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _origin,
              decoration: InputDecoration(labelText: 'legal_spain.public_web_origin'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _house,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'legal_spain.house_rules'.tr()),
            ),
            if (widget.showWsSecrets) ...[
              const SizedBox(height: AppSpacing.md),
              Text('legal_spain.ws_creds'.tr(), style: Theme.of(context).textTheme.titleSmall),
              TextFormField(
                controller: _user,
                decoration: InputDecoration(labelText: 'legal_spain.ws_username'.tr()),
              ),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(labelText: 'legal_spain.ws_password'.tr()),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );
  }
}
