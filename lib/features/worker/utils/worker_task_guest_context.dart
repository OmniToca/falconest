import 'package:falconest/core/repositories/task/task_repository.dart';

/// Pomocné funkce pro rozhodnutí, které údaje o hostovi / rezervaci zobrazit u worker detailu.
///
/// PROČ: Úklid (cleaning), údržba (maintenance), prádelna / extra (laundry…) sice mohou být navázané na rezervaci,
/// ale pracovník u nich nepotřebuje „konverzační“ kontext (jazyk hosta, speciální požadavky, standardní časy recepce).
/// Naopak check-in / check-out / transfer je přímo o interakci s hostem – tyto sekce musí zůstat viditelné.

/// Typy úkolů, u kterých dává smysl zobrazit karty: speciální požadavky hosta, jazyk, standardní časy apartmánu.
/// Ostatní typy (např. cleaning, maintenance, laundry) se řídí výhradně negací této whitelist logiky.
bool workerTaskTypeShowsGuestReservationDetailSections(String taskType) {
  final t = taskType.trim().toLowerCase();
  return t == 'check_in' ||
      t == 'check_out' ||
      t == 'transfer' ||
      t == 'transfer_in' ||
      t == 'transfer_out';
}

/// Zda v horní části detailu zvýraznit jméno hosta (úkol je vázaný na rezervaci a jméno známe).
///
/// PROČ: U prádelny nebo úklidu mezi pobyty potřebuje pracovník rychle vědět, kterého hosta se úkol týká,
/// i když nepotřebuje celý blok „jazyk / speciální požadavky“.
bool workerTaskDetailShouldShowProminentGuestName(WorkerTaskDetail detail) {
  if (!detail.hasLinkedReservation) return false;
  final n = detail.guestName?.trim();
  return n != null && n.isNotEmpty;
}
