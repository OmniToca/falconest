import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/task_local.dart';

/// Provider načítající dnešní úkoly z lokální Isar databáze.
///
/// Filtruje úkoly podle [scheduledStart] – zobrazí jen ty, jejichž plánovaný
/// začátek spadá do aktuálního lokálního dne. Řazení podle času.
///
/// Na webu Isar není dostupný – vrací prázdný seznam.
final todaysTasksProvider = Provider<List<TaskLocal>>((ref) {
  if (kIsWeb) return [];

  try {
    final isar = IsarService.instance;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final results = isar.taskLocals
        .where()
        .anyId()
        .filter()
        .scheduledStartBetween(startOfToday, endOfToday, includeUpper: false)
        .findAllSync();
    results.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return results;
  } catch (_) {
    return [];
  }
});
