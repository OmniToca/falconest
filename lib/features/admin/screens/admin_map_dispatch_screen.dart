import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';

/// Výchozí střed mapy (Quesada, Španělsko) – zobrazí se, dokud nemáme žádné entity se souřadnicemi.
const LatLng _kMapDefaultCenter = LatLng(38.0753, -0.7262);

/// Zoom při absenci markerů nebo jako horní mez při fit výřezu.
const double _kMapDefaultZoom = 13.0;

/// Živý mapový přehled pro dispečera – apartmány a úkoly s vyplněnou geolokací.
///
/// PROČ: OpenStreetMap + flutter_map bez licenčních poplatků; data z existujících
/// Riverpod providerů (stejný zdroj jako záložky Byty / Úkoly). Obrazovka je vnořená
/// do [AdminLayout] [IndexedStack] (bez vlastního [Scaffold]/AppBar – horní lištu
/// drží admin shell).
///
/// Trasy (Bod 11): dnešní úkoly pracovníka se řadí podle [TaskRow.scheduledStart];
/// polyline (Bod 21): mezi dvěma a více body stejného přiřazení se stejným dnem.
class AdminMapDispatchScreen extends ConsumerStatefulWidget {
  const AdminMapDispatchScreen({super.key});

  @override
  ConsumerState<AdminMapDispatchScreen> createState() =>
      _AdminMapDispatchScreenState();
}

class _AdminMapDispatchScreenState extends ConsumerState<AdminMapDispatchScreen> {
  /// null = všichni pracovníci; jinak UUID profilu (stejné jako [TaskRow.assignedTo]).
  String? _workerFilterId;

  static bool _sameLocalCalendarDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  /// Úkol „dnes“ podle začátku (`scheduled_start` / `due_date`) v lokálním čase.
  static bool _taskIsToday(TaskRow t) {
    final anchor = t.scheduledStart ?? t.dueDate;
    return _sameLocalCalendarDay(anchor, DateTime.now());
  }

  /// Úkol patří vybranému filtru pracovníka (hlavní nebo další přiřazení).
  static bool _taskMatchesWorker(TaskRow t, String workerId) {
    if (t.assignedTo == workerId) return true;
    return t.assignedUserIds.contains(workerId);
  }

  /// Seskupí dnešní úkoly s GPS podle `assigned_to`, seřadí podle času začátku.
  static Map<String, List<TaskRow>> _groupTodayTasksByAssignee(
    List<TaskRow> geoTasks,
  ) {
    final today = geoTasks.where(_taskIsToday).toList();
    final map = <String, List<TaskRow>>{};
    for (final t in today) {
      final id = t.assignedTo?.trim();
      if (id == null || id.isEmpty) continue;
      map.putIfAbsent(id, () => []).add(t);
    }
    for (final e in map.entries) {
      e.value.sort((a, b) {
        final ta = a.scheduledStart ?? a.dueDate;
        final tb = b.scheduledStart ?? b.dueDate;
        return ta.compareTo(tb);
      });
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsFullListProvider);
    final tasksAsync = ref.watch(adminTasksStreamProvider);
    final teamAsync = ref.watch(teamFullListProvider);

    final apartments = apartmentsAsync.valueOrNull ?? const [];
    final tasks = tasksAsync.valueOrNull ?? const [];
    final loading = apartmentsAsync.isLoading || tasksAsync.isLoading;
    final hasError = apartmentsAsync.hasError || tasksAsync.hasError;

    final geoApartments = apartments
        .where(
          (a) =>
              a.latitude != null &&
              a.longitude != null &&
              a.deletedAt == null,
        )
        .toList();
    var geoTasks = tasks
        .where(
          (t) =>
              t.latitude != null &&
              t.longitude != null &&
              t.deletedAt == null,
        )
        .toList();

    if (_workerFilterId != null && _workerFilterId!.isNotEmpty) {
      final w = _workerFilterId!;
      geoTasks = geoTasks.where((t) => _taskMatchesWorker(t, w)).toList();
    }

    final byAssignee = _groupTodayTasksByAssignee(geoTasks);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final polylines = <Polyline>[];
    for (final entry in byAssignee.entries) {
      final list = entry.value;
      if (list.length < 2) continue;
      final points =
          list.map((t) => LatLng(t.latitude!, t.longitude!)).toList();
      polylines.add(
        Polyline(
          points: points,
          strokeWidth: 3,
          color: primaryColor.withValues(alpha: 0.45),
        ),
      );
    }

    final markerPoints = <LatLng>[
      for (final a in geoApartments) LatLng(a.latitude!, a.longitude!),
      for (final t in geoTasks) LatLng(t.latitude!, t.longitude!),
    ];

    final markers = <Marker>[
      ...geoApartments.map(
        (a) => Marker(
          point: LatLng(a.latitude!, a.longitude!),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: _MapEntityPin(
            color: Theme.of(context).colorScheme.primary,
            icon: Icons.apartment_rounded,
            tooltip: a.name,
          ),
        ),
      ),
      ...geoTasks.map(
        (t) => Marker(
          point: LatLng(t.latitude!, t.longitude!),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: _MapEntityPin(
            color: Colors.deepOrange,
            icon: _taskMarkerIcon(t.taskType),
            tooltip: t.title,
          ),
        ),
      ),
    ];

    final mapOptions = _buildMapOptions(markerPoints);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                'admin.map_dispatch_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Material(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    teamAsync.when(
                      data: (team) {
                        final staff = team
                            .where((m) => m.dropdownId.isNotEmpty)
                            .toList();
                        if (_workerFilterId != null &&
                            !staff.any((m) => m.dropdownId == _workerFilterId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _workerFilterId = null);
                            }
                          });
                        }
                        final effectiveFilter =
                            _workerFilterId != null &&
                                    staff.any(
                                      (m) => m.dropdownId == _workerFilterId,
                                    )
                                ? _workerFilterId
                                : null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'admin.map_worker_filter_label'.tr(),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: effectiveFilter,
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'admin.map_worker_filter_all'.tr(),
                                    ),
                                  ),
                                  ...staff.map(
                                    (m) => DropdownMenuItem<String?>(
                                      value: m.dropdownId,
                                      child: Text(
                                        m.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _workerFilterId = v),
                              ),
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _LegendChip(
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.apartment_rounded,
                          label: 'admin.map_legend_apartments'.tr(),
                        ),
                        _LegendChip(
                          color: Colors.deepOrange,
                          icon: Icons.build,
                          label: 'admin.map_legend_tasks'.tr(),
                        ),
                        _LegendChip(
                          color: primaryColor.withValues(alpha: 0.45),
                          icon: Icons.timeline,
                          label: 'admin.map_legend_routes'.tr(),
                        ),
                        if (geoApartments.isEmpty && geoTasks.isEmpty)
                          Text(
                            'admin.map_empty_hint'.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: hasError && markerPoints.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'common.generic_error_user_friendly'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : FlutterMap(
                      options: mapOptions,
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.falconest.app',
                        ),
                        if (polylines.isNotEmpty)
                          PolylineLayer(polylines: polylines),
                        MarkerLayer(markers: markers),
                        SimpleAttributionWidget(
                          source: Text(
                            'OpenStreetMap contributors',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          onTap: () async {
                            final uri = Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          alignment: Alignment.bottomRight,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

/// Volba ikony úkolu podle typu služby – úklid vs. stavba/opravy (heuristika na text).
IconData _taskMarkerIcon(String taskType) {
  final t = taskType.toLowerCase();
  if (t.contains('clean') ||
      t.contains('uklid') ||
      t.contains('úklid') ||
      t.contains('ukliz')) {
    return Icons.cleaning_services;
  }
  return Icons.build;
}

/// [MapOptions] – buď výchozí střed (Quesada), nebo výřez na všechny špendlíky.
MapOptions _buildMapOptions(List<LatLng> points) {
  if (points.isEmpty) {
    return const MapOptions(
      initialCenter: _kMapDefaultCenter,
      initialZoom: _kMapDefaultZoom,
    );
  }
  if (points.length == 1) {
    return MapOptions(
      initialCenter: points.first,
      initialZoom: 15,
    );
  }
  return MapOptions(
    initialCameraFit: CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.all(48),
      maxZoom: 17,
    ),
  );
}

/// Jednotný vzhled špendlíku – kulaté pozadí + ikona (kontrast vůči dlaždicím).
class _MapEntityPin extends StatelessWidget {
  const _MapEntityPin({
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  final Color color;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
