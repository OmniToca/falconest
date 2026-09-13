import 'package:falconest/features/settings/models/tenant_service_model.dart';

/// Vytvoří hlubokou kopii [TenantServiceModel.nameI18n] vhodnou pro zápis do sloupce [tasks.title_i18n]
/// při INSERTu nového úkolu.
///
/// Vrací `null`, pokud katalog nemá žádné smysluplné překlady (prázdná mapa, chybí `translations`,
/// nebo všechny jazyky jsou prázdné řetězce). Při zápisu do DB vždy použij
/// [ensureTaskTitleI18nForInsert] — `null` snapshot → `{}` kvůli NOT NULL na `tasks.title_i18n`.
///
/// **PROČ SNAPSHOT (kopie v okamžiku vzniku úkolu):**
/// Účetní podklady a PDF často vycházejí z textu úkolu v jazyce exportu. Kdyby aplikace četla překlady
/// vždy „živě“ z [tenant_services], změna názvu služby v ceníku by zpětně přepsala význam u už
/// uzavřených měsíců a zmátla majitele i účetnictví. Uložením kopie do řádku úkolu zmrazíme význam
/// pro ten konkrétní úkon; úprava katalogu ovlivní jen nově vytvořené úkoly.
///
/// **Shoda s DB triggerem:** při pozdější změně [tasks.title] / [tasks.custom_title] se [tasks.title_i18n]
/// vynuluje — dispečer nebo nová automatika musí překlady obnovit; snapshot z katalogu platí jen pro
/// konzistentní pár (titulek úkolu odpovídá službě v době vzniku).
Map<String, dynamic>? snapshotTaskTitleI18nFromTenantService(TenantServiceModel service) {
  final raw = service.nameI18n;
  if (raw == null || raw.isEmpty) return null;

  final translationsRaw = raw['translations'];
  if (translationsRaw is! Map) return null;

  final translationsOut = <String, String>{};
  for (final e in translationsRaw.entries) {
    final lang = e.key.toString().trim().toLowerCase();
    final text = e.value?.toString().trim() ?? '';
    if (lang.isNotEmpty && text.isNotEmpty) {
      translationsOut[lang] = text;
    }
  }
  if (translationsOut.isEmpty) return null;

  final out = <String, dynamic>{'translations': translationsOut};
  final hashRaw = raw['source_hash'];
  if (hashRaw != null) {
    final h = hashRaw.toString().trim();
    if (h.isNotEmpty) {
      out['source_hash'] = h;
    }
  }
  return out;
}
