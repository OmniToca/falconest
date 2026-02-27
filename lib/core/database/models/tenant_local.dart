import 'package:isar/isar.dart';

part 'tenant_local.g.dart';

/// Lokální Isar model reprezentující nastavení tenanta (agentury) – minimální subset pro Worker.
///
/// PROČ: Worker UI (např. formátování hotovosti u transferů) potřebuje znát měnu tenanta
/// i v offline režimu. currentTenantCurrencyProvider čte z Isaru místo Supabase – tím se
/// vyhneme fallbacku na osobní preferredCurrency uživatele a zobrazí se správná měna firmy.
///
/// Sync: WorkerSyncService při stažení úkolů stáhne i tenants (id, currency) a uloží sem.
///
/// POZNÁMKA PRO VÝVOJÁŘE: Po přidání nebo úpravě tohoto modelu spusť `dart run build_runner build`
/// pro vygenerování souboru tenant_local.g.dart.
@collection
class TenantLocal {
  /// Automaticky generované Isar ID pro lokální jednoznačnost.
  Id id = Isar.autoIncrement;

  /// UUID tenanta v Supabase (tenants.id). Unikátní – v Isaru máme max. jeden záznam na tenant.
  @Index(unique: true)
  late String supabaseId;

  /// Kód měny tenanta – např. EUR, CZK. Pro formátování částek v Worker UI (amount_to_collect).
  String? currency;

  /// Implicitní konstruktor – potřebný pro Isar deserializaci a factory.
  TenantLocal();

  /// Vytvoří TenantLocal z mapy (např. JSON odpověď ze Supabase).
  ///
  /// Klíče: id (UUID tenanta), currency.
  factory TenantLocal.fromMap(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    final currRaw = map['currency']?.toString().trim();
    return TenantLocal()
      ..supabaseId = (idRaw != null && idRaw.isNotEmpty) ? idRaw : ''
      ..currency = (currRaw != null && currRaw.isNotEmpty)
          ? currRaw.toUpperCase()
          : null;
  }
}
