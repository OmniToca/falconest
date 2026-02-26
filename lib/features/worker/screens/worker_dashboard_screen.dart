import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/providers/connectivity_provider.dart';
import 'package:falconest/core/widgets/sync_status_icon.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/features/worker/providers/weekly_stats_provider.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';
import 'package:falconest/features/worker/providers/worker_sync_state_provider.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Hlavní obrazovka Worker App – "Moje Práce".
///
/// Zobrazuje seznam úkolů přiřazených aktuálnímu uživateli, seskupených podle
/// data (Dnes, Zítra, Později). Pull-to-Refresh, velké karty vhodné pro mobil.
class WorkerDashboardScreen extends ConsumerStatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  ConsumerState<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends ConsumerState<WorkerDashboardScreen> {
  bool? _hasPin;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      PinStorage.hasPin().then((v) {
        if (mounted) setState(() => _hasPin = v);
      });
      // Jednorázový sync při otevření obrazovky – čtecí provider žádný sync nespouští.
      Future.microtask(() async {
        await ref.read(workerSyncStateProvider.notifier).runSync();
        if (mounted) ref.invalidate(workerTasksProvider);
      });
    }
  }

  /// Pull-to-refresh: stáhne čerstvá data ze Supabase a aktualizuje provider.
  Future<void> _refresh() async {
    await ref.read(workerSyncStateProvider.notifier).runSync();
    ref.invalidate(workerTasksProvider);
    await ref.read(workerTasksProvider.future);
    if (mounted && ref.read(workerSyncStateProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('worker.sync_success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(workerTasksProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final syncError = ref.watch(workerSyncStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('worker.my_work'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const SyncStatusIcon(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(),
          ),
        ],
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: _WorkerDrawer(hasPin: _hasPin ?? false),
      body: Column(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade700,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'worker.offline_mode_banner'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
          // Vizuální upozornění pro pracovníka, že synchronizace na pozadí selhala.
          // Práce je v bezpečí v lokální DB, ale backend o ní zatím neví.
          if (syncError != null && syncError.isNotEmpty)
            Material(
              color: Colors.red.shade700,
              child: InkWell(
                onTap: () => ref.read(workerSyncStateProvider.notifier).clearSyncError(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'worker.sync_error_banner'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.close, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: _EmptyState(),
                      ),
                    );
                  }
                  return _TaskList(tasks: tasks);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'common.error_with_message'.tr(namedArgs: {'message': '$e'}),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () {
                                ref.invalidate(workerTasksProvider);
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text('common.retry'.tr()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Neklikatelná karta přehledu týdne – X úkolů • Y h.
class _WeeklySummaryTile extends ConsumerWidget {
  const _WeeklySummaryTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(weeklyStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final tasksText = 'worker.weekly_tasks_count'.tr(namedArgs: {'count': '${stats.totalTasks}'});
        final hoursText = 'worker.weekly_hours_format'.tr(namedArgs: {'hours': _formatHours(stats.totalHours)});
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_chart_outlined, color: _primaryBlue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'worker.weekly_this_week'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tasksText • $hoursText',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.insert_chart_outlined, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(child: LinearProgressIndicator()),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Formátování hodin – 18.5 nebo 18 podle des. míst.
  static String _formatHours(double h) {
    if (h == h.truncateToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1);
  }
}

/// Dialog pro výběr jazyka přes easy_localization – cs, en, es.
/// Uloží výběr do profiles přes AuthNotifier a přepne locale; easy_localization překreslí UI.
void _showLanguageDialog(BuildContext context, WidgetRef ref) {
  Future<void> selectAndClose(String code) async {
    await ref.read(authNotifierProvider.notifier).updateLanguageCode(code);
    if (context.mounted) {
      context.setLocale(Locale(code));
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('worker.drawer_language_select'.tr()),
      children: [
        SimpleDialogOption(
          onPressed: () => selectAndClose('cs'),
          child: const Text('Čeština'),
        ),
        SimpleDialogOption(
          onPressed: () => selectAndClose('en'),
          child: const Text('English'),
        ),
        SimpleDialogOption(
          onPressed: () => selectAndClose('es'),
          child: const Text('Español'),
        ),
      ],
    ),
  );
}

/// Drawer v Worker flow – vizitka uživatele, přehled týdne, Moje nepřítomnost, PIN, odhlášení.
class _WorkerDrawer extends ConsumerWidget {
  const _WorkerDrawer({required this.hasPin});

  final bool hasPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final auth = ref.watch(authNotifierProvider);
    final roleLabel = (auth.role == 'admin' || auth.role == 'manager')
        ? 'worker.drawer_role_admin'.tr()
        : 'worker.drawer_role_worker'.tr();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Sjednocená hlavička – vizitka uživatele + přepínač jazyka v pravém horním rohu.
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundColor: _primaryBlue.withValues(alpha: 0.2),
                child: Icon(Icons.person, color: _primaryBlue),
              ),
              accountName: profileAsync.when(
                data: (p) => Text(
                  p.name.isNotEmpty ? p.name : 'worker.drawer_my_profile'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                loading: () => Text('worker.drawer_my_profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                error: (_, __) => Text('worker.drawer_my_profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              accountEmail: profileAsync.when(
                data: (p) => Text(
                  p.email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              decoration: BoxDecoration(color: _primaryBlue.withValues(alpha: 0.08)),
                ),
                // Přepínač jazyka – dialog pro výběr cs/en/es přes easy_localization.
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.language, color: _primaryBlue, size: 24),
                    tooltip: 'worker.drawer_language_select'.tr(),
                    onPressed: () => _showLanguageDialog(context, ref),
                  ),
                ),
              ],
            ),
            // Role – zobrazení primární role (admin/worker).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(roleLabel, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ],
              ),
            ),
            // Přehled týdne – neklikatelná informační karta (úkoly + odhadované hodiny).
            _WeeklySummaryTile(),
            const Divider(),
            // Peněženka – firemní výdaje, evidence hotovosti.
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('worker.menu_wallet'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/worker/wallet');
              },
            ),
            // Moje nepřítomnost – přehled a žádosti o dovolenou/nemoc.
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: Text('worker.drawer_my_absences'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/worker/absences');
              },
            ),
            if (hasPin && !kIsWeb)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text('pin.change_title'.tr()),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/pin-change');
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text('waiting_room.btn_logout'.tr()),
              onTap: () async {
                Navigator.of(context).pop();
                await SupabaseService.client.auth.signOut();
                if (context.mounted) context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _DateGroup { today, tomorrow, later }

String _dateGroupLabel(_DateGroup g) {
  switch (g) {
    case _DateGroup.today:
      return 'worker.today'.tr();
    case _DateGroup.tomorrow:
      return 'worker.tomorrow'.tr();
    case _DateGroup.later:
      return 'worker.later'.tr();
  }
}

_DateGroup _getDateGroup(DateTime taskDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
  final diff = taskDay.difference(today).inDays;
  if (diff == 0) return _DateGroup.today;
  if (diff == 1) return _DateGroup.tomorrow;
  return _DateGroup.later;
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<WorkerTask> tasks;

  @override
  Widget build(BuildContext context) {
    final grouped = <_DateGroup, List<WorkerTask>>{
      _DateGroup.today: [],
      _DateGroup.tomorrow: [],
      _DateGroup.later: [],
    };
    for (final t in tasks) {
      final g = _getDateGroup(t.scheduledStart);
      grouped[g]!.add(t);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final g in [_DateGroup.today, _DateGroup.tomorrow, _DateGroup.later])
          if (grouped[g]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                _dateGroupLabel(g),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
              ),
            ),
            ...grouped[g]!.map((t) => _TaskCard(task: t)),
          ],
      ],
    );
  }
}

IconData _iconForTaskType(String type) {
  final t = type.toLowerCase();
  if (t.contains('cleaning') || t.contains('úklid')) return Icons.cleaning_services_rounded;
  if (t.contains('transfer')) return Icons.directions_car_rounded;
  if (t.contains('check_in') || t.contains('check_out')) return Icons.key_rounded;
  return Icons.task_alt_rounded;
}

Color _iconColorForTaskType(String type) {
  final t = type.toLowerCase();
  if (t.contains('cleaning') || t.contains('úklid')) return Colors.blue.shade600;
  if (t.contains('transfer')) return Colors.green.shade600;
  if (t.contains('check_in') || t.contains('check_out')) return Colors.orange.shade600;
  return Colors.grey.shade600;
}

/// Vrací lokalizovaný název typu úkolu (admin.task_type_*) pro zobrazení na kartě.
String _taskTypeLabel(String taskType) {
  final t = taskType.toLowerCase();
  if (t.contains('transfer_in')) return 'admin.task_type_transfer_in'.tr();
  if (t.contains('transfer_out')) return 'admin.task_type_transfer_out'.tr();
  if (t.contains('cleaning') || t.contains('úklid')) return 'admin.task_type_cleaning'.tr();
  if (t.contains('check_in')) return 'admin.task_type_check_in'.tr();
  if (t.contains('check_out')) return 'admin.task_type_check_out'.tr();
  if (t.contains('issue') || t.contains('závada')) return 'admin.task_type_issue'.tr();
  if (t.contains('material')) return 'admin.task_type_material'.tr();
  return 'admin.task_type_other'.tr();
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final WorkerTask task;

  Future<void> _openMaps(BuildContext context, String? address) async {
    final query = (address ?? '').trim();
    if (query.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(task.scheduledStart);
    final iconColor = _iconColorForTaskType(task.taskType);
    final statusColor = task.status == 'in_progress' ? _primaryBlue : Colors.amber.shade700;
    final hasInstructions = (task.description.trim()).isNotEmpty;
    final address = task.apartmentAddress ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/worker/task/${task.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForTaskType(task.taskType), size: 32, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.apartmentName ?? '—',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    // Zobrazení přesného typu úkolu pro lepší orientaci v terénu
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _taskTypeLabel(task.taskType),
                        style: TextStyle(
                          fontSize: 12,
                          color: _primaryBlue.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (hasInstructions) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.description.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (address.isNotEmpty)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openMaps(context, address),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _primaryBlue.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions, color: _primaryBlue, size: 26),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'worker.empty'.tr(),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'worker.empty_hint'.tr(),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
