import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';
import 'package:falconest/features/legal_spain/utils/legal_parte_pdf.dart';
import 'package:falconest/features/legal_spain/widgets/apartment_legal_settings_form.dart';
import 'package:falconest/features/legal_spain/widgets/legal_status_chip.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';

/// Admin přehled compliance (dnes / čeká podpis / SES chyba) + kódy SES u bytů.
class AdminLegalSpainScreen extends ConsumerWidget {
  const AdminLegalSpainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isModuleActive(ref, kLegalSpainModuleKey)) {
      return Scaffold(
        appBar: AppBar(title: Text('modules.legal_spain.title'.tr())),
        body: Center(
          child: FilledButton(
            onPressed: () => PremiumUpsellDialog.show(
              context,
              moduleKey: kLegalSpainModuleKey,
              titleKey: 'modules.legal_spain.title',
              descriptionKey: 'legal_spain.upsell_desc',
            ),
            child: Text('legal_spain.unlock'.tr()),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('modules.legal_spain.title'.tr()),
          bottom: TabBar(
            tabs: [
              Tab(text: 'legal_spain.tab_dashboard'.tr()),
              Tab(text: 'legal_spain.tab_book'.tr()),
              Tab(text: 'legal_spain.tab_apartments'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DashboardTab(),
            _BookTab(),
            _ApartmentsTab(),
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
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(child: Text('legal_spain.empty_dashboard'.tr()));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final df = DateFormat.yMMMd(context.locale.toString());
            final dates = [
              if (r.startDate != null) df.format(r.startDate!),
              if (r.endDate != null) df.format(r.endDate!),
            ].join(' – ');
            return ListTile(
              title: Text(r.guestName?.trim().isNotEmpty == true
                  ? r.guestName!
                  : 'legal_spain.unnamed_guest'.tr()),
              subtitle: Text('${r.apartmentName ?? '–'} · $dates'),
              trailing: LegalStatusChip(status: r.status),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(16),
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
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton.tonalIcon(
                  onPressed: () async {
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
                        '${m['first_name'] ?? ''} ${m['last_name'] ?? ''} ${m['second_last_name'] ?? ''}'.trim(),
                        '${m['document_type'] ?? ''} ${m['document_number'] ?? ''}'.trim(),
                        '${rmap?['start_date'] ?? ''} – ${rmap?['end_date'] ?? ''}',
                        apt,
                      ]);
                    }
                    await LegalPartePdf.printVisitorBook(
                      title: 'legal_spain.book_title'.tr(),
                      rows: data,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('legal_spain.export_pdf'.tr()),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final m = rows[i];
                  return ListTile(
                    title: Text('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim()),
                    subtitle: Text('${m['document_type'] ?? ''} ${m['document_number'] ?? ''}'),
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
      error: (e, _) => Center(child: Text('$e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final a = list[i];
          return ListTile(
            title: Text(a.name),
            subtitle: Text(a.address ?? ''),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: ApartmentLegalSettingsForm(apartmentId: a.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
