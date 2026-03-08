import 'package:falconest/core/services/supabase_service.dart';

/// Zpracuje frontovaný offline issue task z MutationQueueService.
///
/// PROČ: Pracovník může nahlásit problém bez připojení k internetu. Payload
/// obsahuje surový přepis (description), tenant_id, apartment_id atd. Místo
/// přímého INSERT voláme Edge Function `process-issue-ai`, která:
/// 1) Pomocí OpenAI přeloží popis do španělštiny a vytvoří nadpis,
/// 2) Při výpadku AI (fail-safe) uloží surový text s fallback nadpisem,
/// 3) Provede INSERT do tasks s Service Role. Mutace se smaže ze fronty
/// POUZE při 200 OK – při 5xx zůstane k opakování.
Future<void> processOfflineIssueTask(Map<String, dynamic> payload) async {
  final tenantId = payload['tenant_id']?.toString();
  if (tenantId == null || tenantId.isEmpty) return;

  // Volání Edge Function místo přímého INSERT – AI překlad + fallback
  final res = await SupabaseService.client.functions.invoke(
    'process-issue-ai',
    body: payload,
  );

  if (res.status != 200) {
    // 5xx nebo jiná chyba – hodíme výjimku, drift_mutation_queue_service
    // ji zachytí a při isRetryableError ponechá mutaci ve frontě
    throw ProcessIssueTaskException(
      status: res.status,
      message: res.data is Map && (res.data as Map).containsKey('error')
          ? (res.data as Map)['error']?.toString() ?? 'Unknown error'
          : 'process-issue-ai vrátila status ${res.status}',
    );
  }
}

/// Výjimka při selhání Edge Function – umožňuje DriftMutationQueueService
/// rozpoznat 5xx jako retryable (mutace zůstane ve frontě).
class ProcessIssueTaskException implements Exception {
  ProcessIssueTaskException({required this.status, required this.message});

  final int status;
  final String message;

  @override
  String toString() => 'ProcessIssueTaskException(status=$status): $message';

  /// 5xx = přechodná chyba serveru – mutace se má ponechat k opakování.
  bool get isRetryable => status >= 500;
}
