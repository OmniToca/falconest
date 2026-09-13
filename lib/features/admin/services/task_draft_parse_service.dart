import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/models/task_form_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Volání Edge funkce [parse-task-draft] – extrakce polí úkolu z textu / screenshotu.
///
/// PROČ samostatná služba: JWT header explicitně (Flutter Web), parsování JSON
/// a mapování na [TaskFormDraft] mimo UI vrstvu.
class TaskDraftParseService {
  TaskDraftParseService._();

  static const int maxRawTextLength = 2000;

  /// Pošle text a/nebo Base64 obrázek na server; vrátí návrh formuláře (bez INSERT).
  static Future<TaskFormDraft> parseFromText({
    required String rawText,
    String? locale,
    String? tenantTimezone,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final trimmed = rawText.trim();
    final hasImage = imageBase64 != null && imageBase64.trim().isNotEmpty;
    if (trimmed.isEmpty && !hasImage) {
      throw TaskDraftParseException('TASK_DRAFT_EMPTY_TEXT');
    }
    if (trimmed.length > maxRawTextLength) {
      throw TaskDraftParseException('TASK_DRAFT_TEXT_TOO_LONG');
    }

    final client = SupabaseService.client;

    // PROČ: Gateway Edge Functions (verify_jwt) i naše auth.getUser vyžadují platný
    // uživatelský access token. Před invoke případně refreshneme session (Flutter Web).
    var session = client.auth.currentSession;
    if (session == null) {
      throw TaskDraftParseException('TASK_DRAFT_NO_SESSION');
    }

    final expiresAt = session.expiresAt;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final shouldRefresh =
        expiresAt == null || expiresAt <= nowSec + 60;
    if (shouldRefresh) {
      try {
        final refreshed = await client.auth.refreshSession();
        session = refreshed.session ?? client.auth.currentSession;
      } catch (e, st) {
        AppLogger.error(
          'TaskDraftParseService: refreshSession selhal',
          e,
          st,
        );
        session = client.auth.currentSession;
      }
    }

    if (session == null) {
      throw TaskDraftParseException('TASK_DRAFT_NO_SESSION');
    }

    final accessToken = session.accessToken.trim();
    if (accessToken.isEmpty) {
      AppLogger.error(
        'TaskDraftParseService: accessToken je prázdný',
        'empty token',
        StackTrace.current,
      );
      throw TaskDraftParseException('TASK_DRAFT_NO_SESSION');
    }

    final body = <String, dynamic>{
      'raw_text': trimmed,
      'reference_now_utc': DateTime.now().toUtc().toIso8601String(),
      if (locale != null && locale.isNotEmpty) 'locale': locale,
      if (tenantTimezone != null && tenantTimezone.isNotEmpty)
        'tenant_timezone': tenantTimezone,
      if (hasImage) 'image_base64': imageBase64.trim(),
      if (hasImage && imageMimeType != null && imageMimeType.isNotEmpty)
        'image_mime_type': imageMimeType,
    };

    // PROČ: Explicitní Bearer – stejný vzor jako TwilioProvisionService /
    // AutomationQueueRepository. Bez něj gateway / Edge Function často dostane
    // anon key a vrátí 401/403 (zejména Flutter Web).
    final res = await client.functions.invoke(
      'parse-task-draft',
      body: body,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (res.status == 429) {
      throw TaskDraftParseException('TASK_DRAFT_RATE_LIMIT');
    }
    if (res.status == 401 || res.status == 403) {
      final err = _extractError(res.data);
      AppLogger.error(
        'TaskDraftParseService: parse-task-draft HTTP ${res.status} '
        '(jwtLen=${accessToken.length}, error=${err ?? res.data})',
        err ?? 'forbidden',
        StackTrace.current,
      );
      throw TaskDraftParseException('TASK_DRAFT_FORBIDDEN');
    }
    if (res.status != 200) {
      final err = _extractError(res.data);
      AppLogger.error(
        'TaskDraftParseService: parse-task-draft HTTP ${res.status}',
        err ?? 'unknown',
        StackTrace.current,
      );
      throw TaskDraftParseException(err ?? 'TASK_DRAFT_HTTP_${res.status}');
    }

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw TaskDraftParseException('TASK_DRAFT_INVALID_RESPONSE');
    }

    return TaskFormDraft.fromEdgeResponse(data);
  }

  static String? _extractError(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final e = map['error'];
      if (e is String && e.isNotEmpty) {
        final detail = map['detail'];
        if (detail is String && detail.isNotEmpty) {
          return '$e ($detail)';
        }
        return e;
      }
      // Gateway Supabase někdy vrací { message: "..." } místo { error: "..." }.
      final msg = map['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return null;
  }
}

/// Chyba parsování – UI mapuje kód na lokalizovaný text.
class TaskDraftParseException implements Exception {
  TaskDraftParseException(this.code);
  final String code;

  @override
  String toString() => 'TaskDraftParseException($code)';
}

/// Provider pro volání parse služby z dialogu (loading stav přes AsyncValue).
final taskDraftParseProvider =
    FutureProvider.autoDispose.family<TaskFormDraft, String>((ref, rawText) async {
  final auth = ref.read(authNotifierProvider);
  return TaskDraftParseService.parseFromText(
    rawText: rawText,
    locale: auth.state.languageCode,
    tenantTimezone: auth.state.effectiveTenantTimezone,
  );
});
