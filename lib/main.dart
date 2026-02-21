import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'app.dart';

/// Vstupní bod FalcoNest - multi-tenant B2B SaaS aplikace.
///
/// Pořadí inicializace:
/// 1. Flutter binding
/// 2. dotenv - načtení .env s Supabase klíči (před init Supabase)
/// 3. Supabase - připojení k backendu
/// 4. Isar - lokální offline databáze (čtení/zápis funguje i bez sítě)
/// 5. EasyLocalization - i18n
/// 6. ProviderScope + aplikace
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Načtení config.env před jakýmkoli přístupem k SUPABASE_URL / SUPABASE_ANON_KEY
  // Soubor bez tečky v názvu kvůli blokování na Netlify a webových serverech
  await dotenv.load(fileName: 'assets/config.env');

  // Inicializace Supabase klienta (čte z dotenv)
  await SupabaseService.init();

  // Inicializace Isar lokální DB – data dostupná offline, sync na pozadí
  await IsarService.init();

  // Inicializace lokalizace (potřeba před runApp)
  await EasyLocalization.ensureInitialized();

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
