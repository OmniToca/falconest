import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/calendar_feed_token_row.dart';

/// Přístup k tabulce [tenant_calendar_feed_tokens] – exportní ICS tokeny (read-only feed přes Edge).
///
/// PROČ: Veškeré dotazy jdou přes [SupabaseService.safeFrom], aby Super Admin při převtělení
/// nemohl omylem číst/zapisovat tokeny jiné agentury. Surový token se generuje v aplikaci,
/// do DB se ukládá jen SHA-256 hex – shodně s funkcí [export_calendar] a RPC [get_calendar_feed_data].
class CalendarFeedTokensRepository {
  CalendarFeedTokensRepository._();

  static const _uuid = Uuid();

  /// Sestaví veřejnou URL Edge funkce `export_calendar` s query [export_token].
  ///
  /// PROČ: Základ bereme z `config.env` (`SUPABASE_URL`), stejně jako při inicializaci klienta.
  static String buildExportCalendarUrl(String plainToken) {
    final base = (dotenv.env['SUPABASE_URL'] ?? '').trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return '';
    final encoded = Uri.encodeQueryComponent(plainToken);
    return '$base/functions/v1/export_calendar?export_token=$encoded';
  }

  static String _sha256Hex(String plain) {
    final digest = sha256.convert(utf8.encode(plain));
    return digest.toString();
  }

  /// Tokeny platné pro zobrazení v detailu apartmánu: celotenantské (`apartment_id` IS NULL)
  /// nebo vázané na tento byt.
  ///
  /// PROČ: Filtr po načtení v Dartu místo složeného PostgREST `.or()` – méně chyb v escapování UUID.
  static Future<List<CalendarFeedTokenRow>> fetchActiveForTenantAndApartment({
    required String tenantId,
    required String apartmentId,
  }) async {
    if (tenantId.trim().isEmpty) return [];
    final apt = apartmentId.trim();

    final res = await SupabaseService.safeFrom('tenant_calendar_feed_tokens', tenantId)
        .select(
          'id, tenant_id, token_hash, label, revoked_at, created_at, apartment_id, '
          'owner_visible_calendar_url',
        )
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);

    final list = res as List<dynamic>? ?? [];
    return list
        .map((e) => CalendarFeedTokenRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((r) => r.id.isNotEmpty && r.tokenHash.isNotEmpty)
        .where((r) => r.apartmentId == null || r.apartmentId!.isEmpty || r.apartmentId == apt)
        .toList();
  }

  /// Vytvoří záznam s hashem a vrátí **[row, plainToken]** – plainToken ukaž uživateli jen jednou.
  static Future<({CalendarFeedTokenRow row, String plainToken})> createToken({
    required String tenantId,
    required String label,
    String? apartmentId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw StateError('tenantId is empty');
    }
    final plain = _uuid.v4();
    final hash = _sha256Hex(plain);
    final trimmedLabel = label.trim();
    final payload = <String, dynamic>{
      'token_hash': hash,
      'label': trimmedLabel.isEmpty ? null : trimmedLabel,
    };
    if (apartmentId != null && apartmentId.trim().isNotEmpty) {
      payload['apartment_id'] = apartmentId.trim();
    }
    final visibleUrl = buildExportCalendarUrl(plain);
    if (visibleUrl.isNotEmpty) {
      payload['owner_visible_calendar_url'] = visibleUrl;
    }

    // PROČ: [SafeTenantTable.insert] už zavolá [safeInsertPayload] – neobalujeme dvakrát.
    final inserted = await SupabaseService.safeFrom('tenant_calendar_feed_tokens', tenantId)
        .insert(payload)
        .select(
          'id, tenant_id, token_hash, label, revoked_at, created_at, apartment_id, '
          'owner_visible_calendar_url',
        )
        .single();

    final row = CalendarFeedTokenRow.fromJson(Map<String, dynamic>.from(inserted as Map));
    return (row: row, plainToken: plain);
  }

  /// Soft revoke – nastaví [revoked_at] (tvrdý DELETE v migraci záměrně nepoužíváme).
  static Future<void> revokeToken({
    required String tenantId,
    required String tokenRowId,
  }) async {
    if (tenantId.trim().isEmpty || tokenRowId.trim().isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.safeFrom('tenant_calendar_feed_tokens', tenantId)
        .update({'revoked_at': now})
        .eq('id', tokenRowId.trim());
  }
}
