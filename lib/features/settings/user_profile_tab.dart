import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';

/// První záložka v Nastavení – vizitka identity a změna hesla.
///
/// Zobrazení identity aktuálního uživatele a jeho domovské agentury.
class UserProfileTab extends ConsumerStatefulWidget {
  const UserProfileTab({super.key});

  @override
  ConsumerState<UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends ConsumerState<UserProfileTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Bezpečná změna hesla přímo přes Supabase Auth API.
  Future<void> _onChangePassword() async {
    if (!_formKey.currentState!.validate() || _isChangingPassword) return;

    final newPassword = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.profile_validation_password_required'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (newPassword != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.profile_validation_password_mismatch'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.profile_validation_password_min'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;

      _newPasswordController.clear();
      _confirmPasswordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.profile_password_success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.profile_password_error'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  String _roleLabel(String? role) {
    if (role == null || role.isEmpty) return 'settings.profile_tenant_none'.tr();
    final key = 'settings.profile_role_${role.toLowerCase()}';
    final translated = key.tr();
    return translated != key ? translated : role;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final tenantNameAsync = ref.watch(currentTenantNameProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final role = ref.watch(authNotifierProvider).state.role;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVizitka(context, tenantNameAsync, profileAsync, role),
          const SizedBox(height: 24),
          _buildSecuritySection(context),
        ],
      ),
    );
  }

  /// Vizitka – agentura (tenant) a údaje přihlášeného uživatele.
  Widget _buildVizitka(
    BuildContext context,
    AsyncValue<String> tenantNameAsync,
    AsyncValue<CurrentUserProfile> profileAsync,
    String? role,
  ) {
    final tenantName = tenantNameAsync.valueOrNull ?? '';
    final profile = profileAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.business_rounded, size: 28, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName.isEmpty
                          ? 'settings.profile_tenant_none'.tr()
                          : tenantName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _ProfileRow(
            icon: Icons.person_rounded,
            label: profile?.name ?? '—',
          ),
          const SizedBox(height: 8),
          _ProfileRow(
            icon: Icons.email_rounded,
            label: profile?.email ?? '—',
          ),
          const SizedBox(height: 8),
          _ProfileRow(
            icon: Icons.badge_rounded,
            label: _roleLabel(role),
          ),
        ],
      ),
    );
  }

  /// Sekce Zabezpečení účtu – formulář pro změnu hesla.
  Widget _buildSecuritySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'settings.profile_security_section'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'settings.profile_field_new_password'.tr(),
                hintText: 'settings.profile_hint_password'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'settings.profile_validation_password_required'.tr();
                }
                if (v.trim().length < 6) {
                  return 'settings.profile_validation_password_min'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'settings.profile_field_confirm_password'.tr(),
                hintText: 'settings.profile_hint_password'.tr(),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'settings.profile_validation_password_required'.tr();
                }
                if (v.trim() != _newPasswordController.text.trim()) {
                  return 'settings.profile_validation_password_mismatch'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isChangingPassword ? null : _onChangePassword,
              icon: _isChangingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset),
              label: Text('settings.profile_btn_change_password'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Řádek v vizitce – ikona a text.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[800],
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
