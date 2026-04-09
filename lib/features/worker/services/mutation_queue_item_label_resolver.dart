import 'package:easy_localization/easy_localization.dart';

import 'package:falconest/core/offline/pending_mutation_list_item.dart';

/// Převod technických údajů z fronty mutací na texty pro běžného pracovníka.
///
/// PROČ: V SQLite jsou `action_type` a `target_table` – bez mapování by UI ukazovalo
/// nečitelné konstanty; i18n klíče drží srozumitelné popisy podle typu operace.
class MutationQueueItemLabelResolver {
  MutationQueueItemLabelResolver._();

  /// Hlavní řádek karty (co se má stát po odeslání).
  static String primaryLine(PendingMutationListItem m) {
    final action = m.actionType.toUpperCase();
    switch (action) {
      case 'OFFLINE_TASK_COMPLETE_WITH_PHOTOS':
        return 'worker.mutation_queue_item_task_photos'.tr();
      case 'OFFLINE_CASH_COLLECTION':
        return 'worker.mutation_queue_item_cash_collection'.tr();
      case 'OFFLINE_ISSUE_TASK':
        return 'worker.mutation_queue_item_issue_task'.tr();
      case 'OFFLINE_COMPANY_EXPENSE':
        return 'worker.mutation_queue_item_company_expense'.tr();
      case 'INSERT':
        if (m.tableName == 'staff_absences') {
          return 'worker.mutation_queue_item_staff_absence'.tr();
        }
        return 'worker.mutation_queue_item_insert'.tr(
          namedArgs: {'table': _prettyTable(m.tableName)},
        );
      case 'UPDATE':
        return 'worker.mutation_queue_item_update'.tr(
          namedArgs: {'table': _prettyTable(m.tableName)},
        );
      case 'DELETE':
        return 'worker.mutation_queue_item_delete'.tr(
          namedArgs: {'table': _prettyTable(m.tableName)},
        );
      default:
        return 'worker.mutation_queue_item_unknown'.tr(
          namedArgs: {
            'action': m.actionType,
            'table': _prettyTable(m.tableName),
          },
        );
    }
  }

  /// Doplňující řádek (např. absence → typ; úkol → název z payloadu pokud je).
  static String? secondaryLine(PendingMutationListItem m) {
    final action = m.actionType.toUpperCase();
    final p = m.payload;
    if (p == null) return null;

    if (action == 'INSERT' && m.tableName == 'staff_absences') {
      final reason = p['reason']?.toString().trim();
      if (reason != null && reason.isNotEmpty) {
        return 'worker.mutation_queue_detail_absence_reason'.tr(namedArgs: {'reason': reason});
      }
    }

    final title = p['title']?.toString().trim();
    if (title != null && title.isNotEmpty) {
      return 'worker.mutation_queue_detail_task_title'.tr(namedArgs: {'title': title});
    }

    final taskId = p['task_id']?.toString().trim();
    if (taskId != null && taskId.isNotEmpty) {
      return 'worker.mutation_queue_detail_task_id'.tr(namedArgs: {'id': taskId});
    }

    return null;
  }

  /// Zjednodušený název tabulky (bez změny významu – jen čitelnější pro ne-IT).
  static String _prettyTable(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'common.placeholder_dash'.tr();
    return t.replaceAll('_', ' ');
  }
}
