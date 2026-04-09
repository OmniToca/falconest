import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/task_guest_cash_summary.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/utils/worker_google_maps_uri.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';

/// Obsah scrollu pro úkol typu Transfer – bez vlastního Scaffold; vykresluje ho [WorkerTaskDetailScreen].
///
/// PROČ: Jeden master Scaffold + AppBar eliminuje dvojité hlavičky a umožní sticky čas pod AppBar.
abstract final class TransferTaskScreen {
  TransferTaskScreen._();

  static const Color backgroundColor = Color(0xFFE3F2FD);

  static List<Widget> buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    WorkerTaskDetail detail,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.report_problem_outlined),
        onPressed: () {
          final tenantId = ref.read(authNotifierProvider).tenantIdForData;
          if (tenantId == null || tenantId.isEmpty) return;
          showDialog(
            context: context,
            builder: (ctx) => IssueReporterDialog(
              tenantId: tenantId,
              apartmentId: detail.apartmentId,
            ),
          );
        },
      ),
    ];
  }

  static BeforeCompleteCallback? beforeComplete(String taskId, WorkerTaskDetail detail) {
    return (ctx, ref, mediaUrls, {localPhotoPaths}) => maybeShowCashCollectionDialog(
          ctx,
          ref,
          detail,
          taskId: taskId,
          onCompleted: () {
            ref.invalidate(workerTaskDetailProvider(taskId));
            if (ctx.mounted) ctx.pop();
          },
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          localPhotoPaths: localPhotoPaths,
        );
  }

  static List<Widget> buildScrollChildren(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    WorkerTaskDetail detail,
  ) {
    return [
      ..._buildContactAndLocationCard(context, detail),
      const SizedBox(height: 16),
      ..._buildKeyboxAndGuestContact(context, detail),
      const SizedBox(height: 16),
      _buildInstructionsCard(context, detail.description, detail.metadata ?? {}),
      ..._buildFlightInfo(context, detail.flightNumber),
      ..._buildTransferMetadata(context, ref, detail.metadata ?? {}),
    ];
  }

  /// Karta Kontakt a Lokace – jméno, adresa (s navigací), odhad času.
  static List<Widget> _buildContactAndLocationCard(BuildContext context, WorkerTaskDetail detail) {
    final displayName = detail.displayName.trim();
    final displayAddress = detail.displayAddress.trim();
    final addressLine = displayAddress.isNotEmpty
        ? displayAddress
        : (detail.hasGps ? '${detail.latitude}, ${detail.longitude}' : '');
    final estimatedMin = parseTaskEstimateMinutes(detail.description, detail.metadata);
    final hasAny = displayName.isNotEmpty || addressLine.isNotEmpty || estimatedMin > 0;
    if (!hasAny) return [];

    return [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (displayName.isNotEmpty) _buildContactRow(context, Icons.person, displayName),
              if (displayName.isNotEmpty && (addressLine.isNotEmpty || estimatedMin > 0))
                const SizedBox(height: 12),
              if (addressLine.isNotEmpty) _buildAddressRowWithNavigate(context, detail, addressLine),
              if (addressLine.isNotEmpty && estimatedMin > 0) const SizedBox(height: 12),
              if (estimatedMin > 0)
                _buildContactRow(
                  context,
                  Icons.access_time,
                  'worker.estimated_time'.tr(namedArgs: {'minutes': '$estimatedMin'}),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  static Widget _buildContactRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
        ),
      ],
    );
  }

  static Widget _buildAddressRowWithNavigate(
    BuildContext context,
    WorkerTaskDetail detail,
    String addressLine,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, size: 22, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  addressLine,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 22),
                color: Colors.blue.shade700,
                onPressed: () async {
                  final copyText = detail.hasGps
                      ? '${detail.displayAddress} (GPS: ${detail.latitude}, ${detail.longitude})'
                      : addressLine;
                  await Clipboard.setData(ClipboardData(text: copyText.trim()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('worker.address_copied'.tr()),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                tooltip: 'worker.copy_address_tooltip'.tr(),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  await launchWorkerGoogleMapsSearch(
                    hasGps: detail.hasGps,
                    latitude: detail.latitude,
                    longitude: detail.longitude,
                    addressFallback: addressLine,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 20, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'worker.maps'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildKeyboxAndGuestContact(BuildContext context, WorkerTaskDetail detail) {
    final widgets = <Widget>[];
    final keybox = detail.keybox?.trim();
    final guestName = detail.displayName.trim().isNotEmpty ? detail.displayName.trim() : null;
    final guestPhone = TemplatePlaceholderService.resolveGuestPhone(detail)?.trim();
    if (keybox != null && keybox.isNotEmpty) {
      widgets.add(_buildKeyboxCard(keybox));
      widgets.add(const SizedBox(height: 12));
    }
    if (guestName != null && guestName.isNotEmpty || guestPhone != null && guestPhone.isNotEmpty) {
      widgets.add(_buildGuestContactCard(context, guestName, guestPhone));
    }
    return widgets;
  }

  static Widget _buildKeyboxCard(String keybox) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key, size: 24, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.label_keybox'.tr(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(keybox, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGuestContactCard(BuildContext context, String? guestName, String? guestPhone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (guestName != null && guestName.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'worker.label_guest_name'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(guestName, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (guestPhone != null && guestPhone.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'worker.label_guest_phone'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(guestPhone, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                final tel = guestPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                launchUrl(Uri.parse('tel:$tel'), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.phone, size: 20),
              label: Text('worker.guest_call'.tr()),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildInstructionsCard(BuildContext context, String description, Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    final descTrimmed = description.trim();
    final hasContent = descTrimmed.isNotEmpty || noteText.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    final parts = <String>[];
    if (descTrimmed.isNotEmpty) parts.add(descTrimmed);
    if (noteText.isNotEmpty) parts.add(noteText);
    final content = parts.join(parts.length > 1 ? '\n\n' : '');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'worker.instructions_flight_info'.tr(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(content, style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }

  static List<Widget> _buildFlightInfo(BuildContext context, String? fn) {
    final flight = fn?.trim();
    if (flight == null || flight.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.flight_takeoff, color: Colors.blue.shade700, size: 28),
          title: Text(
            flight.toUpperCase(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
          ),
          subtitle: Text('tasks.track_flight'.tr()),
          trailing: const Icon(Icons.open_in_new, color: Colors.blue),
          onTap: () async {
            final uri = Uri.parse('https://www.flightradar24.com/data/flights/${flight.toUpperCase()}');
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e, st) {
              AppLogger.error('TransferTaskScreen: otevření odkazu FlightRadar selhalo', e, st);
            }
          },
        ),
      ),
    ];
  }

  static List<Widget> _buildTransferMetadata(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> meta,
  ) {
    final widgets = <Widget>[];
    final agency = taskMetadataAmountEur(meta, 'amount_to_collect');
    final transit = taskMetadataAmountEur(meta, 'transit_amount_to_collect');
    if (agency + transit > 0) {
      widgets.addAll([
        const SizedBox(height: 16),
        TaskGuestCashSummary(
          agencyEur: agency,
          transitEur: transit,
          formatEurAmount: (e) => formatTaskAmount(context, ref, e),
          variant: TaskGuestCashSummaryVariant.workerBanner,
        ),
      ]);
    }
    return widgets;
  }
}
