import 'package:falconest/core/repositories/task/task_insert_sanitizer.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Centrální „dveře“ pro INSERT do `tasks` – vždy přes [sanitizeTaskInsertPayload].
///
/// PROČ: Repository pattern; žádné přímé `.insert` mimo tento modul pro aplikační toky vytváření úkolů.
class SupabaseTaskInsertRepository {
  SupabaseTaskInsertRepository._();

  /// Jeden úkol. [payload] musí obsahovat `tenant_id`.
  ///
  /// Vrací nové `id` řádku v `tasks` (pro navázání např. na `task_checklists`).
  static Future<String> createTask(Map<String, dynamic> payload) async {
    final tenantId = payload['tenant_id']?.toString();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('SupabaseTaskInsertRepository: chybí tenant_id');
    }
    final sanitized = sanitizeTaskInsertPayload(Map<String, dynamic>.from(payload));
    final row = await SupabaseService.safeFrom('tasks', tenantId).insert(sanitized).select('id').single();
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StateError('SupabaseTaskInsertRepository: INSERT tasks nevrátil id');
    }
    return id;
  }

  /// Dávka se stejným tenantem (smart/scheduled generátor).
  /// Vrací [id] vytvořených řádků ve stejném pořadí jako [payloads] (pro navázání checklistů).
  static Future<List<String>> createTasksBatch(List<Map<String, dynamic>> payloads) async {
    if (payloads.isEmpty) return [];
    final tenantId = payloads.first['tenant_id']?.toString();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('SupabaseTaskInsertRepository: chybí tenant_id u dávky');
    }
    for (final p in payloads) {
      if (p['tenant_id']?.toString() != tenantId) {
        throw StateError('SupabaseTaskInsertRepository: dávka musí mít jednotný tenant_id');
      }
    }
    final sanitized = payloads.map((p) => sanitizeTaskInsertPayload(Map<String, dynamic>.from(p))).toList();
    final raw = await SupabaseService.safeFrom('tasks', tenantId).insert(sanitized).select('id');
    final list = raw as List<dynamic>;
    return list
        .map((e) => ((e as Map)['id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
