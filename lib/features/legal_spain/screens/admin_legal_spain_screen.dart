import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';
import 'package:falconest/features/legal_spain/utils/legal_parte_pdf.dart';
import 'package:falconest/features/legal_spain/widgets/apartment_legal_settings_form.dart';
import 'package:falconest/features/legal_spain/widgets/legal_spain_ui.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';

/// Admin přehled compliance (dnes / čeká podpis / SES chyba) + kódy SES u bytů.
///
/// PROČ bez vlastního AppBar: obrazovka žije v [AdminLayout] (sidebar + top bar).
/// Header + TabBar kopírují Automatizace / Komunikaci.
class AdminLegalSpainScreen extends ConsumerWidget {
  const AdminLegalSpainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isModuleActive(ref, kLegalSpainModuleKey)) {
      return Scaffold(
        body: legalSpainEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'modules.legal_spain.title'.tr(),
          subtitle: 'legal_spain.upsell_desc'.tr(),
          action: FilledButton.icon(
            onPressed: () => PremiumUpsellDialog.show(
              context,
              moduleKey: kLegalSpainModuleKey,
              titleKey: 'modules.legal_spain.title',
              descriptionKey: 'legal_spain.upsell_desc',
            ),
            icon: const Icon(Icons.lock_open_rounded),
            label: Text('legal_spain.unlock'.tr()),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'modules.legal_spain.title'.tr(),
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'legal_spain.subtitle'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    tabs: [
                      Tab(text: 'legal_spain.tab_dashboard'.tr()),
                      Tab(text: 'legal_spain.tab_book'.tr()),
                      Tab(text: 'legal_spain.tab_apartments'.tr()),
                    ],
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _DashboardTab(),
                  _BookTab(),
                  _ApartmentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(legalComplianceDashboardProvider(''));
    return rowsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => legalSpainErrorState(
        context,
        onRetry: () => ref.invalidate(legalComplianceDashboardProvider('')),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return legalSpainEmptyState(
            icon: Icons.badge_outlined,
            title: 'legal_spain.empty_dashboard'.tr(),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            final name = r.guestName?.trim().isNotEmpty == true
                ? r.guestName!
                : 'legal_spain.unnamed_guest'.tr();
            final dates = legalSpainStayDates(context, r);
            final apt = r.apartmentName ?? '–';
            return LegalSpainStayCard(
              title: name,
              subtitle: dates.isEmpty ? apt : '$apt · $dates',
              status: r.status,
              onTap: () => showLegalSpainPanel(
                context: context,
                title: 'legal_spain.stay_detail_title'.tr(),
                content: SingleChildScrollView(
                  child: ReservationLegalSection(
                    reservationId: r.reservationId,
                    apartmentId: r.apartmentId,
                    showSesRetry: r.status == 'rejected' || r.status == 'timeout',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BookTab extends ConsumerWidget {
  const _BookTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(legalVisitorBookProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => legalSpainErrorState(
        context,
        onRetry: () => ref.invalidate(legalVisitorBookProvider),
      ),
      data: (rows) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: rows.isEmpty
                      ? null
                      : () async {
                          final header = [
                            'legal_spain.col_name'.tr(),
                            'legal_spain.col_doc'.tr(),
                            'legal_spain.col_dates'.tr(),
                            'legal_spain.col_apartment'.tr(),
                          ];
                          final data = <List<String>>[header];
                          for (final m in rows) {
                            final res = m['reservations'];
                            Map<String, dynamic>? rmap;
                            if (res is Map) rmap = Map<String, dynamic>.from(res);
                            String apt = '';
                            final a = rmap?['apartments'];
                            if (a is Map) apt = '${a['name'] ?? ''}';
                            data.add([
                              '${m['first_name'] ?? ''} ${m['last_name'] ?? ''} ${m['second_last_name'] ?? ''}'
                                  .trim(),
                              '${m['document_type'] ?? ''} ${m['document_number'] ?? ''}'
                                  .trim(),
                              '${rmap?['start_date'] ?? ''} – ${rmap?['end_date'] ?? ''}',
                              apt,
                            ]);
                          }
                          await LegalPartePdf.printVisitorBook(
                            title: 'legal_spain.book_title'.tr(),
                            rows: data,
                          );
                        },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  label: Text('legal_spain.export_pdf'.tr()),
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? legalSpainEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'legal_spain.empty_book'.tr(),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final m = rows[i];
                        final name =
                            '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                        return LegalSpainStayCard(
                          title: name.isEmpty
                              ? 'legal_spain.unnamed_guest'.tr()
                              : name,
                          subtitle:
                              '${m['document_type'] ?? ''} ${m['document_number'] ?? ''}'
                                  .trim(),
                          leadingIcon: Icons.person_outline_rounded,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ApartmentsTab extends ConsumerWidget {
  const _ApartmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apts = ref.watch(apartmentsFullListProvider);
    return apts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => legalSpainErrorState(
        context,
        onRetry: () => ref.invalidate(apartmentsFullListProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return legalSpainEmptyState(
            icon: Icons.apartment_outlined,
            title: 'legal_spain.empty_apartments'.tr(),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final a = list[i];
            return LegalSpainStayCard(
              title: a.name,
              subtitle: a.address ?? '',
              leadingIcon: Icons.apartment_rounded,
              onTap: () => showLegalSpainPanel(
                context: context,
                title: 'legal_spain.apartment_settings_title'.tr(),
                content: SingleChildScrollView(
                  child: ApartmentLegalSettingsForm(apartmentId: a.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
