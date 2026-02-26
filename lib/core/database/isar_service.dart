import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/apartment_local.dart';
import 'models/pending_audit_action.dart';
import 'models/pending_mutation_local.dart';
import 'models/reservation_local.dart';
import 'models/task_local.dart';

/// Služba pro inicializaci a přístup k Isar lokální databázi.
///
/// Offline-first: Isar uchovává data lokálně. Aplikace čte primárně z Isar,
/// synchronizace s Supabase běží na pozadí. Při offline režimu uživatel pracuje
/// s lokálními daty; po obnovení připojení se změny odesílají (pending → synced).
///
/// V main.dart volat před runApp, protože další vrstvy (např. Riverpod providery)
/// potřebují otevřenou databázi.
class IsarService {
  IsarService._();

  static Isar? _instance;

  /// Inicializuje Isar databázi v documents directory.
  ///
  /// Na webu Isar neběží – použij podmínku [kIsWeb] a fallback na Supabase-only.
  /// Na mobilu/desktupu vytvoří DB v aplikací privátní složce.
  static Future<void> init() async {
    if (_instance != null) return;

    // Web nemá persistující filesystem – Isar na webu zatím nepodporujeme
    if (kIsWeb) {
      // TODO: Web build – synchronizace pouze přes Supabase
      return;
    }

    // KRITICKÉ: await před použitím – path_provider může v Release na iOS blokovat,
    // dokud není Flutter binding hotový (zajištěno v main.dart jako první krok).
    final dir = await getApplicationDocumentsDirectory();

    _instance = await Isar.open(
      [
        ApartmentLocalSchema,
        TaskLocalSchema,
        ReservationLocalSchema,
        PendingAuditActionSchema,
        PendingMutationLocalSchema,
      ],
      directory: dir.path,
      name: 'falconest',
    );
  }

  /// Otevřená instance Isar. Volat až po [init()].
  static Isar get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'Isar není inicializován. Zavolej IsarService.init() v main() před runApp.',
      );
    }
    return i;
  }

  /// Zavře databázi (např. při logout nebo ukončení aplikace).
  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }
}
