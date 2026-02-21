/// Stav synchronizace záznamu mezi lokální Isar DB a cloudem (Supabase).
///
/// Používá se pro offline-first architekturu:
/// - [synced] – záznam je v souladu s cloudem (nebo byl právě stažen)
/// - [pending] – lokální změny čekají na odeslání do cloudu
///
/// Synchronizační vrstva vybírá záznamy s [pending] a odesílá je na pozadí.
enum SyncStatus {
  /// Záznam synchronizován s Supabase
  synced,

  /// Lokální změny zatím neodeslány (offline editace, nový záznam)
  pending,
}
