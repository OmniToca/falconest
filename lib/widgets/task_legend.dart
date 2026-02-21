import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Sdílená legenda úkolů – zobrazuje kritické stavy (Nepřiřazeno, Konflikt) a typy služeb z DB.
/// ConsumerWidget – sleduje taskCategoriesProvider. Při načítání zobrazí indikátor.
/// Na začátku legendy jsou natvrdo chybové stavy (Nepřiřazeno, Časový konflikt), potom dynamické kategorie.
class TaskLegend extends ConsumerWidget {
  const TaskLegend({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(taskCategoriesProvider);
    return asyncCategories.when(
      loading: () => const SizedBox(height: 24, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, _) => _buildLegendWrap(context, TaskVisuals.getLegendItems()),
      data: (categoriesByCode) {
        final items = categoriesByCode.isNotEmpty
            ? TaskVisuals.getLegendItemsFromCategories(categoriesByCode)
            : TaskVisuals.getLegendItems();
        return _buildLegendWrap(context, items);
      },
    );
  }

  Widget _buildLegendWrap(BuildContext context, List<TaskLegendItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0,
        runSpacing: 8.0,
        children: items
            .map((item) => _LegendBadge(item: item))
            .toList(),
      ),
    );
  }
}

/// Chip/Badge položka legendy – vysoký kontrast, čitelnost na světlém pozadí.
/// Chybové stavy (Nepřiřazeno, Konflikt) mají vlastní paletu; kategorie z DB mají tmavý text na pastelovém pozadí.
class _LegendBadge extends StatelessWidget {
  const _LegendBadge({required this.item});

  final TaskLegendItem item;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color contentColor;
    if (item.labelKey == 'planning_calendar.legend_unassigned') {
      bgColor = Colors.red.shade100;
      contentColor = Colors.red.shade900;
    } else if (item.labelKey == 'planning_calendar.legend_conflict') {
      bgColor = Colors.orange.shade100;
      contentColor = Colors.orange.shade900;
    } else {
      bgColor = item.color;
      contentColor = Colors.grey.shade800;
    }
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon!, size: 14, color: contentColor),
            const SizedBox(width: 6),
          ],
          Text(
            item.labelKey.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }
}
