import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Konstanty pro pole [triggered_by] v details – zda akci vyvolal uživatel, kaskáda nebo systém.
///
/// Ukládáme je do JSONB, aby bylo možné později filtrovat a zobrazit kontext (např. „Přímá akce“
/// vs „Kaskádové smazání“). Bez tohoto rozlišení by nebylo jasné, kdo/co změnu inicioval.
abstract class AuditTriggeredBy {
  static const String manual = 'manual';
  static const String cascade = 'cascade';
  static const String system = 'system';
}

/// Sestaví Enterprise payload pro sloupec details (JSONB) v audit_logs.
///
/// PROČ: Každá mutační akce musí do logu zapsat kompletní kontext – název entity v době akce,
/// snapshot toho, kdo akci provedl (i když bude později smazán), kompletní stav entity před
/// změnou (pro Undo/Restore a zobrazení rozdílů), nový stav u Update, klient (Web/iOS/Android),
/// typ spuštění (přímá/kaskáda/systém) a volitelný důvod. Tím z audit logu uděláme „černou skříňku“.
class EnterpriseAuditPayload {
  EnterpriseAuditPayload._();

  /// Vrátí informaci o klientovi (zařízení), na kterém byla akce provedena.
  ///
  /// Ukládáme ji do details.client_info, aby bylo možné analyzovat, zda problém vznikl na Web,
  /// iOS nebo Android, a případně i verzi aplikace (až bude dostupná). Žádný hardcoded text – hodnoty
  /// jsou strojové (Web, iOS, Android) a v UI se překládají přes slovník.
  static String getClientInfo() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Unknown';
    }
  }

  /// Načte snapshot aktuálního uživatele (jméno, e-mail) z tabulky profiles podle auth_id.
  ///
  /// PROČ: Ukládáme actor_snapshot do details v době akce – pokud by byl actor později smazán
  /// nebo změněn, JOIN by v budoucnu selhal a v audit logu by chybělo „kdo to udělal“. Snapshot
  /// zaručuje neměnnost kontextu. Vrací null při chybě nebo nepřihlášeném uživateli.
  ///
  /// [tenantId] – při neprázdném hodnotě dotaz přes [safeFrom] (Super Admin v kontextu agentury).
  static Future<Map<String, String>?> getCurrentActorSnapshot({String? tenantId}) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return null;
      final dynamic res;
      if (tenantId != null && tenantId.isNotEmpty) {
        res = await SupabaseService.safeFrom('profiles', tenantId)
            .select('auth_id, first_name, last_name, name, email')
            .eq('auth_id', userId)
            .maybeSingle();
      } else {
        res = await SupabaseService.client
            .from('profiles')
            .select('auth_id, first_name, last_name, name, email')
            .eq('auth_id', userId)
            .maybeSingle();
      }
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res as Map);
      final first = (map['first_name']?.toString() ?? '').trim();
      final last = (map['last_name']?.toString() ?? '').trim();
      final name = (map['name']?.toString() ?? '').trim();
      final email = (map['email']?.toString() ?? '').trim();
      final displayName = first.isNotEmpty || last.isNotEmpty
          ? '$first $last'.trim()
          : (name.isNotEmpty ? name : '');
      return {
        'name': displayName.isEmpty ? (email.isNotEmpty ? email : userId) : displayName,
        'email': email.isEmpty ? '' : email,
      };
    } catch (e, st) {
      AppLogger.error('EnterpriseAuditPayload.getCurrentActorSnapshot: dotaz profiles selhal', e, st);
      return null;
    }
  }

  /// Sestaví kompletní mapu details pro zápis do audit_logs.details (JSONB).
  ///
  /// Slučuje enterprise klíče (record_name, actor_snapshot, previous_state, new_state, client_info,
  /// triggered_by, reason) s volitelnými [extra] klíči pro zpětnou kompatibilitu (module_key,
  /// triggered_by hodnoty z kaskády atd.). previous_state a new_state se ukládají jako kompletní
  /// JSON objekt entity – umožní budoucí Undo, Restore a zobrazení „co se přesně změnilo“.
  static Map<String, dynamic> buildDetails({
    String? recordName,
    Map<String, String>? actorSnapshot,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
    String? triggeredBy,
    String? reason,
    Map<String, dynamic>? extra,
  }) {
    final details = <String, dynamic>{};

    if (recordName != null && recordName.trim().isNotEmpty) {
      details['record_name'] = recordName.trim();
    }
    if (actorSnapshot != null && actorSnapshot.isNotEmpty) {
      details['actor_snapshot'] = Map<String, String>.from(actorSnapshot);
    }
    details['client_info'] = getClientInfo();
    if (triggeredBy != null && triggeredBy.trim().isNotEmpty) {
      details['triggered_by'] = triggeredBy.trim();
    }
    if (reason != null && reason.trim().isNotEmpty) {
      details['reason'] = reason.trim();
    }
    if (previousState != null && previousState.isNotEmpty) {
      details['previous_state'] = Map<String, dynamic>.from(previousState);
    }
    if (newState != null && newState.isNotEmpty) {
      details['new_state'] = Map<String, dynamic>.from(newState);
    }
    if (extra != null && extra.isNotEmpty) {
      for (final e in extra.entries) {
        details[e.key] = e.value;
      }
    }
    return details;
  }

  /// Vrátí z details (JSONB) hodnotu record_name, nebo null.
  static String? getRecordName(Map<String, dynamic>? details) {
    if (details == null) return null;
    final v = details['record_name'];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  /// Vrátí z details (JSONB) jméno z actor_snapshot, nebo null.
  static String? getActorNameFromSnapshot(Map<String, dynamic>? details) {
    if (details == null) return null;
    final snap = details['actor_snapshot'];
    if (snap is! Map) return null;
    final map = Map<String, dynamic>.from(snap);
    final name = (map['name']?.toString() ?? '').trim();
    return name.isEmpty ? null : name;
  }

  /// Vrátí z details (JSONB) client_info (zařízení), nebo null.
  static String? getClientInfoFromDetails(Map<String, dynamic>? details) {
    if (details == null) return null;
    final v = details['client_info'];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  /// Vrátí z details (JSONB) previous_state jako mapu, nebo null.
  static Map<String, dynamic>? getPreviousState(Map<String, dynamic>? details) {
    if (details == null) return null;
    final v = details['previous_state'];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Vrátí z details (JSONB) new_state jako mapu, nebo null.
  static Map<String, dynamic>? getNewState(Map<String, dynamic>? details) {
    if (details == null) return null;
    final v = details['new_state'];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Formátuje mapu (previous_state / new_state) na čitelný víceřádkový text pro zobrazení v dialogu.
  /// Používáme pretty-print JSON, aby uživatel viděl strukturu bez nutnosti parsovat surový objekt.
  static String formatStateForDisplay(Map<String, dynamic>? state) {
    if (state == null || state.isEmpty) return '';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(state);
    } catch (e, st) {
      AppLogger.error('EnterpriseAuditPayload.formatStateForDisplay: JsonEncoder selhal', e, st);
      return state.toString();
    }
  }
}
