import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/login_service.dart';
import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Firemní barvy FalcoNest.
class _AppColors {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color accentOrange = Color(0xFFE65100);
}

/// Šířka od které se zobrazí split-screen (levá grafika, pravá karta). Pod ní mobilní layout (logo + formulář).
const double _kSplitBreakpoint = 800;

/// Obrazovka přihlášení – rozdílná logika pro Web a Mobil.
///
/// **Web:** Formulář E-mail + Heslo. Bez PINu.
/// **Mobil:** První přihlášení = E-mail + Heslo, pak vytvoření 6místného PINu.
/// Každé další = číselník pro PIN (session aktivní). Tlačítko "Přihlásit se e-mailem"
/// vymaže PIN a vrátí na formulář.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// WEB: Přihlášení e-mailem a heslem.
  Future<void> _onWebLogin() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final success = await loginWithEmailPassword(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) _showErrorSnackBar();
    // Úspěch → GoRouter redirect podle role
  }

  /// MOBIL: Přihlášení e-mailem a heslem.
  Future<void> _onMobileEmailLogin() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final success = await loginWithEmailPassword(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      final hasPin = await PinStorage.hasPin();
      if (!mounted) return;
      if (!hasPin) {
        context.go('/pin-setup');
      } else {
        context.go('/pin-verify');
      }
    } else {
      _showErrorSnackBar();
    }
  }

  final _formKey = GlobalKey<FormState>();

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('login.error_invalid'.tr()),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Zobrazí dialog pro obnovení hesla. Po zadání e-mailu odešle
  /// reset link přes Supabase Auth. Při úspěchu/chybě zobrazí SnackBar.
  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    // PROČ: Po await uvnitř dialogu nepoužíváme BuildContext obrazovky – SnackBar přes instanci zachycenou před dialogem.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('forgot_password.dialog_title'.tr()),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'forgot_password.dialog_message'.tr(),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'forgot_password.field_email'.tr(),
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'login.validation_email_required'.tr();
                    if (!t.contains('@')) return 'login.validation_email_format'.tr();
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final email = emailController.text.trim();
              try {
                // Pro web: redirectTo vede uživatele zpět do aplikace na /update-password
                final redirectTo = '${Uri.base.origin}/update-password';
                await SupabaseService.client.auth.resetPasswordForEmail(
                  email,
                  redirectTo: redirectTo,
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('forgot_password.success'.tr()),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (_) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('forgot_password.error'.tr()),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('forgot_password.btn_send'.tr()),
          ),
        ],
      ),
    );

    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.watch(authNotifierProvider);
    final profileError = authNotifier.profileLoadError;
    if (profileError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(profileError),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          authNotifier.clearProfileLoadError();
        }
      });
    }

    // Jednotný responzivní layout pro Web i Mobil. Rozdělení Web/Mobil zůstává jen v callbacku
    // onLogin: Web volá _onWebLogin, Mobil _onMobileEmailLogin (včetně přesměrování na PIN).
    return _AuthLayout(
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      isSubmitting: _isSubmitting,
      onLogin: kIsWeb ? _onWebLogin : _onMobileEmailLogin,
      onForgotPassword: _showForgotPasswordDialog,
    );
  }
}

/// Responzivní split-screen layout přihlášení: Web/Tablet = levá polovina branding, pravá karta s formulářem;
/// mobil = kompaktní header (logo bez velkého modrého pozadí) + scrollovatelný formulář pod ním.
/// Zachovává stejné callbacky (onLogin) – Web vs Mobil se řeší v LoginScreen (kIsWeb ? _onWebLogin : _onMobileEmailLogin).
class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isSubmitting,
    required this.onLogin,
    required this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;

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

  Widget _buildFormCard(BuildContext context) {
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
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'login.title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                  ),
                  const SizedBox(height: 28),
                  _AuthTextField(
                    controller: emailController,
                    label: 'login.field_email'.tr(),
                    hint: 'login.hint_email'.tr(),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isSubmitting,
                    forLightBackground: true,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'login.validation_email_required'.tr();
                      if (!t.contains('@')) return 'login.validation_email_format'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _AuthTextField(
                    controller: passwordController,
                    label: 'login.field_password'.tr(),
                    hint: 'login.hint_password'.tr(),
                    obscureText: true,
                    enabled: !isSubmitting,
                    forLightBackground: true,
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'login.validation_password_required'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  if (isSubmitting)
                    const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: onLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: _AppColors.accentOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'login.btn_login'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isSubmitting ? null : onForgotPassword,
                    child: Text('login.forgot_password'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSubmitting ? null : () => context.push('/register'),
                    child: Text('login.create_agency'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: width < _kSplitBreakpoint ? _AppColors.primaryBlue : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width >= _kSplitBreakpoint) {
            return Row(
              children: [
                Expanded(child: _buildBrandingPanel()),
                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    child: _buildFormCard(context),
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
                  _buildFormCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sdílené textové pole pro e-mail/heslo.
/// [forLightBackground]: true = tmavý text a okraje (pro bílou kartu), false = bílý styl na modrém pozadí.
class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.forLightBackground = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool forLightBackground;

  @override
  Widget build(BuildContext context) {
    if (forLightBackground) {
      return TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: Colors.grey.shade900, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey.shade700),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _AppColors.primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
    }
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _AppColors.accentOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
