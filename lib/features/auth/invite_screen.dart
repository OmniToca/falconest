import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/invite_repository.dart';
import 'package:falconest/features/auth/providers/invite_provider.dart';

/// Obrazovka pro přijetí pozvánky (zvací proces – pracovníci a majitelé).
///
/// Token z URL (/invite?token=...) načte záznam z tabulky [invitations]. Pokud je pozvánka platná,
/// zobrazí formulář (e-mail read-only, heslo, potvrzení hesla). Po odeslání: signUp, propojení
/// ghost profilu s auth_id, smazání pozvánky a přesměrování na dashboard.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// Odeslání formuláře: ověření shody hesel, volání repozitáře, reload profilu a přesměrování.
  Future<void> _onSubmit(String token) async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('invite.error_password_mismatch'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await InviteRepository.instance.acceptInvitation(token, password);
      if (!mounted) return;
      await ref.read(authNotifierProvider.notifier).reloadProfile();
      if (!mounted) return;
      context.go('/auth-loading');
    } on InviteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.i18nKey.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('invite.error_signup_failed'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queryParams = GoRouterState.of(context).uri.queryParameters;
    final token = (queryParams['token'] ?? queryParams['id'] ?? '').trim();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final useSplit = width >= _kSplitBreakpoint;

          final branding = _buildBrandingPanel();
          final content = token.isEmpty
              ? _buildErrorContent(context)
              : _buildContent(context, token: token);

          if (useSplit) {
            return Row(
              children: [
                Expanded(child: branding),
                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    child: content,
                  ),
                ),
              ],
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMobileBrandingHeader(),
                  content,
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static const double _kSplitBreakpoint = 800;

  /// Levý panel pro split-screen (Web/Tablet) – modrý gradient s logem a tagline.
  Widget _buildBrandingPanel() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 280,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(
                  'app.title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'login.tagline'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobilní header: jen logo bez velkého modrého pozadí, aby formulář nebyl překryt.
  Widget _buildMobileBrandingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Text(
            'app.title'.tr(),
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required String token}) {
    final inviteAsync = ref.watch(inviteDataProvider(token));

    return inviteAsync.when(
      data: (invitation) {
        if (invitation == null) {
          return _buildErrorContent(context);
        }
        return _buildFormContent(context, token: token, invitation: invitation);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _buildErrorContent(context),
    );
  }

  /// Chybový stav: neplatná/vypršelá pozvánka nebo chybějící token. Tlačítko zpět na přihlášení.
  Widget _buildErrorContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Card(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'invite.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'invite.error_invalid_or_expired'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('invite.btn_back_login'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formulář: e-mail (read-only), nové heslo, potvrzení hesla, tlačítko odeslání.
  Widget _buildFormContent(
    BuildContext context, {
    required String token,
    required InvitationData invitation,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Card(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'invite.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'invite.welcome'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    initialValue: invitation.email,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'invite.field_email'.tr(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'invite.field_password'.tr(),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if ((v ?? '').length < 6) return 'invite.error_password_too_short'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordConfirmController,
                    obscureText: _obscurePasswordConfirm,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'invite.field_password_confirm'.tr(),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                      ),
                    ),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'invite.error_password_too_short'.tr();
                      if ((v ?? '') != _passwordController.text) return 'invite.error_password_mismatch'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  if (_isSubmitting)
                    const Center(child: CircularProgressIndicator())
                  else
                    FilledButton(
                      onPressed: () => _onSubmit(token),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('invite.btn_submit'.tr()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
