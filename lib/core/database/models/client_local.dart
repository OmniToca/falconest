import 'package:isar/isar.dart';

part 'client_local.g.dart';

/// Lokální Isar model reprezentující klienta (client) – minimální subset pro Worker.
///
/// PROČ: Externí úkoly (např. transfer bez rezervace) mají tasks.client_id. Pro offline zobrazení
/// jména klienta řidiči musíme stáhnout a uložit klienty do Isaru. Sync probíhá pouze pro
/// client_id referencované ze stažených úkolů – šetříme místo a data.
///
/// [id] = Isar auto-increment pro lokální identifikaci
/// [supabaseId] = UUID z Supabase pro párování s tasks.client_id
@collection
class ClientLocal {
  /// Automaticky generované Isar ID pro lokální jednoznačnost.
  Id id = Isar.autoIncrement;

  /// UUID záznamu v Supabase. Používá se pro párování s TaskLocal.clientSupabaseId.
  String? supabaseId;

  /// ID tenanta – multi-tenant izolace. Musí odpovídat přihlášenému uživateli.
  late String tenantId;

  /// Jméno klienta – pro zobrazení řidiči u externích úkolů (transfer, služba pro klienta).
  late String name;

  /// Telefon klienta – volitelné pro kontakt v terénu.
  String? phone;

  /// Implicitní konstruktor – potřebný pro Isar deserializaci a factory.
  ClientLocal();

  /// Vytvoří ClientLocal z mapy (např. JSON odpověď ze Supabase).
  ///
  /// Klíče: id, tenant_id, name, phone.
  factory ClientLocal.fromMap(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    return ClientLocal()
      ..supabaseId = (idRaw != null && idRaw.isNotEmpty) ? idRaw : null
      ..tenantId = (map['tenant_id']?.toString() ?? '').trim()
      ..name = (map['name']?.toString() ?? '').trim()
      ..phone = (map['phone']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['phone']?.toString() ?? '').trim();
  }
}
