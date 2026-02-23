// DEPRECATED: Tento soubor je zastaralý a bude smazán. Aktivní UI je v lib/features/worker/.
// Nepoužívat pro nový vývoj – připravujeme přepojení WorkerDashboardScreen na Isar.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/dashboard/providers/connectivity_provider.dart';
import 'package:falconest/features/dashboard/providers/todays_tasks_provider.dart';

/// Firemní barvy – konzistentní s login obrazovkou.
const _primaryBlue = Color(0xFF1565C0);
const _accentOrange = Color(0xFFE65100);

/// Dashboard pracovníka – zobrazení dnešních úkolů z Isar.
///
/// Nahoře indikátor Online/Offline, pod ním seznam úkolů jako karty.
/// Při prázdném seznamu zobrazí elegantní empty state.
class WorkerDashboard extends ConsumerStatefulWidget {
  const WorkerDashboard({super.key});

  @override
  ConsumerState<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends ConsumerState<WorkerDashboard> {
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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(todaysTasksProvider);
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('app.title'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
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
          // Indikátor Online/Offline
          _ConnectivityIndicator(status: connectivityAsync),

          // Seznam úkolů nebo empty state
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _TaskCard(task: tasks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Drawer s možností změny PINu a odhlášení.
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
                    'app.title'.tr(),
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

/// Malý indikátor stavu sítě – zelená/červená tečka + text.
class _ConnectivityIndicator extends StatelessWidget {
  const _ConnectivityIndicator({required this.status});

  final AsyncValue<bool> status;

  @override
  Widget build(BuildContext context) {
    final isOnline = status.valueOrNull ?? false;
    final color = isOnline ? Colors.green : Colors.red;
    final text = isOnline
        ? 'dashboard.status_online'.tr()
        : 'dashboard.status_offline'.tr();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Karta jednoho úkolu – vertikální layout s časem, stavem a dalšími údaji.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskLocal task;

  @override
  Widget build(BuildContext context) {
    final t = task.scheduledStart;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/task/${task.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _accentOrange,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          task.status,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusLabel(task.status),
                        style: TextStyle(
                          fontSize: 13,
                          color: _getStatusColor(task.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (task.apartmentSupabaseId != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.apartment,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'dashboard.apartment_id'.tr(
                        namedArgs: {
                          'id': task.apartmentSupabaseId!.length >= 8
                              ? task.apartmentSupabaseId!.substring(0, 8)
                              : task.apartmentSupabaseId!,
                        },
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return _accentOrange;
      case 'cancelled':
        return Colors.grey;
      default:
        return _primaryBlue;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'dashboard.status_pending'.tr();
      case 'in_progress':
        return 'dashboard.status_in_progress'.tr();
      case 'completed':
        return 'dashboard.status_completed'.tr();
      case 'cancelled':
        return 'dashboard.status_cancelled'.tr();
      default:
        return status;
    }
  }
}

/// Empty state – vycentrovaná ikona a text při prázdném seznamu.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              'dashboard.empty_today'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
