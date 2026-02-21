import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/task_category_model.dart';

/// Mapuje code na TaskCategory pro bleskové vyhledávání v TaskVisuals.
typedef TaskCategoriesByCode = Map<String, TaskCategoryModel>;

/// Načte globální kategorie úkolů z public.task_categories (platformový číselník).
/// Vrací mapu podle [code] pro rychlý lookup. Při chybě vrací prázdnou mapu – použije se statický fallback.
final taskCategoriesProvider = FutureProvider<TaskCategoriesByCode>((ref) async {
  final list = await TaskCategoriesRepository.fetchAll();
  final map = <String, TaskCategoryModel>{};
  for (final c in list) {
    if (c.code.isNotEmpty) {
      map[c.code] = c;
    }
  }
  return map;
});

/// Repository pro čtení globální tabulky task_categories.
class TaskCategoriesRepository {
  TaskCategoriesRepository._();

  /// Načte všechny kategorie seřazené podle order_index (globální číselník).
  /// Při chybě (tabulka neexistuje, RLS) vrací prázdný seznam – použije se statický fallback.
  static Future<List<TaskCategoryModel>> fetchAll() async {
    try {
      final res = await SupabaseService.client
          .from('task_categories')
          .select()
          .order('order_index', ascending: true);
      final list = res as List;
      return list
          .map((e) => TaskCategoryModel.fromJson(e as Map<String, dynamic>))
          .where((c) => c.code.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
