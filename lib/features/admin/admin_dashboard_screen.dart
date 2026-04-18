import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/apartment_live_context_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_automation_tab_index_provider.dart';
import 'package:falconest/features/admin/providers/admin_automation_filter_provider.dart';
import 'package:falconest/features/admin/providers/apartment_status_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/dashboard_provider.dart';
import 'package:falconest/features/admin/providers/automation_summary_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/providers/finance_tab_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/providers/new_clients_this_month_provider.dart';
import 'package:falconest/features/admin/providers/messaging_health_provider.dart';
import 'package:falconest/features/admin/providers/messaging_failures_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/utils/task_visuals.dart';
import 'package:falconest/features/admin/providers/upcoming_absences_provider.dart';
import 'package:falconest/features/admin/widgets/statistics/admin_efficiency_chart.dart';

/// Mezera mezi hlavními bloky nástěnky (Phase 1 – jednotný rhythm).
const double _kDashboardBlockGap = AppSpacing.sm;

/// Mezera mezi nadpisem sekce a kartami (vizuální hierarchie bez „prázdné díry“).
const double _kDashboardTitleToContentGap = 10;

/// Sjednocená výška oblasti výkresu u grafů na nástěnce (čárový trend + donut řádek).
///
/// PROČ: Nižší vizuální dominance než dřívější ~200–224 px; stejná hodnota u obou karet,
/// aby vedle sebe v řádku lícně seděly a odpovídaly nízké datové hustotě (14 bodů / pár segmentů).
const double _kDashboardChartPlotHeight = 180;

/// Kompaktní prázdný stav pro nástěnku – jeden řádek, žádná fixní výška ani velká ilustrace.
///
/// PROČ: [AppEmptyState] používá velkou ikonu a sloupcový layout; v dashboardu
/// zbytečně roztahoval karty. Tato varianta šetří vertikální místo při zachování i18n textu.
class _DashboardCompactEmptyState extends StatelessWidget {
  const _DashboardCompactEmptyState({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.88),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Administrativní nástěnka – operativní Dashboard s daty pro Action Strip.
///
/// Zobrazuje operativní sekce (Dnešní plán, Stav apartmánů, Kdo je v akci).
/// Data pro varovný Action Strip připravuje dashboardSummaryProvider.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(adminDashboardTasksProvider);
    final apartmentStatusResAsync = ref.watch(apartmentStatusContextReservationsProvider);
    final apartmentStatusTasksAsync = ref.watch(todayApartmentTasksProvider);
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    final teamAsync = ref.watch(teamFullListProvider);
    if (tasksAsync.isLoading ||
        apartmentStatusResAsync.isLoading ||
        apartmentStatusTasksAsync.isLoading ||
        apartmentsAsync.isLoading ||
        teamAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (tasksAsync.hasError ||
        apartmentStatusResAsync.hasError ||
        apartmentStatusTasksAsync.hasError ||
        apartmentsAsync.hasError ||
        teamAsync.hasError) {
      if (kDebugMode) {
        final err = tasksAsync.hasError
            ? tasksAsync.error
            : apartmentStatusResAsync.hasError
                ? apartmentStatusResAsync.error
                : apartmentStatusTasksAsync.hasError
                    ? apartmentStatusTasksAsync.error
                    : apartmentsAsync.hasError
                        ? apartmentsAsync.error
                        : teamAsync.error;
        debugPrint('AdminDashboardScreen provider error: $err');
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: AppSpacing.xxl,
                  color: context.colors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'admin.dashboard_loading_error'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'common.generic_error_user_friendly'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tasks = tasksAsync.valueOrNull ?? [];
    final fleetReservations = apartmentStatusResAsync.valueOrNull ?? [];
    final fleetTasks = apartmentStatusTasksAsync.valueOrNull ?? [];
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

    // Smart Fallback: Pokud je dnes prázdno, zobrazíme nejbližší události (zítra až +7 dní).
    final tomorrowStart = todayEnd;
    final upcomingEnd = tomorrowStart.add(const Duration(days: 7));
    final upcomingTasks = tasks.where((t) {
      final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
      final day = DateTime(local.year, local.month, local.day);
      return !day.isBefore(tomorrowStart) && day.isBefore(upcomingEnd);
    }).toList();
    final useUpcomingFallback = todayTasks.isEmpty && upcomingTasks.isNotEmpty;
    final displayPlanTasks = useUpcomingFallback ? upcomingTasks : todayTasks;

    // Externí úkoly = bez apartment_id (transfery, služby u klienta).
    final externalTasks = todayTasks
        .where((t) => t.apartmentId.trim().isEmpty)
        .toList();
    final upcomingExternalTasks = upcomingTasks
        .where((t) => t.apartmentId.trim().isEmpty)
        .toList();
    final displayExternalTasks = externalTasks.isNotEmpty
        ? externalTasks
        : (useUpcomingFallback ? upcomingExternalTasks : externalTasks);

    final todayAssignedIds = todayTasks
        .map((t) => t.assignedTo)
        .where((id) => id != null && id.trim().isNotEmpty)
        .map((id) => id!)
        .toSet()
        .toList();
    final upcomingAssignedIds = upcomingTasks
        .map((t) => t.assignedTo)
        .where((id) => id != null && id.trim().isNotEmpty)
        .map((id) => id!)
        .toSet()
        .toList();
    final teamMembersToday = teamMembers
        .where(
          (m) =>
              (m.profileId != null && todayAssignedIds.contains(m.profileId)) ||
              todayAssignedIds.contains(m.id),
        )
        .toList();
    final teamMembersUpcoming = teamMembers
        .where(
          (m) =>
              (m.profileId != null &&
                  upcomingAssignedIds.contains(m.profileId)) ||
              upcomingAssignedIds.contains(m.id),
        )
        .toList();
    final displayTeamMembers = useUpcomingFallback
        ? teamMembersUpcoming
        : teamMembersToday;

    // Smart Fallback pro graf skladby: pokud dnes nic není, použij data z dalších 7 dní.
    final displayTasksComposition = _buildTasksCompositionMap(displayPlanTasks);

    int countOccupied = 0, countToClean = 0, countClean = 0;
    for (final apt in apartments) {
      final status = getApartmentStatusForToday(fleetReservations, fleetTasks, apt.id);
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
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.md,
              horizontalPadding,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Na širokém monitoru: pozdrav a Action Strip v jednom řádku; na úzkém sloupec.
                LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final headerWide = headerConstraints.maxWidth > 900;
                    if (headerWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _DashboardHeader(
                            profileAsync: profileAsync,
                            now: now,
                          ),
                          const SizedBox(width: _kDashboardBlockGap),
                          Expanded(child: _ActionStripWidget(summary: summary)),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DashboardHeader(profileAsync: profileAsync, now: now),
                        const SizedBox(height: _kDashboardBlockGap),
                        _ActionStripWidget(summary: summary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _kDashboardBlockGap),
                // --- Operativa: plán | tým | flotila ---
                _DashboardSectionTitle(
                  titleKey: 'admin.dashboard_section_quick_overview',
                ),
                isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _DashboardPlanSection(
                                tasks: displayPlanTasks,
                                isUpcoming: useUpcomingFallback,
                                today: today,
                              ),
                            ),
                            const SizedBox(width: _kDashboardBlockGap),
                            Expanded(
                              child: _TodaysTeamSection(
                                members: displayTeamMembers,
                                displayTasks: displayPlanTasks,
                                profileIdsWithCash: summary.profileIdsWithCash,
                                isUpcoming: useUpcomingFallback,
                              ),
                            ),
                            const SizedBox(width: _kDashboardBlockGap),
                            Expanded(
                              child: _ApartmentFleetSection(
                                totalApartments: apartments.length,
                                countClean: countClean,
                                countToClean: countToClean,
                                countOccupied: countOccupied,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DashboardPlanSection(
                            tasks: displayPlanTasks,
                            isUpcoming: useUpcomingFallback,
                            today: today,
                          ),
                          const SizedBox(height: _kDashboardBlockGap),
                          _TodaysTeamSection(
                            members: displayTeamMembers,
                            displayTasks: displayPlanTasks,
                            profileIdsWithCash: summary.profileIdsWithCash,
                            isUpcoming: useUpcomingFallback,
                          ),
                          const SizedBox(height: _kDashboardBlockGap),
                          _ApartmentFleetSection(
                            totalApartments: apartments.length,
                            countClean: countClean,
                            countToClean: countToClean,
                            countOccupied: countOccupied,
                          ),
                        ],
                      ),
                const SizedBox(height: _kDashboardBlockGap),
                // --- Operativní akce: externí služby | rychlé akce ---
                _DashboardSectionTitle(
                  titleKey: 'admin.dashboard_section_operations',
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wideOps = constraints.maxWidth > 900;
                    if (wideOps) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ExternalTasksSection(
                                externalTasks: displayExternalTasks,
                                isUpcoming: useUpcomingFallback,
                                today: today,
                              ),
                            ),
                            const SizedBox(width: _kDashboardBlockGap),
                            Expanded(child: _QuickActionsSection(ref: ref)),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExternalTasksSection(
                          externalTasks: displayExternalTasks,
                          isUpcoming: useUpcomingFallback,
                          today: today,
                        ),
                        const SizedBox(height: _kDashboardBlockGap),
                        _QuickActionsSection(ref: ref),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _kDashboardBlockGap),
                // --- KPI a rizika ---
                _DashboardSectionTitle(
                  titleKey: 'admin.dashboard_kpi_overview_title',
                ),
                _KpiRisksRowSection(tasks: tasks),
                const SizedBox(height: _kDashboardBlockGap),
                _FinanceTwoCardsSection(
                  tasks: tasks,
                  apartments: apartments,
                ),
                const SizedBox(height: _kDashboardBlockGap),
                _DashboardSectionTitle(
                  titleKey: 'admin.stats.efficiency_section_title',
                ),
                AdminTaskEfficiencyInsightsCard(tasks: tasks),
                const SizedBox(height: _kDashboardBlockGap),
                _DashboardSectionTitle(
                  titleKey: 'admin.dashboard_manager_overview',
                ),
                _BusinessOverviewSection(
                  summary: summary,
                  tasksComposition: displayTasksComposition,
                  compositionIsUpcoming: useUpcomingFallback,
                ),
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

/// Panel na nástěnce se [premiumCardDecoration] – náhrada [AppCard] bez vlastních stínů/rádiusů.
///
/// PROČ: KPI a Finance karty mají vizuál sjednotit s „Dnešní plán“ a flotilou bytů.
Widget _dashboardPanel(
  BuildContext context, {
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  VoidCallback? onTap,
}) {
  final radius = BorderRadius.circular(AppSpacing.md);
  final decorated = Container(
    decoration: premiumCardDecoration(context),
    child: Padding(padding: padding, child: child),
  );
  if (onTap == null) return decorated;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: decorated,
    ),
  );
}

/// Jednotný nadpis sekce nástěnky – mezera k obsahu dle Phase 1 (foundation).
class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.titleKey});

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kDashboardTitleToContentGap),
      child: Text(
        titleKey.tr(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
              letterSpacing: -0.3,
            ),
      ),
    );
  }
}

/// Řádek KPI: pozornost | komunikace + automatizace | noví klienti + absence radar.
///
/// PROČ: Oddělení od finančního řádku – stejná data a providery jako dříve, jen nové rozložení.
class _KpiRisksRowSection extends ConsumerWidget {
  const _KpiRisksRowSection({required this.tasks});

  final List<TaskRow> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortfallsAsync = ref.watch(cashShortfallsCountProvider);
    final shortfallCount = shortfallsAsync.valueOrNull ?? 0;
    final switchToTab = AdminTabScope.of(context);

    void onTapShortfalls() {
      ref.read(financeRequestedSubTabProvider.notifier).state =
          financeSubTabIndexBilling;
      switchToTab?.call(adminTabIndexFinance);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideKpi = constraints.maxWidth > 900;
        if (wideKpi) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _NeedsAttentionCard(
                    tasks: tasks,
                    shortfallCount: shortfallCount,
                    onTapTasks: () => switchToTab?.call(adminTabIndexTasks),
                    onTapShortfalls: onTapShortfalls,
                  ),
                ),
                const SizedBox(width: _kDashboardBlockGap),
                Expanded(
                  child: _CommunicationAndAutomationStatusCard(),
                ),
                const SizedBox(width: _kDashboardBlockGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NewClientsThisMonthCard(),
                      const SizedBox(height: _kDashboardBlockGap),
                      const _AbsenceRadarCard(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NeedsAttentionCard(
              tasks: tasks,
              shortfallCount: shortfallCount,
              onTapTasks: () => switchToTab?.call(adminTabIndexTasks),
              onTapShortfalls: onTapShortfalls,
            ),
            const SizedBox(height: _kDashboardBlockGap),
            const _CommunicationAndAutomationStatusCard(),
            const SizedBox(height: _kDashboardBlockGap),
            _NewClientsThisMonthCard(),
            const SizedBox(height: _kDashboardBlockGap),
            const _AbsenceRadarCard(),
          ],
        );
      },
    );
  }
}

/// Finance: pouze vyplacení + očekávaný příjem (Needs Attention je v [_KpiRisksRowSection]).
class _FinanceTwoCardsSection extends ConsumerWidget {
  const _FinanceTwoCardsSection({
    required this.tasks,
    required this.apartments,
  });

  final List<TaskRow> tasks;
  final List<ApartmentRow> apartments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(groupedPendingPayoutsProvider);
    final settlementsActive = isModuleActive(ref, 'settlements');
    final financeExportActive = isModuleActive(ref, 'finance_export');
    final switchToTab = AdminTabScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardSectionTitle(
          titleKey: 'admin.dashboard_section_finance_attention',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wideFin = constraints.maxWidth > 600;
            if (wideFin) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _FinanceAttentionCard(
                        titleKey: 'admin.dashboard_card_pending_payouts',
                        icon: Icons.payments_outlined,
                        isLocked: !settlementsActive,
                        lockedMessageKey:
                            'admin.dashboard_card_pending_payouts_locked',
                        moduleKey: 'settlements',
                        payoutsAsync: payoutsAsync,
                        formatAmount: (v) =>
                            formatWalletAmount(context, ref, v),
                        onTapUnlocked: () =>
                            switchToTab?.call(adminTabIndexFinance),
                      ),
                    ),
                    const SizedBox(width: _kDashboardBlockGap),
                    Expanded(
                      child: _ExpectedIncomeCard(
                        tasks: tasks,
                        apartments: apartments,
                        isLocked: !financeExportActive,
                        formatAmount: (v) =>
                            formatWalletAmount(context, ref, v),
                        onTapUnlocked: () =>
                            switchToTab?.call(adminTabIndexFinance),
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
                  lockedMessageKey:
                      'admin.dashboard_card_pending_payouts_locked',
                  moduleKey: 'settlements',
                  payoutsAsync: payoutsAsync,
                  formatAmount: (v) => formatWalletAmount(context, ref, v),
                  onTapUnlocked: () =>
                      switchToTab?.call(adminTabIndexFinance),
                ),
                const SizedBox(height: _kDashboardBlockGap),
                _ExpectedIncomeCard(
                  tasks: tasks,
                  apartments: apartments,
                  isLocked: !financeExportActive,
                  formatAmount: (v) => formatWalletAmount(context, ref, v),
                  onTapUnlocked: () =>
                      switchToTab?.call(adminTabIndexFinance),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Osobní uvítací hlavička – Dobré ráno/odpoledne, [Jméno] a dnešní datum.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profileAsync, required this.now});

  final AsyncValue<CurrentUserProfile> profileAsync;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final dateStr = DateFormat('EEEE, d. MMMM', locale).format(now);
    final hour = now.hour;
    final name = profileAsync.valueOrNull?.name.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name.split(RegExp(r'\s+')).first
        : 'admin.dashboard_welcome_fallback'.tr();

    // PROČ: Celá fráze (interpunkce + emoji) musí být v jednom i18n klíči,
    // protože pořadí slov/interpunkce se v různých jazycích liší.
    final greetingPhraseKey = hour < 12
        ? 'admin.dashboard_greeting_morning_with_name'
        : hour < 18
            ? 'admin.dashboard_greeting_afternoon_with_name'
            : 'admin.dashboard_greeting_evening_with_name';
    final greetingPhrase = greetingPhraseKey.tr(
      namedArgs: {'displayName': displayName},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greetingPhrase,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'admin.dashboard_today_is'.tr(namedArgs: {'date': dateStr}),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Sekce „Manažerský přehled“ – dva prémiové grafy (čárový + prstencový).
class _BusinessOverviewSection extends StatelessWidget {
  const _BusinessOverviewSection({
    required this.summary,
    required this.tasksComposition,
    required this.compositionIsUpcoming,
  });

  final DashboardSummary summary;
  final Map<String, int> tasksComposition;
  final bool compositionIsUpcoming;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 60,
                child: _ReservationsTrendChart(
                  reservationsTrend: summary.reservationsTrend,
                ),
              ),
              const SizedBox(width: _kDashboardBlockGap),
              Expanded(
                flex: 40,
                child: _TasksCompositionChart(
                  tasksComposition: tasksComposition,
                  isUpcoming: compositionIsUpcoming,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _ReservationsTrendChart(
              reservationsTrend: summary.reservationsTrend,
            ),
            const SizedBox(height: _kDashboardBlockGap),
            _TasksCompositionChart(
              tasksComposition: tasksComposition,
              isUpcoming: compositionIsUpcoming,
            ),
          ],
        );
      },
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
                  Icon(
                    Icons.lock,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lockedMessageKey.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
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
            error: (_, _) => Text(
              'common.placeholder_dash'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            data: (data) {
              // PROČ: Když nejsou žádné pending payouty, „0“ by působilo jako
              // výpočetní chyba. Ukážeme uživatelsky srozumitelný stav bez dat.
              if (data.groups.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.dashboard_no_pending_payouts'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }
              final total = data.groups.fold<double>(
                0,
                (s, g) => s + g.totalAmount,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatAmount(total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.customColors.success,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'admin.dashboard_pending_payouts_subtitle'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          );

    return _dashboardPanel(context,
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
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isLocked
                      ? context.colors.onSurfaceVariant
                      : context.colors.tertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titleKey.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? context.colors.onSurfaceVariant
                          : context.colors.onSurface,
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

/// Vrací (rok, měsíc) úkolu pro rozdělení do aktuálního vs. příštího měsíce (scheduled_start nebo due_date, lokální čas).
(int, int) _taskYearMonth(TaskRow t) {
  final dt = t.scheduledStart ?? t.dueDate;
  final local = dt.isUtc ? dt.toLocal() : dt;
  return (local.year, local.month);
}

/// Karta „Očekávaný příjem (Fakturace)“ – B2B: hotové tento měsíc + výhled aktuálního a příštího měsíce. Uzamčeno při neaktivním finance_export.
/// Zahrnuje i měsíční paušály za správu apartmánů (monthlyManagementFee) jako jistý příjem.
class _ExpectedIncomeCard extends StatelessWidget {
  const _ExpectedIncomeCard({
    required this.tasks,
    required this.apartments,
    required this.isLocked,
    required this.formatAmount,
    required this.onTapUnlocked,
  });

  final List<TaskRow> tasks;
  final List<ApartmentRow> apartments;
  final bool isLocked;
  final String Function(double) formatAmount;
  final VoidCallback? onTapUnlocked;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;
    final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;

    final currentMonthTasks = tasks.where((t) {
      final (y, m) = _taskYearMonth(t);
      return y == currentYear && m == currentMonth;
    }).toList();
    final nextMonthTasks = tasks.where((t) {
      final (y, m) = _taskYearMonth(t);
      return y == nextYear && m == nextMonth;
    }).toList();

    final monthlyFeeSum = apartments.fold<double>(
      0,
      (sum, apt) => sum + (apt.monthlyManagementFee),
    );

    final currentMonthCompleted = currentMonthTasks
        .where((t) => _isTaskCompleted(t.status))
        .fold<double>(0, (s, t) => s + _taskExpectedAmount(t));
    final currentMonthTotal = currentMonthTasks.fold<double>(
      0,
      (s, t) => s + _taskExpectedAmount(t),
    );
    final nextMonthTotal = nextMonthTasks.fold<double>(
      0,
      (s, t) => s + _taskExpectedAmount(t),
    );

    // Měsíční paušály za správu – jistý příjem, přičteme k hotovým i k výhledu.
    final currentMonthCompletedWithFees = currentMonthCompleted + monthlyFeeSum;
    final currentMonthTotalWithFees = currentMonthTotal + monthlyFeeSum;
    final nextMonthTotalWithFees = nextMonthTotal + monthlyFeeSum;

    // PROČ: Empty state pro očekávaný příjem, když nemáme žádné úkoly ani apartmány
    // (tedy ani zdroj pro měsíční paušály). Bez toho by UI ukazovalo zavádějící „0“.
    final content = isLocked
        ? Row(
            children: [
              Icon(
                Icons.lock,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin.dashboard_card_expected_income_locked'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        : (tasks.isEmpty && apartments.isEmpty)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'admin.dashboard_no_expected_income'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'admin.dashboard_expected_income_done_this_month'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatAmount(currentMonthCompletedWithFees),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.customColors.success,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${'admin.dashboard_expected_income_outlook_month'.tr()}: ${formatAmount(currentMonthTotalWithFees)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'admin.dashboard_expected_income_outlook_next'.tr()}: ${formatAmount(nextMonthTotalWithFees)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );

    return _dashboardPanel(context,
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
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 22,
                  color: isLocked
                      ? context.colors.onSurfaceVariant
                      : context.colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'admin.dashboard_card_expected_income'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? context.colors.onSurfaceVariant
                          : context.colors.onSurface,
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
    final isProblem =
        status == 'problem' || status == 'problém' || status == 'issue';
    final local = t.dueDate.isUtc ? t.dueDate.toLocal() : t.dueDate;
    final taskDay = DateTime(local.year, local.month, local.day);
    final isOverdue = taskDay.isBefore(today) && !_isTaskCompleted(t.status);
    return isProblem || isOverdue;
  }).length;
}

/// Mapuje raw task_type na kategorii pro graf (stejná logika jako v dashboard_provider).
Map<String, int> _buildTasksCompositionMap(List<TaskRow> taskList) {
  final result = <String, int>{};
  for (final t in taskList) {
    final cat = _taskTypeToCategoryKey(t.taskType);
    result[cat] = (result[cat] ?? 0) + 1;
  }
  return result;
}

/// Klíč kategorie pro donut graf (`admin.dashboard_chart_category_*` v JSON).
///
/// PROČ i18n: legendy nesmí být natvrdo v češtině – tenant může mít jiný jazyk UI.
/// POZOR: v cs/en musí být klíče pod `admin` jako `dashboard_chart_category_*` (jedna tečka
/// po `admin`), ne `admin.dashboard.chart_*` – jinak `.tr()` zobrazí surový řetězec.
String _taskTypeToCategoryKey(String taskType) {
  final t = taskType.trim().toLowerCase();
  if (t.contains('cleaning') || t.contains('úklid')) {
    return 'admin.dashboard_chart_category_cleaning';
  }
  if (t.contains('transfer_in') ||
      (t.contains('transfer') && t.contains('in'))) {
    return 'admin.dashboard_chart_category_transfers';
  }
  if (t.contains('transfer_out') ||
      (t.contains('transfer') && t.contains('out'))) {
    return 'admin.dashboard_chart_category_transfers';
  }
  if (t.contains('transfer')) {
    return 'admin.dashboard_chart_category_transfers';
  }
  if (t.contains('check_in')) {
    return 'admin.dashboard_chart_category_arrivals';
  }
  if (t.contains('check_out')) {
    return 'admin.dashboard_chart_category_departures';
  }
  if (t.contains('issue') ||
      t.contains('material') ||
      t.contains('údržba') ||
      t.contains('závada')) {
    return 'admin.dashboard_chart_category_maintenance';
  }
  return 'admin.dashboard_chart_category_other';
}

/// Formátuje časové okno úkolu pro Dnešní plán / externí služby (lokální čas).
///
/// PROČ: Dříve se bral jen [TaskRow.dueDate] → jeden čas (konec); dispečer potřebuje interval
/// začátek–konec stejně jako v Kanbanu ([scheduled_start] + [due_date]).
/// `task_duration_parse.dart` parsuje délku z popisu; zde pracujeme výhradně s DB časy.
String formatDashboardTaskTimeWindow(BuildContext context, TaskRow t) {
  final startRaw = t.scheduledStart;
  final endRaw = t.dueDate;
  final endLocal = endRaw.isUtc ? endRaw.toLocal() : endRaw;
  String hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  if (startRaw != null) {
    final startLocal = startRaw.isUtc ? startRaw.toLocal() : startRaw;
    final diffMin = endRaw.difference(startRaw).inMinutes;
    if (diffMin > 0) {
      return '${hm(startLocal)} - ${hm(endLocal)}';
    }
    return 'admin.dashboard_task_from'.tr(namedArgs: {'time': hm(startLocal)});
  }
  // Bez explicitního začátku: půlnoc lokálně = heuristika „celý den“ (bez konkrétní hodiny).
  if (endLocal.hour == 0 && endLocal.minute == 0) {
    return 'admin.dashboard_task_all_day'.tr();
  }
  return hm(endLocal);
}

/// Formátuje datum a čas úkolu pro zobrazení v režimu „Nejbližší plán“ (Smart Fallback).
/// Zítra → „Zítra 09:00–10:00“, jinak → „Čt 12.3. 09:00–10:00“. PROČ: Dispečer musí na první pohled vidět, že jde o budoucí den.
String formatTaskDueForUpcoming(
  BuildContext context,
  TaskRow task,
  DateTime today,
) {
  final localDue = task.dueDate.isUtc ? task.dueDate.toLocal() : task.dueDate;
  final taskDay = DateTime(localDue.year, localDue.month, localDue.day);
  final tomorrow = today.add(const Duration(days: 1));
  final timePart = formatDashboardTaskTimeWindow(context, task);
  if (taskDay == tomorrow) {
    final tomorrowStr = 'common.tomorrow'.tr();
    return '$tomorrowStr $timePart';
  }
  final locale = context.locale.toString();
  return '${DateFormat('EEE d.M.', locale).format(localDue)} $timePart';
}

/// Sjednocená karta „Vyžaduje pozornost“ – zpožděné úkoly a nedoplatky v hotovosti.
/// Každý řádek je samostatně kliknutelný (úkoly → záložka Úkoly, nedoplatky → Finance).
class _NeedsAttentionCard extends StatelessWidget {
  const _NeedsAttentionCard({
    required this.tasks,
    required this.shortfallCount,
    required this.onTapTasks,
    required this.onTapShortfalls,
  });

  final List<TaskRow> tasks;
  final int shortfallCount;
  final VoidCallback? onTapTasks;
  final VoidCallback? onTapShortfalls;

  @override
  Widget build(BuildContext context) {
    final overdueCount = _countCriticalOrOverdue(tasks);

    return _dashboardPanel(context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: context.customColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'admin.dashboard_card_needs_attention'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _NeedsAttentionRow(
            icon: Icons.schedule,
            iconColor: context.customColors.warning,
            label: 'admin.dashboard_needs_attention_overdue'.tr(),
            value: overdueCount,
            valueColor: overdueCount > 0
                ? context.customColors.warning
                : context.colors.onSurfaceVariant,
            onTap: onTapTasks,
          ),
          const SizedBox(height: 8),
          _NeedsAttentionRow(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: context.colors.error,
            label: 'admin.dashboard_needs_attention_shortfalls'.tr(),
            value: shortfallCount,
            valueColor: shortfallCount > 0
                ? context.colors.error
                : context.colors.onSurfaceVariant,
            onTap: onTapShortfalls,
          ),
        ],
      ),
    );
  }
}

/// Jeden řádek v kartě Vyžaduje pozornost – ikona, název, hodnota vpravo; celý řádek kliknutelný.
class _NeedsAttentionRow extends StatelessWidget {
  const _NeedsAttentionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.colors.onSurface),
          ),
        ),
        Text(
          '$value',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: row,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: row,
    );
  }
}

/// Karta „Noví klienti v tomto měsíci“ – KPI z CRM.
///
/// PROČ: U manažera je důležité vidět trend leadů/klientů v čase.
/// Kliknutí přepíná na modul „Klienti“, kde může data rozkliknout detailně.
class _NewClientsThisMonthCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchToTab = AdminTabScope.of(context);
    final clientsAsync = ref.watch(newClientsThisMonthProvider);

    return _dashboardPanel(context,
      onTap: () => switchToTab?.call(adminTabIndexClients),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: clientsAsync.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.person_add_outlined,
                    size: 22, color: context.colors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'admin.dashboard_new_clients_card_title'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ),
        error: (e, st) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.person_add_outlined,
                    size: 22, color: context.colors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'admin.dashboard_new_clients_card_title'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'common.generic_error_user_friendly'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
            ),
          ],
        ),
        data: (s) {
          // PROČ: Když je v období 0 nových klientů, v UI nechceme
          // „rozpad“ breakdownu na několik řádků s nulami – ukážeme
          // uživatelsky srozumitelný empty state.
          final totalIsZero = s.totalNewClients == 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add_outlined,
                      size: 22, color: context.colors.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'admin.dashboard_new_clients_card_title'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (totalIsZero)
                Text(
                  'admin.dashboard_new_clients_empty'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                )
              else ...[
                Text(
                  '${s.totalNewClients}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (s.ownerNewClients > 0)
                      _NewClientTypeBadge(
                        text:
                            'admin.dashboard_new_clients_type_owner'.tr(
                          namedArgs: {'count': '${s.ownerNewClients}'},
                        ),
                        backgroundColor: context.colors.primaryContainer,
                        foregroundColor: context.colors.onPrimaryContainer,
                      ),
                    if (s.externalNewClients > 0)
                      _NewClientTypeBadge(
                        text:
                            'admin.dashboard_new_clients_type_external'.tr(
                          namedArgs: {'count': '${s.externalNewClients}'},
                        ),
                        backgroundColor: context.colors.secondaryContainer,
                        foregroundColor: context.colors.onSecondaryContainer,
                      ),
                    if (s.agencyNewClients > 0)
                      _NewClientTypeBadge(
                        text:
                            'admin.dashboard_new_clients_type_agency'.tr(
                          namedArgs: {'count': '${s.agencyNewClients}'},
                        ),
                        backgroundColor: context.colors.tertiaryContainer,
                        foregroundColor: context.colors.onTertiaryContainer,
                      ),
                    if (s.unknownNewClients > 0)
                      _NewClientTypeBadge(
                        text:
                            'admin.dashboard_new_clients_type_unknown'.tr(
                          namedArgs: {'count': '${s.unknownNewClients}'},
                        ),
                        backgroundColor: context.colors.surfaceContainerHighest,
                        foregroundColor: context.colors.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Kompaktní odznak typu klienta (breakdown) – vizuálně oddělený od dominantního součtu.
class _NewClientTypeBadge extends StatelessWidget {
  const _NewClientTypeBadge({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
        ),
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
    final isEmptyOrAllZeros =
        reservationsTrend.isEmpty || reservationsTrend.every((v) => v == 0);
    if (isEmptyOrAllZeros) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: premiumCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.dashboard_chart_reservations_14'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DashboardCompactEmptyState(
              icon: Icons.show_chart,
              title: 'admin.dashboard_chart_trend_no_data'.tr(),
            ),
          ],
        ),
      );
    }

    // Spread operátor – bezpečné doplnění nul k seznamům s pevnou délkou (fixed-length list).
    final trend = reservationsTrend.length >= 14
        ? reservationsTrend
        : [
            ...reservationsTrend,
            ...List.filled(14 - reservationsTrend.length, 0),
          ];
    final spots = trend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
    final maxVal = trend.reduce((a, b) => a > b ? a : b).toDouble();
    // Bezpečné meze: maxY musí být > minY, jinak fl_chart vyhodí render error
    final maxY = maxVal > 0 ? maxVal + 1 : 5.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.dashboard_chart_reservations_14'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: _kDashboardChartPlotHeight,
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
                    color: context.colors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          context.colors.primary.withValues(alpha: 0.35),
                          context.colors.primary.withValues(alpha: 0.0),
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
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 13) return const SizedBox.shrink();
                        final dayOffset = i - 7;
                        // PROČ: Znaménko a tvar popisku (např. "+X" vs. "-X")
                        // musí být lokalizovatelný, proto jej skládáme přes i18n klíče.
                        final label = dayOffset == 0
                            ? 'common.today'.tr()
                            : dayOffset > 0
                                ? 'admin.dashboard_chart_day_offset_plus'.tr(
                                    namedArgs: {'days': '$dayOffset'},
                                  )
                                : 'admin.dashboard_chart_day_offset_minus'.tr(
                                    namedArgs: {'days': '${-dayOffset}'},
                                  );
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            label,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
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

/// Paleta segmentů donut grafu z aktuálního tématu (PROČ: žádné natvrdo Material barvy).
List<Color> _chartCompositionPalette(BuildContext context) {
  final c = context.colors;
  final cc = context.customColors;
  return [
    c.tertiary,
    c.primary,
    cc.success,
    cc.warning,
    c.secondary,
    c.error,
    c.inversePrimary,
  ];
}

/// Prstencový graf – skladba dnešních úkolů nebo dalších 7 dní (Smart Fallback) s legendou.
class _TasksCompositionChart extends StatelessWidget {
  const _TasksCompositionChart({
    required this.tasksComposition,
    this.isUpcoming = false,
  });

  final Map<String, int> tasksComposition;
  final bool isUpcoming;

  String _titleKey(BuildContext context) => isUpcoming
      ? 'admin.dashboard_upcoming_composition'.tr()
      : 'admin.dashboard_chart_tasks_composition'.tr();

  @override
  Widget build(BuildContext context) {
    final entries = tasksComposition.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: premiumCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleKey(context),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DashboardCompactEmptyState(
              icon: Icons.pie_chart_outline,
              title: 'admin.dashboard_chart_no_data'.tr(),
            ),
          ],
        ),
      );
    }

    final palette = _chartCompositionPalette(context);
    final sections = entries.asMap().entries.map((e) {
      final idx = e.key % palette.length;
      final color = palette[idx];
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: color,
        radius: AppSpacing.xxl,
        title: '${e.value.value}',
        titleStyle: context.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: context.colors.surface,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleKey(context),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSpacing.lg * 9 + AppSpacing.sm,
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
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.onSurface,
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
                      final idx = e.key % palette.length;
                      final color = palette[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: AppSpacing.sm + AppSpacing.xs,
                              height: AppSpacing.sm + AppSpacing.xs,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.xs,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              // PROČ: Závorky a pořadí kategorie + počet mohou být v různých jazycích různé,
                              // proto je renderujeme přes i18n klíč.
                              child: Text(
                                'admin.dashboard_chart_legend_category_with_count'
                                    .tr(
                                  namedArgs: {
                                    'category': e.value.key.tr(),
                                    'count': '${e.value.value}',
                                  },
                                ),
                                style: context.textTheme.labelLarge?.copyWith(
                                  color: context.colors.onSurface,
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
    final hasWarnings =
        summary.pendingTasksCount > 0 ||
        summary.problemTasksCount > 0 ||
        summary.employeesWithCashCount > 0;

    if (!hasWarnings) {
      final greenPill = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.customColors.success.withValues(alpha: 0.85),
              context.customColors.success,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
          boxShadow: [
            BoxShadow(
              color: context.customColors.success.withValues(alpha: 0.35),
              blurRadius: AppSpacing.sm + AppSpacing.xs,
              offset: Offset(0, AppSpacing.xs),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: context.customColors.onSuccess,
                  size: AppSpacing.lg,
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Text(
                  'admin.dashboard_action_strip_all_clear'.tr(),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.customColors.onSuccess,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Align(alignment: Alignment.centerRight, child: greenPill);
          }
          return greenPill;
        },
      );
    }

    final cards = <Widget>[];
    final switchToTab = AdminTabScope.of(context);

    if (summary.pendingTasksCount > 0) {
      cards.add(
        _ActionCard(
          text: 'admin.dashboard_action_pending_proposals'.tr(
            namedArgs: {'count': '${summary.pendingTasksCount}'},
          ),
          gradient: LinearGradient(
            colors: [
              context.colors.primary.withValues(alpha: 0.88),
              context.colors.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.pending_actions,
          onTap: () => switchToTab?.call(adminTabIndexTasks),
        ),
      );
    }
    if (summary.problemTasksCount > 0) {
      cards.add(
        _ActionCard(
          text: 'admin.dashboard_action_problems'.tr(
            namedArgs: {'count': '${summary.problemTasksCount}'},
          ),
          gradient: LinearGradient(
            colors: [
              context.colors.error.withValues(alpha: 0.9),
              context.colors.error.withValues(alpha: 0.65),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.warning_amber_rounded,
          onTap: () => switchToTab?.call(adminTabIndexTasks),
        ),
      );
    }
    if (summary.employeesWithCashCount > 0) {
      final amountStr = summary.totalUncollectedCash.toStringAsFixed(1);
      cards.add(
        _ActionCard(
          text: 'admin.dashboard_action_cash_uncollected'.tr(
            namedArgs: {
              'amount': amountStr,
              'count': '${summary.employeesWithCashCount}',
            },
          ),
          gradient: LinearGradient(
            colors: [
              context.customColors.warning,
              context.customColors.warning.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.account_balance_wallet,
          onTap: () => switchToTab?.call(adminTabIndexFinance),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Wrap(
          alignment: isWide ? WrapAlignment.end : WrapAlignment.start,
          spacing: AppSpacing.sm + AppSpacing.xs,
          runSpacing: AppSpacing.sm + AppSpacing.xs,
          children: cards,
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
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.22),
            blurRadius: AppSpacing.sm + AppSpacing.xs,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: context.colors.surface, size: AppSpacing.lg),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Flexible(
                  child: Text(
                    text,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colors.surface,
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

/// Konsolidovaná karta komunikace + automatizací.
///
/// PROČ: Manažer řeší tyto metriky společně (pravidla, fronta, selhání,
/// objem zpráv, náklady). Jedna karta minimalizuje redundanci a zkracuje
/// cestu k nápravě.
class _CommunicationAndAutomationStatusCard extends ConsumerWidget {
  const _CommunicationAndAutomationStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchToTab = AdminTabScope.of(context);
    final automationAsync = ref.watch(automationSummaryProvider);
    final healthAsync = ref.watch(messagingHealthProvider);
    final failuresAsync = ref.watch(messagingFailuresProvider);

    void openAutomations({
      required bool showFailedQueue,
      required bool showFailedLog,
    }) {
      // PROČ: Přenos filtru do Automations zajišťuje, že uživatel po kliknutí
      // uvidí rovnou relevantní část modulu (bez ručního hledání).
      final preferredTab = showFailedQueue
          ? 1
          : showFailedLog
              ? 2
              : 0;
      ref.read(adminAutomationTabIndexProvider.notifier).state = preferredTab;
      ref.read(adminAutomationFilterProvider.notifier).state =
          AdminAutomationFilterState(
        preferredTabIndex: preferredTab,
        showFailedQueue: showFailedQueue,
        showFailedLog: showFailedLog,
      );
      switchToTab?.call(adminTabIndexAutomations);
    }

    if (automationAsync.isLoading ||
        healthAsync.isLoading ||
        failuresAsync.isLoading) {
      return _dashboardPanel(context,
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (automationAsync.hasError || healthAsync.hasError || failuresAsync.hasError) {
      if (kDebugMode) {
        debugPrint('Communication/Automation KPI error');
      }
      return _dashboardPanel(context,
        onTap: () => openAutomations(showFailedQueue: true, showFailedLog: true),
        padding: const EdgeInsets.all(16),
        child: Text(
          'common.generic_error_user_friendly'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.colors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final automation = automationAsync.valueOrNull;
    final health = healthAsync.valueOrNull;
    final failures = failuresAsync.valueOrNull;
    if (automation == null || health == null || failures == null) {
      return _dashboardPanel(context,
        padding: const EdgeInsets.all(16),
        child: Text(
          'common.generic_error_user_friendly'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.error,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }

    final hasFailure =
        automation.failedQueueCount > 0 || failures.failedLogCountLastDays > 0;

    return _dashboardPanel(context,
      onTap: () => openAutomations(
        showFailedQueue: automation.failedQueueCount > 0,
        showFailedLog: failures.failedLogCountLastDays > 0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub_outlined,
                size: 20,
                color: hasFailure ? context.colors.error : context.colors.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin.dashboard_communication_automation_status_title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mřížka 2×3 – rychlé skenování stejných metrik jako dříve (bez nových dat).
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AutomationMiniKpiTile(
                      icon: Icons.auto_awesome_outlined,
                      labelKey: 'admin.dashboard_automation_kpi_active_rules_label',
                      namedArgs: const {},
                      valueText: '${automation.activeRulesCount}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AutomationMiniKpiTile(
                      icon: Icons.hourglass_empty_outlined,
                      labelKey:
                          'admin.dashboard_automation_kpi_queue_scheduled_label',
                      namedArgs: const {},
                      valueText: '${automation.scheduledQueueCount}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AutomationMiniKpiTile(
                      icon: Icons.error_outline,
                      labelKey:
                          'admin.dashboard_automation_kpi_queue_failed_label',
                      namedArgs: const {},
                      valueText: '${automation.failedQueueCount}',
                      iconColor: automation.failedQueueCount > 0
                          ? context.colors.error
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AutomationMiniKpiTile(
                      icon: Icons.forum_outlined,
                      labelKey: 'admin.dashboard_messaging_health_sent_label',
                      namedArgs: const {},
                      valueText: '${health.sentMessagesThisMonth}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AutomationMiniKpiTile(
                      icon: Icons.euro_outlined,
                      labelKey: 'admin.dashboard_messaging_health_cost_label',
                      namedArgs: const {},
                      valueText:
                          health.estimatedCostEurThisMonth.toStringAsFixed(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AutomationMiniKpiTile(
                      icon: Icons.report_problem_outlined,
                      labelKey:
                          'admin.dashboard_messaging_failures_log_label',
                      namedArgs: {'days': '${failures.lastDays}'},
                      valueText: '${failures.failedLogCountLastDays}',
                      iconColor: failures.failedLogCountLastDays > 0
                          ? context.colors.error
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Jedna mini dlaždice v mřížce komunikace/automatizace – ikona, krátký popisek, číslo.
class _AutomationMiniKpiTile extends StatelessWidget {
  const _AutomationMiniKpiTile({
    required this.icon,
    required this.labelKey,
    required this.namedArgs,
    required this.valueText,
    this.iconColor,
  });

  final IconData icon;
  final String labelKey;
  final Map<String, String> namedArgs;
  final String valueText;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? c.tertiary),
          const SizedBox(height: 4),
          Text(
            labelKey.tr(namedArgs: namedArgs),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            valueText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: c.onSurface,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.dashboard_quick_actions'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
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
                    backgroundColor: context.colors.secondaryContainer,
                    foregroundColor: context.colors.onSecondaryContainer,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => switchToTab?.call(adminTabIndexFinance),
                  icon: const Icon(Icons.account_balance_wallet, size: 20),
                  label: Text('admin.dashboard_quick_finance_wallet'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.tertiaryContainer,
                    foregroundColor: context.colors.onTertiaryContainer,
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

/// KPI karta „Absence radar do budoucna“.
///
/// PROČ: Manažer potřebuje v jednom pohledu vidět, jestli v dalších dnech
/// budou některé osoby mimo provoz (schválené absence). Tím snížíme
/// riziko špatných plánů a následných nouzových přerozdělení úkolů.
class _AbsenceRadarCard extends ConsumerWidget {
  const _AbsenceRadarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchToTab = AdminTabScope.of(context);
    final upcomingAbsencesAsync = ref.watch(upcomingAbsencesProvider);
    final teamMembers = ref.watch(teamFullListProvider).valueOrNull ?? [];

    // PROČ: `profile_id` -> jméno je potřeba pro „kdo“ (ne jen „kolik“),
    // UI pak může zobrazit iniciály absentujících členů.
    final memberByProfileId = <String, TeamMember>{
      for (final m in teamMembers)
        if (m.profileId != null && m.profileId!.isNotEmpty) m.profileId!: m,
    };

    return _dashboardPanel(context,
      onTap: () => switchToTab?.call(adminTabIndexTeam),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 18,
                color: context.colors.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin.dashboard_absence_radar_title'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          upcomingAbsencesAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, st) {
              // PROČ: user-friendly error zabrání „white screen of death“,
              // zatímco technický detail logujeme pro diagnostiku.
              if (kDebugMode) {
                debugPrint('upcomingAbsencesProvider error: $e');
              }
              return Text(
                'common.generic_error_user_friendly'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.error,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
            data: (s) {
              final absentMembersCount = s.absentMemberProfileIds14Days.length;
              if (absentMembersCount == 0) {
                return _DashboardCompactEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'admin.dashboard_absence_radar_empty'.tr(),
                );
              }

              final absentIds = s.absentMemberProfileIds14Days;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'admin.dashboard_absence_radar_absences_14_label'.tr(
                            namedArgs: {
                              'count':
                                  '${s.approvedAbsencesCount14Days}',
                            },
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SizedBox(
                          height: 18,
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: context.colors.outlineVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'admin.dashboard_absence_radar_members_label'.tr(
                            namedArgs: {
                              'count': '$absentMembersCount',
                            },
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: absentIds
                        .take(4)
                        .map((pid) {
                          final member = memberByProfileId[pid];
                          final name = member?.name ?? '';
                          final initials = name.isNotEmpty
                              ? AdminDashboardScreen._initialsFromName(name)
                              : 'common.placeholder_dash'.tr();
                          return CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                context.colors.secondaryContainer,
                            child: Text(
                              initials,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: context.colors
                                        .onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Sekce „Dnešní externí služby“ nebo „Nejbližší externí služby“ (Smart Fallback).
class _ExternalTasksSection extends StatelessWidget {
  const _ExternalTasksSection({
    required this.externalTasks,
    required this.isUpcoming,
    required this.today,
  });

  final List<TaskRow> externalTasks;
  final bool isUpcoming;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUpcoming
                ? 'admin.dashboard_upcoming_external'.tr()
                : 'admin.dashboard_external_services'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
          ),
          const SizedBox(height: 10),
          if (externalTasks.isEmpty)
            _DashboardCompactEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'admin.dashboard_external_services_empty'.tr(),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < externalTasks.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: context.colors.outlineVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  Builder(
                    builder: (context) {
                      final t = externalTasks[i];
                      final dateTimeStr = isUpcoming
                          ? formatTaskDueForUpcoming(context, t, today)
                          : formatDashboardTaskTimeWindow(context, t);
                      final title = t.customTitle?.trim().isNotEmpty == true
                          ? t.customTitle!
                          : t.title.trim().isNotEmpty
                              ? t.title
                              : 'admin.task_no_title'.tr();
                      return InkWell(
                        onTap: () {
                          final switchToTab = AdminTabScope.of(context);
                          if (switchToTab != null) {
                            switchToTab(adminTabIndexTasks);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                TaskVisuals.getIconStatic(t.taskType),
                                size: AppSpacing.sm +
                                    AppSpacing.sm +
                                    AppSpacing.xs,
                                color: context.colors.primary,
                              ),
                              const SizedBox(
                                width: AppSpacing.sm + AppSpacing.xs,
                              ),
                              Expanded(
                                child: Text(
                                  '$title • $dateTimeStr',
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: context.colors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Sekce „Dnešní plán“ nebo „Nejbližší plán“ (Smart Fallback) – scrollovací timeline úkolů.
class _DashboardPlanSection extends StatelessWidget {
  const _DashboardPlanSection({
    required this.tasks,
    required this.isUpcoming,
    required this.today,
  });

  final List<TaskRow> tasks;
  final bool isUpcoming;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUpcoming
                ? 'admin.dashboard_upcoming_plan'.tr()
                : 'admin.dashboard_plan_today'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            _DashboardCompactEmptyState(
              icon: Icons.coffee_outlined,
              title: 'admin.dashboard_today_done_coffee'.tr(),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < tasks.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _DashboardPlanTaskTile(
                    task: tasks[index],
                    isUpcoming: isUpcoming,
                    today: today,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Jedna položka plánu – extrahováno kvůli čitelnosti po odstranění [ListView] s fixní výškou.
class _DashboardPlanTaskTile extends StatelessWidget {
  const _DashboardPlanTaskTile({
    required this.task,
    required this.isUpcoming,
    required this.today,
  });

  final TaskRow task;
  final bool isUpcoming;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final icon = TaskVisuals.getIconStatic(t.taskType);
    final bgColor = TaskVisuals.getBackgroundColorStatic(t.taskType);
    final iconColor = TaskVisuals.getBorderColorStatic(t.taskType);
    final timeWindowStr = formatDashboardTaskTimeWindow(context, t);
    final subtitleStr = isUpcoming
        ? formatTaskDueForUpcoming(context, t, today)
        : '${t.apartmentName ?? t.apartmentId} • $timeWindowStr';
    final hasAssignee =
        t.assignedToName != null && t.assignedToName!.trim().isNotEmpty;
    final canCommunicate = (t.reservationId?.trim().isNotEmpty ?? false) ||
        (t.clientId?.trim().isNotEmpty ?? false);
    final messageSent = t.lastCommunicationAt != null ||
        (t.lastCommunicationTemplateId?.trim().isNotEmpty ?? false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final switchToTab = AdminTabScope.of(context);
          if (switchToTab != null) {
            switchToTab(adminTabIndexTasks);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
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
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canCommunicate)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: messageSent
                        ? 'admin.dashboard_plan_message_sent'.tr()
                        : 'admin.dashboard_plan_message_missing'.tr(),
                    child: Icon(
                      messageSent
                          ? Icons.mark_chat_read
                          : Icons.mark_chat_unread,
                      size: 18,
                      color: messageSent
                          ? context.customColors.success
                          : context.customColors.warning,
                    ),
                  ),
                ),
              if (hasAssignee)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    radius: AppSpacing.sm + AppSpacing.xs,
                    backgroundColor: context.colors.tertiaryContainer,
                    child: Text(
                      AdminDashboardScreen._initialsFromName(
                        t.assignedToName!,
                      ),
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sekce „Kdo je dnes v akci“ nebo „Nejbližší směny“ (Smart Fallback) – avatary pracovníků s počtem úkolů.
class _TodaysTeamSection extends ConsumerWidget {
  const _TodaysTeamSection({
    required this.members,
    required this.displayTasks,
    required this.profileIdsWithCash,
    required this.isUpcoming,
  });

  final List<TeamMember> members;
  final List<TaskRow> displayTasks;
  final Set<String> profileIdsWithCash;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PROČ: Stejně jako u apartmánů chceme uživateli říct, když jsme se trefili na limit,
    // takže kompletní seznam týmu nemusí být k dispozici.
    final teamLimitReached = ref.watch(teamDataLimitReachedProvider);
    final showLimitWarning = teamLimitReached && members.isNotEmpty;

    int taskCountFor(TeamMember m) {
      return displayTasks
          .where(
            (t) =>
                (t.assignedTo == m.profileId || t.assignedTo == m.id) &&
                (t.assignedTo != null && t.assignedTo!.trim().isNotEmpty),
          )
          .length;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUpcoming
                ? 'admin.dashboard_upcoming_team'.tr()
                : 'admin.dashboard_todays_team'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (showLimitWarning)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'admin.dashboard_data_limit_reached_warning'.tr(
                  namedArgs: {'limit': '$teamFullListProviderLimit'},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.customColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (members.isEmpty)
            _DashboardCompactEmptyState(
              icon: Icons.groups_outlined,
              title: 'admin.dashboard_no_shift_today'.tr(),
            )
          else
            Wrap(
              spacing: AppSpacing.sm + AppSpacing.xs,
              runSpacing: AppSpacing.sm + AppSpacing.xs,
              children: members.map((m) {
                final count = taskCountFor(m);
                final profileId = m.profileId ?? m.id;
                final hasCash =
                    profileId.isNotEmpty &&
                    profileIdsWithCash.contains(profileId);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: AppSpacing.xxl - AppSpacing.xs,
                          height: AppSpacing.xxl - AppSpacing.xs,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.tertiaryContainer,
                            border: Border.all(
                              color: context.colors.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              AdminDashboardScreen._initialsFromName(m.name),
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ),
                        if (hasCash)
                          Positioned(
                            right: -AppSpacing.xs,
                            bottom: -AppSpacing.xs,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: context.customColors.warning,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.surface,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                size: AppSpacing.sm + AppSpacing.xs,
                                color: context.customColors.onWarning,
                              ),
                            ),
                          ),
                        if (count > 0)
                          Positioned(
                            right: -AppSpacing.xs,
                            top: -AppSpacing.xs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.error,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm + AppSpacing.xs,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.shadow.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: AppSpacing.xs,
                                    offset: Offset(0, AppSpacing.xs),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$count',
                                style: context.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.onError,
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
                          color: context.colors.onSurface,
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

/// Sekce „Stav apartmánů“ – celkový počet z flotily + dnešní provozní stavy (bez health KPI).
///
/// PROČ: Health check bez „N/A“ v DB matl uživatele; stačí rychlý přehled počtu a úklidů.
class _ApartmentFleetSection extends ConsumerWidget {
  const _ApartmentFleetSection({
    required this.totalApartments,
    required this.countClean,
    required this.countToClean,
    required this.countOccupied,
  });

  final int totalApartments;
  final int countClean;
  final int countToClean;
  final int countOccupied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchToTab = AdminTabScope.of(context);
    final apartmentsLimitReached = ref.watch(apartmentsDataLimitReachedProvider);
    final apartmentsEmpty = totalApartments == 0;

    void openApartments() => switchToTab?.call(adminTabIndexApartments);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: premiumCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.dashboard_apartment_fleet'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
          ),
          if (apartmentsLimitReached && !apartmentsEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                'admin.dashboard_data_limit_reached_warning'.tr(
                  namedArgs: {'limit': '$apartmentsFullListProviderLimit'},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.customColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (apartmentsEmpty)
            _DashboardCompactEmptyState(
              icon: Icons.apartment_outlined,
              title: 'admin.dashboard_no_apartments_in_fleet'.tr(),
            )
          else ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openApartments,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'admin.dashboard_apartments_count'.tr(
                      namedArgs: {'count': '$totalApartments'},
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.primary,
                        ),
                  ),
                ),
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
                    backgroundColor:
                        context.customColors.success.withValues(alpha: 0.12),
                    accentColor: context.customColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: _FleetStatusBlock(
                    count: countToClean,
                    labelKey: 'admin.dashboard_fleet_to_clean',
                    icon: Icons.cleaning_services_outlined,
                    backgroundColor:
                        context.customColors.warning.withValues(alpha: 0.12),
                    accentColor: context.customColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: _FleetStatusBlock(
                    count: countOccupied,
                    labelKey: 'admin.dashboard_fleet_occupied',
                    icon: Icons.people_outline,
                    backgroundColor: context.colors.primaryContainer
                        .withValues(alpha: 0.5),
                    accentColor: context.colors.primary,
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Icon(icon, size: AppSpacing.md + AppSpacing.xs, color: accentColor),
          const SizedBox(height: AppSpacing.xs),
          Text(
            labelText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
