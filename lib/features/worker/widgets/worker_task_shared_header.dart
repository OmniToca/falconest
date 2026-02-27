import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';

/// Sjednocená hlavička a odpočet času pro VŠECHNY obrazovky úkolů (Check-in, Check-out, Úklid, Transfer, Závada, Údržba, Materiál, Default).
///
/// PROČ: CTO si oblíbil layout obrazovky Check-out – Název, Datum, Adresa, tlačítko Navigovat
/// a zelený box s odpočtem "Zbývá času". Tento widget sjednocuje vizuální styl a odpočet
/// na všech 8 typech úkolů, aby uživatel měl konzistentní UX bez ohledu na typ úkolu.
///
/// Obsahuje:
/// 1. [TaskHeaderWidget] – nadpis (title) a datum/čas (scheduledStart) s ikonou hodin
/// 2. Adresa bytu s tlačítkem Navigovat (otevře Google Maps)
/// 3. [TaskCountdownTimer] – zelený box s živým odpočtem (při in_progress od startedAt do startedAt+duration)
///
/// Volající obrazovka předává [title], [scheduledStart], [apartmentAddress], [startedAt], [completedAt]
/// a [estimatedMinutes]. Každá obrazovka si sama odvodí title (např. Check-in/Transfer používají část za dvojtečkou).
class WorkerTaskSharedHeader extends StatelessWidget {
  const WorkerTaskSharedHeader({
    super.key,
    required this.title,
    this.scheduledStart,
    this.apartmentAddress,
    this.startedAt,
    this.completedAt,
    required this.estimatedMinutes,
  });

  /// Hlavní nadpis úkolu (např. "Petr Sokol", "Úklid bytu 3A").
  final String title;

  /// Plánovaný začátek – zobrazen pod nadpisem s ikonou hodin.
  final DateTime? scheduledStart;

  /// Adresa bytu – zobrazena s tlačítkem Navigovat.
  final String? apartmentAddress;

  /// Skutečný čas zahájení práce (UTC). Pro odpočet – když in_progress, počítá do startedAt + estimatedMinutes.
  final DateTime? startedAt;

  /// Při dokončení se odpočet nezobrazuje.
  final DateTime? completedAt;

  /// Odhad času v minutách (parsováno z description/metadata pomocí parseTaskEstimateMinutes).
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskHeaderWidget(
          title: title,
          scheduledStart: scheduledStart,
        ),
        const SizedBox(height: 16),
        _buildAddressWithNavigate(context, apartmentAddress?.trim() ?? ''),
        const SizedBox(height: 16),
        TaskCountdownTimer(
          startedAt: startedAt,
          completedAt: completedAt,
          estimatedMinutes: estimatedMinutes,
        ),
      ],
    );
  }

  /// Adresa s tlačítkem Navigovat – otevře Google Maps (spolehlivý formát pro iOS i Android).
  Widget _buildAddressWithNavigate(BuildContext context, String address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          address.isEmpty ? '—' : address,
          style: TextStyle(fontSize: 17, color: Colors.grey.shade800),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _openMaps(context, address),
            icon: const Icon(Icons.map, size: 20),
            label: Text('worker.task_detail_navigate'.tr()),
          ),
        ],
      ],
    );
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    final query = address.trim();
    if (query.isEmpty) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
