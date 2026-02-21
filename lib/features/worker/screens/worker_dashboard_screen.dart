import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/worker/providers/worker_dashboard_provider.dart';

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
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(workerTasksProvider);
    await ref.read(workerTasksProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(workerTasksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('worker.my_work'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
      body: RefreshIndicator(
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
    );
  }
}

class _WorkerDrawer extends StatelessWidget {
  const _WorkerDrawer({required this.hasPin});

  final bool hasPin;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.person, color: _primaryBlue),
                  const SizedBox(width: 12),
                  Text(
                    'worker.my_work'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(),
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
