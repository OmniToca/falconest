import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Obrazovka pro dokončení registrace pozvaného zaměstnance.
///
/// Zaměstnanec přichází z e-mailu s odkazem (Supabase invite / magic link).
/// Tato obrazovka umožňuje nastavit heslo, aktualizuje profiles.status = 'active'
/// a přesměruje na dashboard podle role.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isSubmitting = false;
  bool _isRecoveringSession = true;
  bool _hasValidSession = false;

  @override
  void initState() {
    super.initState();
    _tryRecoverSession();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// Na webu: při příchodu z invite e-mailu obsahuje URL fragment (#access_token=...&type=invite).
  /// Zavoláme getSessionFromUrl, abychom obnovili session.
  Future<void> _tryRecoverSession() async {
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          _isRecoveringSession = false;
          _hasValidSession = true;
        });
      }
      return;
    }

    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.hasFragment && uri.fragment.contains('access_token')) {
        try {
          await SupabaseService.client.auth.getSessionFromUrl(uri);
          if (mounted) {
            setState(() {
              _isRecoveringSession = false;
              _hasValidSession = true;
            });
          }
          return;
        } catch (_) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('SetPasswordScreen: getSessionFromUrl failed');
          }
        }
      }
    }

    if (!kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final user = SupabaseService.client.auth.currentUser;
      if (mounted) {
        setState(() {
          _isRecoveringSession = false;
          _hasValidSession = user != null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isRecoveringSession = false;
        _hasValidSession = false;
      });
    }
  }

  Future<void> _onCompleteRegistration() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final password = _passwordController.text.trim();
    final confirm = _passwordConfirmController.text.trim();
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('set_password.validation_mismatch'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: password),
      );

      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        await SupabaseService.client
            .from('profiles')
            .update({'status': 'active'})
            .eq('auth_id', user.id);
      }

      if (!mounted) return;

      await ref.read(authNotifierProvider).reloadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('set_password.success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _navigateToDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('set_password.error'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _navigateToDashboard() {
    final authNotifier = ref.read(authNotifierProvider);
    final state = authNotifier.state;

    if (state.isSuperAdmin) {
      context.go('/super-admin');
    } else if (state.isAdminOrManager) {
      context.go('/admin');
    } else if (state.isPropertyOwner) {
      context.go('/owner');
    } else {
      context.go('/worker');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecoveringSession) {
      return Scaffold(
        backgroundColor: const Color(0xFF1565C0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'common.loading'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasValidSession) {
      return Scaffold(
        backgroundColor: const Color(0xFF1565C0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'set_password.invalid_link'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text('login.title'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'set_password.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isSubmitting,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'set_password.field_password'.tr(),
                        hintText: 'set_password.hint_password'.tr(),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) {
                          return 'set_password.validation_required'.tr();
                        }
                        if (t.length < 6) {
                          return 'set_password.validation_min'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordConfirmController,
                      obscureText: _obscurePasswordConfirm,
                      enabled: !_isSubmitting,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'set_password.field_confirm'.tr(),
                        hintText: 'set_password.hint_confirm'.tr(),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePasswordConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          onPressed: () {
                            setState(() => _obscurePasswordConfirm =
                                !_obscurePasswordConfirm);
                          },
                        ),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) {
                          return 'set_password.validation_required'.tr();
                        }
                        if (t != _passwordController.text.trim()) {
                          return 'set_password.validation_mismatch'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    if (_isSubmitting)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      FilledButton(
                        onPressed: _onCompleteRegistration,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'set_password.btn_complete'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
