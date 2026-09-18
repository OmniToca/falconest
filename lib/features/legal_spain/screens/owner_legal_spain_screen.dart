import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';
import 'package:falconest/features/legal_spain/widgets/legal_status_chip.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Přehled SES semaforu v klientském portálu (jen když tenant má modul).
class OwnerLegalSpainScreen extends ConsumerWidget {
  const OwnerLegalSpainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aptsAsync = ref.watch(ownerApartmentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('modules.legal_spain.title'.tr())),
      body: aptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (apts) {
          final ids = apts.map((a) => a.id).where((id) => id.isNotEmpty).join(',');
          final rowsAsync = ref.watch(legalComplianceDashboardProvider(ids));
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
                  return ListTile(
                    title: Text(r.guestName ?? 'legal_spain.unnamed_guest'.tr()),
                    subtitle: Text(r.apartmentName ?? ''),
                    trailing: LegalStatusChip(status: r.status),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: ReservationLegalSection(
                          reservationId: r.reservationId,
                          apartmentId: r.apartmentId,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
