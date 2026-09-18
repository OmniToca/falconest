import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';
import 'package:falconest/features/legal_spain/widgets/legal_spain_ui.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';

/// Přehled SES semaforu v klientském portálu (jen když tenant má modul).
///
/// PROČ bez AppBar: [OwnerLayout] už drží navigaci. Vizuál kopíruje dashboard
/// majitele (headline, constrain, karty) místo admin ListTile.
class OwnerLegalSpainScreen extends ConsumerWidget {
  const OwnerLegalSpainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aptsAsync = ref.watch(ownerApartmentsProvider);
    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLowest,
      body: SafeArea(
        child: ownerPortalConstrainBody(
          child: aptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => legalSpainErrorState(
              context,
              onRetry: () => ref.invalidate(ownerApartmentsProvider),
            ),
            data: (apts) {
              final ids =
                  apts.map((a) => a.id).where((id) => id.isNotEmpty).join(',');
              final rowsAsync = ref.watch(legalComplianceDashboardProvider(ids));
              return rowsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => legalSpainErrorState(
                  context,
                  onRetry: () =>
                      ref.invalidate(legalComplianceDashboardProvider(ids)),
                ),
                data: (rows) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                        child: Column(
                          children: [
                            Text(
                              'modules.legal_spain.title'.tr(),
                              style: context.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'legal_spain.subtitle'.tr(),
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: rows.isEmpty
                            ? legalSpainEmptyState(
                                icon: Icons.badge_outlined,
                                title: 'legal_spain.empty_dashboard'.tr(),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  AppSpacing.md,
                                  0,
                                  32,
                                ),
                                itemCount: rows.length,
                                itemBuilder: (context, i) {
                                  final r = rows[i];
                                  final name = r.guestName?.trim().isNotEmpty ==
                                          true
                                      ? r.guestName!
                                      : 'legal_spain.unnamed_guest'.tr();
                                  return LegalSpainStayCard(
                                    title: name,
                                    subtitle: r.apartmentName ?? '',
                                    status: r.status,
                                    onTap: () => showLegalSpainPanel(
                                      context: context,
                                      title: 'legal_spain.stay_detail_title'.tr(),
                                      content: SingleChildScrollView(
                                        child: ReservationLegalSection(
                                          reservationId: r.reservationId,
                                          apartmentId: r.apartmentId,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
