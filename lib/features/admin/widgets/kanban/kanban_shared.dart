import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/features/admin/providers/admin_tasks_provider.dart'
    show TaskRow, kanbanNormalizeToSystemStatus;

/// Sdílené pomocné funkce a barvy pro Kanban a související úpravy úkolů v adminu.
///
/// PROČ samostatný soubor: původně žily uvnitř `admin_tasks_screen.dart` vedle karet i dialogů;
/// po vyčlenění widgetů je musí importovat jak Kanban komponenty, tak hlavní obrazovka (formuláře),
/// aniž by se duplikovala logika nebo se měnilo chování.

/// Barvy pro stavy úkolu – stejný styl jako v ostatních admin obrazovkách.
const _statusDraft = Color(0xFF7B1FA2);
const _statusNew = Color(0xFF757575);
const _statusInProgress = Color(0xFF1565C0);
const _statusDone = Color(0xFF2E7D32);
const _statusProblem = Color(0xFFC62828);

/// Vrací kladnou částku k výběru z metadata.amount_to_collect, jinak null.
double? amountToCollectFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  final amt = metadata['amount_to_collect'];
  if (amt is num && amt > 0) return amt.toDouble();
  if (amt != null) {
    final parsed = double.tryParse(amt.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }
  return null;
}

/// Zobrazí dialog pro výběr: jen dokončit úkol vs. dokončit a zapsat hotovost do peněženky.
/// Vrací true = zapsat do peněženky, false = jen dokončit.
Future<bool> showCashCollectionOnCompleteDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('tasks.cash_collection_title'.tr()),
      content: Text('tasks.cash_collection_message'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('tasks.action_just_complete'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('tasks.action_complete_and_save_cash'.tr()),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Normalizuje surový status z DB na systémovou hodnotu (pending, assigned, in_progress, completed, problem).
/// Zajišťuje zpětnou kompatibilitu s legacy hodnotami (Návrh, Nový, Probíhá, Hotovo).
String normalizeToSystemStatus(String? raw) =>
    kanbanNormalizeToSystemStatus(raw);

/// Lokalizovaný text statusu – využití easy_localization (task_status.* v JSON).
String localizedTaskStatus(String systemStatus) {
  return 'task_status.$systemStatus'.tr();
}

/// Barva podle systémového statusu (pending, assigned, in_progress, completed, problem).
Color kanbanTaskStatusColor(String systemStatus) {
  switch (systemStatus) {
    case 'pending':
      return _statusDraft;
    case 'assigned':
      return _statusNew;
    case 'in_progress':
      return _statusInProgress;
    case 'problem':
      return _statusProblem;
    case 'completed':
      return _statusDone;
    default:
      return _statusNew;
  }
}

/// Počáteční trvání (min) pro editaci úkolu: odhad z metadata, případně rozdíl konec − začátek, jinak 60.
///
/// PROČ: Obnovíme smysluplné trvání i u starých záznamů, kde UI dřív přepsalo oba časy na stejnou hodnotu
/// (rozdíl 0) – pak spadneme na výchozích 60 min místo nečitelné nuly.
int initialDurationMinutesForTask(TaskRow t) {
  final meta = t.metadata;
  if (meta != null) {
    final raw = meta['estimated_minutes'] ?? meta['estimate_minutes'];
    if (raw != null) {
      final m = raw is int ? raw : int.tryParse(raw.toString());
      if (m != null && m > 0) return m;
    }
  }
  final start = t.scheduledStart;
  final end = t.dueDate;
  if (start != null) {
    final diff = end.difference(start).inMinutes;
    if (diff > 0) return diff;
  }
  return 60;
}

/// Převod DateTime z DB do lokální zóny zařízení.
///
/// PROČ: `timestamptz` z Supabase je v UTC; bez `toLocal()` by dispečink v ČR viděl posun oproti očekávání z detailu úkolu.
DateTime toLocalDateTime(DateTime d) => d.isUtc ? d.toLocal() : d;

/// Lokální začátek a konec časového okna pro kartu Kanbanu.
///
/// PROČ: V detailu úkolu máme **plánovaný začátek** (`scheduled_start`) a **trvání** (metadata / rozdíl konec−začátek / výchozí 60 min).
/// Pokud je v DB kladný rozdíl mezi `due_date` a `scheduled_start`, bereme `due_date` jako explicitní konec (shodné s editačním formulářem).
/// **Fallback (začátek + trvání):** když rozdíl konec−začátek není kladný, nebo chybí `scheduled_start`, konec vždy dopočítáme jako
/// `start + initialDurationMinutesForTask` – stejná pravidla jako ve formuláři (metadata → odhad z rozdílu → 60 min).
/// Bez `scheduled_start` je kotva `dueDate` a okno táhneme **dopředu** o tuto délku, aby karta ukázala smysluplný interval i u starších záznamů.
(DateTime startLocal, DateTime endLocal) kanbanTaskLocalTimeWindow(
  TaskRow task,
) {
  final sched = task.scheduledStart;
  final due = task.dueDate;
  final startUtc = sched ?? due;
  var startLocal = toLocalDateTime(startUtc);
  late DateTime endLocal;
  if (sched != null) {
    final diffMin = due.difference(sched).inMinutes;
    if (diffMin > 0) {
      endLocal = toLocalDateTime(due);
    } else {
      // Fallback: explicitní konec v DB chybí nebo je neplatný → začátek + trvání z metadat / výchozích 60 min.
      endLocal = startLocal.add(
        Duration(minutes: initialDurationMinutesForTask(task)),
      );
    }
  } else {
    // Bez scheduled_start jediný pevný bod je dueDate; konec = začátek + stejné trvání jako ve formuláři.
    endLocal = startLocal.add(
      Duration(minutes: initialDurationMinutesForTask(task)),
    );
  }
  // PROČ: Při poškozených datech nesmíme zobrazit záporné okno – minimálně 1 minuta rozsahu.
  if (!endLocal.isAfter(startLocal)) {
    endLocal = startLocal.add(const Duration(minutes: 1));
  }
  return (startLocal, endLocal);
}

/// Formát časového okna na kartě: stejný den `02.04. 16:00 - 18:00`, jinak plné datum u obou mezí.
///
/// PROČ: Dispečer potřebuje na první pohled vidět datum jen jednou, pokud úkon nepřetéká přes půlnoc; přes hranice dne musí být jasné oba kalendářní dny.
String formatKanbanTimeWindowRange(DateTime startLocal, DateTime endLocal) {
  String dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  String hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final sameDay =
      startLocal.year == endLocal.year &&
      startLocal.month == endLocal.month &&
      startLocal.day == endLocal.day;
  if (sameDay) {
    return '${dm(startLocal)}. ${hm(startLocal)} - ${hm(endLocal)}';
  }
  return '${dm(startLocal)}.${startLocal.year} ${hm(startLocal)} - ${dm(endLocal)}.${endLocal.year} ${hm(endLocal)}';
}

/// Text pro pilulku času na Kanban kartě (TaskCard / KanbanTaskCardContent).
String kanbanTaskTimeWindowText(TaskRow task) {
  final (s, e) = kanbanTaskLocalTimeWindow(task);
  return formatKanbanTimeWindowRange(s, e);
}

/// Vrací lokalizační klíč pro daný task_type (fallback pro smazané/systémové typy mimo katalog).
String taskTypeLabelKey(String taskType) {
  switch (taskType) {
    case 'cleaning':
      return 'admin.task_type_cleaning';
    case 'transfer_in':
      return 'admin.task_type_transfer_in';
    case 'transfer_out':
      return 'admin.task_type_transfer_out';
    case 'check_in':
      return 'admin.task_type_check_in';
    case 'check_out':
      return 'admin.task_type_check_out';
    case 'issue':
      return 'admin.task_type_issue';
    case 'material':
      return 'admin.task_type_material';
    case 'rent_collection':
      return 'admin.task_type_rent_collection';
    case 'Úklid':
      return 'admin.task_type_cleaning';
    case 'Transfer':
      return 'admin.task_type_transfer_in';
    case 'Jiné':
      return 'admin.task_type_other';
    default:
      return 'admin.task_type_other';
  }
}
