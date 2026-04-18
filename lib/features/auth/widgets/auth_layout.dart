import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/auth/widgets/auth_login_colors.dart';
import 'package:falconest/features/auth/widgets/auth_text_field.dart';

/// Responzivní split-screen layout přihlášení: Web/Tablet = branding vlevo, karta vpravo;
/// mobil = kompaktní logo + scrollovatelný formulář.
///
/// PROČ: Odděleno od [LoginScreen], aby obrazovka řídila jen auth logiku a callbacks.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
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
                  AuthTextField(
                    controller: emailController,
                    label: 'login.field_email'.tr(),
                    hint: 'login.hint_email'.tr(),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isSubmitting,
                    autofocus: true,
                    forLightBackground: true,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'login.validation_email_required'.tr();
                      if (!t.contains('@')) return 'login.validation_email_format'.tr();
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
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
                        backgroundColor: AuthLoginColors.accentOrange,
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
    return Scaffold(
      backgroundColor: MediaQuery.of(context).size.width < kAuthLoginSplitBreakpoint
          ? AuthLoginColors.primaryBlue
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width >= kAuthLoginSplitBreakpoint) {
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
