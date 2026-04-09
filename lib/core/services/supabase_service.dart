import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Služba pro inicializaci a přístup k Supabase klientu.
///
/// Čte konfiguraci z config.env (SUPABASE_URL, SUPABASE_ANON_KEY),
/// aby se citlivé údaje nedostaly do verzovacího systému.
/// config.env musí být načten v main.dart pomocí dotenv.load() před voláním init().
class SupabaseService {
  SupabaseService._();

  /// Inicializuje Supabase klienta s údaji z config.env.
  ///
  /// Před voláním musí být:
  /// 1. WidgetsFlutterBinding.ensureInitialized()
  /// 2. dotenv.load(fileName: "assets/config.env")
  ///
  /// V assets/config.env nastav:
  /// SUPABASE_URL=https://tvuj-projekt.supabase.co
  /// SUPABASE_ANON_KEY=tvuj-anon-key
  static Future<void> init() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw Exception(
        'SUPABASE_URL není nastaven v config.env. Přidej řádek: SUPABASE_URL=https://xxx.supabase.co',
      );
    }

    if (anonKey == null || anonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY není nastaven v config.env. Najdeš ho v Supabase Dashboard → Settings → API.',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Singleton instance Supabase klienta po inicializaci.
  ///
  /// Všechny dotazy na backend musí jít přes tento klient,
  /// aby se uplatnilo Row Level Security (RLS) podle přihlášeného uživatele.
  static SupabaseClient get client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Frontend Firewall – bezpečné dotazy s vynuceným tenant_id při převtělení
  // ---------------------------------------------------------------------------
  //
  // PROBLÉM: RLS používá (is_super_admin() OR tenant_id = my_tenant_id()).
  // Super Admin tedy může načíst VŠECHNA data, pokud repozitář nezadá filtr
  // .eq('tenant_id', tenantIdForData). Jediná ochrana je na straně aplikace.
  //
  // ŘEŠENÍ: Pro tabulky s tenant_id používej [safeFrom] a [safeInsertPayload].
  // - safeFrom(table, currentTenantId): když currentTenantId je zadáno, VŽDY
  //   připojí .eq('tenant_id', currentTenantId) dřív, než repozitář volá select/update/delete/stream.
  // - safeInsertPayload(currentTenantId, payload): při INSERT vnutí tenant_id do payloadu,
  //   aby ani zapomenutý filtr v insert mapě neumožnil zápis pod cizím tenantem.
  // - Když currentTenantId je null nebo prázdné: chování jako client.from(table) / payload beze změny
  //   (Super Admin globální dotazy, např. seznam tenantů).
  // ---------------------------------------------------------------------------

  /// Bezpečný vstup do tabulky s automatickým filtrem tenant_id (Frontend Firewall).
  ///
  /// [table] – název tabulky (např. `tasks`, `apartments`).
  /// [currentTenantId] – obvykle `authNotifier.tenantIdForData`. Pokud je neprázdné,
  /// každé volání select/update/delete/stream NEZVRATNĚ přidá filtr tenant_id.
  /// Repozitář už NEMUSÍ (a při použití safeFrom NEMÁ) přidávat .eq('tenant_id', ...).
  ///
  /// Pokud je [currentTenantId] null nebo prázdný, chová se jako nefiltrovaný přístup
  /// (pro globální dotazy Super Admina).
  ///
  /// Použití: `SupabaseService.safeFrom('tasks', tenantIdForData).select(...).order(...)`
  /// nebo `.stream(primaryKey: ['id']).order(...)` atd.
  static SafeTenantTable safeFrom(String table, String? currentTenantId) {
    return SafeTenantTable(table, currentTenantId?.trim());
  }

  /// Pro INSERT vnutí [currentTenantId] do payloadu jako `tenant_id`.
  ///
  /// Když je [currentTenantId] neprázdné, do [payload] se vloží nebo přepíše
  /// klíč `tenant_id`. Tím se zabrání zápisu pod cizím tenantem i když vývojář
  /// v insert mapě tenant_id zapomene.
  ///
  /// Použití: `client.from('tasks').insert(SupabaseService.safeInsertPayload(tenantId, payload))`
  /// nebo se safeFrom: `SupabaseService.safeFrom('tasks', tenantId).insert(SupabaseService.safeInsertPayload(tenantId, payload))`.
  static Map<String, dynamic> safeInsertPayload(
    String? currentTenantId,
    Map<String, dynamic> payload,
  ) {
    final tid = currentTenantId?.trim();
    if (tid == null || tid.isEmpty) return payload;
    return {...payload, 'tenant_id': tid};
  }
}

/// Obálka nad tabulkou, která při zadaném [tenantId] vnutí filtr tenant_id do všech operací.
///
/// Supabase klient vrací z .from() builder bez .eq(); .eq() je až na builderu po .select().
/// Tato třída proto exponuje select/insert/update/delete/stream a do řetězce vždy vloží
/// .eq('tenant_id', tenantId) (nebo u stream .inFilter('tenant_id', [tenantId])) když je tenantId zadán.
class SafeTenantTable {
  SafeTenantTable(this._table, this._tenantId);

  final String _table;
  final String? _tenantId;

  bool get _scoped => _tenantId != null && _tenantId.isNotEmpty;

  String get _tid => _tenantId ?? '';

  /// SELECT – při _scoped přidá .eq('tenant_id', _tid) za .select(...).
  /// Parametr [columns] má výchozí hodnotu '*' – nativní SDK nepřijímá null.
  PostgrestFilterBuilder select([String columns = '*']) {
    var b = SupabaseService.client.from(_table).select(columns);
    if (_scoped) b = b.eq('tenant_id', _tid);
    return b;
  }

  /// INSERT – při _scoped vnutí tenant_id do payloadu přes [SupabaseService.safeInsertPayload].
  PostgrestFilterBuilder insert(dynamic data) {
    final payload = data is Map<String, dynamic>
        ? SupabaseService.safeInsertPayload(_tenantId, data)
        : data;
    return SupabaseService.client.from(_table).insert(payload);
  }

  /// UPSERT – při _scoped projde [safeInsertPayload] každý řádek (mapa nebo seznam map).
  ///
  /// PROČ: Stejná Frontend Firewall jako u INSERT – super admin s prázdným [currentTenantId]
  /// chová se jako holý klient (globální HQ operace); jinak se tenant_id vnutí do payloadu.
  PostgrestFilterBuilder upsert(
    dynamic data, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = false,
  }) {
    dynamic prepared = data;
    if (_scoped) {
      if (data is List) {
        prepared = data.map((e) {
          if (e is Map<String, dynamic>) {
            return SupabaseService.safeInsertPayload(_tenantId, Map<String, dynamic>.from(e));
          }
          if (e is Map) {
            return SupabaseService.safeInsertPayload(
              _tenantId,
              Map<String, dynamic>.from(e),
            );
          }
          return e;
        }).toList();
      } else if (data is Map<String, dynamic>) {
        prepared = SupabaseService.safeInsertPayload(_tenantId, data);
      } else if (data is Map) {
        prepared = SupabaseService.safeInsertPayload(
          _tenantId,
          Map<String, dynamic>.from(data),
        );
      }
    }
    return SupabaseService.client.from(_table).upsert(
      prepared,
      onConflict: onConflict,
      ignoreDuplicates: ignoreDuplicates,
      defaultToNull: defaultToNull,
    );
  }

  /// UPDATE – při _scoped přidá .eq('tenant_id', _tid) za .update(...).
  PostgrestFilterBuilder update(Map<String, dynamic> data) {
    var b = SupabaseService.client.from(_table).update(data);
    if (_scoped) b = b.eq('tenant_id', _tid);
    return b;
  }

  /// DELETE – při _scoped přidá .eq('tenant_id', _tid).
  PostgrestFilterBuilder delete() {
    var b = SupabaseService.client.from(_table).delete();
    if (_scoped) b = b.eq('tenant_id', _tid);
    return b;
  }

  /// STREAM – při _scoped přidá .inFilter('tenant_id', [_tid]) za .stream(...).
  ///
  /// Návratový typ [SupabaseStreamBuilder] zachová typovou informaci v řetězci
  /// .order().limit().map(), takže výsledek .map() je korektně inferován jako
  /// `Stream<List<Map<String, dynamic>>>` a nedojde k runtime TypeError (_MapStream).
  SupabaseStreamBuilder stream({required List<String> primaryKey}) {
    final b = SupabaseService.client.from(_table).stream(primaryKey: primaryKey);
    if (_scoped) return b.inFilter('tenant_id', [_tid]);
    return b;
  }
}
