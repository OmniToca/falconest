import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:falconest/features/admin/providers/zones_provider.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';

/// Odpojí personál od budoucích, nedokončených úkolů v zadaném rozsahu datumů.
/// [fromDate] – úkoly s due_date >= fromDate; [toDate] – úkoly s due_date <= toDate.
/// Zachovává historii: úkoly se stavem „Hotovo“ se nemění.
Future<void> _unassignTasksForMember(
  WidgetRef ref,
  String memberId, {
  DateTime? fromDate,
  DateTime? toDate,
}) async {
  if (memberId.isEmpty) return;
  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return;
  try {
    final tasksRes = await SupabaseService.client
        .from('tasks')
        .select('id, due_date, status')
        .eq('tenant_id', tenantId)
        .eq('assigned_to', memberId)
        .isFilter('deleted_at', null);
    final taskList = tasksRes as List<dynamic>? ?? [];
    for (final t in taskList) {
      final map = t is Map ? Map<String, dynamic>.from(t) : null;
      if (map == null) continue;
      final status = (map['status'] as String?)?.trim() ?? '';
      final isCompleted = status.toLowerCase().contains('hotovo') || status == 'completed';
      if (isCompleted) continue;
      final dueRaw = map['due_date'];
      DateTime? due;
      if (dueRaw is DateTime) {
        due = dueRaw;
      } else if (dueRaw != null) {
        due = DateTime.tryParse(dueRaw.toString());
      }
      if (due == null) continue;
      final dueDay = DateTime(due.year, due.month, due.day);
      if (fromDate != null) {
        final fromDay = DateTime(fromDate.year, fromDate.month, fromDate.day);
        if (dueDay.isBefore(fromDay)) continue;
      }
      if (toDate != null) {
        final toDay = DateTime(toDate.year, toDate.month, toDate.day);
        if (dueDay.isAfter(toDay)) continue;
      }
      final taskId = map['id']?.toString();
      if (taskId == null || taskId.isEmpty) continue;
      await SupabaseService.client
          .from('tasks')
          .update({'assigned_to': null, 'assigned_user_id': null})
          .eq('id', taskId)
          .eq('tenant_id', tenantId);
    }
    ref.invalidate(adminTasksProvider);
    ref.invalidate(planningCalendarAllTasksProvider);
    ref.invalidate(planningCalendarAllTasksForMonthProvider);
  } catch (_) {}
}

/// Obrazovka správy týmu – profiles + invitations, editace, mazání.
/// Horní lišta a karty sjednoceny se Správou bytů.
class AdminTeamScreen extends ConsumerStatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  ConsumerState<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends ConsumerState<AdminTeamScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filtruje členy podle jména nebo role (case insensitive) – jméno i české/anglické názvy rolí.
  List<TeamMember> _computeFiltered(List<TeamMember> members) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return members;
    final roleLabels = {
      'admin': 'admin',
      'cleaner': 'admin.role_cleaner'.tr(),
      'driver': 'admin.role_driver'.tr(),
      'maintenance': 'admin.role_maintenance'.tr(),
      'checkin_agent': 'admin.role_checkin_agent'.tr(),
    };
    return members.where((m) {
      final name = m.name.toLowerCase();
      if (name.contains(query)) return true;
      for (final r in m.roles) {
        final label = (roleLabels[r] ?? r).toLowerCase();
        if (label.contains(query) || r.toLowerCase().contains(query)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(adminTeamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: teamAsync.when(
        data: (members) {
          final filtered = _computeFiltered(members);
          // Majitelé se zobrazují v samostatné sekci – vyřazujeme je z aktivních a čekajících.
          final staffOnly = filtered.where((m) => m.role != 'property_owner').toList();
          final activeMembers = staffOnly.where((m) => !m.isFromInvitation).toList();
          final pendingInvitations = staffOnly.where((m) => m.isFromInvitation).toList();
          final hasAny = activeMembers.isNotEmpty ||
              pendingInvitations.isNotEmpty ||
              ref.watch(propertyOwnersInTenantProvider).valueOrNull?.isNotEmpty == true;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TeamTopActionBar(
                searchController: _searchController,
                onSearchChanged: () => setState(() {}),
                onAdd: () => _showAddMemberDialog(context, ref),
              ),
              Expanded(
                child: !hasAny
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'admin.team_empty'.tr()
                              : 'admin.team_search_no_results'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isWide = constraints.maxWidth > 800;
                              final double cardWidth =
                                  isWide ? (constraints.maxWidth / 2) - 8 : constraints.maxWidth;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (activeMembers.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                                      child: Text(
                                        'admin.team_section_active'.tr(),
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: activeMembers
                                          .map((m) => SizedBox(
                                                width: cardWidth,
                                                child: _MemberCard(
                                                  member: m,
                                                  onEdit: (m) => _showEditDialog(context, ref, m),
                                                  onDelete: (m) => _showDeleteConfirm(context, ref, m),
                                                  onManageAbsence: (m) => _showAbsenceDialog(context, ref, m),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                  if (pendingInvitations.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.schedule, size: 18, color: Colors.orange.shade700),
                                          const SizedBox(width: 6),
                                          Text(
                                            'admin.team_section_pending_invitations'.tr(),
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade800,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: pendingInvitations
                                          .map((m) => SizedBox(
                                                width: cardWidth,
                                                child: _MemberCard(
                                                  member: m,
                                                  onEdit: (m) => _showEditDialog(context, ref, m),
                                                  onDelete: (m) => _showDeleteConfirm(context, ref, m),
                                                  onManageAbsence: (m) => _showAbsenceDialog(context, ref, m),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                  // Sekce Majitelé – profily s role=property_owner, zjednodušené karty.
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final ownersAsync = ref.watch(propertyOwnersInTenantProvider);
                                      return ownersAsync.when(
                                        data: (owners) {
                                          if (owners.isEmpty) return const SizedBox.shrink();
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 16),
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.home_outlined,
                                                        size: 18, color: Colors.teal.shade700),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'admin.team_section_owners'.tr(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.teal.shade800,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Wrap(
                                                spacing: 16,
                                                runSpacing: 16,
                                                children: owners
                                                    .map((o) => SizedBox(
                                                          width: cardWidth,
                                                          child: _OwnerCard(
                                                            owner: o,
                                                            onCopyLink: o.isPending
                                                                ? () {
                                                                    final token = o.profileId;
                                                                    final origin = Uri.base.origin;
                                                                    final inviteUrl =
                                                                        '$origin/#/invite?token=$token';
                                                                    Clipboard.setData(
                                                                        ClipboardData(text: inviteUrl));
                                                                    ScaffoldMessenger.of(context)
                                                                        .showSnackBar(
                                                                      SnackBar(
                                                                        content: Text(
                                                                            'admin.team_invite_copied_snackbar'.tr()),
                                                                        behavior:
                                                                            SnackBarBehavior.floating,
                                                                      ),
                                                                    );
                                                                  }
                                                                : null,
                                                            onDelete: () =>
                                                                _showDeleteConfirm(
                                                              context,
                                                              ref,
                                                              _ownerToTeamMember(o),
                                                            ),
                                                          ),
                                                        ))
                                                    .toList(),
                                              ),
                                            ],
                                          );
                                        },
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) => const SizedBox.shrink(),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'admin.team_load_error'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(adminTeamProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddMemberDialog(
        onAdded: () {
          ref.invalidate(adminTeamProvider);
          ref.invalidate(propertyOwnersInTenantProvider);
        },
      ),
    );
  }

  void _showAbsenceDialog(BuildContext context, WidgetRef ref, TeamMember member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AbsenceDialog(
        ref: ref,
        member: member,
        onSaved: () {
          ref.invalidate(staffAbsencesProvider);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TeamMember member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditMemberDialog(
        member: member,
        onSaved: () => ref.invalidate(adminTeamProvider),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    TeamMember member,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(
        member: member,
        ref: ref,
        onDeleted: () {
          ref.invalidate(adminTeamProvider);
          ref.invalidate(propertyOwnersInTenantProvider);
        },
      ),
    );
  }
}

/// Dialog potvrzení mazání člena – obsahuje logiku smazání (invitations / profiles).
class _DeleteConfirmDialog extends ConsumerStatefulWidget {
  const _DeleteConfirmDialog({
    required this.member,
    required this.ref,
    required this.onDeleted,
  });

  final TeamMember member;
  final WidgetRef ref;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_DeleteConfirmDialog> createState() =>
      _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends ConsumerState<_DeleteConfirmDialog> {
  bool _isDeleting = false;

  Future<void> _doDelete() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    try {
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      if (widget.member.isFromInvitation) {
        // Pending: soft delete profilu (záznam zůstane v DB, deleted_at vyplněn)
        await SupabaseService.client
            .from('profiles')
            .update({'deleted_at': deletedAt})
            .eq('id', widget.member.id);
        // Bezpečnostní zneplatnění pozvánky při smazání čekajícího uživatele.
        if (tenantId != null && tenantId.isNotEmpty) {
          try {
            await SupabaseService.client
                .from('invitations')
                .update({'deleted_at': deletedAt})
                .eq('profile_id', widget.member.id)
                .eq('tenant_id', tenantId);
          } catch (_) {
            // Fallback: tabulka invitations nemá deleted_at – fyzický DELETE.
            await SupabaseService.client
                .from('invitations')
                .delete()
                .eq('profile_id', widget.member.id)
                .eq('tenant_id', tenantId);
          }
        }
      } else {
        // Active: soft delete (deleted_at + tenant_id=null pro konzistenci)
        await SupabaseService.client
            .from('profiles')
            .update({'tenant_id': null, 'deleted_at': deletedAt})
            .eq('id', widget.member.id);
      }
      final userId = SupabaseService.client.auth.currentUser?.id;
      await AuditLogService.logEnterprise(
        tenantId: tenantId,
        userId: userId,
        actionType: 'SOFT_DELETE',
        tableName: 'profiles',
        recordId: widget.member.id,
        recordName: widget.member.name,
        previousState: widget.member.toJson(),
        triggeredBy: AuditTriggeredBy.manual,
      );

      await _unassignTasksForMember(ref, widget.member.id, fromDate: DateTime.now());

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDeleted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      // ignore: avoid_print
      print('--- CHYBA MAZÁNÍ ČLENA TÝMU: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('admin.team_delete'.tr()),
      content: Text('admin.team_delete_confirm'.tr()),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _isDeleting ? null : _doDelete,
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('admin.team_delete'.tr()),
        ),
      ],
    );
  }
}

/// Horní lišta – nadpis Personál, vyhledávání, fialové tlačítko Přidat člena (stejná struktura jako u Apartmánů).
class _TeamTopActionBar extends StatelessWidget {
  const _TeamTopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Text(
            'admin.menu_staff'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              decoration: InputDecoration(
                hintText: 'admin.team_search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: Text('admin.fab_add_member'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vrátí iniciály uživatele: první písmeno prvního a příjmení (např. „Monika Sokolová“ → „MS“, „Jan“ → „J“).
String _initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  final first = parts.first;
  if (first.isEmpty) return '?';
  final firstLetter = first[0].toUpperCase();
  if (parts.length == 1) return firstLetter;
  final last = parts.last;
  if (last.isEmpty) return firstLetter;
  return '$firstLetter${last[0].toUpperCase()}';
}

/// Karta člena – moderní design s avatarem, ikonami a plnou klikatelností (InkWell → úprava).
class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
    required this.onManageAbsence,
  });

  final TeamMember member;
  final ValueChanged<TeamMember> onEdit;
  final ValueChanged<TeamMember> onDelete;
  final ValueChanged<TeamMember> onManageAbsence;

  /// Formátuje poslední přihlášení pro Manager Insights: dd.MM. HH:mm nebo fallback "Zatím nepřihlášen".
  static String _formatLastSignIn(DateTime? dt) {
    if (dt == null) return 'admin.team_last_sign_in_never'.tr();
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}. ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Dynamicky skládá překladové klíče admin.role_* z JSON slovníku – žádný hardcode map.
  static String _roleSubtitle(List<String> roles) {
    if (roles.isEmpty) return '–';
    return roles.map((r) => 'admin.role_$r'.tr()).join(', ');
  }

  /// Text smlouvy: např. „Smlouva: 1.4.2024 - neurčito“. Prázdný když není zadáno.
  static String _contractLabel(TeamMember member) {
    final start = member.startDate;
    final end = member.endDate;
    if (start == null && end == null) return '';
    final startStr = start != null
        ? '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}'
        : '–';
    final endStr = end != null
        ? '${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}'
        : 'admin.team_contract_indefinite'.tr();
    return 'admin.team_contract_display'.tr(namedArgs: {'start': startStr, 'end': endStr});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onEdit(member),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.purple.shade100,
                  child: Text(
                    _initialsFromName(member.name),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (member.role == 'admin') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'admin.team_badge_admin'.tr(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleSubtitle(member.roles),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (member.isFromInvitation && (member.email ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _TeamDetailRow(
                          icon: Icons.email_outlined,
                          text: member.email!,
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_contractLabel(member).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _TeamDetailRow(
                            icon: Icons.work_outline,
                            text: _contractLabel(member),
                          ),
                        ),
                      _TeamDetailRow(
                        icon: Icons.access_time,
                        text: 'admin.team_workload'.tr(namedArgs: {'hours': '${member.weeklyHours}'}),
                      ),
                      // Zobrazení informace, že pracovník má nastavené zóny pro lepší plánování.
                      if (member.zonePreferences != null && member.zonePreferences!.isNotEmpty)
                        _TeamDetailRow(
                          icon: Icons.map_outlined,
                          text: 'admin.team_has_preferred_zones'.tr(),
                        ),
                      _TeamDetailRow(
                        icon: Icons.login_outlined,
                        text: _formatLastSignIn(member.lastSignInAt),
                      ),
                      const SizedBox(height: 4),
                      _MemberCardExtra(member: member),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: member.isFromInvitation
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        member.isFromInvitation
                            ? 'admin.team_status_pending'.tr()
                            : 'admin.team_status_active'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: member.isFromInvitation
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (member.isFromInvitation)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.link, color: Colors.blue.shade700),
                            tooltip: 'admin.team_invite_copy_tooltip'.tr(),
                            onPressed: () {
                              // Zvací odkaz jako záložní varianta pro sdílení mimo e-mail (WhatsApp, SMS atd.).
                              final token = member.invitationId ?? member.id;
                              final origin = Uri.base.origin;
                              final inviteUrl = '$origin/#/invite?token=$token';
                              Clipboard.setData(ClipboardData(text: inviteUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('admin.team_invite_copied_snackbar'.tr()),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                            tooltip: 'admin.team_delete'.tr(),
                            onPressed: () => onDelete(member),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                            ),
                          ),
                        ],
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.event_busy, color: Colors.purple.shade700),
                        tooltip: 'admin.absence_manage_tooltip'.tr(),
                        onPressed: () => onManageAbsence(member),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.purple.shade50,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Převod PropertyOwnerOption na TeamMember pro využití standardní mazací logiky.
TeamMember _ownerToTeamMember(PropertyOwnerOption o) {
  return TeamMember(
    id: o.profileId,
    name: o.name,
    email: o.email,
    role: 'property_owner',
    roles: const [],
    isFromInvitation: o.isPending,
    profileId: o.profileId,
  );
}

/// Zjednodušená karta majitele – ikona, jméno, e-mail. Bez pracovních úvazků a smluv.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.onDelete,
    this.onCopyLink,
  });

  final PropertyOwnerOption owner;
  final VoidCallback onDelete;
  /// Volitelné – pro čekající pozvánky umožňuje kopírovat zvací odkaz do schránky.
  final VoidCallback? onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.person_outline, color: Colors.teal.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    owner.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (owner.email != null && owner.email!.isNotEmpty)
                    Text(
                      owner.email!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (owner.isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'admin.team_status_pending'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tlačítko pro zkopírování odkazu pozvánky majitele do schránky. Používá stejnou logiku jako běžné pozvánky.
                if (onCopyLink != null)
                  IconButton(
                    icon: Icon(Icons.link, color: Colors.blue.shade700),
                    tooltip: 'admin.team_invite_copy_tooltip'.tr(),
                    onPressed: onCopyLink,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                    ),
                  ),
                // Tlačítko pro smazání majitele nebo zrušení jeho pozvánky. Využívá standardní mazací logiku obrazovky.
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  tooltip: 'admin.team_delete'.tr(),
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Řádek s ikonou a šedým textem – smlouva, úvazek, naplánované úkoly.
class _TeamDetailRow extends StatelessWidget {
  const _TeamDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Na kartě personálu: ukazatel kapacity (vytížení tento týden vs úvazek), celkový počet aktivních úkolů a plánovaná nepřítomnost.
class _MemberCardExtra extends ConsumerWidget {
  const _MemberCardExtra({required this.member});

  final TeamMember member;

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Vrací true, pokud je úkol aktivní (není hotový). Hotovo/Completed se ignorují.
  static bool _isActiveTask(TaskRow t) {
    final s = (t.status).toLowerCase();
    return !s.contains('hotovo') && s != 'completed';
  }

  /// Najde službu v katalogu odpovídající úkolu. Priorita: serviceId, fallback mapování taskType -> serviceType.
  static TenantServiceModel? _findServiceForTask(
    TaskRow t,
    List<TenantServiceModel> services,
  ) {
    if (services.isEmpty) return null;
    if (t.serviceId != null && t.serviceId!.trim().isNotEmpty) {
      final byId = services.where((s) => s.id == t.serviceId!.trim()).firstOrNull;
      if (byId != null) return byId;
    }
    final normalized = _taskTypeToServiceType(t.taskType);
    return services.where((s) => s.serviceType == normalized).firstOrNull;
  }

  /// Mapuje task_type (z tasks) na service_type (z tenant_services) pro fallback párování.
  /// Pouze kanonické hodnoty – žádné hardcodované lokalizované řetězce.
  static String _taskTypeToServiceType(String taskType) {
    final t = taskType.trim().toLowerCase();
    if (t == 'cleaning') return 'cleaning';
    if (t.startsWith('transfer')) return 'transfer';
    if (t == 'check_in' || t == 'check_out') return 'extra';
    if (t == 'issue' || t == 'material' || t == 'maintenance') return 'maintenance';
    return 'extra';
  }

  /// Placeholder pro loading/error – stejný layout jako data stav, dvě prázdné tyče.
  static Widget _buildCapacityPlaceholder(BuildContext context, int weeklyHours) {
    final maxHours = weeklyHours > 0 ? weeklyHours.toDouble() : 1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWorkloadIndicator(
            context,
            title: 'admin.team_capacity_this_week'.tr(),
            tasks: 0,
            hours: 0,
            maxHours: maxHours,
          ),
          const SizedBox(height: 12),
          _buildWorkloadIndicator(
            context,
            title: 'admin.team_capacity_next_week'.tr(),
            tasks: 0,
            hours: 0,
            maxHours: maxHours,
          ),
          const SizedBox(height: 4),
          Text(
            'admin.team_total_active_future'.tr(namedArgs: {'count': '0'}),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Spočítá aktivní úkoly přiřazené členovi. Vrací celkem, tento týden, příští týden.
  /// Filtrování podle ISO týdne (pondělí–neděle, weekday 1 = pondělí).
  /// Čas se počítá z Katalogu služeb agentury (tenant_services) – bez hardcodovaných hodnot.
  static ({
    int total,
    int thisWeek,
    int thisWeekMinutes,
    int nextWeek,
    int nextWeekMinutes,
  }) _computeCapacity(
    List<TaskRow> tasks,
    String memberId,
    DateTime now,
    List<ApartmentRow> apartments,
    List<TenantServiceModel> services,
  ) {
    if (memberId.isEmpty) {
      return (total: 0, thisWeek: 0, thisWeekMinutes: 0, nextWeek: 0, nextWeekMinutes: 0);
    }
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    /// Příští týden: pondělí až neděle následujícího týdne.
    /// nextMonday = první den kalendářního týdne po aktuálním (toto pondělí + 7 dní).
    /// nextSunday = neděle příštího týdne (nextMonday + 6 dní).
    final nextMonday = monday.add(const Duration(days: 7));
    final nextSunday = nextMonday.add(const Duration(days: 6));

    int total = 0;
    int thisWeek = 0;
    int thisWeekMinutes = 0;
    int nextWeek = 0;
    int nextWeekMinutes = 0;

    int _minutesForTask(TaskRow t) {
      // Priorita 1: Odhad na úkolu – TaskRow zatím nemá pole estimateMinutes. Po přidání: if (t.estimateMinutes != null && t.estimateMinutes! > 0) return t.estimateMinutes!;

      final service = _findServiceForTask(t, services);
      if (service == null) return 0;

      // Priorita 2: Úklid (serviceType z katalogu, ne textové hledání) = standardCleaningDuration bytu + duration_minutes služby.
      if (service.serviceType == 'cleaning') {
        final apt = apartments.where((a) => a.id == t.apartmentId).firstOrNull;
        final baseCleaning = apt?.standardCleaningDuration ?? 0;
        final serviceDuration = service.durationMinutes ?? 0;
        return baseCleaning + serviceDuration;
      }

      // Priorita 3: Ostatní typy – časová náročnost přímo ze služby.
      final duration = service.durationMinutes ?? 0;
      return duration > 0 ? duration : 0;
    }

    for (final t in tasks) {
      if (t.assignedTo != memberId) continue;
      if (!_isActiveTask(t)) continue;
      total++;
      final dueDay = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      final minutes = _minutesForTask(t);
      if (!dueDay.isBefore(monday) && !dueDay.isAfter(sunday)) {
        thisWeek++;
        thisWeekMinutes += minutes;
      } else if (!dueDay.isBefore(nextMonday) && !dueDay.isAfter(nextSunday)) {
        nextWeek++;
        nextWeekMinutes += minutes;
      }
    }
    return (
      total: total,
      thisWeek: thisWeek,
      thisWeekMinutes: thisWeekMinutes,
      nextWeek: nextWeek,
      nextWeekMinutes: nextWeekMinutes,
    );
  }

  /// Jedna položka ukazatele vytížení – titulek, počet úkolů/hodin a progress bar.
  /// Barvy: zelená < 70 %, oranžová < 90 %, červená ≥ 90 %.
  static Widget _buildWorkloadIndicator(
    BuildContext context, {
    required String title,
    required int tasks,
    required double hours,
    required double maxHours,
  }) {
    final ratio = (maxHours > 0) ? (hours / maxHours).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '$tasks ${'admin.team_tasks_label'.tr()} (~${hours.toStringAsFixed(1)}h / ${maxHours.toInt()}h)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth * ratio;
                return Stack(
                  children: [
                    if (w > 0)
                      Container(
                        width: w,
                        decoration: BoxDecoration(
                          color: ratio < 0.7
                              ? Colors.green.shade400
                              : ratio < 0.9
                                  ? Colors.orange.shade400
                                  : Colors.red.shade500,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(adminTasksProvider);
    final absencesAsync = ref.watch(staffAbsencesProvider);
    final apartments = ref.watch(apartmentsProvider).valueOrNull ?? [];
    final services = ref.watch(tenantServicesProvider).valueOrNull ?? [];

    return tasksAsync.when(
      data: (tasks) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final memberId = member.profileId ?? member.id;
        final capacity = _computeCapacity(tasks, memberId, now, apartments, services);
        final totalActiveTasks = capacity.total;
        final thisWeekPlannedHours = capacity.thisWeekMinutes / 60.0;
        final nextWeekPlannedHours = capacity.nextWeekMinutes / 60.0;
        final maxHours = member.weeklyHours.toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dvojice ukazatelů kapacity – tento týden a příští týden.
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWorkloadIndicator(
                    context,
                    title: 'admin.team_capacity_this_week'.tr(),
                    tasks: capacity.thisWeek,
                    hours: thisWeekPlannedHours,
                    maxHours: maxHours > 0 ? maxHours : 1.0,
                  ),
                  const SizedBox(height: 12),
                  _buildWorkloadIndicator(
                    context,
                    title: 'admin.team_capacity_next_week'.tr(),
                    tasks: capacity.nextWeek,
                    hours: nextWeekPlannedHours,
                    maxHours: maxHours > 0 ? maxHours : 1.0,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin.team_total_active_future'.tr(namedArgs: {'count': totalActiveTasks.toString()}),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            absencesAsync.when(
              data: (absences) {
                final planned = absences
                    .where((a) =>
                        a.belongsTo(member) &&
                        a.endDate != null &&
                        !a.endDate!.isBefore(today))
                    .toList();
                if (planned.isEmpty) return const SizedBox.shrink();
                final absenceText = planned
                    .map((a) =>
                        'admin.team_planned_absence'.tr(
                          namedArgs: {
                            'start': _formatDate(a.startDate ?? today),
                            'end': _formatDate(a.endDate ?? today),
                          },
                        ))
                    .join(', ');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          absenceText,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        );
      },
      loading: () => _buildCapacityPlaceholder(context, member.weeklyHours),
      error: (_, _) => _buildCapacityPlaceholder(context, member.weeklyHours),
    );
  }
}

/// Dialog správy nepřítomností daného člena – seznam záznamů a formulář pro přidání.
class _AbsenceDialog extends ConsumerStatefulWidget {
  const _AbsenceDialog({
    required this.ref,
    required this.member,
    required this.onSaved,
  });

  final WidgetRef ref;
  final TeamMember member;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AbsenceDialog> createState() => _AbsenceDialogState();
}

class _AbsenceDialogState extends ConsumerState<_AbsenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Future<void> _pickFromDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _fromDate = d);
  }

  Future<void> _pickToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _toDate = d);
  }

  Future<void> _saveAbsence() async {
    if (_fromDate == null || _toDate == null) return;
    if (_toDate!.isBefore(_fromDate!)) return;
    if (_isSaving) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null) return;
    // Aktivní člen = profile_id, člen z pozvánky = invitation_id (pro plánování kapacit).
    final isInvitation = widget.member.isFromInvitation;
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'start_date': _fromDate!.toIso8601String(),
      'end_date': _toDate!.toIso8601String(),
      'reason': _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
    };
    if (isInvitation) {
      payload['invitation_id'] = widget.member.invitationId ?? widget.member.id;
      payload['profile_id'] = null;
    } else {
      payload['profile_id'] = widget.member.profileId;
      payload['invitation_id'] = null;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('staff_absences').insert(payload);
      if (!mounted) return;
      ref.invalidate(staffAbsencesProvider);
      final memberId = widget.member.profileId ?? widget.member.id;
      await _unassignTasksForMember(ref, memberId, fromDate: _fromDate, toDate: _toDate);
      if (!mounted) return;
      widget.onSaved();
      _reasonController.clear();
      setState(() {
        _fromDate = null;
        _toDate = null;
        _isSaving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
    final absencesAsync = ref.watch(staffAbsencesProvider);
    return AlertDialog(
      title: Text('admin.absence_title'.tr()),
      content: SizedBox(
        width: 400,
        child: absencesAsync.when(
          data: (all) {
            final list = all.where((a) => a.belongsTo(widget.member)).toList();
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.member.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'admin.absence_empty_list'.tr(),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ...list.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a.startDate != null ? _formatDate(a.startDate!) : '–'} – ${a.endDate != null ? _formatDate(a.endDate!) : '–'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (a.reason != null && a.reason!.isNotEmpty)
                                  Text(
                                    a.reason!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'admin.absence_add'.tr(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickFromDate,
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _fromDate == null
                                      ? 'admin.absence_from'.tr()
                                      : _formatDate(_fromDate!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickToDate,
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _toDate == null
                                      ? 'admin.absence_to'.tr()
                                      : _formatDate(_toDate!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.notes_outlined),
                            labelText: 'admin.absence_reason_hint'.tr(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text('common.error'.tr()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  await _saveAbsence();
                },
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Dialog pro přidání nového člena.
class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog({required this.onAdded});

  final VoidCallback onAdded;

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weeklyHoursController = TextEditingController(text: '40');

  /// Systémový přístup (sloupec role): admin = manažer, worker = pouze mobil, property_owner = majitel.
  String _systemRole = 'worker';
  /// Pracovní pozice (sloupec roles): pouze cleaner, driver, maintenance, checkin_agent.
  final Set<String> _selectedRoles = {};
  /// Vybrané apartmány pro majitele – při role=property_owner.
  final Set<String> _selectedApartmentIds = {};
  /// Mapa zone_id -> priorita (1 = nejraději, 2 = dojedu). Při výběru "-" se klíč odstraňuje.
  final Map<String, int> _selectedZonePreferences = {};
  bool _isSaving = false;
  DateTime? _startDate;
  DateTime? _endDate;
  final ScrollController _tab1ScrollController = ScrollController();
  final ScrollController _tab2ScrollController = ScrollController();

  @override
  void dispose() {
    _tab1ScrollController.dispose();
    _tab2ScrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  int _parseWeeklyHours() {
    final s = _weeklyHoursController.text.trim();
    if (s.isEmpty) return 40;
    return int.tryParse(s) ?? 40;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_systemRole != 'property_owner' && _selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.team_validation_roles_required'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    if (_systemRole == 'property_owner' && _selectedApartmentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.team_validation_apartments_owner'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    if (_isSaving) return;

    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final weeklyHours = _parseWeeklyHours();

    try {
      final email = _emailController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final jobRolesList = _systemRole == 'property_owner' ? <String>[] : _selectedRoles.toList();
      var displayName = '$firstName $lastName'.trim();
      if (displayName.isEmpty) displayName = email;

      // role = systémový přístup (admin/worker/property_owner), roles = pracovní pozice (u majitele prázdné).
      final profilePayload = <String, dynamic>{
        'tenant_id': tenantId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName.isEmpty ? 'admin.team_last_name_awaiting'.tr() : lastName,
        'name': displayName,
        'status': 'pending',
        'role': _systemRole,
        'roles': jobRolesList,
        'weekly_hours': _systemRole == 'property_owner' ? 0 : weeklyHours,
      };
      if (_systemRole != 'property_owner') {
        if (_startDate != null) profilePayload['start_date'] = _startDate!.toIso8601String();
        if (_endDate != null) profilePayload['end_date'] = _endDate!.toIso8601String();
        if (_selectedZonePreferences.isNotEmpty) {
          profilePayload['zone_preferences'] = _selectedZonePreferences;
        }
      }
      final profileRes = await SupabaseService.client
          .from('profiles')
          .insert(profilePayload)
          .select('id')
          .single();
      final profileId = (profileRes as Map)['id']?.toString();
      if (profileId == null || profileId.isEmpty) {
        throw PostgrestException(message: 'Profil nebyl vytvořen', code: '500', details: 'internal');
      }

      // Poté vytvoř pozvánku (pro registrační flow – email matching).
      final invPayload = <String, dynamic>{
        'tenant_id': tenantId,
        'profile_id': profileId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': _systemRole,
        'roles': jobRolesList,
        'weekly_hours': _systemRole == 'property_owner' ? 0 : weeklyHours,
      };
      if (_systemRole != 'property_owner') {
        if (_startDate != null) invPayload['start_date'] = _startDate!.toIso8601String();
        if (_endDate != null) invPayload['end_date'] = _endDate!.toIso8601String();
      }
      await SupabaseService.client.from('invitations').insert(invPayload);

      // Pro majitele: přiřadit vybrané apartmány do apartment_owners.
      if (_systemRole == 'property_owner' && _selectedApartmentIds.isNotEmpty) {
        for (final aptId in _selectedApartmentIds) {
          await ApartmentOwnersRepository.addOwner(
            apartmentId: aptId,
            ownerId: profileId,
            tenantId: tenantId,
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.team_invite_sent'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA UKLÁDÁNÍ (Tým): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.team_invite_error'.tr(namedArgs: {'error': e.message})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA UKLÁDÁNÍ (Tým): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleRole(String key) {
    setState(() {
      if (_selectedRoles.contains(key)) {
        _selectedRoles.remove(key);
      } else {
        _selectedRoles.add(key);
      }
    });
  }

  /// Obsah záložky 1 – Základní informace: Jméno, Příjmení, E-mail, Úvazek, Data, Role.
  Widget _buildTab1BasicInfo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  labelText: 'admin.team_field_first_name'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                ),
                validator: (v) =>
                    (v == null || v.toString().trim().isEmpty)
                        ? 'admin.team_validation_first_name'.tr()
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  labelText: 'admin.team_field_last_name'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                ),
                validator: (v) =>
                    (v == null || v.toString().trim().isEmpty)
                        ? 'admin.team_validation_last_name'.tr()
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined),
                  labelText: 'admin.team_field_email'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                ),
                validator: (v) =>
                    (v == null || v.toString().trim().isEmpty)
                        ? 'admin.team_validation_email'.tr()
                        : null,
              ),
              if (_systemRole != 'property_owner') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weeklyHoursController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers_outlined),
                    labelText: 'admin.team_field_weekly_hours'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
              ],
              if (_systemRole != 'property_owner') ...[
                const SizedBox(height: 12),
                InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) setState(() => _startDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    labelText: 'admin.team_contract_start_date'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                  child: Text(
                    _startDate != null
                        ? '${_startDate!.day.toString().padLeft(2, '0')}.${_startDate!.month.toString().padLeft(2, '0')}.${_startDate!.year}'
                        : '',
                    style: TextStyle(
                      color: _startDate != null ? null : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && mounted) setState(() => _endDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          labelText: 'admin.team_contract_end_date'.tr(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                        ),
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.day.toString().padLeft(2, '0')}.${_endDate!.month.toString().padLeft(2, '0')}.${_endDate!.year}'
                              : 'admin.team_contract_indefinite'.tr(),
                          style: TextStyle(
                            color: _endDate != null ? null : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'admin.team_contract_indefinite'.tr(),
                      onPressed: () => setState(() => _endDate = null),
                    ),
                ],
              ),
              ],
              const SizedBox(height: 20),
              Text(
                'admin.team_system_role_label'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'admin',
                      groupValue: _systemRole,
                      onChanged: (v) => setState(() {
                        _systemRole = v ?? 'worker';
                        if (_systemRole == 'admin' || _systemRole == 'worker') {
                          _selectedApartmentIds.clear();
                        }
                      }),
                      title: Text('admin.system_role_admin'.tr()),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'worker',
                      groupValue: _systemRole,
                      onChanged: (v) => setState(() {
                        _systemRole = v ?? 'worker';
                        if (_systemRole == 'admin' || _systemRole == 'worker') {
                          _selectedApartmentIds.clear();
                        }
                      }),
                      title: Text('admin.system_role_worker'.tr()),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      value: 'property_owner',
                      groupValue: _systemRole,
                      onChanged: (v) => setState(() {
                        _systemRole = v ?? 'worker';
                        if (_systemRole == 'property_owner') {
                          _selectedRoles.clear();
                        }
                      }),
                      title: Text('admin.team_role_owner'.tr()),
                    ),
                  ),
                ],
              ),
              if (_systemRole != 'property_owner') ...[
                const SizedBox(height: 16),
                Text(
                  'admin.team_job_roles_label'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: teamJobRoleKeys.map((key) {
                    final selected = _selectedRoles.contains(key);
                    return FilterChip(
                      label: Text(_jobRoleLabel(key)),
                      selected: selected,
                      onSelected: (_) => _toggleRole(key),
                    );
                  }).toList(),
                ),
              ],
              // Pokud je vybrána role majitele, skrýváme pracovněprávní pole a zobrazujeme výběr apartmánů pro hromadné přiřazení.
              if (_systemRole == 'property_owner') ...[
                const SizedBox(height: 16),
                Text(
                  'admin.select_apartments_for_owner'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _ApartmentChecklistSection(
                  selectedIds: _selectedApartmentIds,
                  onToggle: (apartmentId, selected) {
                    setState(() {
                      if (selected) {
                        _selectedApartmentIds.add(apartmentId);
                      } else {
                        _selectedApartmentIds.remove(apartmentId);
                      }
                    });
                  },
                ),
              ],
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernAdminPanel(
      title: 'admin.team_add_member'.tr(),
      maxWidth: 800,
      content: Form(
        key: _formKey,
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.info_outline), text: 'admin.tab_basic_info'.tr()),
                  Tab(icon: const Icon(Icons.map), text: 'admin.preferred_zones'.tr()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(child: _buildTab1BasicInfo(context)),
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ZonePreferencesSection(
                          selectedPreferences: _selectedZonePreferences,
                          onPreferenceChanged: (zoneId, priority) {
                            setState(() {
                              if (priority == null) {
                                _selectedZonePreferences.remove(zoneId);
                              } else {
                                _selectedZonePreferences[zoneId] = priority;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }

  String _jobRoleLabel(String key) {
    switch (key) {
      case 'cleaner':
        return 'admin.role_cleaner'.tr();
      case 'driver':
        return 'admin.role_driver'.tr();
      case 'maintenance':
        return 'admin.role_maintenance'.tr();
      case 'checkin_agent':
        return 'admin.role_checkin_agent'.tr();
      default:
        return key;
    }
  }
}

/// Checklist apartmánů pro majitele – zobrazuje se při výběru role property_owner.
/// Načítá byty z apartmentsProvider (multi-tenant) a umožňuje hromadné zaškrtávání.
class _ApartmentChecklistSection extends ConsumerWidget {
  const _ApartmentChecklistSection({
    required this.selectedIds,
    required this.onToggle,
  });

  final Set<String> selectedIds;
  final void Function(String apartmentId, bool selected) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartmentsAsync = ref.watch(apartmentsProvider);
    return apartmentsAsync.when(
      data: (apartments) {
        if (apartments.isEmpty) {
          return Text(
            'admin.apartments_empty'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: apartments.map((a) {
            final selected = selectedIds.contains(a.id);
            return FilterChip(
              label: Text(a.name),
              selected: selected,
              onSelected: (sel) => onToggle(a.id, sel == true),
            );
          }).toList(),
        );
      },
      loading: () =>
          const Center(child: SizedBox(height: 40, width: 40, child: CircularProgressIndicator())),
      error: (e, _) =>
          Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
    );
  }
}

/// Sekce preferencí oblastí – seznam zón s dropdownem priority.
/// Bez ListView/Expanded/Flexible – jednoduchý Column kvůli prevenci layout exception.
/// null = "–" (odstraní klíč), -1 = Hard Blacklist (Nikdy), 1–5 = priorita.
class _ZonePreferencesSection extends ConsumerWidget {
  const _ZonePreferencesSection({
    required this.selectedPreferences,
    required this.onPreferenceChanged,
  });

  final Map<String, int> selectedPreferences;
  final void Function(String zoneId, int? priority) onPreferenceChanged;

  /// null = bez preference, -1 = Hard Blacklist (Nikdy), 1–5 = priorita.
  static const List<int?> _priorityOptions = [null, 1, 2, 3, 4, 5, -1];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(zonesProvider);
    return zonesAsync.when(
      data: (zones) {
        if (zones.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              'admin.preferred_zones'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            ...zones.map((zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          zone.name,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<int?>(
                          initialValue: selectedPreferences[zone.id],
                          isDense: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          items: _priorityOptions.map((p) {
                            return DropdownMenuItem<int?>(
                              value: p,
                              child: Text(
                                p == null
                                    ? 'common.none'.tr()
                                    : p == -1
                                        ? 'common.never'.tr()
                                        : '$p',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => onPreferenceChanged(zone.id, v),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Dialog pro úpravu člena – profiles (UPDATE) nebo invitations (UPDATE).
class _EditMemberDialog extends ConsumerStatefulWidget {
  const _EditMemberDialog({
    required this.member,
    required this.onSaved,
  });

  final TeamMember member;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<_EditMemberDialog> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _weeklyHoursController;
  late String _systemRole;
  final Set<String> _selectedRoles = {};
  /// Mapa zone_id -> priorita. Při otevření se naplní z member.zonePreferences.
  late Map<String, int> _selectedZonePreferences;
  bool _isSaving = false;
  bool _emailEnabled = true;
  DateTime? _startDate;
  DateTime? _endDate;
  final ScrollController _tab1ScrollController = ScrollController();
  final ScrollController _tab2ScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final parts = widget.member.name.split(' ');
    _firstNameController = TextEditingController(
      text: parts.isNotEmpty ? parts.first : widget.member.name,
    );
    _lastNameController = TextEditingController(
      text: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
    _emailController = TextEditingController(
      text: widget.member.email ?? '',
    );
    _weeklyHoursController = TextEditingController(
      text: widget.member.weeklyHours.toString(),
    );
    _systemRole = systemRoleValues.contains(widget.member.role) ? widget.member.role : 'worker';
    _selectedRoles.addAll(widget.member.roles);
    _selectedZonePreferences = Map.from(widget.member.zonePreferences ?? {});
    _emailEnabled = widget.member.isFromInvitation;
    _startDate = widget.member.startDate;
    _endDate = widget.member.endDate;
  }

  @override
  void dispose() {
    _tab1ScrollController.dispose();
    _tab2ScrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  int _parseWeeklyHours() {
    final s = _weeklyHoursController.text.trim();
    if (s.isEmpty) return 40;
    return int.tryParse(s) ?? 40;
  }

  Future<void> _onSave() async {
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.team_validation_roles_required'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final jobRolesList = _selectedRoles.toList();
    final name = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
    final weeklyHours = _parseWeeklyHours();

    try {
      final startIso = _startDate?.toIso8601String();
      final endIso = _endDate?.toIso8601String();
      final profileUpdate = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'name': name.isNotEmpty ? name : _emailController.text.trim(),
        'role': _systemRole,
        'roles': jobRolesList,
        'weekly_hours': weeklyHours,
        'start_date': startIso,
        'end_date': endIso,
      };
      if (widget.member.isFromInvitation) {
        profileUpdate['email'] = _emailController.text.trim();
      }
      // Preferované oblasti – JSONB zone_preferences. Prázdná mapa = {} (odstranění preferencí).
      profileUpdate['zone_preferences'] =
          _selectedZonePreferences.isEmpty ? {} : _selectedZonePreferences;
      await SupabaseService.client
          .from('profiles')
          .update(profileUpdate)
          .eq('id', widget.member.id);

      if (_endDate != null) {
        await _unassignTasksForMember(
          ref,
          widget.member.id,
          fromDate: _endDate!.add(const Duration(days: 1)),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('--- CHYBA ÚPRAVY ČLENA TÝMU: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_with_message'.tr(namedArgs: {'message': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleRole(String key) {
    setState(() {
      if (_selectedRoles.contains(key)) {
        _selectedRoles.remove(key);
      } else {
        _selectedRoles.add(key);
      }
    });
  }

  /// Obsah záložky 1 – Základní informace: Jméno, Příjmení, E-mail, Úvazek, Data, Role.
  Widget _buildTab1BasicInfo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline),
                labelText: 'admin.team_field_first_name'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline),
                    labelText: 'admin.team_field_last_name'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  enabled: _emailEnabled,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined),
                    labelText: 'admin.team_field_email'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weeklyHoursController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers_outlined),
                    labelText: 'admin.team_field_weekly_hours'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) setState(() => _startDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      labelText: 'admin.team_contract_start_date'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                    ),
                    child: Text(
                      _startDate != null
                          ? '${_startDate!.day.toString().padLeft(2, '0')}.${_startDate!.month.toString().padLeft(2, '0')}.${_startDate!.year}'
                          : '',
                      style: TextStyle(
                        color: _startDate != null ? null : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? _startDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null && mounted) setState(() => _endDate = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            labelText: 'admin.team_contract_end_date'.tr(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                          ),
                          child: Text(
                            _endDate != null
                                ? '${_endDate!.day.toString().padLeft(2, '0')}.${_endDate!.month.toString().padLeft(2, '0')}.${_endDate!.year}'
                                : 'admin.team_contract_indefinite'.tr(),
                            style: TextStyle(
                              color: _endDate != null ? null : Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'admin.team_contract_indefinite'.tr(),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'admin.team_system_role_label'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'admin',
                        groupValue: _systemRole,
                        onChanged: (v) => setState(() => _systemRole = v ?? 'worker'),
                        title: Text('admin.system_role_admin'.tr()),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'worker',
                        groupValue: _systemRole,
                        onChanged: (v) => setState(() => _systemRole = v ?? 'worker'),
                        title: Text('admin.system_role_worker'.tr()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'admin.team_job_roles_label'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: teamJobRoleKeys.map((key) {
                    final selected = _selectedRoles.contains(key);
                    return FilterChip(
                      label: Text(_jobRoleLabel(key)),
                      selected: selected,
                      onSelected: (_) => _toggleRole(key),
                    );
                  }).toList(),
                ),
              ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernAdminPanel(
      title: 'admin.team_edit_title'.tr(),
      maxWidth: 800,
      content: Form(
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.info_outline), text: 'admin.tab_basic_info'.tr()),
                  Tab(icon: const Icon(Icons.map), text: 'admin.preferred_zones'.tr()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    Scrollbar(
                      controller: _tab1ScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tab1ScrollController,
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: _buildTab1BasicInfo(context),
                      ),
                    ),
                    Scrollbar(
                      controller: _tab2ScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tab2ScrollController,
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: _ZonePreferencesSection(
                          selectedPreferences: _selectedZonePreferences,
                          onPreferenceChanged: (zoneId, priority) {
                            setState(() {
                              if (priority == null) {
                                _selectedZonePreferences.remove(zoneId);
                              } else {
                                _selectedZonePreferences[zoneId] = priority;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isSaving ? null : _onSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }

  String _jobRoleLabel(String key) {
    switch (key) {
      case 'cleaner':
        return 'admin.role_cleaner'.tr();
      case 'driver':
        return 'admin.role_driver'.tr();
      case 'maintenance':
        return 'admin.role_maintenance'.tr();
      case 'checkin_agent':
        return 'admin.role_checkin_agent'.tr();
      default:
        return key;
    }
  }
}
