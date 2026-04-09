import 'package:flutter/material.dart';

/// Jedna vlastní štítek úkolu (VIP, Pes…) ukládaný v `tasks.metadata.custom_tags`.
///
/// PROČ: Kategorie úkolu (úklid, check-in) zůstávají v `task_type`; štítky dávají agentuře
/// volné barevné značení bez změny schématu DB — vše v JSONB metadatech.
class TaskCustomTag {
  const TaskCustomTag({required this.label, required this.color});

  final String label;
  final Color color;

  /// Serializace do JSON pole v `metadata['custom_tags']`.
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'color': _colorToHex(color),
    };
  }

  static TaskCustomTag? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final label = (m['label'] ?? m['t'])?.toString().trim() ?? '';
    if (label.isEmpty) return null;
    final color = _parseColor(m['color'] ?? m['c']);
    return TaskCustomTag(label: label, color: color);
  }

  /// Načte seznam štítků z `tasks.metadata`.
  static List<TaskCustomTag> listFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return [];
    final raw = metadata['custom_tags'];
    if (raw is! List) return [];
    final out = <TaskCustomTag>[];
    for (final e in raw) {
      final t = tryParse(e);
      if (t != null) out.add(t);
    }
    return out;
  }

  /// Zapíše štítky do mapy metadat (nahradí klíč `custom_tags`).
  static void applyToMetadata(Map<String, dynamic> metadata, List<TaskCustomTag> tags) {
    if (tags.isEmpty) {
      metadata.remove('custom_tags');
    } else {
      metadata['custom_tags'] = tags.map((e) => e.toJson()).toList();
    }
  }

  /// Texty štítků spojené pro vyhledávání v Kanbanu (malá písmena).
  static String searchBlob(Map<String, dynamic>? metadata) {
    final tags = listFromMetadata(metadata);
    return tags.map((t) => t.label.toLowerCase()).join(' ');
  }

  /// Barva popředí štítku pro čitelnost na libovolném pozadí.
  static Color readableForegroundOn(Color bg) {
    final r = (bg.r * 255.0).round();
    final g = (bg.g * 255.0).round();
    final b = (bg.b * 255.0).round();
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.55 ? const Color(0xFF212121) : const Color(0xFFFFFFFF);
  }

  static String _colorToHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  static Color _parseColor(dynamic raw) {
    if (raw is int) return Color(raw);
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return const Color(0xFF607D8B);
    var hex = s;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    if (hex.length == 8) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(v);
    }
    return const Color(0xFF607D8B);
  }
}
