import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Veřejná obrazovka registrace nové agentury (Fáze 3 – Multi-tenancy).
///
/// Umožňuje nezaregistrovaným uživatelům založit novou firmu. Formulář obsahuje
/// název agentury, jméno správce, e-mail a heslo. Po úspěšné registraci se
/// uživatel přihlásí a přesměruje na domovskou obrazovku.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agencyNameController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  /// Během volání Supabase signUp je true – zobrazí se loading, formulář je disabled
  bool _isSubmitting = false;

  @override
  void dispose() {
    _agencyNameController.dispose();
    _managerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// Hlavní logika registrace – volá se po kliknutí na "Zaregistrovat firmu".
  ///
  /// Chytrá registrace podle e-mailu:
  /// 1. PŘED signUp: Zkontroluj tabulku invitations podle e-mailu.
  /// 2. Varianta A (pozvánka existuje): signUp, zapiš do profiles z pozvánky, smaž pozvánku.
  /// 3. Varianta B (organický uživatel): signUp, RPC register_agency vytvoří tenanta.
  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final agencyName = _agencyNameController.text.trim();
    final managerName = _managerNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (password != passwordConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding.validation_password_mismatch'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print('--- DEBUG REGISTRACE: Hledám pozvánku pro $email');
      }

      // Krok 0: Kontrola pozvánky PŘED vytvořením tenanta
      final invite = await SupabaseService.client
          .from('invitations')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (kDebugMode) {
        // ignore: avoid_print
        print('--- DEBUG REGISTRACE: Nalezena pozvánka: $invite');
      }

      final inviteData = invite != null
          ? Map<String, dynamic>.from(invite as Map)
          : null;

      // Krok 1: Vytvoření účtu v Supabase Auth
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (kDebugMode) {
        // ignore: avoid_print
        print('--- DEBUG REGISTRACE: SignUp úspěšný. UID: ${response.user?.id}');
      }

      if (user == null || SupabaseService.client.auth.currentUser == null) {
        // signUp bez session (např. email confirmation vyžadován)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('onboarding.success'.tr()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/');
        return;
      }

      if (inviteData != null) {
        // Varianta A: Pozvánka existuje – ignoruj název agentury, použij data z pozvánky
        final tenantIdRaw = inviteData['tenant_id']?.toString();
        if (tenantIdRaw == null || tenantIdRaw.isEmpty) {
          throw Exception('Pozvánka nemá platné tenant_id');
        }
        final tenantId = tenantIdRaw;
        final role = inviteData['role'] as String? ?? 'admin';
        final firstName = inviteData['first_name'] as String? ?? '';
        final lastName = inviteData['last_name'] as String? ?? '';
        // STRIKTNĚ jméno z pozvánky – ignoruj cokoliv z formuláře.
        var displayName = '$firstName $lastName'.trim();
        if (displayName.isEmpty) {
          displayName = email.split('@').first;
        }
        if (displayName.isEmpty) {
          displayName = email;
        }

        // Týmové role z pozvánky – ulož přímo do sloupce profiles.roles (text[]).
        final rolesRaw = inviteData['roles'];
        List<String> rolesList = [];
        if (rolesRaw != null && rolesRaw is List && (rolesRaw).isNotEmpty) {
          const validRoles = ['admin', 'cleaner', 'driver', 'maintenance'];
          for (final r in rolesRaw) {
            final roleStr = (r?.toString().trim() ?? '').toString();
            if (roleStr.isNotEmpty && validRoles.contains(roleStr)) {
              rolesList.add(roleStr);
            }
          }
        }

        // Ghost Profile Strategy: Trigger handle_new_user již propojil profil (auth_id, status).
        // Aktualizujeme name, role, roles podle pozvánky.
        final profileUpdate = <String, dynamic>{
          'role': role,
          'name': displayName,
          'first_name': firstName,
          'last_name': lastName,
        };
        if (rolesList.isNotEmpty) {
          profileUpdate['roles'] = rolesList;
        }
        await SupabaseService.client
            .from('profiles')
            .update(profileUpdate)
            .eq('auth_id', user.id);

        if (kDebugMode) {
          // ignore: avoid_print
          print('--- DEBUG REGISTRACE: Profil aktualizován/vytvořen.');
        }

        // Smaž pozvánku, aby už nebyla aktivní.
        // Pozn.: RLS na invitations musí umožnit delete (např. vlastník záznamu nebo RPC).
        try {
          final inviteId = inviteData['id'];
          if (inviteId != null) {
            await SupabaseService.client
                .from('invitations')
                .delete()
                .eq('id', inviteId);
          } else {
            await SupabaseService.client
                .from('invitations')
                .delete()
                .eq('email', email)
                .eq('tenant_id', tenantId); // tenantId je non-null (validováno výše)
          }
          if (kDebugMode) {
            // ignore: avoid_print
            print('--- DEBUG REGISTRACE: Pozvánka smazána.');
          }
        } catch (delErr) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('--- DEBUG REGISTRACE: Smazání pozvánky selhalo (registrace OK): $delErr');
          }
          // Smazání pozvánky selhalo (např. RLS) – registrace proběhla, pozvánka zůstane
        }
      } else {
        if (kDebugMode) {
          // ignore: avoid_print
          print('--- DEBUG REGISTRACE: Organická registrace (bez pozvánky)');
        }
        // Varianta B: Organický uživatel – vytvoř nového tenanta přes RPC
        final tenantId = await SupabaseService.client.rpc(
          'register_agency',
          params: {
            'p_agency_name': agencyName,
            'p_manager_name': managerName,
          },
        ) as String?;

        if (tenantId == null || tenantId.isEmpty) {
          throw Exception('RPC register_agency nevrátilo tenant_id');
        }
      }

      if (!mounted) return;

      if (kDebugMode) {
        // ignore: avoid_print
        print('--- DEBUG REGISTRACE: Načítám profil před navigací...');
      }
      // Načti profil (role, tenant_id) PŘED navigací – plynulý přechod bez auth-loading
      await ref.read(authNotifierProvider).reloadProfile();

      if (kDebugMode) {
        // ignore: avoid_print
        print('--- DEBUG REGISTRACE: Úspěch! Přesměrovávám na dashboard.');
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding.welcome'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/admin');
    } on AuthException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('--- FATAL ERROR PŘI REGISTRACI (AuthException): $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('--- FATAL ERROR PŘI REGISTRACI: $e');
        // ignore: avoid_print
        print('--- Stack trace: $st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('onboarding.error_generic'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    Text(
                      'onboarding.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'onboarding.subtitle'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Karta s formulářem – prémiový design
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextFormField(
                            controller: _agencyNameController,
                            label: 'onboarding.field_agency_name'.tr(),
                            hint: 'onboarding.hint_agency_name'.tr(),
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              return t.isEmpty
                                  ? 'onboarding.validation_agency_required'.tr()
                                  : null;
                            },
                            enabled: !_isSubmitting,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'onboarding.invitation_hint'.tr(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildTextFormField(
                            controller: _managerNameController,
                            label: 'onboarding.field_manager_name'.tr(),
                            hint: 'onboarding.hint_manager_name'.tr(),
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              return t.isEmpty
                                  ? 'onboarding.validation_manager_required'.tr()
                                  : null;
                            },
                            enabled: !_isSubmitting,
                          ),
                          const SizedBox(height: 20),
                          _buildTextFormField(
                            controller: _emailController,
                            label: 'onboarding.field_email'.tr(),
                            hint: 'onboarding.hint_email'.tr(),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) {
                                return 'onboarding.validation_email_required'.tr();
                              }
                              if (!t.contains('@')) {
                                return 'onboarding.validation_email_format'.tr();
                              }
                              return null;
                            },
                            enabled: !_isSubmitting,
                          ),
                          const SizedBox(height: 20),
                          _buildTextFormField(
                            controller: _passwordController,
                            label: 'onboarding.field_password'.tr(),
                            hint: 'onboarding.hint_password'.tr(),
                            obscureText: true,
                            validator: (v) {
                              final t = v ?? '';
                              if (t.isEmpty) {
                                return 'onboarding.validation_password_required'.tr();
                              }
                              if (t.length < 6) {
                                return 'onboarding.validation_password_min'.tr();
                              }
                              return null;
                            },
                            enabled: !_isSubmitting,
                          ),
                          const SizedBox(height: 20),
                          _buildTextFormField(
                            controller: _passwordConfirmController,
                            label: 'onboarding.field_password_confirm'.tr(),
                            hint: 'onboarding.hint_password_confirm'.tr(),
                            obscureText: true,
                            validator: (v) {
                              final t = v ?? '';
                              if (t.isEmpty) {
                                return 'onboarding.validation_password_required'.tr();
                              }
                              if (t != _passwordController.text) {
                                return 'onboarding.validation_password_mismatch'.tr();
                              }
                              return null;
                            },
                            enabled: !_isSubmitting,
                          ),

                          const SizedBox(height: 28),

                          if (_isSubmitting)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                ),
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: _onRegister,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'onboarding.btn_register'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: _isSubmitting ? null : () => context.pop(),
                      child: Text(
                        'common.back'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sdílené textové pole s jednotným stylem pro prémiový vzhled.
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?)? validator,
    required bool enabled,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
