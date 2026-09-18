import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/models/reservation_guest.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';
import 'package:falconest/features/legal_spain/repositories/legal_spain_repository.dart';
import 'package:falconest/features/legal_spain/widgets/legal_guest_form.dart';
import 'package:falconest/features/legal_spain/widgets/legal_spain_ui.dart';
import 'package:falconest/features/legal_spain/widgets/legal_status_chip.dart';

/// Sekce Hosté u rezervace – vyplnit v aplikaci nebo poslat veřejný formulář.
///
/// PROČ: Dva sběry (A in-app, B odkaz) zapisují totéž do reservation_guests.
class ReservationLegalSection extends ConsumerWidget {
  const ReservationLegalSection({
    super.key,
    required this.reservationId,
    required this.apartmentId,
    this.guestPhone,
    this.guestEmail,
    this.readOnly = false,
    this.showSesRetry = false,
  });

  final String reservationId;
  final String apartmentId;
  final String? guestPhone;
  final String? guestEmail;
  final bool readOnly;
  final bool showSesRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isModuleActive(ref, kLegalSpainModuleKey)) {
      return const SizedBox.shrink();
    }
    final guestsAsync = ref.watch(reservationGuestsProvider(reservationId));
    final checkinAsync = ref.watch(guestCheckinProvider(reservationId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'legal_spain.guests_section'.tr(),
          style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        checkinAsync.when(
          data: (c) => c == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      LegalStatusChip(status: c.status),
                      if ((c.lastError ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.lastError!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('common.generic_error_user_friendly'.tr()),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: readOnly ? null : () => _sendLink(context, ref),
              icon: const Icon(Icons.link, size: 20),
              label: Text('legal_spain.send_form'.tr()),
            ),
            if (showSesRetry)
              OutlinedButton.icon(
                onPressed: readOnly
                    ? null
                    : () async {
                        await ref.read(legalSpainRepositoryProvider).enqueuePv(reservationId);
                        ref.invalidate(guestCheckinProvider(reservationId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('legal_spain.requeued'.tr())),
                          );
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: Text('legal_spain.resend_ses'.tr()),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        guestsAsync.when(
          data: (guests) => Column(
            children: [
              for (final g in guests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: premiumCardShell(
                    context,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: context.colors.secondaryContainer,
                        child: Icon(
                          g.isMinorUnder14
                              ? Icons.child_care_outlined
                              : Icons.person_outline_rounded,
                          color: context.colors.onSecondaryContainer,
                        ),
                      ),
                      title: Text(
                        g.displayName.isEmpty
                            ? 'legal_spain.unnamed_guest'.tr()
                            : g.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        g.isMinorUnder14
                            ? 'legal_spain.minor_under_14'.tr()
                            : (g.isSigned
                                ? 'legal_spain.already_signed'.tr()
                                : 'legal_spain.awaiting_signature'.tr()),
                      ),
                      trailing: readOnly
                          ? LegalStatusChip(status: g.isSigned ? 'reported' : 'draft')
                          : IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openGuest(context, ref, g),
                            ),
                    ),
                  ),
                ),
              if (!readOnly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _openGuest(
                      context,
                      ref,
                      ReservationGuest(
                        id: '',
                        tenantId: ref.read(authNotifierProvider).tenantIdForData ?? '',
                        reservationId: reservationId,
                      ),
                    ),
                    icon: const Icon(Icons.person_add_outlined, size: 20),
                    label: Text('legal_spain.add_guest'.tr()),
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('common.generic_error_user_friendly'.tr()),
        ),
      ],
    );
  }

  Future<void> _openGuest(BuildContext context, WidgetRef ref, ReservationGuest guest) async {
    await showLegalSpainPanel(
      context: context,
      title: guest.id.isEmpty
          ? 'legal_spain.add_guest'.tr()
          : 'legal_spain.guest_form_title'.tr(),
      maxWidth: 640,
      content: SingleChildScrollView(
        child: LegalGuestForm(
          guest: guest,
          onSave: (g) async {
            await ref.read(legalSpainRepositoryProvider).upsertGuest(
                  reservationId: reservationId,
                  guest: g,
                );
            ref.invalidate(reservationGuestsProvider(reservationId));
            if (context.mounted) Navigator.of(context).pop();
          },
          onSign: (b64) async {
            var id = guest.id;
            if (id.isEmpty) {
              final saved = await ref.read(legalSpainRepositoryProvider).upsertGuest(
                    reservationId: reservationId,
                    guest: guest,
                  );
              id = saved.id;
            }
            await ref.read(legalSpainRepositoryProvider).saveSignature(
                  guestId: id,
                  pngBase64: b64,
                );
            ref.invalidate(reservationGuestsProvider(reservationId));
            ref.invalidate(guestCheckinProvider(reservationId));
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _sendLink(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(legalSpainRepositoryProvider);
    final session = await repo.ensureSession(reservationId);
    final settings = await repo.loadApartmentSettings(apartmentId);
    final url = LegalSpainRepository.buildCheckinUrl(
      session.publicToken,
      publicWebOrigin: settings?.publicWebOrigin,
    );
    await Clipboard.setData(ClipboardData(text: url));
    final phone = (guestPhone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    final body = 'legal_spain.checkin_message'.tr(namedArgs: {'link': url});
    if (phone.isNotEmpty) {
      final wa = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}?text=${Uri.encodeComponent(body)}');
      await launchUrl(wa, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('legal_spain.link_copied'.tr())),
      );
    }
    ref.invalidate(guestCheckinProvider(reservationId));
  }
}
