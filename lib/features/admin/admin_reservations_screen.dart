import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';
import 'package:falconest/features/admin/providers/admin_reservations_repository.dart';
import 'package:falconest/features/admin/admin_reservation_forms.dart';
import 'package:falconest/features/admin/admin_reservation_utils.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/utils/download_helper/download_helper.dart';
import 'package:falconest/core/utils/read_file_bytes/read_file_bytes.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/features/admin/services/reservation_import_service.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';
import 'package:falconest/utils/task_visuals.dart';
import 'package:url_launcher/url_launcher.dart';

/// Obal karty rezervace (Kanban / případný seznam) – stejný vzor jako úkoly ([premiumCardDecoration]).
Widget _reservationPremiumCardShell({
  required BuildContext context,
  VoidCallback? onTap,
  required Widget child,
}) {
  final radius = BorderRadius.circular(AppSpacing.md);
  final deco = premiumCardDecoration(context);
  return ClipRRect(
    borderRadius: radius,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: deco,
          child: child,
        ),
      ),
    ),
  );
}

/// Barva Chipu / štítku podle životního cyklu – z [ColorScheme] a [CustomColors].
Color reservationStatusColor(BuildContext context, String status) {
  final cs = context.colors;
  final cc = context.customColors;
  switch (status) {
    case 'new':
      return cs.primary;
    case 'confirmed':
      return cc.success;
    case 'checked_in':
      return cs.tertiary;
    case 'checked_out':
      return cs.surfaceContainerHighest;
    case 'cancelled':
      return cs.error;
    default:
      return cs.primary;
  }
}

/// Barva popředí textu na chipu se sémantickým pozadím [reservationStatusColor].
Color _statusChipForegroundColor(BuildContext context, String status) {
  final cs = context.colors;
  final cc = context.customColors;
  switch (status) {
    case 'new':
      return cs.onPrimary;
    case 'confirmed':
      return cc.onSuccess;
    case 'checked_in':
      return cs.onTertiary;
    case 'checked_out':
      return cs.onSurface;
    case 'cancelled':
      return cs.onError;
    default:
      return cs.onPrimary;
  }
}

/// Pastelové pozadí bloků rezervace na Plachtě – kontejnerové / blend barvy z tématu.
Color _timelineBlockColor(BuildContext context, String status) {
  final cs = context.colors;
  final cc = context.customColors;
  switch (status) {
    case 'new':
      return cs.primaryContainer;
    case 'confirmed':
      return Color.alphaBlend(cc.success.withValues(alpha: 0.2), cs.surface);
    case 'checked_in':
      return Color.alphaBlend(cc.warning.withValues(alpha: 0.22), cs.surface);
    case 'checked_out':
      return cs.surfaceContainerHighest;
    case 'cancelled':
      return cs.errorContainer;
    default:
      return cs.tertiaryContainer;
  }
}

/// Legenda Plachty – dvojice (pozadí, text) pro konzistentní kontrast.
(Color bg, Color fg) _legendPillColors(BuildContext context, String status) {
  final cs = context.colors;
  final cc = context.customColors;
  switch (status) {
    case 'new':
      return (cs.primaryContainer, cs.onPrimaryContainer);
    case 'confirmed':
      return (
        Color.alphaBlend(cc.success.withValues(alpha: 0.2), cs.surface),
        cc.success,
      );
    case 'checked_in':
      return (
        Color.alphaBlend(cc.warning.withValues(alpha: 0.22), cs.surface),
        cc.warning,
      );
    case 'checked_out':
      return (cs.surfaceContainerHighest, cs.onSurfaceVariant);
    case 'cancelled':
      return (cs.errorContainer, cs.onErrorContainer);
    default:
      return (cs.tertiaryContainer, cs.onTertiaryContainer);
  }
}

/// Administrativní správa rezervací – stejným designovým jazykem jako Apartmány.
///
/// Top Bar: titulek, vyhledávání, tlačítko Přidat.
/// ListView kart s rezervacemi – host, termín, apartmán, štítek transferu.
class AdminReservationsScreen extends ConsumerStatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  ConsumerState<AdminReservationsScreen> createState() =>
      _AdminReservationsScreenState();

  /// Veřejná metoda pro otevření dialogu přidání rezervace.
  /// [initialApartmentId] – předvyplní apartmán (např. z kontextu Detailu klienta-majitele).
  static void showAddReservationDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialApartmentId,
    String? initialCheckIn,
    VoidCallback? onSaved,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AddReservationDialog(
        ref: ref,
        onSaved: onSaved ?? () => ref.invalidate(adminReservationsProvider),
        initialApartmentId: initialApartmentId,
        initialCheckIn: initialCheckIn,
      ),
    );
  }

  /// Veřejná metoda pro otevření dialogu úpravy rezervace.
  /// Voláno např. z kontextu úkolu (odkaz na rezervaci v task editoru).
  static void showEditReservationDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationRow reservation, {
    VoidCallback? onSaved,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditReservationDialog(
        ref: ref,
        reservation: reservation,
        onSaved: onSaved ?? () => ref.invalidate(adminReservationsProvider),
      ),
    );
  }
}

class _AdminReservationsScreenState extends ConsumerState<AdminReservationsScreen> {
  final _searchController = TextEditingController();
  late DateTime _timelineVisibleStartDate;

  @override
  void initState() {
    super.initState();
    // Plachta výchozí pohled: vždy 1. den aktuálního měsíce (měsíční zobrazení).
    final now = DateTime.now();
    _timelineVisibleStartDate = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PROČ: Po křížové navigaci z úkolu otevřeme stejný dialog úpravy rezervace jako z řádku v seznamu.
    ref.listen<AdminCrossNavPending>(adminCrossNavPendingProvider, (previous, next) {
      final id = next.reservationId;
      if (id == null || id.isEmpty) return;
      final list = ref.read(adminReservationsProvider).valueOrNull;
      ReservationRow? row;
      if (list != null) {
        for (final r in list) {
          if (r.id == id) {
            row = r;
            break;
          }
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(adminCrossNavPendingProvider.notifier).clear();
        if (row != null) {
          _showEditDialog(context, ref, row);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.cross_nav_reservation_not_found'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    });
    // PROČ select: při realtime změně rezervace zůstane fáze „data“ – horní lišta a záložky se nepřestavují celé.
    final loadPhase = ref.watch(
      adminReservationsProvider.select((async) {
        if (async.isLoading) return 0;
        if (async.hasError) return 1;
        return 2;
      }),
    );

    if (loadPhase == 0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loadPhase == 1) {
      final err = ref.read(adminReservationsProvider).error;
      if (kDebugMode) debugPrint('adminReservationsProvider error: $err');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: AppSpacing.xxl, color: context.colors.error),
              SizedBox(height: AppSpacing.md),
              Text(
                'admin.reservations_load_error'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(color: context.colors.error),
              ),
              SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(adminReservationsProvider),
                child: Text('admin.tasks_retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopActionBar(
              searchController: _searchController,
              onSearchChanged: () {
                ref.read(kanbanReservationsSearchQueryProvider.notifier).state =
                    _searchController.text.trim().toLowerCase();
              },
              onAdd: () => _showAddDialog(context, ref),
              onDownloadTemplate: () => _downloadCsvTemplate(context),
              onImportCsv: () => _importCsv(context, ref),
            ),
            Material(
              color: context.colors.surface,
              child: TabBar(
                labelColor: context.colors.primary,
                unselectedLabelColor: context.colors.onSurfaceVariant,
                indicatorColor: context.colors.primary,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.calendar_month, size: 20),
                    text: 'admin.reservations_tab_timeline'.tr(),
                  ),
                  Tab(
                    icon: const Icon(Icons.list, size: 20),
                    text: 'admin.reservations_tab_list'.tr(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: ReservationTimeline(
                      visibleStartDate: _timelineVisibleStartDate,
                      onPrevious: () => setState(() {
                        _timelineVisibleStartDate = DateTime(
                          _timelineVisibleStartDate.year,
                          _timelineVisibleStartDate.month - 1,
                          1,
                        );
                      }),
                      onToday: () {
                        final now = DateTime.now();
                        setState(() {
                          _timelineVisibleStartDate = DateTime(now.year, now.month, 1);
                        });
                      },
                      onNext: () => setState(() {
                        _timelineVisibleStartDate = DateTime(
                          _timelineVisibleStartDate.year,
                          _timelineVisibleStartDate.month + 1,
                          1,
                        );
                      }),
                      onReservationTap: (r) => _showEditDialog(context, ref, r),
                      onReservationWhatsApp: (r) => _openWhatsAppForReservation(context, r),
                      onEmptyCellTap: (apartmentId, date) {
                        final d = date;
                        final checkInStr =
                            '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
                        _showAddDialog(
                          context,
                          ref,
                          initialApartmentId: apartmentId,
                          initialCheckIn: checkInStr,
                        );
                      },
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final hasVisible = ref.watch(kanbanHasVisibleReservationsProvider);
                      final qEmpty = ref.watch(kanbanReservationsSearchQueryProvider).isEmpty;
                      if (!hasVisible) {
                        return Center(
                          child: AppEmptyState(
                            icon: Icons.event_available_outlined,
                            title: qEmpty
                                ? 'admin.reservations_empty'.tr()
                                : 'admin.reservations_search_no_results'.tr(),
                            subtitle: qEmpty
                                ? null
                                : 'admin.general.search_empty_subtitle'.tr(),
                          ),
                        );
                      }
                      return _ReservationsKanbanBoard(
                        onEdit: (r) => _showEditDialog(context, ref, r),
                        onDelete: (r) => _showDeleteConfirm(context, ref, r),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialApartmentId,
    String? initialCheckIn,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AddReservationDialog(
        ref: ref,
        onSaved: () => ref.invalidate(adminReservationsProvider),
        initialApartmentId: initialApartmentId,
        initialCheckIn: initialCheckIn,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ReservationRow reservation,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditReservationDialog(
        ref: ref,
        reservation: reservation,
        onSaved: () => ref.invalidate(adminReservationsProvider),
      ),
    );
  }

  /// Otevře Smart Template Selector pro rezervaci (Plachta → WhatsApp ikona). Načte byt a sestaví kontext.
  void _openWhatsAppForReservation(
    BuildContext context,
    ReservationRow r,
  ) {
    // Timeline UX musí být identické jako Kanban: otevřít čisté WhatsApp `wa.me`
    // bez bottom sheetu a bez parametrů `?text=...`.
    () async {
      final phoneRaw = r.guestPhone?.trim() ?? '';
      if (phoneRaw.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('communication.template_selector_missing_phone'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Očištění: necháváme jen čísla a případně '+'.
      final cleanedAndPlus = phoneRaw.replaceAll(RegExp(r'[^0-9+]'), '');
      final cleaned = cleanedAndPlus.contains('+')
          ? '+${cleanedAndPlus.replaceAll('+', '')}'
          : cleanedAndPlus.replaceAll('+', '');

      if (cleaned.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('communication.template_selector_missing_phone'.tr()),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final url = Uri.parse('https://wa.me/$cleaned');
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        // Záměrně tiché: pokud WA není dostupný, uživatel může zprávu otevřít ručně.
      }
    }();
  }

  void _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    ReservationRow reservation,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.reservations_delete'.tr()),
        content: Text('admin.reservations_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('admin.reservations_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => _doDelete(ctx, ref, reservation),
            child: Text('admin.reservations_delete'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(
    BuildContext dialogContext,
    WidgetRef ref,
    ReservationRow reservation,
  ) async {
    final id = reservation.id;
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(
              content: Text('common.error'.tr()),
              backgroundColor: dialogContext.colors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final userId = SupabaseService.client.auth.currentUser?.id;
      final previousState = Map<String, dynamic>.from(reservation.toMap())
        ..['id'] = reservation.id
        ..['apartment_id'] = reservation.apartmentId;
      final recordName = AdminReservationsRepository.auditRecordNameForReservation(
        reservationId: reservation.id,
        guestName: reservation.guestName,
      );
      await AdminReservationsRepository.softDeleteReservationWithLinkedTasks(
        tenantId: tenantId,
        userId: userId,
        reservationId: id,
        previousState: previousState,
        recordName: recordName,
      );

      if (tenantId.isNotEmpty) {
        ref.invalidate(adminTasksProvider);
        ref.invalidate(planningCalendarAllTasksProvider);
        ref.invalidate(planningCalendarAllTasksForMonthProvider);
      }

      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      ref.invalidate(adminReservationsProvider);
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('common.saved'.tr()),
          backgroundColor: dialogContext.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
      // ignore: avoid_print
      print('--- CHYBA MAZÁNÍ REZERVACE: $e');
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: dialogContext.colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Stáhne vzorový XLSX soubor – na webu Blob, na mobilu FilePicker dialog.
  Future<void> _downloadCsvTemplate(BuildContext context) async {
    try {
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData ?? '';
      if (tenantId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.import_no_tenant'.tr())),
          );
        }
        return;
      }
      final bytes = await ReservationImportService.generateExcelTemplate(tenantId);
      await downloadBytesAsFile(bytes, 'reservations_template.xlsx');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.import_template_downloaded'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
        );
      }
    }
  }

  /// Otevře FilePicker, načte XLSX a předá do processImport.
  /// Během zpracování zobrazí celoobrazovkový loading; po dokončení výsledek v AlertDialogu (ne SnackBar).
  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    var loadingShown = false;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      List<int> bytes = result.files.single.bytes?.toList() ?? [];
      if (bytes.isEmpty && result.files.single.path != null) {
        final path = result.files.single.path!;
        bytes = await readFileBytes(path);
      }
      if (bytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.import_empty_csv'.tr())),
          );
        }
        return;
      }
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.tenantIdForData ?? '';
      if (tenantId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('admin.import_no_tenant'.tr())),
          );
        }
        return;
      }
      final apartments = await ref.read(apartmentsFullListProvider.future);
      final codeToApartmentId = <String, String>{};
      for (final a in apartments) {
        if (a.code != null && a.code!.trim().isNotEmpty) {
          codeToApartmentId[a.code!.trim()] = a.id;
        }
      }

      // Celá obrazovka: indikátor + text, zablokované pozadí – uživatel vidí, že se něco děje.
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: context.colors.scrim.withValues(alpha: 0.5),
          builder: (ctx) => PopScope(
            canPop: false,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'admin.import_processing_message'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        loadingShown = true;
      }

      final importResult = await ReservationImportService.processImport(
        bytes,
        tenantId,
        codeToApartmentId,
      );

      if (context.mounted) {
        if (loadingShown) Navigator.of(context, rootNavigator: true).pop();
        ref.invalidate(adminReservationsProvider);
        _showImportResultDialog(context, importResult);
      }
    } on ArgumentError catch (e) {
      if (context.mounted) {
        if (loadingShown) Navigator.of(context, rootNavigator: true).pop();
        final key = e.message?.toString();
        if (kDebugMode) debugPrint('Reservation import ArgumentError: $key');
        final text = (key != null && key.startsWith('admin.'))
            ? key.tr()
            : 'common.generic_error_user_friendly'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (loadingShown) Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
        );
      }
    }
  }

  /// Velký výsledkový dialog importu – úspěšně / služby s chybou / zcela selhalo (zelená / oranžová / červená).
  void _showImportResultDialog(BuildContext context, ReservationImportResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.import_dialog_title'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImportResultRow(
                label: 'admin.import_dialog_success'.tr(),
                count: result.successCount,
                color: ctx.customColors.success,
                icon: Icons.check_circle_outline,
              ),
              SizedBox(height: AppSpacing.sm),
              _ImportResultRow(
                label: 'admin.import_dialog_services_error'.tr(),
                count: result.warningCount,
                color: ctx.customColors.warning,
                icon: Icons.warning_amber_outlined,
              ),
              SizedBox(height: AppSpacing.sm),
              _ImportResultRow(
                label: 'admin.import_dialog_failed_rows'.tr(),
                count: result.errorCount,
                color: ctx.colors.error,
                icon: Icons.error_outline,
              ),
              if (result.errorCount > 0) ...[
                SizedBox(height: AppSpacing.md),
                Text(
                  'admin.import_dialog_some_rows_failed'.tr(),
                  style: ctx.textTheme.bodySmall?.copyWith(
                        color: ctx.colors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('admin.import_dialog_close'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Jeden řádek výsledku importu – ikona, tučný popis, počet v dané barvě.
class _ImportResultRow extends StatelessWidget {
  const _ImportResultRow({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: AppSpacing.lg),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Text(
          '$count',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Top Action Bar – titulek, vyhledávání, tlačítko Přidat a menu CSV importu.
class _TopActionBar extends StatelessWidget {
  const _TopActionBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onDownloadTemplate,
    required this.onImportCsv,
  });

  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onAdd;
  final VoidCallback onDownloadTemplate;
  final VoidCallback onImportCsv;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          Text(
            'admin.reservations_title'.tr(),
            style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(width: AppSpacing.xl),
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              decoration: InputDecoration(
                hintText: 'admin.reservations_search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: context.colors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_file),
            tooltip: 'admin.import_reservations'.tr(),
            onSelected: (value) {
              if (value == 'download') onDownloadTemplate();
              if (value == 'import') onImportCsv();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 20),
                    const SizedBox(width: 8),
                    Text('admin.download_csv_template'.tr()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file, size: 20),
                    const SizedBox(width: 8),
                    Text('admin.import_reservations'.tr()),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: Text('admin.fab_new_reservation'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Rezervační plachta (Gantt chart) – souvislé pruhy rezervací v mřížce dnů × apartmány.
/// [visibleStartDate] – 1. den zobrazeného měsíce; šipky posunují o celý měsíc, hlavička zobrazuje „Měsíc rok“.
/// [onEmptyCellTap] – tap na prázdnou buňku → nová rezervace s předvyplněním bytu a data.
///
/// Detekce „kolizí“ na plachtě: lokální funkce `isCellEmpty` v `_ReservationTimelineState.build` porovnává každou buňku (byt + kalendářní den)
/// se všemi rezervacemi v paměti – pokud se interval [check_in, check_out] překrývá s daným dnem, buňka není prázdná.
/// To slouží jen k vizuálnímu rozlišení volného slotu a k povolení tapu; neukládá se tím nic do DB.
class ReservationTimeline extends ConsumerStatefulWidget {
  const ReservationTimeline({
    super.key,
    required this.visibleStartDate,
    this.onPrevious,
    this.onToday,
    this.onNext,
    this.onReservationTap,
    this.onReservationWhatsApp,
    this.onEmptyCellTap,
  });

  final DateTime visibleStartDate;
  final VoidCallback? onPrevious;
  final VoidCallback? onToday;
  final VoidCallback? onNext;
  final ValueChanged<ReservationRow>? onReservationTap;
  /// Callback pro otevření WhatsApp výběru šablony z bloku rezervace na Plachtě.
  final ValueChanged<ReservationRow>? onReservationWhatsApp;
  final void Function(String apartmentId, DateTime date)? onEmptyCellTap;

  static const double dayWidth = 85.0;
  static const double rowHeight = 80.0;
  static const double leftColumnWidth = 120.0;

  @override
  ConsumerState<ReservationTimeline> createState() => _ReservationTimelineState();
}

class _ReservationTimelineState extends ConsumerState<ReservationTimeline> {
  /// Controller pro horizontální posun časové osy; vynucujeme viditelný Scrollbar kvůli UX na webu (uživatelé bez trackpadu).
  late final ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(adminReservationsProvider);
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);

    if (reservationsAsync.isLoading || apartmentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final reservations = reservationsAsync.valueOrNull ?? [];
    final apartments = apartmentsAsync.valueOrNull ?? [];

    // Měsíční zobrazení: vždy 1. den měsíce a počet dní daného měsíce (28–31).
    final startDate = DateTime(widget.visibleStartDate.year, widget.visibleStartDate.month, 1);
    final lastDayOfMonth = DateTime(widget.visibleStartDate.year, widget.visibleStartDate.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final days = List<DateTime>.generate(
      totalDays,
      (i) => startDate.add(Duration(days: i)),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // PROČ: Jednoduchá detekce překryvu pobytů v jednom bytě po dnech (stejná logika jako „je tento den obsazený?“).
    // Porovnáváme kalendářní dny check-in až check-out včetně krajů – host „drží“ buňku po celou délku pobytu.
    // Složitější validace (čas příjezdu/odjezdu, hranice mezi dvěma rezervacemi) zůstává u formuláře při uložení.
    bool isCellEmpty(int rowIndex, int colIndex) {
      if (rowIndex >= apartments.length || colIndex >= days.length) return false;
      final apartmentId = apartments[rowIndex].id;
      final cellDate = days[colIndex];
      for (final r in reservations) {
        if (r.apartmentId != apartmentId) continue;
        final checkInDt = parseReservationCheckIn(r.checkIn);
        final checkOutDt = parseReservationCheckOut(r.checkOut);
        if (checkInDt == null || checkOutDt == null) continue;
        final checkInDate = DateTime(checkInDt.year, checkInDt.month, checkInDt.day);
        final checkOutDate = DateTime(checkOutDt.year, checkOutDt.month, checkOutDt.day);
        if (!cellDate.isBefore(checkInDate) && !cellDate.isAfter(checkOutDate)) return false;
      }
      return true;
    }

    final totalWidth = days.length * ReservationTimeline.dayWidth;
    final gridHeight = apartments.length * ReservationTimeline.rowHeight;
    final apartmentIndexById = {for (var i = 0; i < apartments.length; i++) apartments[i].id: i};
    final locale = context.locale.toString();
    // Hlavička: název měsíce a rok (např. „Duben 2026“), lokalizovaně.
    final monthYearFormat = DateFormat.yMMMM(locale);
    final monthYearLabel = monthYearFormat.format(startDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horní ovládací lišta – navigace po měsících, název měsíce + rok, legenda.
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: widget.onPrevious,
                    tooltip: 'admin.reservations_timeline_prev'.tr(),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    monthYearLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: widget.onNext,
                    tooltip: 'admin.reservations_timeline_next'.tr(),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  OutlinedButton(
                      onPressed: widget.onToday,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('admin.reservations_timeline_today'.tr()),
                  ),
                ],
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _ReservationLegendPill(status: 'new'),
                      SizedBox(width: AppSpacing.sm),
                      const _ReservationLegendPill(status: 'confirmed'),
                      SizedBox(width: AppSpacing.sm),
                      const _ReservationLegendPill(status: 'checked_in'),
                      SizedBox(width: AppSpacing.sm),
                      const _ReservationLegendPill(status: 'checked_out'),
                      SizedBox(width: AppSpacing.sm),
                      const _ReservationLegendPill(status: 'cancelled'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Kontejner „papír na stole“ – bílý box; uvnitř vertikální scroll, aby levý sloupec i mřížka rolovály společně.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  height: ReservationTimeline.rowHeight + gridHeight,
                  child: _ReservationTimelineGrid(
                    reservations: reservations,
                    apartments: apartments,
                    days: days,
                    startDate: startDate,
                    today: today,
                    dayWidth: ReservationTimeline.dayWidth,
                    rowHeight: ReservationTimeline.rowHeight,
                    leftColumnWidth: ReservationTimeline.leftColumnWidth,
                    totalWidth: totalWidth,
                    gridHeight: gridHeight,
                    apartmentIndexById: apartmentIndexById,
                    isCellEmpty: isCellEmpty,
                    onReservationTap: widget.onReservationTap,
                    onReservationWhatsApp: widget.onReservationWhatsApp,
                    onEmptyCellTap: widget.onEmptyCellTap,
                    horizontalScrollController: _horizontalScrollController,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pilulka v legendě Plachty – stav rezervace s pastelovým pozadím a tmavým textem.
class _ReservationLegendPill extends StatelessWidget {
  const _ReservationLegendPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _legendPillColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        reservationStatusLabelKey(status).tr(),
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Prémiová mřížka Plachty rezervací (Gantt) – Apple Vibe. Levý sloupec apartmány, hlavička dny, bloky rezervací.
class _ReservationTimelineGrid extends StatelessWidget {
  const _ReservationTimelineGrid({
    required this.reservations,
    required this.apartments,
    required this.days,
    required this.startDate,
    required this.today,
    required this.dayWidth,
    required this.rowHeight,
    required this.leftColumnWidth,
    required this.totalWidth,
    required this.gridHeight,
    required this.apartmentIndexById,
    required this.isCellEmpty,
    required this.onReservationTap,
    this.onReservationWhatsApp,
    required this.onEmptyCellTap,
    required this.horizontalScrollController,
  });

  final List<ReservationRow> reservations;
  final List<ApartmentRow> apartments;
  final List<DateTime> days;
  final DateTime startDate;
  final DateTime today;
  final double dayWidth;
  final double rowHeight;
  final double leftColumnWidth;
  final double totalWidth;
  final double gridHeight;
  final Map<String, int> apartmentIndexById;
  final bool Function(int rowIndex, int colIndex) isCellEmpty;
  final ValueChanged<ReservationRow>? onReservationTap;
  final ValueChanged<ReservationRow>? onReservationWhatsApp;
  final void Function(String apartmentId, DateTime date)? onEmptyCellTap;
  final ScrollController horizontalScrollController;

  static const List<String> _dayKeys = [
    'planning_calendar.mon', 'planning_calendar.tue', 'planning_calendar.wed',
    'planning_calendar.thu', 'planning_calendar.fri', 'planning_calendar.sat',
    'planning_calendar.sun',
  ];

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final dateFormat = DateFormat('d.M.', locale);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReservationTimelineLeftColumn(
          apartments: apartments,
          rowHeight: rowHeight,
          leftColumnWidth: leftColumnWidth,
        ),
        Expanded(
          // Horizontální posuvník vždy viditelný kvůli UX na webu – uživatelé s myší (bez trackpadu) musí vědět, že lze rolovat dny.
          child: Scrollbar(
            controller: horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hlavička dnů s dolní hranicí (oddělení od mřížky)
                    Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
                    ),
                    child: _ReservationTimelineHeader(
                      days: days,
                      today: today,
                      dayWidth: dayWidth,
                      rowHeight: rowHeight,
                      dateFormat: dateFormat,
                    ),
                  ),
                  SizedBox(
                    width: totalWidth,
                    height: gridHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ReservationTimelineGridBackground(
                          dayCount: days.length,
                          rowCount: apartments.length,
                          dayWidth: dayWidth,
                          rowHeight: rowHeight,
                          gridLineColor: context.colors.outline.withValues(alpha: 0.12),
                        ),
                        if (onEmptyCellTap != null)
                          ...List.generate(apartments.length * days.length, (i) {
                            final rowIndex = i ~/ days.length;
                            final colIndex = i % days.length;
                            if (!isCellEmpty(rowIndex, colIndex)) return const SizedBox.shrink();
                            final apartmentId = apartments[rowIndex].id;
                            final date = days[colIndex];
                            return Positioned(
                              left: colIndex * dayWidth,
                              top: rowIndex * rowHeight,
                              width: dayWidth,
                              height: rowHeight,
                              child: InkWell(
                                onTap: () => onEmptyCellTap!(apartmentId, date),
                                child: const SizedBox.expand(),
                              ),
                            );
                          }),
                        ...reservations.map((r) => _ReservationTimelineBlock(
                              reservation: r,
                              startDate: startDate,
                              dayWidth: dayWidth,
                              rowHeight: rowHeight,
                              apartmentIndexById: apartmentIndexById,
                              onTap: () => onReservationTap?.call(r),
                              onWhatsAppTap: onReservationWhatsApp != null ? () => onReservationWhatsApp!(r) : null,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ],
    );
  }
}

/// Levý sloupec – názvy apartmánů. FontWeight.w600, šedá, pravý border odděluje od mřížky.
class _ReservationTimelineLeftColumn extends StatelessWidget {
  const _ReservationTimelineLeftColumn({
    required this.apartments,
    required this.rowHeight,
    required this.leftColumnWidth,
  });

  final List<ApartmentRow> apartments;
  final double rowHeight;
  final double leftColumnWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: leftColumnWidth,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(right: BorderSide(color: context.colors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.06),
            offset: const Offset(2, 0),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: rowHeight),
          ...apartments.map(
            (a) => SizedBox(
              height: rowHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.sm),
                  child: Text(
                    a.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurfaceVariant,
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

/// Hlavička Plachty – dny. Dnešní den v modrém kruhu, víkendy jemným šedým podbarvením.
class _ReservationTimelineHeader extends StatelessWidget {
  const _ReservationTimelineHeader({
    required this.days,
    required this.today,
    required this.dayWidth,
    required this.rowHeight,
    required this.dateFormat,
  });

  final List<DateTime> days;
  final DateTime today;
  final double dayWidth;
  final double rowHeight;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: days.map((d) {
        final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
        final weekday = d.weekday;
        final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
        return Container(
          width: dayWidth,
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday
                ? context.colors.primaryContainer
                : (isWeekend ? context.colors.surfaceContainerHighest : context.colors.surface),
            border: Border(
              right: BorderSide(color: context.colors.outline.withValues(alpha: 0.2)),
              bottom: BorderSide(color: context.colors.outline.withValues(alpha: 0.25)),
            ),
          ),
          child: isToday
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.primary,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '${_ReservationTimelineGrid._dayKeys[d.weekday - 1].tr()} ${dateFormat.format(d)}',
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onPrimaryContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  '${_ReservationTimelineGrid._dayKeys[d.weekday - 1].tr()} ${dateFormat.format(d)}',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        );
      }).toList(),
    );
  }
}

/// Jeden blok rezervace na Plachtě – Apple Vibe s jemným stínem, tmavým textem, ikonami.
class _ReservationTimelineBlock extends StatelessWidget {
  const _ReservationTimelineBlock({
    required this.reservation,
    required this.startDate,
    required this.dayWidth,
    required this.rowHeight,
    required this.apartmentIndexById,
    required this.onTap,
    this.onWhatsAppTap,
  });

  final ReservationRow reservation;
  final DateTime startDate;
  final double dayWidth;
  final double rowHeight;
  final Map<String, int> apartmentIndexById;
  final VoidCallback onTap;
  /// Volá se při kliku na ikonu WhatsApp (bez otevření edit dialogu).
  final VoidCallback? onWhatsAppTap;

  @override
  Widget build(BuildContext context) {
    final checkInDt = parseReservationCheckIn(reservation.checkIn);
    final checkOutDt = parseReservationCheckOut(reservation.checkOut);
    if (checkInDt == null || checkOutDt == null) return const SizedBox.shrink();
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    // Výpočet v jednotkách dní (zlomky) – podpora same-day turnover (check-out 10:00, check-in 14:00).
    final exactStartDays = checkInDt.difference(startDateOnly).inMinutes / (24 * 60.0);
    final exactEndDays = checkOutDt.difference(startDateOnly).inMinutes / (24 * 60.0);
    final rawLeft = exactStartDays * dayWidth;
    final left = rawLeft < 0 ? 0.0 : rawLeft;
    final rawWidth = (exactEndDays - exactStartDays) * dayWidth;
    final width = rawLeft < 0 ? (rawWidth + rawLeft) : rawWidth;
    if (width <= 0) return const SizedBox.shrink();
    final aptIndex = apartmentIndexById[reservation.apartmentId] ?? 0;
    final top = aptIndex * rowHeight;
    final guestName = (reservation.guestName ?? '').trim().isEmpty ? 'admin.dashboard_guest_unknown'.tr() : reservation.guestName!;
    final phoneRaw = (reservation.guestPhone ?? '').trim();
    final hasPhone = phoneRaw.isNotEmpty;
    final totalGuests = reservation.guestAdults + reservation.guestChildren;
    final blockColor = _timelineBlockColor(context, reservation.status);

    return Positioned(
      left: left + 3,
      top: top + 3,
      child: SizedBox(
        width: width - 6,
        height: rowHeight - 6,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRect(
                child: SizedBox(
                  height: rowHeight - 6 - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              guestName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.colors.onSurface,
                              ),
                            ),
                          ),
                          if (reservation.referenceNumber != null && reservation.referenceNumber!.trim().isNotEmpty)
                            Flexible(
                              child: Text(
                                '#${reservation.referenceNumber!.trim()}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Responzivní druhý řádek: ikonky – Flexible aby při malé výšce řádku (menší monitor) nepřetekl.
                      if (width > 120)
                        Flexible(
                          child: ClipRect(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '👥 $totalGuests',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: context.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (onWhatsAppTap != null) ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: hasPhone
                                            ? 'communication.template_selector_whatsapp_tooltip'.tr()
                                            : 'communication.template_selector_missing_phone'.tr(),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: hasPhone ? onWhatsAppTap : null,
                                            child: Icon(
                                              Icons.chat,
                                              size: 14,
                                              color: hasPhone
                                                  ? context.customColors.success
                                                  : context.colors.outlineVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (reservation.needsTransfer == true) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.flight_land, size: 14, color: context.colors.onSurfaceVariant),
                                    ],
                                    if (reservation.internalNote != null && reservation.internalNote!.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.notes, size: 14, color: context.colors.onSurfaceVariant),
                                    ],
                                    if (reservation.lastCommunicationAt != null) ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: _lastCommunicationTooltip(reservation),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: TaskVisuals.getBackgroundColor(
                                              reservation.lastCommunicationTemplateContext,
                                              categoriesByCode: null,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            TaskVisuals.getIcon(
                                              reservation.lastCommunicationTemplateContext,
                                              categoriesByCode: null,
                                            ),
                                            size: 12,
                                            color: TaskVisuals.getBorderColor(
                                              reservation.lastCommunicationTemplateContext,
                                              categoriesByCode: null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
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

  /// Text tooltipu pro indikátor „zpráva připravena“ (datum + typ šablony).
  static String _lastCommunicationTooltip(ReservationRow r) {
    final ctx = (r.lastCommunicationTemplateContext ?? '').trim().isEmpty
        ? '–'
        : 'admin.task_type_${r.lastCommunicationTemplateContext}'.tr();
    final date = r.lastCommunicationAt != null
        ? DateFormat('d.M.y HH:mm').format(r.lastCommunicationAt!.toLocal())
        : '–';
    return 'communication.last_communication_tooltip'.tr(namedArgs: {'context': ctx, 'date': date});
  }
}

/// Jemná mřížka na pozadí Plachty – extrémně jemné čáry (alpha 0.1).
class _ReservationTimelineGridBackground extends StatelessWidget {
  const _ReservationTimelineGridBackground({
    required this.dayCount,
    required this.rowCount,
    required this.dayWidth,
    required this.rowHeight,
    required this.gridLineColor,
  });

  final int dayCount;
  final int rowCount;
  final double dayWidth;
  final double rowHeight;
  /// Barva čar mřížky – z [ColorScheme.outline], aby odpovídala aktuálnímu tématu.
  final Color gridLineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(dayCount * dayWidth, rowCount * rowHeight),
      painter: _ReservationTimelineGridPainter(
        dayCount: dayCount,
        rowCount: rowCount,
        dayWidth: dayWidth,
        rowHeight: rowHeight,
        gridLineColor: gridLineColor,
      ),
    );
  }
}

class _ReservationTimelineGridPainter extends CustomPainter {
  _ReservationTimelineGridPainter({
    required this.dayCount,
    required this.rowCount,
    required this.dayWidth,
    required this.rowHeight,
    required this.gridLineColor,
  });

  final int dayCount;
  final int rowCount;
  final double dayWidth;
  final double rowHeight;
  final Color gridLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1;
    for (var i = 0; i <= dayCount; i++) {
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var i = 0; i <= rowCount; i++) {
      final y = i * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Konfigurace jednoho sloupce Kanbanu: cílový status při dropu a které stavy se v sloupci zobrazí.
class _KanbanColumnConfig {
  const _KanbanColumnConfig({
    required this.targetStatus,
    required this.displayStatuses,
    required this.labelKey,
  });
  final String targetStatus;
  final List<String> displayStatuses;
  final String labelKey;
}

const _kanbanColumns = [
  _KanbanColumnConfig(
    targetStatus: 'new',
    displayStatuses: ['new'],
    labelKey: 'admin.reservations_kanban_new',
  ),
  _KanbanColumnConfig(
    targetStatus: 'confirmed',
    displayStatuses: ['confirmed'],
    labelKey: 'admin.reservations_kanban_confirmed',
  ),
  _KanbanColumnConfig(
    targetStatus: 'checked_in',
    displayStatuses: ['checked_in'],
    labelKey: 'admin.reservations_kanban_in_progress',
  ),
  _KanbanColumnConfig(
    targetStatus: 'checked_out',
    displayStatuses: ['checked_out', 'cancelled'],
    labelKey: 'admin.reservations_kanban_completed',
  ),
];

/// Jeden sloupec Kanbanu rezervací – odebírá jen [reservationsBySystemStatusProvider] pro svůj [targetStatus].
class _ReservationsKanbanColumn extends ConsumerWidget {
  const _ReservationsKanbanColumn({
    required this.config,
    required this.onEdit,
    required this.onDelete,
    required this.onWhatsApp,
    required this.onAcceptDrop,
  });

  final _KanbanColumnConfig config;
  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;
  final void Function(BuildContext context, ReservationRow r) onWhatsApp;
  final Future<void> Function(ReservationRow r) onAcceptDrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final column = ref.watch(reservationsBySystemStatusProvider(config.targetStatus));
    final columnReservations = column.reservations;
    return DragTarget<ReservationRow>(
      onAcceptWithDetails: (d) async {
        final reservation = d.data;
        if (reservation.status != config.targetStatus) {
          await onAcceptDrop(reservation);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlight = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHighlight
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.sm,
                ),
                child: Text(
                  '${config.labelKey.tr()} (${columnReservations.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  ),
                  itemCount: columnReservations.length,
                  itemBuilder: (context, index) {
                    final r = columnReservations[index];
                    return _KanbanReservationCard(
                      key: ValueKey<String>(r.id),
                      reservation: r,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onWhatsApp: () => onWhatsApp(context, r),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Kanban board rezervací – 4 sloupce podle stavu, drag & drop s aktualizací v Supabase.
///
/// DŮLEŽITÉ: Drag zde mění pouze **workflow stav** rezervace (new → confirmed → checked_in → …), nikoli check-in/check-out
/// ani apartmán. „Collision detection“ termínů a změna dat pobytu nejsou součástí Kanbanu – řeší je úprava rezervace
/// v dialozích a backend / validace formuláře.
///
/// Data sloupců: [reservationsBySystemStatusProvider] – bez předávání celého seznamu z nadřazeného widgetu.
class _ReservationsKanbanBoard extends ConsumerStatefulWidget {
  const _ReservationsKanbanBoard({
    required this.onEdit,
    required this.onDelete,
  });

  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;

  @override
  ConsumerState<_ReservationsKanbanBoard> createState() =>
      _ReservationsKanbanBoardState();
}

class _ReservationsKanbanBoardState extends ConsumerState<_ReservationsKanbanBoard> {
  /// Kanban-only: přímé otevření prázdného WhatsApp chatu (bez bottom sheetu).
  ///
  /// PROČ: na Webu chceme WhatsApp v Kanbanu jednoduchý a rychlý, šablony se editují uvnitř
  /// detailu rezervace (ne přes MessageTemplateSelectorBottomSheet).
  Future<void> _openWhatsAppDirectForKanbanReservation(
    BuildContext context,
    ReservationRow r,
  ) async {
    final phoneRaw = r.guestPhone?.trim() ?? '';
    if (phoneRaw.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('communication.template_selector_missing_phone'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Očištění: necháváme jen čísla a případné '+'.
    final cleanedAndPlus = phoneRaw.replaceAll(RegExp(r'[^0-9+]'), '');
    final cleaned = cleanedAndPlus.contains('+')
        ? '+${cleanedAndPlus.replaceAll('+', '')}'
        : cleanedAndPlus.replaceAll('+', '');

    if (cleaned.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('communication.template_selector_missing_phone'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final url = Uri.parse('https://wa.me/$cleaned');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Záměrně tiché: uživatel se může případně přepnout do WhatsApp manuálně.
    }
  }

  Future<void> _updateReservationStatus(ReservationRow r, String newStatus) async {
    try {
      final tenantId = ref.read(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) return;
      await AdminReservationsRepository.updateReservationStatus(
        tenantId: tenantId,
        reservationId: r.id,
        newStatus: newStatus,
      );
      if (!mounted) return;
      ref.invalidate(adminReservationsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kanbanColumns.map((col) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: _ReservationsKanbanColumn(
                config: col,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                onWhatsApp: _openWhatsAppDirectForKanbanReservation,
                onAcceptDrop: (r) => _updateReservationStatus(r, col.targetStatus),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Kompaktní karta rezervace v Kanbanu – vizuálně shodná s _TaskCard (úkoly).
/// Draggable, celá karta klikatelná pro editaci, ikona koše vpravo.
class _KanbanReservationCard extends StatelessWidget {
  const _KanbanReservationCard({
    super.key,
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
    required this.onWhatsApp,
  });

  final ReservationRow reservation;
  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final id = reservation.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Draggable<ReservationRow>(
        key: ValueKey<String>('res_kanban_drag_$id'),
        data: reservation,
        feedback: Material(
          elevation: 6,
          color: Colors.transparent,
          child: SizedBox(
            width: 260,
            child: _reservationPremiumCardShell(
              context: context,
              onTap: null,
              child: _KanbanCardContent(
                key: ValueKey<String>(id),
                reservation: reservation,
                showDelete: false,
                onDelete: () {},
                onWhatsApp: onWhatsApp,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: _reservationPremiumCardShell(
            context: context,
            onTap: null,
            child: _KanbanCardContent(
              key: ValueKey<String>('res_kanban_ghost_$id'),
              reservation: reservation,
              showDelete: true,
              onDelete: () => onDelete(reservation),
              onWhatsApp: onWhatsApp,
            ),
          ),
        ),
        child: _reservationPremiumCardShell(
          context: context,
          onTap: () => onEdit(reservation),
          child: _KanbanCardContent(
            key: ValueKey<String>('res_kanban_card_$id'),
            reservation: reservation,
            showDelete: true,
            onDelete: () => onDelete(reservation),
            onWhatsApp: onWhatsApp,
          ),
        ),
      ),
    );
  }
}

/// Obsah Kanban karty rezervace – struktura shodná s _TaskCard. Data z reservation modelu.
class _KanbanCardContent extends StatelessWidget {
  const _KanbanCardContent({
    super.key,
    required this.reservation,
    required this.showDelete,
    required this.onDelete,
    required this.onWhatsApp,
  });

  final ReservationRow reservation;
  final bool showDelete;
  final VoidCallback onDelete;
  final VoidCallback onWhatsApp;

  /// Barva ikony podle zdroje rezervace – mapováno na téma (error / primary / success).
  static Color _sourceColor(BuildContext context, String? source) {
    final cs = context.colors;
    final cc = context.customColors;
    final s = (source ?? '').trim();
    if (s == 'Airbnb') return cs.error;
    if (s == 'Booking') return cs.primary;
    if (s == 'Direct') return cc.success;
    return cs.onSurfaceVariant;
  }

  /// Ikona podle zdroje rezervace – Airbnb air, Booking language, Direct home.
  static IconData _sourceIcon(String? source) {
    final s = (source ?? '').trim();
    if (s == 'Airbnb') return Icons.air;
    if (s == 'Booking') return Icons.language;
    if (s == 'Direct') return Icons.home;
    return Icons.book_online;
  }

  /// Tooltip pro indikátor „zpráva připravena“ (datum + typ šablony) – používáno v Kanban kartě.
  static String lastCommunicationTooltip(ReservationRow r) {
    final ctx = (r.lastCommunicationTemplateContext ?? '').trim().isEmpty
        ? '–'
        : 'admin.task_type_${r.lastCommunicationTemplateContext}'.tr();
    final date = r.lastCommunicationAt != null
        ? DateFormat('d.M.y HH:mm').format(r.lastCommunicationAt!.toLocal())
        : '–';
    return 'communication.last_communication_tooltip'.tr(namedArgs: {'context': ctx, 'date': date});
  }

  /// Formátuje termín s volitelným časem z arrival_time/departure_time (např. "13.03. 14:00 → 17.03. 10:00").
  static String _formatDateRange(ReservationRow r) {
    final checkIn = r.checkIn ?? '–';
    final checkOut = r.checkOut ?? '–';
    String from = checkIn;
    String to = checkOut;
    if (r.arrivalTime != null) {
      from = '$checkIn ${r.arrivalTime!.hour.toString().padLeft(2, '0')}:${r.arrivalTime!.minute.toString().padLeft(2, '0')}';
    }
    if (r.departureTime != null) {
      to = '$checkOut ${r.departureTime!.hour.toString().padLeft(2, '0')}:${r.departureTime!.minute.toString().padLeft(2, '0')}';
    }
    return '$from → $to';
  }

  @override
  Widget build(BuildContext context) {
    final guestName = (reservation.guestName ?? '').trim().isEmpty ? '–' : reservation.guestName!;
    final phoneRaw = (reservation.guestPhone ?? '').trim();
    final hasPhone = phoneRaw.isNotEmpty;
    final apartmentName = (reservation.apartmentName ?? '').trim().isEmpty ? '–' : reservation.apartmentName!;
    // Celkový počet osob = dospělí + děti (pro at-a-glance přehled dispečera).
    final totalGuests = reservation.guestAdults + reservation.guestChildren;
    final contextLabel = reservation.reservationSource != null
        ? 'admin.reservation_source_${reservation.reservationSource}'.tr()
        : 'admin.menu_reservations'.tr();
    final statusColor = reservationStatusColor(context, reservation.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. řádek – kontext: barevná ikona podle zdroje (Airbnb/Booking/Direct)
                Row(
                  children: [
                    Icon(
                      _sourceIcon(reservation.reservationSource),
                      size: 16,
                      color: _sourceColor(context, reservation.reservationSource),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        contextLabel,
                        style: context.textTheme.labelLarge?.copyWith(
                          color: _sourceColor(context, reservation.reservationSource),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final ageLabel =
                            reservationRecordAgeLabel(reservation.createdAt);
                        if (ageLabel == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Material(
                            color: context.colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                ageLabel,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                // 2. řádek – hlavní nadpis: jméno hosta + referenční číslo + drobné ikony (transfer, poznámka)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        guestName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (reservation.referenceNumber != null && reservation.referenceNumber!.trim().isNotEmpty) ...[
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        '#${reservation.referenceNumber!.trim()}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (reservation.needsTransfer == true) ...[
                      SizedBox(width: AppSpacing.sm),
                      Icon(Icons.flight_land, size: 14, color: context.colors.primary),
                    ],
                    if (reservation.internalNote != null && reservation.internalNote!.trim().isNotEmpty) ...[
                      SizedBox(width: AppSpacing.xs),
                      Icon(Icons.notes, size: 14, color: context.customColors.warning),
                    ],
                  ],
                ),
                // Telefon na hosta – kritický pro dispečera
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: context.colors.onSurfaceVariant),
                          SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              hasPhone ? phoneRaw : 'communication.template_selector_missing_phone'.tr(),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: hasPhone
                                    ? context.colors.onSurfaceVariant
                                    : context.colors.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: hasPhone
                          ? 'communication.template_selector_whatsapp_tooltip'.tr()
                          : 'communication.template_selector_missing_phone'.tr(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.chat,
                          size: 18,
                          color: hasPhone
                              ? context.customColors.success
                              : context.colors.outline,
                        ),
                        onPressed: hasPhone ? onWhatsApp : null,
                      ),
                    ),
                  ],
                ),
                if (reservation.lastCommunicationAt != null) ...[
                  const SizedBox(height: 2),
                  Tooltip(
                    message: _KanbanCardContent.lastCommunicationTooltip(reservation),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          TaskVisuals.getIcon(
                            reservation.lastCommunicationTemplateContext,
                            categoriesByCode: null,
                          ),
                          size: 12,
                          color: TaskVisuals.getBorderColor(
                            reservation.lastCommunicationTemplateContext,
                            categoriesByCode: null,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'communication.message_prepared_short'.tr(),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.xs),
                // 3. řádek – podnadpis: apartmán + počet osob
                Text(
                  totalGuests > 0 ? '$apartmentName • 👥 $totalGuests' : apartmentName,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // 4. řádek – pilulky: stav a termín (s časem při příjezdu/odjezdu)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reservationStatusLabelKey(reservation.status).tr(),
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDateRange(reservation),
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Konzistence s Úkoly: u Odhlášeno zámeček místo koše (nelze mazat historické záznamy).
          if (reservation.status == 'checked_out') ...[
            SizedBox(width: AppSpacing.xs),
            Icon(Icons.lock, size: 16, color: context.colors.outline),
          ] else if (showDelete) ...[
            SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: context.colors.error.withValues(alpha: 0.75),
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Jedna kompaktní karta rezervace (připraveno pro případné znovupoužití).
// ignore: unused_element
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
  });

  final ReservationRow reservation;
  final ValueChanged<ReservationRow> onEdit;
  final ValueChanged<ReservationRow> onDelete;

  @override
  Widget build(BuildContext context) {
    final guestName = (reservation.guestName ?? '').trim().isEmpty
        ? '–'
        : reservation.guestName!;
    final checkIn = reservation.checkIn ?? '–';
    final checkOut = reservation.checkOut ?? '–';
    final apartmentName = (reservation.apartmentName ?? '').trim().isEmpty
        ? '–'
        : reservation.apartmentName!;
    final needsTransfer = reservation.needsTransfer == true;
    final statusLabel = reservationStatusLabelKey(reservation.status).tr();
    final statusColor = reservationStatusColor(context, reservation.status);
    final statusFg = _statusChipForegroundColor(context, reservation.status);
    final nights = reservationNights(reservation.checkIn, reservation.checkOut);
    final nightsText = nights != null && nights >= 0
        ? 'admin.reservations_nights'.tr(namedArgs: {'count': nights.toString()})
        : null;

    return _reservationPremiumCardShell(
      context: context,
      onTap: () => onEdit(reservation),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            guestName,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (needsTransfer) ...[
                          SizedBox(width: AppSpacing.sm),
                          Icon(Icons.flight_land, size: 18, color: context.customColors.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      apartmentName,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      checkIn,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 16, color: context.colors.onSurfaceVariant),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            checkOut,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (nightsText != null)
                            Text(
                              nightsText,
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Chip(
                label: Text(
                  statusLabel,
                  style: context.textTheme.labelSmall?.copyWith(color: statusFg),
                ),
                backgroundColor: statusColor,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              // Konzistence s Úkoly: u Odhlášeno zámeček místo koše.
              reservation.status == 'checked_out'
                  ? Icon(Icons.lock, size: 16, color: context.colors.outline)
                  : IconButton(
                      icon: const Icon(Icons.delete, size: 22),
                      color: context.colors.error,
                      tooltip: 'admin.reservations_delete_reservation'.tr(),
                      onPressed: () => onDelete(reservation),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
            ],
          ),
        ),
    );
  }
}

