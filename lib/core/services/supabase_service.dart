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
}
