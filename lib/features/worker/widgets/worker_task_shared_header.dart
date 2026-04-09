import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/utils/worker_google_maps_uri.dart';
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
    this.latitude,
    this.longitude,
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

  /// Volitelné WGS 84 z DB – při vyplnění navigace použije `lat,lon` místo textu adresy.
  final double? latitude;

  /// Volitelné WGS 84 z DB – viz [latitude].
  final double? longitude;

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
        _buildAddressWithNavigate(
          context,
          apartmentAddress?.trim() ?? '',
          latitude,
          longitude,
        ),
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
  Widget _buildAddressWithNavigate(
    BuildContext context,
    String address,
    double? lat,
    double? lon,
  ) {
    final hasGps = lat != null && lon != null;
    final line = address.isNotEmpty ? address : (hasGps ? '$lat, $lon' : '');
    final showNavigate = line.isNotEmpty || hasGps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          line.isEmpty ? 'common.placeholder_dash'.tr() : line,
          style: TextStyle(fontSize: 17, color: Colors.grey.shade800),
        ),
        if (showNavigate) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _openMaps(context, address, lat, lon),
            icon: const Icon(Icons.map, size: 20),
            label: Text('worker.task_detail_navigate'.tr()),
          ),
        ],
      ],
    );
  }

  Future<void> _openMaps(
    BuildContext context,
    String address,
    double? lat,
    double? lon,
  ) async {
    final hasGps = lat != null && lon != null;
    await launchWorkerGoogleMapsSearch(
      hasGps: hasGps,
      latitude: lat,
      longitude: lon,
      addressFallback: address,
    );
  }
}

/// Adresa + navigace bez velkého nadpisu a odpočtu (ty jsou v master [WorkerTaskDetailScreen]).
///
/// PROČ: Po přesunu času do sticky lišty zůstává v scrollu jen kontext „kde jedu“, konzistentně s požadavkem
/// CTO na odstranění duplicitních nadpisů z typových obrazovek.
class WorkerTaskAddressContextBar extends StatelessWidget {
  const WorkerTaskAddressContextBar({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
  });

  /// Adresa jednoho řádku nebo více – typicky [WorkerTaskDetail.displayAddress].
  final String address;

  /// WGS 84 z DB – navigace přednostně jako `lat,lon`.
  final double? latitude;

  /// WGS 84 z DB – viz [latitude].
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final a = address.trim();
    final hasGps = latitude != null && longitude != null;
    final line = a.isNotEmpty ? a : (hasGps ? '$latitude, $longitude' : '');
    final showNavigate = line.isNotEmpty || hasGps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          line.isEmpty ? 'common.placeholder_dash'.tr() : line,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
        ),
        if (showNavigate) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _openMaps(context, a),
            icon: const Icon(Icons.map, size: 20),
            label: Text('worker.task_detail_navigate'.tr()),
          ),
        ],
      ],
    );
  }

  Future<void> _openMaps(BuildContext context, String addressFallback) async {
    await launchWorkerGoogleMapsSearch(
      hasGps: latitude != null && longitude != null,
      latitude: latitude,
      longitude: longitude,
      addressFallback: addressFallback,
    );
  }
}
