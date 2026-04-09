import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/features/owner/providers/owner_apartment_detail_provider.dart';

/// UI: Read-only detail apartmánu pro majitele se základními informacemi.
///
/// Zobrazuje data z tabulky apartments v logických sekcích (základní info,
/// přístup, časy, poznámky). Majitel může pouze prohlížet a kopírovat hodnoty.
class OwnerApartmentDetailScreen extends ConsumerWidget {
  const OwnerApartmentDetailScreen({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(ownerApartmentDetailProvider(apartmentId));

    // Bez Scaffold – detail se otevírá v Dialogu, zachová se pozadí layoutu.
    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'owner.apartment_detail_not_found'.tr(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.cancel'.tr()),
                ),
              ],
            ),
          );
        }
        return _DetailContentWithHeader(detail: detail);
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'owner.apartments_load_error'.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Obsah s hlavičkou (název bytu + křížek pro zavření).
class _DetailContentWithHeader extends StatelessWidget {
  const _DetailContentWithHeader({required this.detail});

  final OwnerApartmentDetail detail;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    detail.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'common.cancel'.tr(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _DetailContent(detail: detail),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollovatelný obsah – karty v logických sekcích.
class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.detail});

  final OwnerApartmentDetail detail;

  void _copyToClipboard(BuildContext context, String value, String labelKey) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('owner.copied_to_clipboard'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Základní informace
        _SectionCard(
          title: 'owner.detail_section_basic'.tr(),
          children: [
            _DetailTile(
              label: 'owner.detail_address'.tr(),
              value: detail.address ?? 'owner.detail_not_set'.tr(),
            ),
            _DetailTile(
              label: 'owner.detail_status'.tr(),
              value: _statusLabel(detail.status),
            ),
          ],
        ),
        if (detail.reviewLink != null && detail.reviewLink!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _GuestReviewLinkCard(url: detail.reviewLink!.trim()),
        ],
        const SizedBox(height: 16),
        _CalendarFeedSyncCard(
          url: detail.calendarFeedUrl,
        ),
        const SizedBox(height: 16),

        // Časy příjezdu/odjezdu
        _SectionCard(
          title: 'owner.detail_section_times'.tr(),
          children: [
            _DetailTile(
              label: 'owner.detail_check_in_time'.tr(),
              value: detail.checkInTime ?? 'owner.detail_not_set'.tr(),
            ),
            _DetailTile(
              label: 'owner.detail_check_out_time'.tr(),
              value: detail.checkOutTime ?? 'owner.detail_not_set'.tr(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Přístup – keybox s možností kopírování
        _SectionCard(
          title: 'owner.detail_section_access'.tr(),
          children: [
            _DetailTileWithCopy(
              label: 'owner.detail_keybox'.tr(),
              value: detail.keybox ?? 'owner.detail_not_set'.tr(),
              onCopy: detail.keybox != null && detail.keybox!.isNotEmpty
                  ? () => _copyToClipboard(context, detail.keybox!, 'owner.detail_keybox')
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Úklid
        if (detail.standardCleaningDuration != null) ...[
          _SectionCard(
            title: 'owner.detail_section_cleaning'.tr(),
            children: [
              _DetailTile(
                label: 'owner.detail_cleaning_duration'.tr(),
                value: 'owner.detail_cleaning_minutes'.tr(
                  namedArgs: {'minutes': detail.standardCleaningDuration.toString()},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Poznámky
        _SectionCard(
          title: 'owner.detail_section_notes'.tr(),
          children: [
            _DetailTile(
              label: 'owner.detail_owner_notes'.tr(),
              value: detail.ownerNotes ?? 'owner.detail_not_set'.tr(),
              expanded: true,
            ),
          ],
        ),
      ],
    );
  }

  String _statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'owner.detail_not_set'.tr();
    switch (status) {
      case 'Uklizeno':
        return 'owner.status_clean'.tr();
      case 'K úklidu':
        return 'owner.status_pending'.tr();
      case 'Probíhá úklid':
        return 'owner.status_cleaning'.tr();
      case 'Obsazeno hosty':
        return 'owner.detail_status_occupied'.tr();
      case 'Rekonstrukce':
        return 'owner.detail_status_renovation'.tr();
      default:
        return status;
    }
  }
}

/// Tlačítko otevření odkazu na recenze hostů (Booking/Airbnb).
///
/// PROČ: Majitel dostane jeden klik do prohlížeče; bez hardcoded textů.
class _GuestReviewLinkCard extends StatelessWidget {
  const _GuestReviewLinkCard({required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('owner.detail_link_open_failed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'owner.detail_guest_reviews_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_new, size: 20),
              label: Text('owner.detail_guest_reviews_open'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sekce iCal synchronizace – URL z RPC (pokud agentura token založila), jinak lokalizovaná výzva.
///
/// PROČ: Majitel nevidí hash tokenu; zobrazíme jen uloženou veřejnou URL nebo kontakt na agenturu.
class _CalendarFeedSyncCard extends StatelessWidget {
  const _CalendarFeedSyncCard({this.url});

  final String? url;

  void _copyUrl(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('owner.copied_to_clipboard'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    final hasUrl = trimmed != null && trimmed.isNotEmpty;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'owner.detail_calendar_sync_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'owner.detail_calendar_sync_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 12),
            if (hasUrl) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    trimmed,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _copyUrl(context, trimmed),
                icon: const Icon(Icons.copy_outlined, size: 20),
                label: Text('owner.detail_calendar_sync_copy'.tr()),
              ),
            ] else
              Text(
                'owner.detail_calendar_sync_contact_agency'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade800,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Karta sekce s nadpisem.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Řádek detailu – label + hodnota.
class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
    this.expanded = false,
  });

  final String label;
  final String value;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: expanded ? null : 1,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Řádek s tlačítkem pro zkopírování.
class _DetailTileWithCopy extends StatelessWidget {
  const _DetailTileWithCopy({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              onPressed: onCopy,
              tooltip: 'owner.copy_to_clipboard'.tr(),
            ),
        ],
      ),
    );
  }
}
