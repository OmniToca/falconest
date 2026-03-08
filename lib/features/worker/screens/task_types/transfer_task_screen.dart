import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/currency_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/communication/providers/message_templates_provider.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/core/database/models/message_template_local.dart';
import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';

/// MVP obrazovka pro úkoly typu Transfer (předání/převzetí bytu).
/// Jednoduché zobrazení dat a tlačítko Dokončit.
class TransferTaskScreen extends ConsumerWidget {
  const TransferTaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workerTaskDetailProvider(taskId));
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData ?? '';
    final templatesAsync = ref.watch(messageTemplatesForWorkerProvider(tenantId));
    final templates = templatesAsync.valueOrNull ?? [];

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            body: Center(child: Text('worker.task_detail_not_found'.tr())),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFFE3F2FD),
          appBar: AppBar(
            title: Text(
              _appBarTitle(detail),
              style: const TextStyle(color: Colors.black87),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
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
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaskHeaderWidget(
                          title: _mainHeading(detail),
                          scheduledStart: detail.scheduledStart,
                        ),
                        const SizedBox(height: 16),
                        TaskCountdownTimer(
                          startedAt: detail.startedAt,
                          completedAt: detail.completedAt,
                          estimatedMinutes: parseTaskEstimateMinutes(
                            detail.description,
                            detail.metadata,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // PROČ: Karta Kontakt a Lokace – jméno, adresa (s navigací), odhad času. Používá displayName/displayAddress pro ruční i automatické úkoly.
                        ..._buildContactAndLocationCard(context, detail),
                        const SizedBox(height: 16),
                        // PROČ: Kód schránky a kontakt na hosta – řidič řeší zpoždění a předání klíčů.
                        ..._buildKeyboxAndGuestContact(context, detail),
                        const SizedBox(height: 16),
                        _buildInstructionsCard(context, detail.description, detail.metadata ?? {}),
                        ..._buildFlightInfo(context, detail.flightNumber),
                        ..._buildQuickMessagesSection(context, detail, templates),
                        ..._buildTransferMetadata(context, ref, detail.metadata ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TaskCompleteWithPhotoSection(
                  taskId: taskId,
                  detail: detail,
                  finishKey: 'worker.task_detail_finish_transfer',
                  beforeComplete: (ctx, ref, mediaUrls, {localPhotoPaths}) =>
                      maybeShowCashCollectionDialog(
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        body: Center(child: Text('worker.task_detail_not_found'.tr())),
      ),
    );
  }

  /// Karta Kontakt a Lokace – jméno, adresa (s navigací), odhad času.
  /// PROČ: Jednotné zobrazení pro ruční i automatické úkoly – používá displayName/displayAddress.
  static List<Widget> _buildContactAndLocationCard(BuildContext context, dynamic detail) {
    final displayName = detail.displayName.trim();
    final displayAddress = detail.displayAddress.trim();
    final estimatedMin = parseTaskEstimateMinutes(detail.description, detail.metadata);
    final hasAny = displayName.isNotEmpty || displayAddress.isNotEmpty || estimatedMin > 0;
    if (!hasAny) return [];

    return [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (displayName.isNotEmpty)
                _buildContactRow(context, Icons.person, displayName),
              if (displayName.isNotEmpty && (displayAddress.isNotEmpty || estimatedMin > 0))
                const SizedBox(height: 12),
              if (displayAddress.isNotEmpty)
                _buildAddressRowWithNavigate(context, displayAddress),
              if (displayAddress.isNotEmpty && estimatedMin > 0) const SizedBox(height: 12),
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

  static Widget _buildAddressRowWithNavigate(BuildContext context, String address) {
    // Adresa víceřádkově, tlačítka pod ní – aby nedocházelo k ořezávání
    // dlouhých adres (např. španělské s názvem ulice i čísla domu na více řádcích).
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
                  address,
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
                  await Clipboard.setData(ClipboardData(text: address));
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
                  final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
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

  /// Kód schránky a kontakt na hosta – řidič musí řešit zpoždění a předání.
  /// PROČ: Používá resolveGuestPhone (Fallback Chain) pro zobrazení telefonu.
  List<Widget> _buildKeyboxAndGuestContact(BuildContext context, dynamic detail) {
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

  Widget _buildKeyboxCard(String keybox) {
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

  Widget _buildGuestContactCard(BuildContext context, String? guestName, String? guestPhone) {
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

  /// AppBar: část PŘED dvojtečkou (např. „Transfer Z letiště“) + referenční číslo.
  static String _appBarTitle(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    final base = raw.split(':').first.trim();
    final ref = detail.referenceNumber?.trim();
    return (ref != null && ref.isNotEmpty) ? '$base • #$ref' : base;
  }

  /// Hlavní nadpis: část ZA dvojtečkou, nebo celý název (např. „Petr Sokol“).
  static String _mainHeading(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.contains(':') ? raw.split(':').sublist(1).join(':').trim() : raw;
  }

  /// Karta Instrukce / Informace o letu – description + custom_note (číslo letu, jméno klienta).
  Widget _buildInstructionsCard(BuildContext context, String description, Map<String, dynamic> meta) {
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

  /// Sekce „Rychlé zprávy hostovi“ – tlačítka pro odeslání šablon přes WhatsApp.
  /// PROČ: Řidič rychle pošle předpřipravené zprávy (48h předem, Jsem u letiště…).
  /// Pokud nejsou žádné šablony, sekce se nezobrazí.
  static List<Widget> _buildQuickMessagesSection(
    BuildContext context,
    WorkerTaskDetail detail,
    List<MessageTemplateLocal> templates,
  ) {
    if (templates.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'worker.quick_messages'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: templates
                    .map(
                      (t) => OutlinedButton.icon(
                        onPressed: () =>
                            _sendTemplateMessage(context, t, detail),
                        icon: Icon(Icons.chat_bubble_outline, size: 18, color: Colors.green.shade700),
                        label: Text(t.name),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          side: BorderSide(color: Colors.green.shade400),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// Odeslání šablony přes WhatsApp – otevře wa.me s předvyplněným textem.
  /// PROČ: url_launcher s externalApplication otevře nativní WhatsApp na mobilu.
  /// Používá resolveGuestPhone (Fallback Chain) – ne jen detail.guestPhone.
  static Future<void> _sendTemplateMessage(
    BuildContext context,
    MessageTemplateLocal template,
    WorkerTaskDetail detail,
  ) async {
    final resolvedPhone = TemplatePlaceholderService.resolveGuestPhone(detail);
    if (resolvedPhone == null || resolvedPhone.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.error_missing_phone'.tr())),
        );
      }
      return;
    }

    // Očista telefonu – pouze číslice (wa.me nechce + ve path).
    final cleanedPhone = resolvedPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.error_missing_phone'.tr())),
        );
      }
      return;
    }

    final contextMap =
        TemplatePlaceholderService.buildContextFromTask(detail);
    final parsedText =
        TemplatePlaceholderService.replacePlaceholders(template.body, contextMap);
    final encodedText = Uri.encodeComponent(parsedText);
    final url = Uri.parse('https://wa.me/$cleanedPhone?text=$encodedText');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Uživatel uvidí, že se nic nestalo; typicky chybí WhatsApp nebo omezení OS.
      assert(false, 'launchUrl failed: $e');
    }
  }

  /// Karta čísla letu s proklikem na FlightRadar24 – používá nativní detail.flightNumber.
  /// PROČ: Řidič potřebuje sledovat zpoždění letu; URL formát FlightRadar24: /data/flights/{flightNumber}.
  /// Zdroj: reservation_services.flight_number → tasks.metadata při vytvoření úkolu. Bez parsování [FLIGHT:XXX].
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
            } catch (_) {}
          },
        ),
      ),
    ];
  }

  /// Vykreslení metadat pro Transfer: obří banner na peníze (custom_note je již v kartě Instrukce).
  List<Widget> _buildTransferMetadata(BuildContext context, WidgetRef ref, Map<String, dynamic> meta) {
    final widgets = <Widget>[];

    // Vykreslení obřího banneru pro výběr hotovosti.
    final amountRaw = meta['amount_to_collect'];
    final amount = (amountRaw is num) ? amountRaw.toDouble() : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
    if (amount != null && amount > 0) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildAmountBanner(context, ref, amount),
      ]);
    }

    return widgets;
  }

  /// Obří banner na částku k vybrání od hosta (amount_to_collect z metadat).
  /// Používá formatTaskAmount – měna dle tenanta, fallback profil uživatele.
  Widget _buildAmountBanner(BuildContext context, WidgetRef ref, num amount) {
    final formatted = formatTaskAmount(context, ref, amount);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade400, width: 2),
      ),
      child: Column(
        children: [
          Text(
            'worker.task_amount_to_collect'.tr(),
            style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
