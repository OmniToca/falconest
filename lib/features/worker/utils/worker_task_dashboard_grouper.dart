import 'package:falconest/core/repositories/task/task_repository.dart';

/// Kalendářní sekce na worker nástěnce.
enum WorkerTaskDateBucket { overdue, today, tomorrow, later }

/// Režim vykreslení úkolů uvnitř kalendářní sekce.
enum WorkerTaskListLayoutMode {
  /// Striktní časová osa – žádné seskupování podle adresy.
  chronological,

  /// Původní chování – seskupení podle bytu/adresy v rámci sekce.
  byLocationThenTime,
}

/// Jedna kalendářní sekce na dashboardu (např. „Dnes“).
class WorkerTaskDashboardSection {
  const WorkerTaskDashboardSection({
    required this.bucket,
    required this.tasks,
    this.locationGroups = const [],
  });

  final WorkerTaskDateBucket bucket;

  /// Úkoly seřazené podle [WorkerTask.scheduledStart] vzestupně.
  final List<WorkerTask> tasks;

  /// Vyplněno jen v režimu [WorkerTaskListLayoutMode.byLocationThenTime].
  final List<WorkerTaskLocationGroup> locationGroups;
}

/// Skupina úkolů na stejném místě (byt nebo adresa).
class WorkerTaskLocationGroup {
  const WorkerTaskLocationGroup({required this.key, required this.tasks});

  final String key;
  final List<WorkerTask> tasks;
}

/// Rozdělí úkoly do kalendářních sekcí; uvnitř každé sekce seřadí chronologicky.
///
/// PROČ samostatný modul: řazení/seskupování nesmí být v UI souboru obrazovky –
/// snadná změna režimu ([WorkerTaskListLayoutMode]) bez refaktoru widgetů.
List<WorkerTaskDashboardSection> groupWorkerTasksForDashboard(
  List<WorkerTask> tasks, {
  DateTime? now,
  WorkerTaskListLayoutMode layoutMode = WorkerTaskListLayoutMode.chronological,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);

  WorkerTaskDateBucket bucketFor(WorkerTask t) {
    final day = DateTime(
      t.scheduledStart.year,
      t.scheduledStart.month,
      t.scheduledStart.day,
    );
    final diff = day.difference(today).inDays;
    if (diff < 0) return WorkerTaskDateBucket.overdue;
    if (diff == 0) return WorkerTaskDateBucket.today;
    if (diff == 1) return WorkerTaskDateBucket.tomorrow;
    return WorkerTaskDateBucket.later;
  }

  final buckets = <WorkerTaskDateBucket, List<WorkerTask>>{
    for (final b in WorkerTaskDateBucket.values) b: [],
  };
  for (final t in tasks) {
    buckets[bucketFor(t)]!.add(t);
  }

  int compareTasks(WorkerTask a, WorkerTask b) =>
      a.scheduledStart.compareTo(b.scheduledStart);

  List<WorkerTaskLocationGroup> locationGroupsFor(List<WorkerTask> dayTasks) {
    final sorted = [...dayTasks]..sort(compareTasks);
    final order = <String>[];
    final map = <String, List<WorkerTask>>{};
    for (final t in sorted) {
      final k = _locationGroupKey(t);
      map.putIfAbsent(k, () {
        order.add(k);
        return [];
      }).add(t);
    }
    return [
      for (final k in order)
        WorkerTaskLocationGroup(key: k, tasks: map[k]!),
    ];
  }

  return [
    for (final bucket in WorkerTaskDateBucket.values)
      if (buckets[bucket]!.isNotEmpty)
        WorkerTaskDashboardSection(
          bucket: bucket,
          tasks: [...buckets[bucket]!]..sort(compareTasks),
          locationGroups: layoutMode == WorkerTaskListLayoutMode.byLocationThenTime
              ? locationGroupsFor(buckets[bucket]!)
              : const [],
        ),
  ];
}

/// Klíč seskupení: stejný byt nebo stejná adresa (externí úkoly).
String _locationGroupKey(WorkerTask t) {
  final apt = t.apartmentId.trim();
  if (apt.isNotEmpty) return 'apt:$apt';
  final addr = t.displayAddress.trim();
  if (addr.isNotEmpty) return 'addr:${addr.toLowerCase()}';
  return 'solo:${t.id}';
}
