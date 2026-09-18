import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Tento soubor se nám právě vytvořil

// Podmíněný import: na webu žádný Isar (64-bit int crash), na mobilu plná Isar inicializace.
import 'package:falconest/core/database/database_init_stub.dart'
    if (dart.library.io) 'package:falconest/core/database/database_init_io.dart' as database_init;

/// Vstupní bod FalcoNest - multi-tenant B2B SaaS aplikace.
///
/// Pořadí inicializace:
/// 1. Flutter binding (KRITICKÉ – musí být první)
/// 2. dotenv - načtení .env s Supabase klíči (před init Supabase)
/// 3. Supabase - připojení k backendu
/// 4. Isar - lokální offline databáze (čtení/zápis funguje i bez sítě)
/// 5. EasyLocalization - i18n
/// 6. ProviderScope + aplikace
///
/// Při chybě inicializace se aplikace přesto spustí a zobrazí chybovou hlášku
/// (místo bílého obrazu v Release módu na iOS).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  // TOTO PŘIDEJ: Inicializace Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppLogger.initCrashlytics();

  // PROČ: Nezachycené Flutter / async chyby jinak zmizí – v release (mobil) jdou do Crashlytics.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.recordFlutterFatal(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Nezachycená platform chyba', error, stack);
    return true;
  };

  Object? initError;
  try {
    // Načtení config.env před jakýmkoli přístupem k SUPABASE_URL / SUPABASE_ANON_KEY
    await dotenv.load(fileName: 'assets/config.env');

    // Inicializace Supabase klienta (čte z dotenv)
    await SupabaseService.init();

    // Inicializace lokální DB – na webu no-op, na mobilu Isar (offline-first)
    await database_init.initDatabase();

    // Inicializace lokalizace (potřeba před runApp)
    await EasyLocalization.ensureInitialized();
  } catch (e, st) {
    initError = e;
    AppLogger.error('FalcoNest init ERROR', e, st);
  }

  if (initError != null) {
    runApp(_InitErrorApp(error: initError));
    return;
  }

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('cs'), Locale('en'), Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('cs'),
        startLocale: const Locale('cs'),
        useFallbackTranslations: true,
        child: const FalcoNestApp(),
      ),
    ),
  );
}

/// Fallback aplikace při chybě inicializace – zobrazí chybovou hlášku místo bílého obrazu.
class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 24),
                const Text(
                  'Chyba při spuštění aplikace',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
