import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/theme/app_palette_defaults.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/notification_provider.dart';
import 'package:falconest/core/providers/ui_mode_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/features/admin/admin_apartments_screen.dart';
import 'package:falconest/features/admin/admin_dashboard_screen.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/admin_team_screen.dart';
import 'package:falconest/features/admin/finance_dashboard_screen.dart';
import 'package:falconest/features/admin/screens/admin_map_dispatch_screen.dart';
import 'package:falconest/features/admin/screens/admin_clients_screen.dart';
import 'package:falconest/features/admin/screens/reports_screen.dart';
import 'package:falconest/features/admin/admin_automations_screen.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/communication/screens/communication_templates_screen.dart';
import 'package:falconest/features/calendar/screens/planning_calendar_screen.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/admin/widgets/client_detail_dialog.dart';
import 'package:falconest/features/admin/widgets/omnibox_dialog.dart';
import 'package:falconest/features/admin/providers/omnibox_search_provider.dart';
import 'package:falconest/features/settings/settings_screen.dart';
import 'package:falconest/core/widgets/lazy_indexed_stack.dart';

/// Práh šířky v pixelech – pod ním Drawer, nad ním permanentní Sidebar.
const double _breakpointWidth = 800;

/// Zobrazí dialog „Výkaz práce“ a po výběru uživatele ukončí převtělení a přesměruje do velína.
///
/// PROČ: Každé ukončení Magic Loginu má vyzvat k výkazu práce (audit, podklady pro provize).
/// „Ukončit bez poznámky“ = stop s null; „Uložit a ukončit“ = stop s textem.
Future<void> _showWorkReportDialogThenStop(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final report = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('admin.work_report_dialog_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'admin.work_report_dialog_prompt'.tr(),
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'admin.work_report_dialog_hint'.tr(),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text('admin.work_report_dialog_skip'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: Text('admin.work_report_dialog_save'.tr()),
        ),
      ],
    ),
  );
  controller.dispose();
  await ref.read(authNotifierProvider).stopImpersonating(workReport: report);
  if (context.mounted) context.go('/super-admin');
}

/// Indexy záložek v admin sekci – export pro dashboard (přepnutí na Rezervace/Úkoly).
const int adminTabIndexDashboard = 0;
const int adminTabIndexTeam = 1;
const int adminTabIndexApartments = 2;
const int adminTabIndexReservations = 3;
const int adminTabIndexTasks = 4;
const int adminTabIndexPlanningCalendar = 5;
const int adminTabIndexMap = 6;
const int adminTabIndexFinance = 7;
const int adminTabIndexReports = 8;
const int adminTabIndexClients = 9;
const int adminTabIndexCommunication = 10;
const int adminTabIndexAutomations = 11;

/// Intent pro globální zkratku Omniboxu (CMD/CTRL + K).
class _OpenAdminOmniboxIntent extends Intent {
  const _OpenAdminOmniboxIntent();
}

/// Umožňuje přepnutí záložky z vnořených obrazovek (např. z dashboardu po kliknutí na akci).
class AdminTabScope extends InheritedWidget {
  const AdminTabScope({
    super.key,
    required this.switchToTab,
    required super.child,
  });

  final void Function(int index) switchToTab;

  static void Function(int)? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminTabScope>()?.switchToTab;
  }

  @override
  bool updateShouldNotify(AdminTabScope oldWidget) =>
      oldWidget.switchToTab != switchToTab;
}

/// Responzivní layout pro admin sekci FalcoNest.
///
/// Používá [LazyIndexedStack] – podle [_selectedIndex] zobrazuje jednu z existujících
/// obrazovek: Nástěnka, Personál, Byty, Rezervace, Úkoly.
/// Na úzkých obrazovkách Drawer, na širokých stálý Sidebar.
class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = adminTabIndexDashboard;

  /// Stav kolapsu levého menu – true = zobrazeno, false = skryto (široký layout).
  bool _isSidebarOpen = true;

  /// Tělo obsahu – [LazyIndexedStack] mountuje obrazovku až při první návštěvě tabu;
  /// po načtení drží stav v paměti (scroll, formuláře) stejně jako původní IndexedStack.
  static final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminTeamScreen(),
    const AdminApartmentsScreen(),
    const AdminReservationsScreen(),
    const AdminTasksScreen(),
    const PlanningCalendarScreen(),
    const AdminMapDispatchScreen(),
    const FinanceDashboardScreen(),
    const ReportsScreen(),
    const AdminClientsScreen(),
    const CommunicationTemplatesScreen(),
    const AdminAutomationsScreen(),
  ];

  void _switchToTab(int index) {
    setState(() => _selectedIndex = index.clamp(0, _screens.length - 1));
  }

  /// Otevře Omnibox a po výběru výsledku přeskočí do správné sekce + detailu.
  ///
  /// PROČ: Admin navigace je `LazyIndexedStack` bez route per tab. Proto nejprve přepínáme
  /// tab a následně otevíráme existující detail dialog / editor nad danou sekcí.
  Future<void> _openOmnibox(BuildContext context, WidgetRef ref) async {
    final role = ref.read(authNotifierProvider).state.role;
    final canUseOmnibox = role == 'admin' || role == 'manager';
    if (!canUseOmnibox) return;

    ref.read(omniboxSearchQueryProvider.notifier).state = '';
    final selected = await showDialog<OmniboxSearchResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const OmniboxDialog(),
    );
    if (!context.mounted || selected == null) return;

    switch (selected.type) {
      case OmniboxEntityType.client:
        final client = selected.client;
        if (client == null) return;
        _switchToTab(adminTabIndexClients);
        await showDialog<void>(
          context: context,
          builder: (ctx) => ClientDetailDialog(client: client),
        );
        break;
      case OmniboxEntityType.apartment:
        final apartment = selected.apartment;
        if (apartment == null) return;
        _switchToTab(adminTabIndexApartments);
        showApartmentEditDialog(context, ref, apartment);
        break;
      case OmniboxEntityType.task:
        _switchToTab(adminTabIndexTasks);
        final task = await ref.read(taskByIdProvider(selected.id).future);
        if (task == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.omnibox_task_not_found'.tr())),
          );
          return;
        }
        if (!context.mounted) return;
        AdminTasksScreen.showEditTaskDialog(context, ref, task);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabScope(
      switchToTab: _switchToTab,
      child: Consumer(
        builder: (context, ref, _) {
          // PROČ: Křížová navigace z dialogů nastaví [adminTabJumpRequestProvider]; přepínáme záložku
          // až po frame, aby se [LazyIndexedStack] bezpečně přestavila po zavření overlay dialogu.
          ref.listen<int?>(adminTabJumpRequestProvider, (previous, next) {
            if (next != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  _switchToTab(next);
                  ref.read(adminTabJumpRequestProvider.notifier).state = null;
                }
              });
            }
          });
          final isImpersonating = ref.watch(
            authNotifierProvider.select((a) => a.state.isImpersonating),
          );
          final role = ref.watch(
            authNotifierProvider.select((a) => a.state.role),
          );
          final tenantIdForData = ref.watch(
            authNotifierProvider.select((a) => a.tenantIdForData),
          );
          // Super Admin a Account Manager smí na /admin jen s vybranou agenturou (převtělení) – jinak na velín.
          if ((role == 'super_admin' || role == 'account_manager') &&
              tenantIdForData == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/super-admin');
            });
            return const Center(child: CircularProgressIndicator());
          }
          final tenantNameAsync = ref.watch(currentTenantNameProvider);
          final tenantName = tenantNameAsync.valueOrNull ?? '';
          final announcementAsync = ref.watch(currentTenantAnnouncementProvider);
          final announcement = announcementAsync.valueOrNull;
          // Drží stav tenanta včetně Realtime – aby se provider budoval a naslouchal změnám.
          ref.watch(currentTenantWithRealtimeProvider);
          // Okamžitý vyhazovač: když je tenant vypnut (is_active == false) a nejde o převtělení.
          ref.listen<AsyncValue<CurrentTenantDetail?>>(
            currentTenantWithRealtimeProvider,
            (previous, next) {
              final tenant = next.valueOrNull;
              if (tenant != null &&
                  tenant.isActive == false &&
                  !isImpersonating &&
                  context.mounted) {
                context.go('/suspended');
              }
            },
          );
          return Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.keyK, meta: true): _OpenAdminOmniboxIntent(),
              SingleActivator(LogicalKeyboardKey.keyK, control: true): _OpenAdminOmniboxIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _OpenAdminOmniboxIntent: CallbackAction<_OpenAdminOmniboxIntent>(
                  onInvoke: (intent) {
                    _openOmnibox(context, ref);
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= _breakpointWidth;
                    final body = isWide
                        ? _WideLayout(
                            isSidebarOpen: _isSidebarOpen,
                            onSidebarToggle: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                            selectedIndex: _selectedIndex,
                            onIndexChanged: (i) => setState(() => _selectedIndex = i),
                            body: LazyIndexedStack(
                              index: _selectedIndex.clamp(0, _screens.length - 1),
                              children: _screens,
                            ),
                          )
                        : _NarrowLayout(
                            selectedIndex: _selectedIndex,
                            onIndexChanged: (i) => setState(() => _selectedIndex = i),
                            body: LazyIndexedStack(
                              index: _selectedIndex.clamp(0, _screens.length - 1),
                              children: _screens,
                            ),
                          );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isImpersonating)
                          _ImpersonationBanner(
                            tenantName: tenantName,
                            onStop: () => _showWorkReportDialogThenStop(context, ref),
                          ),
                        if (announcement != null && announcement.isNotEmpty)
                          _SystemAnnouncementBanner(message: announcement),
                        Expanded(
                          child: SafeArea(
                            top: false,
                            child: body,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Varovný pruh režimu převtělení – zobrazuje se ÚPLNĚ NAHOŘE, nesmí mizet při scrollování.
/// Pozadí výrazné (deepOrange), text bílý, název agentury tučně.
class _ImpersonationBanner extends StatelessWidget {
  const _ImpersonationBanner({
    required this.tenantName,
    required this.onStop,
  });

  final String tenantName;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final template = 'admin.impersonation_agency'.tr();
    const placeholder = '{name}';
    final idx = template.indexOf(placeholder);
    /// Barva výstržného pruhu z [CustomColors.warning] – konzistentní s DS, text [onWarning].
    final cc = context.customColors;
    final bannerFg = cc.onWarning;
    final bodyStyle = context.textTheme.titleSmall?.copyWith(
      color: bannerFg,
      fontWeight: FontWeight.w600,
    );
    Widget textWidget;
    if (idx >= 0) {
      final before = template.substring(0, idx);
      final after = template.substring(idx + placeholder.length);
      textWidget = Text.rich(
        TextSpan(
          style: bodyStyle,
          children: [
            TextSpan(text: before),
            TextSpan(
              text: tenantName.isNotEmpty ? tenantName : '…',
              style: bodyStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: after),
          ],
        ),
      );
    } else {
      textWidget = Text(
        tenantName.isNotEmpty
            ? template.replaceAll(placeholder, tenantName)
            : template,
        style: bodyStyle,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: cc.warning,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(child: textWidget),
            SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: bannerFg,
                side: BorderSide(color: bannerFg),
              ),
              child: Text('admin.impersonation_stop'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zvoneček s Badge – rozbalovací dropdown s nepřečtenými notifikacemi.
///
/// PROČ: showGeneralDialog místo showMenu – vyhnutí se layout konfliktům (Flexible+shrinkWrap)
/// a nekonečné smyčce. Dialog s průhledným pozadím, zarovnaný vpravo nahoře.
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final notifications = unreadAsync.valueOrNull ?? [];
    final count = notifications.length;

    Widget icon = const Icon(Icons.notifications_none_outlined);
    if (count > 0) {
      icon = Badge(
        backgroundColor: context.colors.error,
        label: Text(
          count > 99 ? '99+' : count.toString(),
          style: context.textTheme.labelSmall?.copyWith(color: context.colors.onError),
        ),
        child: icon,
      );
    }

    return IconButton(
      icon: icon,
      onPressed: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Notifications',
          // Průhledná bariéra: plný průhled (Colors.transparent není v ColorScheme).
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) {
            return Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 60, right: 24),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
                    child: _NotificationsDropdownContent(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.05),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
        );
      },
      tooltip: 'admin.topbar_notifications'.tr(),
    );
  }
}

/// Obsah rozbalovacího menu notifikací – hlavička + seznam.
///
/// PROČ: Column(min) + Flexible + ListView(shrinkWrap) – bezpečná kombinace pro showGeneralDialog.
/// Položky inline (Row+InkWell), žádný separátní _NotificationTile kvůli layout stabilitě.
class _NotificationsDropdownContent extends ConsumerWidget {
  const _NotificationsDropdownContent({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final list = unreadAsync.valueOrNull ?? [];
    final repository = ref.read(notificationRepositoryProvider);
    final profileId = ref.read(authNotifierProvider).state.profileId;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'admin.notifications_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                ),
              ),
              if (list.isNotEmpty && profileId != null)
                TextButton(
                  onPressed: () async {
                    await repository.markAllAsRead(profileId, tenantId);
                    if (context.mounted) onClose();
                  },
                  child: Text('admin.notifications_mark_all_read'.tr()),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: unreadAsync.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'admin.notifications_empty'.tr(),
                          style: TextStyle(color: context.colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final n = list[index];
                        final timeStr = n.createdAt != null
                            ? DateFormat('d.M. HH:mm', context.locale.languageCode)
                                .format(n.createdAt!.toLocal())
                            : 'admin.general.dash_placeholder'.tr();

                        IconData iconType = Icons.notifications_outlined;
                        Color iconColor = Theme.of(context).colorScheme.primary;
                        if (n.type == 'finance') {
                          iconType = Icons.account_balance_wallet_outlined;
                          iconColor = context.customColors.success;
                        } else if (n.type == 'finance_shortfall') {
                          iconType = Icons.warning_amber_rounded;
                          iconColor = context.colors.error;
                        } else if (n.type == 'system') {
                          iconType = Icons.info_outline;
                        } else if (n.type == 'daily_summary') {
                          iconType = Icons.wb_sunny_outlined;
                        } else if (n.type == 'task' ||
                            n.type == 'new_task' ||
                            n.type == 'template_reminder' ||
                            n.type == 'upcoming_task') {
                          iconType = Icons.task_alt_outlined;
                        } else if (n.type == 'absence') {
                          iconType = Icons.event_busy;
                          iconColor = context.customColors.warning;
                        }

                        return Material(
                          color: n.isRead ? Colors.transparent : context.colors.primaryContainer.withValues(alpha: 0.5),
                          child: InkWell(
                            onTap: () async {
                              await repository.markAsRead(n.id, tenantId);
                              if (context.mounted) {
                                if (n.type == 'new_task' ||
                                    n.type == 'template_reminder' ||
                                    n.type == 'upcoming_task') {
                                  final taskId =
                                      n.metadata?['task_id']?.toString().trim();
                                  if (taskId != null && taskId.isNotEmpty) {
                                    context.go('/worker/task/$taskId');
                                  }
                                } else if (n.type == 'daily_summary') {
                                  final taskId =
                                      n.metadata?['task_id']?.toString().trim();
                                  if (taskId != null && taskId.isNotEmpty) {
                                    context.go('/worker/task/$taskId');
                                  } else {
                                    AdminTabScope.of(context)?.call(adminTabIndexTasks);
                                  }
                                } else if (n.type == 'absence') {
                                  AdminTabScope.of(context)?.call(adminTabIndexTeam);
                                } else if (n.type == 'finance_shortfall') {
                                  AdminTabScope.of(context)?.call(adminTabIndexFinance);
                                }
                                onClose();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(iconType, color: iconColor, size: 24),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        // Nedoplatek: title/message jsou i18n klíč a "amount|reason".
                                        String displayTitle = n.title;
                                        String displayMessage = n.message;
                                        if (n.type == 'finance_shortfall') {
                                          displayTitle = n.title.tr();
                                          final parts = n.message.split('|');
                                          final amount = parts.isNotEmpty ? parts[0].trim() : 'common.placeholder_dash'.tr();
                                          final reason = parts.length > 1 ? parts[1].trim() : 'common.placeholder_dash'.tr();
                                          displayMessage = 'admin.notification_cash_shortfall_message'.tr(
                                            namedArgs: {'amount': amount, 'reason': reason},
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayTitle,
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                    fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold,
                                                  ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (displayMessage.isNotEmpty) ...[
                                              SizedBox(height: AppSpacing.xs),
                                              Text(
                                                displayMessage,
                                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                      color: context.colors.onSurfaceVariant,
                                                    ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            SizedBox(height: AppSpacing.xs),
                                            Text(
                                              timeStr,
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: context.colors.outline,
                                                  ),
                                            ),
                                          ],
                                        );
                                      },
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
    );
  }
}

/// Globální Top Bar (header) – hamburger pro sidebar, ikony kalendář/notifikace, profil s PopupMenu.
class _AdminTopBar extends ConsumerWidget {
  const _AdminTopBar({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(
      authNotifierProvider.select((a) => a.state.role),
    );
    final isImpersonating = ref.watch(
      authNotifierProvider.select((a) => a.state.isImpersonating),
    );
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;

    final displayName = (profile?.name ?? '').trim().isNotEmpty
        ? profile!.name
        : (profile?.email ?? '').split('@').first;
    final initials = _initials(displayName, profile?.email ?? '');

    final roleLabel = _roleLabel(context, role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuTap,
              tooltip: 'admin.topbar_menu'.tr(),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () {
                AdminTabScope.of(context)?.call(adminTabIndexPlanningCalendar);
              },
              tooltip: 'admin.topbar_calendar'.tr(),
            ),
            _NotificationsBell(),
            SizedBox(width: AppSpacing.sm),
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        initials,
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : 'common.placeholder_dash'.tr(),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          roleLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Icon(Icons.arrow_drop_down, color: context.colors.onSurfaceVariant),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'switch_mobile',
                  child: Row(
                    children: [
                      Icon(Icons.smartphone, size: 20, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text('common.switch_to_mobile'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text('settings.menu_settings'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: isImpersonating ? 'back' : 'logout',
                  child: Row(
                    children: [
                      Icon(
                        isImpersonating ? Icons.arrow_back : Icons.logout,
                        size: 20,
                        color: isImpersonating
                            ? context.customColors.warning
                            : context.colors.error,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        isImpersonating
                            ? 'admin.back_to_command_center'.tr()
                            : 'admin.menu_logout'.tr(),
                        style: TextStyle(
                          color: isImpersonating
                              ? context.customColors.warning
                              : context.colors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'switch_mobile') {
                  await ref.read(uiModeNotifierProvider).setMode(AdminUiMode.forceMobile);
                } else if (value == 'settings') {
                  SettingsModal.show(context);
                } else if (value == 'back') {
                  await _showWorkReportDialogThenStop(context, ref);
                } else if (value == 'logout') {
                  await SupabaseService.client.auth.signOut();
                  if (context.mounted) context.go('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name, String email) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final a = parts.first.isNotEmpty ? parts.first[0] : '';
        final b = parts.last.isNotEmpty ? parts.last[0] : '';
        return '${a.toUpperCase()}${b.toUpperCase()}';
      }
      return name.substring(0, 1).toUpperCase();
    }
    if (email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  String _roleLabel(BuildContext context, String? role) {
    if (role == null || role.isEmpty) return 'settings.profile_tenant_none'.tr();
    final key = 'settings.profile_role_${role.toLowerCase()}';
    final translated = key.tr();
    return translated != key ? translated : role;
  }
}

/// Pruh s oznámením systému (Megafon) – modré pozadí, bílý text, ikona campaign.
class _SystemAnnouncementBanner extends StatelessWidget {
  const _SystemAnnouncementBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = 'admin.system_announcement_label'.tr(namedArgs: {'message': message});
    final cs = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: cs.primary,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.campaign, color: cs.onPrimary, size: 24),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: context.textTheme.titleSmall?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout pro široké obrazovky – Sidebar (skrývání) + Top Bar + IndexedStack s obsahem.
class _WideLayout extends ConsumerWidget {
  const _WideLayout({
    required this.isSidebarOpen,
    required this.onSidebarToggle,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.body,
  });

  final bool isSidebarOpen;
  final VoidCallback onSidebarToggle;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          if (isSidebarOpen)
            _AdminSidebar(
              isDrawer: false,
              selectedIndex: selectedIndex,
              onIndexChanged: onIndexChanged,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminTopBar(
                  onMenuTap: onSidebarToggle,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout pro úzké obrazovky – AppBar s hamburgerem + Drawer.
class _NarrowLayout extends ConsumerWidget {
  const _NarrowLayout({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isImpersonating = ref.watch(
      authNotifierProvider.select((a) => a.state.isImpersonating),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('admin.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'settings.menu_settings'.tr(),
            onPressed: () => SettingsModal.show(context),
          ),
          IconButton(
            icon: Icon(isImpersonating ? Icons.arrow_back : Icons.logout),
            tooltip: isImpersonating
                ? 'admin.back_to_command_center'.tr()
                : 'admin.menu_logout'.tr(),
            onPressed: () async {
              if (isImpersonating) {
                await _showWorkReportDialogThenStop(context, ref);
              } else {
                await SupabaseService.client.auth.signOut();
                if (context.mounted) context.go('/');
              }
            },
          ),
        ],
      ),
      // Pozadí draweru = [AppPaletteDefaults.sidebarBackground] (ne globální surface – karty zůstávají bílé).
      drawer: Drawer(
        backgroundColor: AppPaletteDefaults.sidebarBackground,
        child: _AdminSidebar(
          isDrawer: true,
          selectedIndex: selectedIndex,
          onIndexChanged: onIndexChanged,
        ),
      ),
      body: body,
    );
  }
}

/// Postranní panel s menu – položky z katalogu modulů (SaaS menu).
/// Aktivní moduly jsou klikatelné, neaktivní zobrazeny jako zamčené (🔒) s toastem.
class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.isDrawer,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final bool isDrawer;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(allModulesProvider);
    final activeKeysAsync = ref.watch(activeModuleKeysProvider);
    final isSuperAdmin = ref.watch(
          authNotifierProvider.select((a) => a.state.role),
        ) ==
        'super_admin';
    final activeKeys = activeKeysAsync.valueOrNull ?? {};
    final rawModules = modulesAsync.valueOrNull;
    final allModules = (rawModules == null || rawModules.isEmpty)
        ? _fallbackModules()
        : rawModules;
    final financeActive = isModuleActive(ref, 'finance');
    final reportsActive = isModuleActive(ref, 'reports');
    final visibleModules = allModules.where((m) {
      if (!m.showInMenu) return false;
      if (m.key == 'finance' && !financeActive) return false;
      if (m.key == 'reports' && !reportsActive) return false;
      return true;
    }).toList();

    final tenantName = ref.watch(currentTenantNameProvider).valueOrNull ?? '';
    final headerTitle = tenantName.trim().isNotEmpty ? tenantName : 'admin.title'.tr();
    /// PROČ: Tmavé brandové pozadí [AppPaletteDefaults.sidebarBackground] vyžaduje světlý text – aktivní [Colors.white],
    /// neaktivní [Colors.white70]; nedotýkáme se globálního color schématu aplikace.
    const sidebarFg = Colors.white;
    const sidebarMuted = Colors.white70;
    final sidebarDivider = Colors.white.withValues(alpha: 0.22);

    return SafeArea(
      child: Container(
        width: 240,
        color: AppPaletteDefaults.sidebarBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hlavička: ikona v „dlaždici“ + název agentury – vizuální kotva brandu (Linear/Vercel styl).
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: const Icon(Icons.layers_rounded, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: sidebarFg,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'admin.sidebar_powered_by'.tr(),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: sidebarMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: sidebarDivider, height: 32),
            if (modulesAsync.isLoading)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: visibleModules.map((module) {
                    final tenantHasModule = activeKeys.contains(module.key);
                    final isActive = isSuperAdmin || tenantHasModule;
                    final isGhost = isSuperAdmin && !tenantHasModule;
                    final tabIndex = ModuleIconMapper.getTabIndex(module.key);
                    final label = ModuleIconMapper.getLabelKey(module.key).tr();
                    return _ModuleNavItem(
                      module: module,
                      label: label,
                      isActive: isActive,
                      isGhost: isGhost,
                      selectedIndex: selectedIndex,
                      isDrawer: isDrawer,
                      sidebarFg: sidebarFg,
                      sidebarMuted: sidebarMuted,
                      onTapActive: () {
                        if (isDrawer && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                          Navigator.of(context).pop();
                        }
                        if (tabIndex != null) {
                          onIndexChanged(tabIndex.clamp(0, adminTabIndexAutomations));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$label – ${'admin.module_coming_soon'.tr()}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      onTapLocked: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('admin.module_locked_toast'.tr(namedArgs: {'name': label})),
                            backgroundColor: context.customColors.warning,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            // Přepínač na mobilní zobrazení – dostupný v Sidebar i Drawer (úzké obrazovky).
            Divider(color: sidebarDivider, height: 1),
            ListTile(
              leading: const Icon(Icons.smartphone, size: 20, color: Colors.white70),
              title: Text(
                'common.switch_to_mobile'.tr(),
                style: context.textTheme.bodyMedium?.copyWith(color: sidebarFg),
              ),
              onTap: () async {
                if (isDrawer && context.mounted && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                  Navigator.of(context).pop();
                }
                await ref.read(uiModeNotifierProvider).setMode(AdminUiMode.forceMobile);
              },
            ),
          ],
        ),
      ),
    );
  }

  static List<ModuleModel> _fallbackModules() {
    const keys = ['dashboard', 'staff', 'apartments', 'reservations', 'tasks'];
    return [for (var i = 0; i < keys.length; i++) ModuleModel(id: keys[i], key: keys[i], name: keys[i], sortOrder: i)];
  }
}

/// Jedna položka menu modulu – aktivní (klikatelná), „ghost“ (jen pro admina), nebo zamčená (šedá + 🔒).
/// PROČ: Na tmavě modrém sidebaru je aktivní řádek jemně zvýrazněný bílou průhledností; text/ikony plně bílé
/// u výběru a [Colors.white70] u ostatních klikatelných položek – čitelnost bez změny globálního tématu.
class _ModuleNavItem extends StatelessWidget {
  const _ModuleNavItem({
    required this.module,
    required this.label,
    required this.isActive,
    required this.isGhost,
    required this.selectedIndex,
    required this.isDrawer,
    required this.sidebarFg,
    required this.sidebarMuted,
    required this.onTapActive,
    required this.onTapLocked,
  });

  final ModuleModel module;
  final String label;
  final bool isActive;
  final bool isGhost;
  final int selectedIndex;
  final bool isDrawer;
  final Color sidebarFg;
  final Color sidebarMuted;
  final VoidCallback onTapActive;
  final VoidCallback onTapLocked;

  @override
  Widget build(BuildContext context) {
    final tabIndex = ModuleIconMapper.getTabIndex(module.key);
    final selected = isActive && tabIndex != null && tabIndex == selectedIndex;
    final icon = ModuleIconMapper.getIcon(module.key);
    final normalColor = sidebarMuted;
    final selectedColor = sidebarFg;
    final ghostColor = context.customColors.warning;
    final lockedColor = Colors.white.withValues(alpha: 0.38);

    if (isActive) {
      final textColor = isGhost ? ghostColor : (selected ? selectedColor : normalColor);
      final iconColor = isGhost ? ghostColor : (selected ? selectedColor : normalColor);
      final titleWidget = Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isGhost)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.visibility_off, size: 14, color: ghostColor),
            ),
        ],
      );
      final tile = ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(icon, color: iconColor, size: 22),
        title: titleWidget,
        onTap: onTapActive,
      );
      final wrapped = isGhost
          ? Tooltip(
              message: 'admin.module_ghost_tooltip'.tr(),
              child: tile,
            )
          : tile;
      if (selected && !isGhost) {
        // Aktivní řádek: jemné bílé „sklo“ na brandovém modrém pozadí sidebaru; text/ikony zůstávají plně bílé.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: wrapped,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        child: wrapped,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(icon, color: lockedColor, size: 22),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.textTheme.titleSmall?.copyWith(color: lockedColor),
              ),
            ),
            Icon(Icons.lock_outline, size: 16, color: lockedColor),
          ],
        ),
        onTap: onTapLocked,
      ),
    );
  }
}
