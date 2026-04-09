import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/settings/providers/tenant_integration_settings_provider.dart';
import 'package:falconest/features/settings/services/twilio_provision_service.dart';

/// Záložka **Integrace** – vertikální seznam rozbalovacích sekcí (SMS / E-mail / WhatsApp), stejný princip jako Checklisty/Oblasti.
///
/// PROČ: Vnořený [TabBar] v modalu působil rušivě; [ExpansionTile] sjednocuje navigaci a formuláře zůstávají v těle řádku.
/// Hodnoty stále jdou do JSONB [tenants.integration_settings]; merge přes
/// [mergeAndSaveTenantIntegrationSmtpSettings] / [mergeAndSaveTenantTwilioApiSettings].
/// Paywall [custom_twilio_whatsapp]: při prvním rozbalení sekce WhatsApp bez modulu se otevře [PremiumUpsellDialog].
class IntegrationsTab extends ConsumerStatefulWidget {
  const IntegrationsTab({super.key});

  @override
  ConsumerState<IntegrationsTab> createState() => _IntegrationsTabState();
}

class _IntegrationsTabState extends ConsumerState<IntegrationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController();
  final _smtpUsernameController = TextEditingController();
  final _smtpPasswordController = TextEditingController();
  final _smtpSenderNameController = TextEditingController();
  final _twilioSidController = TextEditingController();
  final _twilioTokenController = TextEditingController();

  /// PROČ: Po prvním načtení z DB naplníme pole – posluchače zapneme až po frame, aby
  /// programatické vyplnění nespustilo falešný „dirty“ stav.
  bool _listenersActive = false;

  /// Jednorázové vyplnění SMTP z [tenantIntegrationSettingsProvider] po načtení.
  bool _seededFromServer = false;

  /// PROČ: SID/Token načteme jen když je aktivní placený modul – při zamčeném UI
  /// nechceme držet Auth Token v paměti kontrolerů.
  bool _twilioCredentialsSeeded = false;

  bool _dirty = false;
  bool _saving = false;

  /// PROČ: MVP povolené země bez zbytečné byrokracie (Twilio má u CZ často extra požadavky).
  String _twilioCountryCode = 'US';

  /// Indikátor volání Edge `twilio-provision-number` (nesmí se překrývat s ukládáním SMTP).
  bool _twilioProvisioning = false;

  /// Upsell při prvním rozbalení WhatsApp bez modulu (ekvivalent dřívějšího přepnutí na třetí tab).
  bool _whatsappUpsellShown = false;

  @override
  void initState() {
    super.initState();
    void markDirty() {
      if (!_listenersActive) return;
      setState(() => _dirty = true);
    }

    _smtpHostController.addListener(markDirty);
    _smtpPortController.addListener(markDirty);
    _smtpUsernameController.addListener(markDirty);
    _smtpPasswordController.addListener(markDirty);
    _smtpSenderNameController.addListener(markDirty);
    _twilioSidController.addListener(markDirty);
    _twilioTokenController.addListener(markDirty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _listenersActive = true);
    });
  }

  @override
  void dispose() {
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    _smtpSenderNameController.dispose();
    _twilioSidController.dispose();
    _twilioTokenController.dispose();
    super.dispose();
  }

  /// PROČ: Jednorázové naplnění polí z provideru po načtení (nebo po invalidaci po uložení).
  /// Twilio SID/Token jen při aktivním modulu [custom_twilio_whatsapp] – jinak vyčistíme.
  void _seedFromMapIfNeeded(
    Map<String, dynamic> map, {
    required bool customTwilioModuleActive,
  }) {
    if (!_seededFromServer) {
      _seededFromServer = true;

      void setIf(String key, TextEditingController c) {
        final v = map[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          c.text = v.toString().trim();
        }
      }

      setIf(kTenantIntegrationSmtpHost, _smtpHostController);
      setIf(kTenantIntegrationSmtpPort, _smtpPortController);
      setIf(kTenantIntegrationSmtpUsername, _smtpUsernameController);
      setIf(kTenantIntegrationSmtpPassword, _smtpPasswordController);
      setIf(kTenantIntegrationSmtpSenderName, _smtpSenderNameController);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _dirty = false);
      });
    }

    if (customTwilioModuleActive) {
      if (!_twilioCredentialsSeeded) {
        _twilioCredentialsSeeded = true;
        void setIfTwilio(String key, TextEditingController c) {
          final v = map[key];
          if (v != null && v.toString().trim().isNotEmpty) {
            c.text = v.toString().trim();
          }
        }

        setIfTwilio(kTenantIntegrationTwilioAccountSid, _twilioSidController);
        setIfTwilio(kTenantIntegrationTwilioAuthToken, _twilioTokenController);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _dirty = false);
        });
      }
    } else {
      _twilioCredentialsSeeded = false;
      if (_twilioSidController.text.isNotEmpty || _twilioTokenController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _twilioSidController.clear();
          _twilioTokenController.clear();
          setState(() => _dirty = false);
        });
      }
    }
  }

  /// Uložení přes bezpečný merge do JSONB (viz provider).
  Future<void> _onSave(String tenantId) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await mergeAndSaveTenantIntegrationSmtpSettings(
        tenantId: tenantId,
        smtpHost: _smtpHostController.text,
        smtpPort: _smtpPortController.text,
        smtpUsername: _smtpUsernameController.text,
        smtpPassword: _smtpPasswordController.text,
        smtpSenderName: _smtpSenderNameController.text,
      );
      if (isModuleActive(ref, 'custom_twilio_whatsapp')) {
        await mergeAndSaveTenantTwilioApiSettings(
          tenantId: tenantId,
          twilioAccountSid: _twilioSidController.text,
          twilioAuthToken: _twilioTokenController.text,
        );
      }
      if (!mounted) return;
      ref.invalidate(tenantIntegrationSettingsProvider(tenantId));
      setState(() {
        _dirty = false;
        _seededFromServer = false;
        _twilioCredentialsSeeded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.integrations.saved_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'settings.integrations.save_error'.tr(namedArgs: {'message': '$e'}),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// PROČ: Nákup čísla běží na serveru (Twilio + merge JSONB); po úspěchu jen invalidujeme provider.
  Future<void> _onProvisionTwilio(String tenantId) async {
    if (_twilioProvisioning || _saving) return;
    setState(() => _twilioProvisioning = true);
    try {
      await TwilioProvisionService.provisionPhoneNumber(countryCode: _twilioCountryCode);
      if (!mounted) return;
      ref.invalidate(tenantIntegrationSettingsProvider(tenantId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.integrations.twilio_provision_success'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = _formatTwilioProvisionError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _twilioProvisioning = false);
    }
  }

  /// PROČ: Lokální kódy chyb mapujeme na i18n; text z API (Twilio/Edge) zobrazíme jako detail.
  String _formatTwilioProvisionError(Object e) {
    final raw = e.toString();
    if (raw.contains('TWILIO_PROVISION_NO_SESSION')) {
      return 'settings.integrations.twilio_error_no_session'.tr();
    }
    if (raw.contains('TWILIO_PROVISION_INVALID_RESPONSE')) {
      return 'settings.integrations.twilio_error_invalid_response'.tr();
    }
    var s = raw.startsWith('Exception: ') ? raw.substring('Exception: '.length) : raw;
    if (s.startsWith('FunctionException: ')) {
      s = s.substring('FunctionException: '.length);
    }
    return s;
  }

  /// PROČ: Informační „poznámka“ – čitelný fallback bez hardcoded textů.
  Widget _buildIntegrationInfoNote(BuildContext context, String translationKey) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              translationKey.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// PROČ: Zobrazíme výchozí odesílatele (sdílený SMTP) jen když tenant nic nevyplnil.
  bool _isSmtpFieldsEmpty() {
    return _smtpHostController.text.trim().isEmpty &&
        _smtpPortController.text.trim().isEmpty &&
        _smtpUsernameController.text.trim().isEmpty &&
        _smtpPasswordController.text.trim().isEmpty &&
        _smtpSenderNameController.text.trim().isEmpty;
  }

  /// Kulatý leading jako u seznamů Služeb/Checklistů – barva podle kanálu (modrá SMS/SMTP, zelená WhatsApp).
  Widget _leadingIntegrationIcon({
    required Color backgroundColor,
    required Color iconColor,
    required IconData icon,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 28),
    );
  }

  /// Obal jedné integrace – stín a zaoblení jako u master dat v Nastavení.
  Widget _buildIntegrationExpansionCard({
    required BuildContext context,
    required Widget leading,
    required String title,
    required String subtitle,
    required List<Widget> children,
    ValueChanged<bool>? onExpansionChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: onExpansionChanged,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: leading,
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.grey[900],
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }

  /// Obsah sekce SMS (bez vnořeného nadpisu – ten je v řádku [ExpansionTile]).
  Widget _buildSmsSectionBody(
    BuildContext context, {
    required String? twilioPhone,
    required String tenantId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (twilioPhone != null && twilioPhone.isNotEmpty) ...[
          Text(
            'settings.integrations.twilio_active_label'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            twilioPhone,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
        ] else ...[
          Text(
            'settings.integrations.twilio_intro'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'settings.integrations.twilio_country_label'.tr(),
              border: const OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _twilioCountryCode,
                items: [
                  DropdownMenuItem(
                    value: 'US',
                    child: Text('settings.integrations.twilio_country_us'.tr()),
                  ),
                  DropdownMenuItem(
                    value: 'GB',
                    child: Text('settings.integrations.twilio_country_gb'.tr()),
                  ),
                  DropdownMenuItem(
                    value: 'ES',
                    child: Text('settings.integrations.twilio_country_es'.tr()),
                  ),
                ],
                onChanged: _twilioProvisioning || _saving
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => _twilioCountryCode = v);
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: (_twilioProvisioning || _saving)
                ? null
                : () => _onProvisionTwilio(tenantId),
            icon: _twilioProvisioning
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.phone_android_outlined),
            label: Text('settings.integrations.twilio_provision_button'.tr()),
          ),
        ],
        const SizedBox(height: 14),
        _buildIntegrationInfoNote(context, 'settings.integrations.twilio_sms_fallback_info'),
      ],
    );
  }

  /// Obsah sekce SMTP.
  Widget _buildSmtpSectionBody(BuildContext context, {required String tenantId}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _smtpHostController,
          keyboardType: TextInputType.text,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'settings.integrations.smtp_host'.tr(),
            hintText: 'settings.integrations.smtp_host_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _smtpPortController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'settings.integrations.smtp_port'.tr(),
            hintText: 'settings.integrations.smtp_port_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _smtpUsernameController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'settings.integrations.smtp_username'.tr(),
            hintText: 'settings.integrations.smtp_username_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _smtpPasswordController,
          obscureText: true,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'settings.integrations.smtp_password'.tr(),
            hintText: 'settings.integrations.smtp_password_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _smtpSenderNameController,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'settings.integrations.smtp_sender_name'.tr(),
            hintText: 'settings.integrations.smtp_sender_name_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        if (_isSmtpFieldsEmpty()) ...[
          const SizedBox(height: 14),
          _buildIntegrationInfoNote(context, 'settings.integrations.smtp_empty_fallback_info'),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: (_saving || !_dirty) ? null : () => _onSave(tenantId),
          icon: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text('settings.integrations.save_button'.tr()),
        ),
      ],
    );
  }

  /// Obsah sekce WhatsApp / Twilio API.
  Widget _buildWhatsappSectionBody(
    BuildContext context, {
    required bool customTwilioModuleActive,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (customTwilioModuleActive) ...[
          Text(
            'settings.integrations.twilio_api_intro'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _twilioSidController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'settings.integrations.twilio_account_sid'.tr(),
              hintText: 'settings.integrations.twilio_account_sid_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _twilioTokenController,
            obscureText: true,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'settings.integrations.twilio_auth_token'.tr(),
              hintText: 'settings.integrations.twilio_auth_token_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'settings.integrations.twilio_unlocked_save_hint'.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ] else ...[
          _buildWhatsappLockedFieldsOnly(context),
        ],
      ],
    );
  }

  /// PROČ: Bez překryvů a zámků nad poli – vizuální náhled neaktivního stavu; upsell je v dialogu.
  Widget _buildWhatsappLockedFieldsOnly(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabledFill = scheme.surfaceContainerHighest.withValues(alpha: 0.88);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _twilioSidController,
          enabled: false,
          readOnly: true,
          autocorrect: false,
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.62)),
          decoration: InputDecoration(
            labelText: 'settings.integrations.twilio_account_sid'.tr(),
            hintText: 'settings.integrations.twilio_account_sid_hint'.tr(),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: disabledFill,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _twilioTokenController,
          enabled: false,
          readOnly: true,
          obscureText: true,
          autocorrect: false,
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.62)),
          decoration: InputDecoration(
            labelText: 'settings.integrations.twilio_auth_token'.tr(),
            hintText: 'settings.integrations.twilio_auth_token_hint'.tr(),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: disabledFill,
          ),
        ),
      ],
    );
  }

  String _subtitleSms(String? twilioPhone) {
    final p = twilioPhone?.trim();
    if (p != null && p.isNotEmpty) {
      return 'settings.integrations.row_status_sms_active'.tr(namedArgs: {'phone': p});
    }
    return 'settings.integrations.row_status_not_configured'.tr();
  }

  String _subtitleEmail() {
    return _isSmtpFieldsEmpty()
        ? 'settings.integrations.row_status_email_default'.tr()
        : 'settings.integrations.row_status_email_custom'.tr();
  }

  String _subtitleWhatsapp(bool moduleActive, Map<String, dynamic> map) {
    if (!moduleActive) {
      return 'settings.integrations.row_status_whatsapp_locked'.tr();
    }
    final sid = map[kTenantIntegrationTwilioAccountSid]?.toString().trim();
    if (sid != null && sid.isNotEmpty) {
      return 'settings.integrations.row_status_whatsapp_ready'.tr();
    }
    return 'settings.integrations.row_status_not_configured'.tr();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;

    if (tenantId == null || tenantId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'settings.integrations.no_tenant'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final asyncMap = ref.watch(tenantIntegrationSettingsProvider(tenantId));

    return asyncMap.when(
      data: (map) {
        final customTwilioActive = isModuleActive(ref, 'custom_twilio_whatsapp');
        _seedFromMapIfNeeded(map, customTwilioModuleActive: customTwilioActive);
        final twilioPhone = map[kTenantIntegrationTwilioPhoneNumber]?.toString().trim();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings.integrations.title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                  _buildIntegrationExpansionCard(
                    context: context,
                    leading: _leadingIntegrationIcon(
                      backgroundColor: Colors.blue.shade50,
                      iconColor: Colors.blue.shade700,
                      icon: Icons.sms_outlined,
                    ),
                    title: 'settings.integrations.card_sms_title'.tr(),
                    subtitle: _subtitleSms(twilioPhone),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildSmsSectionBody(
                          context,
                          twilioPhone: twilioPhone,
                          tenantId: tenantId,
                        ),
                      ),
                    ],
                  ),
                  _buildIntegrationExpansionCard(
                    context: context,
                    leading: _leadingIntegrationIcon(
                      backgroundColor: Colors.blue.shade50,
                      iconColor: Colors.blue.shade700,
                      icon: Icons.email_outlined,
                    ),
                    title: 'settings.integrations.card_smtp_title'.tr(),
                    subtitle: _subtitleEmail(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildSmtpSectionBody(context, tenantId: tenantId),
                      ),
                    ],
                  ),
                  _buildIntegrationExpansionCard(
                    context: context,
                    leading: _leadingIntegrationIcon(
                      backgroundColor: Colors.green.shade50,
                      iconColor: Colors.green.shade700,
                      icon: Icons.chat_outlined,
                    ),
                    title: 'settings.integrations.card_whatsapp_title'.tr(),
                    subtitle: _subtitleWhatsapp(customTwilioActive, map),
                    onExpansionChanged: (expanded) {
                      if (!expanded) return;
                      if (customTwilioActive) return;
                      if (_whatsappUpsellShown) return;
                      _whatsappUpsellShown = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        PremiumUpsellDialog.show(
                          context,
                          moduleKey: 'custom_twilio_whatsapp',
                          titleKey: 'admin.upsell.custom_twilio_whatsapp.title',
                          descriptionKey: 'admin.upsell.custom_twilio_whatsapp.description',
                        );
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildWhatsappSectionBody(
                          context,
                          customTwilioModuleActive: customTwilioActive,
                        ),
                      ),
                    ],
                  ),
                ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'settings.integrations.save_error'.tr(namedArgs: {'message': '$e'}),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
