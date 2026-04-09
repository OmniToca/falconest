/// Výsledek odeslání žádosti o absenci – [AddAbsenceDialog] podle toho vybere SnackBar.
enum WorkerAbsenceSubmitOutcome {
  /// Úspěšně uloženo na server (web přímý insert, mobil po sync fronty).
  successOnline,

  /// Uloženo do fronty / čeká na síť (web po síťové chybě; na IO se nepoužívá jako samostatný happy path).
  successQueuedOffline,

  /// Chyba – [errorMessage] pro uživatele.
  failure,
}
