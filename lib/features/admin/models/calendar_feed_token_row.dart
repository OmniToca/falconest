import 'package:flutter/foundation.dart';

/// Jedna aktivní nebo historická položka z tabulky [tenant_calendar_feed_tokens].
///
/// PROČ: V DB je uložen pouze [tokenHash] (SHA-256 hex); surový tajný token se po vytvoření
/// ukáže uživateli jen jednou. [apartmentId] null = feed celého tenanta; NOT NULL = jen úkoly daného bytu.
@immutable
class CalendarFeedTokenRow {
  const CalendarFeedTokenRow({
    required this.id,
    required this.tenantId,
    required this.tokenHash,
    this.label,
    this.revokedAt,
    required this.createdAt,
    this.apartmentId,
    this.ownerVisibleCalendarUrl,
  });

  final String id;
  final String tenantId;
  final String tokenHash;
  final String? label;
  final DateTime? revokedAt;
  final DateTime createdAt;
  final String? apartmentId;

  /// Kopie veřejného ICS odkazu (s `export_token`) pro majitelský portál; v DB jen pokud byl token vytvořen po doplnění sloupce.
  final String? ownerVisibleCalendarUrl;

  bool get isActive => revokedAt == null;

  factory CalendarFeedTokenRow.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    final apt = json['apartment_id'];
    final rawUrl = json['owner_visible_calendar_url'];
    final urlStr = rawUrl?.toString().trim();
    return CalendarFeedTokenRow(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      tokenHash: (json['token_hash'] as String?)?.trim() ?? '',
      label: (json['label'] as String?)?.trim(),
      revokedAt: parseTs(json['revoked_at']),
      createdAt: parseTs(json['created_at']) ?? DateTime.now().toUtc(),
      apartmentId: () {
        final s = apt?.toString().trim() ?? '';
        return s.isEmpty ? null : s;
      }(),
      ownerVisibleCalendarUrl: (urlStr == null || urlStr.isEmpty) ? null : urlStr,
    );
  }
}
