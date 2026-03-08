import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/providers/hq_staff_provider.dart';

/// Modální dialog pro pozvání nového člena HQ týmu (Super-Admin / Account Manager).
///
/// PROČ: Ghost Profile Strategy – nejprve vytvoříme profil s tenant_id = null a role,
/// pak pozvánku s tenant_id = null. Po uložení invalidujeme [hqStaffListProvider],
/// aby se nový člen objevil v seznamu HQ týmu.
/// Používá [showAppModal] pro jednotný vizuál (blur, animace) s Nastavením a Fakturačním modalem.
class AddHqMemberDialog extends ConsumerStatefulWidget {
  const AddHqMemberDialog({super.key});

  /// Otevře dialog. Po úspěšném uložení invaliduje [hqStaffListProvider].
  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showAppModal<void>(
      context: context,
      barrierLabel: 'super_admin.barrier_hq_member'.tr(),
      maxWidth: 480,
      child: const AddHqMemberDialog(),
    );
  }

  @override
  ConsumerState<AddHqMemberDialog> createState() => _AddHqMemberDialogState();
}

class _AddHqMemberDialogState extends ConsumerState<AddHqMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  String _role = 'account_manager';
  bool _isSaving = false;
  String? _globalError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() {
      _isSaving = true;
      _globalError = null;
    });
    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final name = '$firstName $lastName'.trim();
      final displayName = name.isEmpty ? email : name;

      final profileRes = await SupabaseService.client
          .from('profiles')
          .insert({
            'tenant_id': null,
            'email': email,
            'first_name': firstName.isEmpty ? null : firstName,
            'last_name': lastName.isEmpty ? null : lastName,
            'name': displayName,
            'status': 'pending',
            'role': _role,
          })
          .select('id')
          .single();

      final profileId = (profileRes as Map<String, dynamic>)['id']?.toString();
      if (profileId == null || profileId.isEmpty) {
        throw Exception('super_admin.hq_member_profile_error'.tr());
      }

      await SupabaseService.client.from('invitations').insert({
        'tenant_id': null,
        'profile_id': profileId,
        'email': email,
        'first_name': firstName.isEmpty ? null : firstName,
        'last_name': lastName.isEmpty ? null : lastName,
        'role': _role,
      });

      if (!mounted) return;
      ref.invalidate(hqStaffListProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.hq_member_invited'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _globalError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('super_admin.hq_member_add_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_globalError != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _globalError!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_member_first_name'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_member_last_name'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_member_email'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'super_admin.hq_member_email_required'.tr();
                        if (!s.contains('@') || !s.contains('.')) return 'super_admin.hq_member_email_invalid'.tr();
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: InputDecoration(
                        labelText: 'super_admin.hq_member_role'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        DropdownMenuItem(value: 'super_admin', child: Text('super_admin.hq_team_role_super_admin'.tr())),
                        DropdownMenuItem(value: 'account_manager', child: Text('super_admin.hq_team_role_account_manager'.tr())),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'account_manager'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: Text('common.cancel'.tr()),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('common.save'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
