import 'package:falconest/core/utils/task_duration_parse.dart';

/// Výchozí trvání pro issue/maintenance toky, kde dříve start == konec (nulová délka v kalendáři).
const int kDefaultTaskDurationMinutes = 60;

DateTime? _parseTimestamp(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  if (v is String) {
    final d = DateTime.tryParse(v);
    return d?.toUtc();
  }
  return null;
}

int? _readEstimatedFromMetadata(Map<String, dynamic> meta) {
  final raw = meta['estimated_minutes'] ?? meta['estimate_minutes'];
  if (raw == null) return null;
  if (raw is int) return raw > 0 ? raw : null;
  if (raw is num) {
    final n = raw.round();
    return n > 0 ? n : null;
  }
  final p = int.tryParse(raw.toString().trim());
  return p != null && p > 0 ? p : null;
}

/// Vrátí hodnotu pro sloupec `tasks.title_i18n` při INSERT — nikdy `null` (Postgres NOT NULL, kód 23502).
///
/// PROČ: Generátory používají `?snapshot` v mapě — při chybějícím překladu klíč vypadne nebo
/// Supabase klient pošle explicitní null. Prázdný JSON `{}` je v aplikaci ekvivalent „žádné překlady“.
Map<String, dynamic> ensureTaskTitleI18nForInsert(dynamic raw) {
  if (raw == null) return <String, dynamic>{};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

/// Sjednocuje INSERT payload pro `tasks`: `scheduled_start`, `due_date`, `metadata.estimated_minutes`.
///
/// PROČ: Single source of truth – kalendář a reporty čtou interval a metadata; bez tohoto vznikají
/// nekonzistence (stejný čas na začátku a konci, chybějící odhad).
///
/// **KRITICKÉ – merge `metadata`:** Nikdy nepřepisujeme celý JSONB objekt jen odhadem času. Vždy
/// vytvoříme kopii existující mapy (`Map.from`), doplníme/aktualizujeme pouze klíče související
/// s trváním (`estimated_minutes`), takže zůstávají zachované finanční a procesní hodnoty
/// (např. `amount_to_collect`, `transit_amount_to_collect`, `payer_type`, `requires_photo`, …).
Map<String, dynamic> sanitizeTaskInsertPayload(Map<String, dynamic> raw) {
  final out = Map<String, dynamic>.from(raw);
  if (out['metadata'] != null && out['metadata'] is! Map) {
    out['metadata'] = <String, dynamic>{};
  }
  // Bezpečný merge: kopie všech existujících klíčů, pak jen doplnění estimated_minutes.
  final meta = Map<String, dynamic>.from((out['metadata'] as Map?) ?? {});

  var sched = _parseTimestamp(out['scheduled_start']);
  var due = _parseTimestamp(out['due_date']);
  final desc = out['description']?.toString() ?? '';

  var est = _readEstimatedFromMetadata(meta);

  if (sched != null && due != null) {
    final diffMin = due.difference(sched).inMinutes;
    if (diffMin > 0) {
      if (est == null || est <= 0) {
        est = diffMin;
      }
      meta['estimated_minutes'] = est;
    } else {
      // Start a konec shodné nebo obrácené – typicky issue/worker; použij výchozí blok.
      est = kDefaultTaskDurationMinutes;
      due = sched.add(Duration(minutes: est));
      meta['estimated_minutes'] = est;
    }
  } else if (sched != null && due == null) {
    if (est == null || est <= 0) {
      est = parseDurationMinutesFromDescription(desc);
      if (est <= 0) est = kDefaultTaskDurationMinutes;
    }
    due = sched.add(Duration(minutes: est));
    meta['estimated_minutes'] = est;
  } else if (sched == null && due != null) {
    if (est == null || est <= 0) {
      est = parseDurationMinutesFromDescription(desc);
      if (est <= 0) est = kDefaultTaskDurationMinutes;
    }
    sched = due.subtract(Duration(minutes: est));
    meta['estimated_minutes'] = est;
  }

  out['scheduled_start'] = sched?.toIso8601String();
  out['due_date'] = due?.toIso8601String();
  out['metadata'] = meta;
  // Ochrana před chybou 23502: `title_i18n` nesmí být v DB null — vždy posíláme validní JSON objekt (min. {}).
  out['title_i18n'] = ensureTaskTitleI18nForInsert(out['title_i18n']);
  return out;
}
