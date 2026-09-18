import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/models/reservation_guest.dart';
import 'package:falconest/features/legal_spain/providers/legal_spain_providers.dart';
import 'package:falconest/features/legal_spain/repositories/legal_spain_repository.dart';
import 'package:falconest/features/legal_spain/widgets/legal_guest_form.dart';
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
        const Divider(),
        Text(
          'legal_spain.guests_section'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        checkinAsync.when(
          data: (c) => c == null
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    LegalStatusChip(status: c.status),
                    if ((c.lastError ?? '').isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(child: Text(c.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    ],
                  ],
                ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: readOnly
                  ? null
                  : () => _sendLink(context, ref),
              icon: const Icon(Icons.link),
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
        const SizedBox(height: AppSpacing.sm),
        guestsAsync.when(
          data: (guests) => Column(
            children: [
              for (final g in guests)
                ListTile(
                  leading: Icon(g.isMinorUnder14 ? Icons.child_care : Icons.person_outline),
                  title: Text(g.displayName.isEmpty ? 'legal_spain.unnamed_guest'.tr() : g.displayName),
                  subtitle: Text(
                    g.isMinorUnder14
                        ? 'legal_spain.minor_under_14'.tr()
                        : (g.isSigned ? 'legal_spain.already_signed'.tr() : 'legal_spain.awaiting_signature'.tr()),
                  ),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openGuest(context, ref, g),
                        ),
                ),
              if (!readOnly)
                TextButton.icon(
                  onPressed: () => _openGuest(
                    context,
                    ref,
                    ReservationGuest(
                      id: '',
                      tenantId: ref.read(authNotifierProvider).tenantIdForData ?? '',
                      reservationId: reservationId,
                    ),
                  ),
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text('legal_spain.add_guest'.tr()),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }

  Future<void> _openGuest(BuildContext context, WidgetRef ref, ReservationGuest guest) async {
    await showModalBottomSheet<void>(
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
          child: LegalGuestForm(
            guest: guest,
            onSave: (g) async {
              await ref.read(legalSpainRepositoryProvider).upsertGuest(
                    reservationId: reservationId,
                    guest: g,
                  );
              ref.invalidate(reservationGuestsProvider(reservationId));
              if (ctx.mounted) Navigator.of(ctx).pop();
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
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
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
