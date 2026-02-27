/// Stub pro načtení měny tenanta z lokálního úložiště (web).
///
/// Na webu Isar neběží – tento soubor NEOBSAHUJE žádný import Isaru.
/// Vždy vrací null, provider pak spadne do fallbacku na Supabase.
Future<String?> getTenantCurrencyFromLocal(String tenantId) async {
  return null;
}
