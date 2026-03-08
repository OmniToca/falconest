import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartment_status_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/dashboard_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Administrativní nástěnka – operativní Dashboard s daty pro Action Strip.
///
/// Zobrazuje operativní sekce (Dnešní plán, Stav apartmánů, Kdo je v akci).
/// Data pro varovný Action Strip připravuje dashboardSummaryProvider.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(adminDashboardTasksProvider);
    final reservationsAsync = ref.watch(adminReservationsProvider);
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    final teamAsync = ref.watch(teamFullListProvider);
    if (tasksAsync.isLoading ||
        reservationsAsync.isLoading ||
        apartmentsAsync.isLoading ||
        teamAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (tasksAsync.hasError ||
        reservationsAsync.hasError ||
        apartmentsAsync.hasError ||
        teamAsync.hasError) {
      final msg = tasksAsync.hasError
          ? tasksAsync.error.toString()
          : reservationsAsync.hasError
              ? reservationsAsync.error.toString()
              : apartmentsAsync.hasError
                  ? apartmentsAsync.error.toString()
                  : teamAsync.error.toString();
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  'admin.dashboard_loading_error'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(msg, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
    }

    final tasks = tasksAsync.valueOrNull ?? [];
    final reservations = reservationsAsync.valueOrNull ?? [];
    final apartments = apartmentsAsync.valueOrNull ?? [];
    final teamMembers = teamAsync.valueOrNull ?? [];
    final summary = ref.watch(dashboardSummaryProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = today.add(const Duration(days: 1));

    // PROČ toLocal(): dueDate je UTC ze Supabase. Pro filtr "dnešní úkoly" porovnáváme lokální datum.
    final todayTasks = tasks.where((t) {
      final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
      final day = DateTime(local.year, local.month, local.day);
      return !day.isBefore(today) && day.isBefore(todayEnd);
    }).toList();

    // Externí úkoly = bez apartment_id (transfery, služby u klienta).
    final externalTasks = todayTasks.where((t) => t.apartmentId.trim().isEmpty).toList();

    final todayAssignedIds = todayTasks
        .map((t) => t.assignedTo)
        .where((id) => id != null && id.trim().isNotEmpty)
        .map((id) => id!)
        .toSet()
        .toList();
    final teamMembersToday = teamMembers
        .where((m) =>
            (m.profileId != null && todayAssignedIds.contains(m.profileId)) ||
            todayAssignedIds.contains(m.id))
        .toList();

    int countOccupied = 0, countToClean = 0, countClean = 0;
    for (final apt in apartments) {
      final status = getApartmentStatusForToday(reservations, tasks, apt.id);
      if (status == apartmentStatusOccupied) {
        countOccupied++;
      } else if (status == apartmentStatusNeedsCleaning) {
        countToClean++;
      } else {
        countClean++;
      }
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth * 0.025;
          final bool isWide = constraints.maxWidth > 900;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DashboardHeader(profileAsync: profileAsync, now: now),
                const SizedBox(height: 20),
                _ActionStripWidget(summary: summary),
                const SizedBox(height: 16),
                // Operativa – tři sloupce (Dnešní plán, Stav apartmánů, Kdo je v akci)
                isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _DashboardPlanSection(todayTasks: todayTasks),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ApartmentFleetSection(
                                countClean: countClean,
                                countToClean: countToClean,
                                countOccupied: countOccupied,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _TodaysTeamSection(
                                members: teamMembersToday,
                                todayTasks: todayTasks,
                                profileIdsWithCash: summary.profileIdsWithCash,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashboardPlanSection(todayTasks: todayTasks),
                          const SizedBox(height: 16),
                          _ApartmentFleetSection(
                            countClean: countClean,
                            countToClean: countToClean,
                            countOccupied: countOccupied,
                          ),
                          const SizedBox(height: 16),
                          _TodaysTeamSection(
                            members: teamMembersToday,
                            todayTasks: todayTasks,
                            profileIdsWithCash: summary.profileIdsWithCash,
                          ),
                        ],
                      ),
                const SizedBox(height: 16),
                _BusinessOverviewSection(summary: summary),
                const SizedBox(height: 16),
                _FinanceAttentionSection(tasks: tasks),
                const SizedBox(height: 16),
                _QuickActionsSection(ref: ref),
                const SizedBox(height: 16),
                _ExternalTasksSection(externalTasks: externalTasks),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _initialsFromName(String name) {
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
}

/// Společný stín pro prémiové karty – měkký, výrazný.
BoxDecoration get _premiumCardDecoration => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );

/// Osobní uvítací hlavička – Dobré ráno/odpoledne, [Jméno] a dnešní datum.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.profileAsync,
    required this.now,
  });

  final AsyncValue<CurrentUserProfile> profileAsync;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final dateStr = DateFormat('EEEE, d. MMMM', locale).format(now);
    final hour = now.hour;
    final greetingKey = hour < 12
        ? 'admin.dashboard_greeting_morning'
        : hour < 18
            ? 'admin.dashboard_greeting_afternoon'
            : 'admin.dashboard_greeting_evening';
    final greeting = greetingKey.tr();
    final name = profileAsync.valueOrNull?.name.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name.split(RegExp(r'\s+')).first
        : 'admin.dashboard_welcome_fallback'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $displayName 👋',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'admin.dashboard_today_is'.tr(namedArgs: {'date': dateStr}),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
        ),
      ],
    );
  }
}

/// Krásný prázdný stav – velká poloprůhledná ikona a stylovaný text.
class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sekce „Manažerský přehled“ – dva prémiové grafy (čárový + prstencový).
class _BusinessOverviewSection extends StatelessWidget {
  const _BusinessOverviewSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'admin.dashboard_manager_overview'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 60,
                    child: _ReservationsTrendChart(reservationsTrend: summary.reservationsTrend),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 40,
                    child: _TasksCompositionChart(tasksComposition: summary.tasksComposition),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _ReservationsTrendChart(reservationsTrend: summary.reservationsTrend),
                const SizedBox(height: 16),
                _TasksCompositionChart(tasksComposition: summary.tasksComposition),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Sekce „Finance & Pozornost“ – tři informační karty s prémiovou zamykací logikou.
///
/// Karty: Čeká na vyplacení (settlements), Očekávaný příjem (finance_export), Kritické/Zpožděné úkoly.
/// První dvě jsou uzamčeny při neaktivním modulu a po kliknutí otevřou PremiumUpsellDialog.
class _FinanceAttentionSection extends ConsumerWidget {
  const _FinanceAttentionSection({
    required this.tasks,
  });

  final List<TaskRow> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(groupedPendingPayoutsProvider);
    final settlementsActive = isModuleActive(ref, 'settlements');
    final financeExportActive = isModuleActive(ref, 'finance_export');
    final switchToTab = AdminTabScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'admin.dashboard_section_finance_attention'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            if (isWide) {
              // IntrinsicHeight dává Row konečnou výšku (nejvyšší karta), aby se karty neroztahovaly
              // do nekonečna uvnitř SingleChildScrollView. Expanded jen pro šířku karet.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _FinanceAttentionCard(
                      titleKey: 'admin.dashboard_card_pending_payouts',
                      icon: Icons.payments_outlined,
                      isLocked: !settlementsActive,
                      lockedMessageKey: 'admin.dashboard_card_pending_payouts_locked',
                      moduleKey: 'settlements',
                      payoutsAsync: payoutsAsync,
                      formatAmount: (v) => formatWalletAmount(context, ref, v),
                      onTapUnlocked: () => switchToTab?.call(adminTabIndexFinance),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ExpectedIncomeCard(
                      tasks: tasks,
                      isLocked: !financeExportActive,
                      formatAmount: (v) => formatWalletAmount(context, ref, v),
                      onTapUnlocked: () => switchToTab?.call(adminTabIndexFinance),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CriticalOverdueCard(
                      tasks: tasks,
                      onTap: () => switchToTab?.call(adminTabIndexTasks),
                    ),
                  ),
                ],
              ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FinanceAttentionCard(
                  titleKey: 'admin.dashboard_card_pending_payouts',
                  icon: Icons.payments_outlined,
                  isLocked: !settlementsActive,
                  lockedMessageKey: 'admin.dashboard_card_pending_payouts_locked',
                  moduleKey: 'settlements',
                  payoutsAsync: payoutsAsync,
                  formatAmount: (v) => formatWalletAmount(context, ref, v),
                  onTapUnlocked: () => switchToTab?.call(adminTabIndexFinance),
                ),
                const SizedBox(height: 12),
                _ExpectedIncomeCard(
                  tasks: tasks,
                  isLocked: !financeExportActive,
                  formatAmount: (v) => formatWalletAmount(context, ref, v),
                  onTapUnlocked: () => switchToTab?.call(adminTabIndexFinance),
                ),
                const SizedBox(height: 12),
                _CriticalOverdueCard(
                  tasks: tasks,
                  onTap: () => switchToTab?.call(adminTabIndexTasks),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Karta „Čeká na vyplacení“ – suma z groupedPendingPayoutsProvider. Uzamčeno při neaktivním settlements.
class _FinanceAttentionCard extends StatelessWidget {
  const _FinanceAttentionCard({
    required this.titleKey,
    required this.icon,
    required this.isLocked,
    required this.lockedMessageKey,
    required this.moduleKey,
    required this.payoutsAsync,
    required this.formatAmount,
    required this.onTapUnlocked,
  });

  final String titleKey;
  final IconData icon;
  final bool isLocked;
  final String lockedMessageKey;
  final String moduleKey;
  final AsyncValue<PayrollTabData> payoutsAsync;
  final String Function(double) formatAmount;
  final VoidCallback? onTapUnlocked;

  @override
  Widget build(BuildContext context) {
    final content = isLocked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lockedMessageKey.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          )
        : payoutsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              '—',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            data: (data) {
              final total = data.groups.fold<double>(0, (s, g) => s + g.totalAmount);
              return Text(
                formatAmount(total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              );
            },
          );

    return AppCard(
      onTap: () {
        if (isLocked) {
          PremiumUpsellDialog.show(
            context,
            moduleKey: moduleKey,
            titleKey: 'admin.upsell.settlements.title',
            descriptionKey: 'admin.upsell.settlements.description',
          );
        } else {
          onTapUnlocked?.call();
        }
      },
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: isLocked ? 0.7 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isLocked ? Colors.grey.shade600 : Colors.teal.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titleKey.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isLocked ? Colors.grey.shade700 : Colors.black87,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }
}

/// Vrací true, pokud je status považován za dokončený (pro výpočet očekávaného příjmu).
bool _isTaskCompleted(String? status) {
  if (status == null || status.trim().isEmpty) return false;
  final s = status.trim().toLowerCase();
  return s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno';
}

/// Z metadata úkolu vybere částku (amount_to_collect nebo service_price).
double _taskExpectedAmount(TaskRow t) {
  final meta = t.metadata;
  if (meta == null || meta.isEmpty) return 0;
  final amt = meta['amount_to_collect'];
  if (amt != null) {
    final v = amt is num ? amt.toDouble() : double.tryParse(amt.toString());
    return v ?? 0;
  }
  final svc = meta['service_price'];
  if (svc != null) {
    final v = svc is num ? svc.toDouble() : double.tryParse(svc.toString());
    return v ?? 0;
  }
  return 0;
}

/// Karta „Očekávaný příjem (Fakturace)“ – součet z dokončených nevyfakturovaných úkolů. Uzamčeno při neaktivním finance_export.
class _ExpectedIncomeCard extends StatelessWidget {
  const _ExpectedIncomeCard({
    required this.tasks,
    required this.isLocked,
    required this.formatAmount,
    required this.onTapUnlocked,
  });

  final List<TaskRow> tasks;
  final bool isLocked;
  final String Function(double) formatAmount;
  final VoidCallback? onTapUnlocked;

  @override
  Widget build(BuildContext context) {
    final completedSum = tasks
        .where((t) => _isTaskCompleted(t.status))
        .fold<double>(0, (s, t) => s + _taskExpectedAmount(t));

    final content = isLocked
        ? Row(
            children: [
              Icon(Icons.lock, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin.dashboard_card_expected_income_locked'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            ],
          )
        : Text(
            formatAmount(completedSum),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
          );

    return AppCard(
      onTap: () {
        if (isLocked) {
          PremiumUpsellDialog.show(
            context,
            moduleKey: 'finance_export',
            titleKey: 'admin.module_finance_export_upsell_title',
            descriptionKey: 'admin.module_finance_export_upsell_desc',
          );
        } else {
          onTapUnlocked?.call();
        }
      },
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: isLocked ? 0.7 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 22,
                  color: isLocked ? Colors.grey.shade600 : Colors.blue.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'admin.dashboard_card_expected_income'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isLocked ? Colors.grey.shade700 : Colors.black87,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }
}

/// Počet kritických (status problem) nebo zpožděných (due_date v minulosti, ne dokončeno) úkolů.
int _countCriticalOrOverdue(List<TaskRow> tasks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return tasks.where((t) {
    final status = (t.status.trim().toLowerCase());
    final isProblem = status == 'problem' || status == 'problém' || status == 'issue';
    final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
    final taskDay = DateTime(local.year, local.month, local.day);
    final isOverdue = taskDay.isBefore(today) && !_isTaskCompleted(t.status);
    return isProblem || isOverdue;
  }).length;
}

/// Karta „Kritické / Zpožděné úkoly“ – bez zámku, odkaz na záložku Úkoly.
class _CriticalOverdueCard extends StatelessWidget {
  const _CriticalOverdueCard({
    required this.tasks,
    required this.onTap,
  });

  final List<TaskRow> tasks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = _countCriticalOrOverdue(tasks);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 22, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'admin.dashboard_card_critical_overdue'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? Colors.orange.shade700 : Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Čárový graf s gradientem – vývoj rezervací 14 dní.
class _ReservationsTrendChart extends StatelessWidget {
  const _ReservationsTrendChart({required this.reservationsTrend});

  final List<int> reservationsTrend;

  @override
  Widget build(BuildContext context) {
    // Detekce prázdných dat – fl_chart nezvládá vykreslit křivku při samých nulách
    final isEmptyOrAllZeros = reservationsTrend.isEmpty ||
        reservationsTrend.every((v) => v == 0);
    if (isEmptyOrAllZeros) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.dashboard_chart_reservations_14'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: _EmptyStateWidget(
                icon: Icons.show_chart,
                message: 'admin.dashboard_chart_trend_no_data'.tr(),
              ),
            ),
          ],
        ),
      );
    }

    // Spread operátor – bezpečné doplnění nul k seznamům s pevnou délkou (fixed-length list).
    final trend = reservationsTrend.length >= 14
        ? reservationsTrend
        : [...reservationsTrend, ...List.filled(14 - reservationsTrend.length, 0)];
    final spots = trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
    final maxVal = trend.reduce((a, b) => a > b ? a : b).toDouble();
    // Bezpečné meze: maxY musí být > minY, jinak fl_chart vyhodí render error
    final maxY = maxVal > 0 ? maxVal + 1 : 5.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_chart_reservations_14'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 13,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: Colors.blue.shade600,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade400.withValues(alpha: 0.35),
                          Colors.blue.shade400.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 13) return const SizedBox.shrink();
                        final dayOffset = i - 7;
                        final label = dayOffset == 0
                            ? 'common.today'.tr()
                            : (dayOffset > 0 ? '+$dayOffset' : '$dayOffset');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
              duration: const Duration(milliseconds: 350),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barvy pro kategorie úkolů v donut grafu – pastelové/brand.
final _compositionColors = [
  Colors.amber.shade400,
  Colors.blue.shade400,
  Colors.green.shade500,
  Colors.orange.shade400,
  Colors.purple.shade400,
  Colors.teal.shade400,
  Colors.indigo.shade400,
];

/// Prstencový graf – skladba dnešních úkolů s legendou.
class _TasksCompositionChart extends StatelessWidget {
  const _TasksCompositionChart({required this.tasksComposition});

  final Map<String, int> tasksComposition;

  @override
  Widget build(BuildContext context) {
    final entries = tasksComposition.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.dashboard_chart_tasks_composition'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Center(
                child: _EmptyStateWidget(
                  icon: Icons.pie_chart_outline,
                  message: 'admin.dashboard_chart_no_data'.tr(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final sections = entries.asMap().entries.map((e) {
      final idx = e.key % _compositionColors.length;
      final color = _compositionColors[idx];
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: color,
        radius: 48,
        title: '${e.value.value}',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_chart_tasks_composition'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 42,
                          sections: sections,
                          pieTouchData: PieTouchData(
                            touchCallback: (_, _) {},
                            enabled: true,
                          ),
                        ),
                        duration: const Duration(milliseconds: 350),
                      ),
                      Center(
                        child: Text(
                          '$total',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.asMap().entries.map((e) {
                      final idx = e.key % _compositionColors.length;
                      final color = _compositionColors[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${e.value.key} (${e.value.value})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Varovný pruh nahoře – zobrazuje návrhy ke schválení, problémy a nevybranou hotovost.
/// Při všech nulách: zelený pruh „Vše je vyřešeno“. Jinak klikací kartičky s navigací.
class _ActionStripWidget extends StatelessWidget {
  const _ActionStripWidget({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasWarnings = summary.pendingTasksCount > 0 ||
        summary.problemTasksCount > 0 ||
        summary.employeesWithCashCount > 0;

    if (!hasWarnings) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'admin.dashboard_action_strip_all_clear'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cards = <Widget>[];
    final switchToTab = AdminTabScope.of(context);

    if (summary.pendingTasksCount > 0) {
      cards.add(_ActionCard(
        text: 'admin.dashboard_action_pending_proposals'.tr(
          namedArgs: {'count': '${summary.pendingTasksCount}'},
        ),
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.pending_actions,
        onTap: () => switchToTab?.call(adminTabIndexTasks),
      ));
    }
    if (summary.problemTasksCount > 0) {
      cards.add(_ActionCard(
        text: 'admin.dashboard_action_problems'.tr(
          namedArgs: {'count': '${summary.problemTasksCount}'},
        ),
        gradient: LinearGradient(
          colors: [Colors.red.shade500, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.warning_amber_rounded,
        onTap: () => switchToTab?.call(adminTabIndexTasks),
      ));
    }
    if (summary.employeesWithCashCount > 0) {
      final amountStr = summary.totalUncollectedCash.toStringAsFixed(1);
      cards.add(_ActionCard(
        text: 'admin.dashboard_action_cash_uncollected'.tr(
          namedArgs: {
            'amount': amountStr,
            'count': '${summary.employeesWithCashCount}',
          },
        ),
        gradient: LinearGradient(
          colors: [Colors.orange.shade500, Colors.deepOrange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.account_balance_wallet,
        onTap: () => switchToTab?.call(adminTabIndexFinance),
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => isWide ? c : SizedBox(width: constraints.maxWidth, child: c))
              .toList(),
        );
      },
    );
  }
}

/// Jedna kartička v Action Strip – prémiový alert s gradientem a bílým textem.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.text,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final Gradient gradient;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sekce Rychlé akce – tlačítka Přidat úkol, Generovat návrhy, Finance.
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final switchToTab = AdminTabScope.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _premiumCardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_quick_actions'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      AdminTasksScreen.showAddTaskDialog(context, ref);
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('admin.dashboard_quick_add_task'.tr()),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => switchToTab?.call(adminTabIndexTasks),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: Text('admin.dashboard_quick_generate_proposals'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade800,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => switchToTab?.call(adminTabIndexFinance),
                    icon: const Icon(Icons.account_balance_wallet, size: 20),
                    label: Text('admin.dashboard_quick_finance_wallet'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// Sekce „Dnešní externí služby“ – úkoly bez apartment_id (transfery, služby u klienta).
class _ExternalTasksSection extends StatelessWidget {
  const _ExternalTasksSection({required this.externalTasks});

  final List<TaskRow> externalTasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(20),
      decoration: _premiumCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_external_services'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 10),
          if (externalTasks.isEmpty)
            _EmptyStateWidget(
              icon: Icons.directions_car_outlined,
              message: 'admin.dashboard_external_services_empty'.tr(),
            )
          else
            ...externalTasks.map((t) {
              final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
              final timeStr =
                  '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
              final title = t.customTitle?.trim().isNotEmpty == true
                  ? t.customTitle!
                  : t.title.trim().isNotEmpty
                      ? t.title
                      : 'admin.task_no_title'.tr();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    final switchToTab = AdminTabScope.of(context);
                    if (switchToTab != null) switchToTab(adminTabIndexTasks);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(TaskVisuals.getIconStatic(t.taskType),
                            size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$title • $timeStr',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Sekce „Dnešní plán“ – scrollovací timeline úkolů.
class _DashboardPlanSection extends StatelessWidget {
  const _DashboardPlanSection({required this.todayTasks});

  final List<TaskRow> todayTasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(20),
      decoration: _premiumCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.dashboard_plan_today'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          if (todayTasks.isEmpty)
            _EmptyStateWidget(
              icon: Icons.coffee_outlined,
              message: 'admin.dashboard_today_done_coffee'.tr(),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: todayTasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = todayTasks[index];
                  final icon = TaskVisuals.getIconStatic(t.taskType);
                  final bgColor = TaskVisuals.getBackgroundColorStatic(t.taskType);
                  final iconColor = TaskVisuals.getBorderColorStatic(t.taskType);
                  final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
                  final timeStr =
                      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                  final hasAssignee = t.assignedToName != null && t.assignedToName!.trim().isNotEmpty;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final switchToTab = AdminTabScope.of(context);
                        if (switchToTab != null) switchToTab(adminTabIndexTasks);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 20, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${t.apartmentName ?? t.apartmentId} • $timeStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (hasAssignee)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.purple.shade100,
                                  child: Text(
                                    AdminDashboardScreen._initialsFromName(t.assignedToName!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple.shade800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Sekce „Kdo je dnes v akci“ – avatary pracovníků s počtem úkolů. Ikona 💰 u těch s nevybranou hotovostí.
class _TodaysTeamSection extends StatelessWidget {
  const _TodaysTeamSection({
    required this.members,
    required this.todayTasks,
    required this.profileIdsWithCash,
  });

  final List<TeamMember> members;
  final List<TaskRow> todayTasks;
  final Set<String> profileIdsWithCash;

  @override
  Widget build(BuildContext context) {
    int taskCountFor(TeamMember m) {
      return todayTasks
          .where((t) =>
              (t.assignedTo == m.profileId || t.assignedTo == m.id) &&
              (t.assignedTo != null && t.assignedTo!.trim().isNotEmpty))
          .length;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 200),
      padding: const EdgeInsets.all(20),
      decoration: _premiumCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_todays_team'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            _EmptyStateWidget(
              icon: Icons.groups_outlined,
              message: 'admin.dashboard_no_shift_today'.tr(),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: members.map((m) {
                final count = taskCountFor(m);
                final profileId = m.profileId ?? m.id;
                final hasCash = profileId.isNotEmpty && profileIdsWithCash.contains(profileId);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple.shade100,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              AdminDashboardScreen._initialsFromName(m.name),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ),
                        ),
                        if (hasCash)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Icon(Icons.account_balance_wallet, size: 14, color: Colors.white),
                            ),
                          ),
                        if (count > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        m.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                              fontSize: 11,
                            ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Sekce „Stav apartmánů“ – barevné pilulky.
class _ApartmentFleetSection extends StatelessWidget {
  const _ApartmentFleetSection({
    required this.countClean,
    required this.countToClean,
    required this.countOccupied,
  });

  final int countClean;
  final int countToClean;
  final int countOccupied;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(20),
      decoration: _premiumCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_apartment_fleet'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FleetStatusBlock(
                  count: countClean,
                  labelKey: 'admin.dashboard_fleet_clean',
                  icon: Icons.check_circle_outline,
                  backgroundColor: Colors.green.shade50,
                  accentColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FleetStatusBlock(
                  count: countToClean,
                  labelKey: 'admin.dashboard_fleet_to_clean',
                  icon: Icons.cleaning_services_outlined,
                  backgroundColor: Colors.orange.shade50,
                  accentColor: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FleetStatusBlock(
                  count: countOccupied,
                  labelKey: 'admin.dashboard_fleet_occupied',
                  icon: Icons.people_outline,
                  backgroundColor: Colors.blue.shade50,
                  accentColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Moderní Status Block – čtvercová/obdélníková karta s číslem, ikonou a textem.
class _FleetStatusBlock extends StatelessWidget {
  const _FleetStatusBlock({
    required this.count,
    required this.labelKey,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
  });

  final int count;
  final String labelKey;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final labelText = labelKey.tr(namedArgs: {'count': '$count'});
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(height: 4),
          Text(
            labelText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
