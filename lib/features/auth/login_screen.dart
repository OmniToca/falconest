import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/login_service.dart';
import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/auth/widgets/auth_layout.dart';

/// Obrazovka přihlášení – rozdílná logika pro Web a Mobil.
///
/// **Web:** Formulář E-mail + Heslo. Bez PINu.
/// **Mobil:** První přihlášení = E-mail + Heslo, pak vytvoření 6místného PINu.
/// Každé další = číselník pro PIN (session aktivní). Tlačítko "Přihlásit se e-mailem"
/// vymaže PIN a vrátí na formulář.
///
/// PROČ: Vizuální layout je v [AuthLayout] (`widgets/`), aby tato třída držela jen auth stav a handlery (SRP).
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
    return AuthLayout(
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      isSubmitting: _isSubmitting,
      onLogin: kIsWeb ? _onWebLogin : _onMobileEmailLogin,
      onForgotPassword: _showForgotPasswordDialog,
    );
  }
}
