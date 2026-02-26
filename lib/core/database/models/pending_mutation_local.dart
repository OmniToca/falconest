import 'package:isar/isar.dart';

part 'pending_mutation_local.g.dart';

/// Univerzální lokální fronta pro offline operace – budoucí rozšíření Admin modulu.
///
/// Umožňuje uložit operaci (INSERT, UPDATE, DELETE) na libovolnou tabulku Supabase
/// a odeslat ji po návratu sítě. V tomto kroku (KROK 1) slouží jako připravená
/// struktura – skutečné zápisy do fronty budou implementovány v dalších krocích
/// (např. Admin offline vytvoření úkolu, úprava rezervace).
///
/// [tableName] – název tabulky v Supabase (tasks, reservations, apartments, …)
/// [actionType] – typ operace: 'INSERT', 'UPDATE', 'DELETE'
/// [payloadJson] – data k odeslání (JSON objekt pro insert/update)
/// [recordId] – volitelně UUID záznamu (pro UPDATE/DELETE)
/// [createdAt] – čas vytvoření (řazení, Timestamp Merging)
@collection
class PendingMutationLocal {
  Id id = Isar.autoIncrement;

  /// Tabulka v Supabase – tasks, reservations, apartments, apartment_services, …
  late String tableName;

  /// Typ operace: INSERT, UPDATE, DELETE.
  late String actionType;

  /// Data k odeslání – JSON string (mapuje na Supabase sloupce).
  late String payloadJson;

  /// Volitelné UUID záznamu – pro UPDATE/DELETE identifikuje cílový řádek.
  String? recordId;

  /// Čas vytvoření v UTC – řazení a Timestamp Merging.
  late DateTime createdAt;

  PendingMutationLocal();
}
