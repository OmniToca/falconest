import 'dart:typed_data';

import 'package:falconest/core/services/supabase_service.dart';

/// Servis pro upload podpisu hosta do Supabase Storage.
///
/// PROČ: Podpis je důkaz převzetí služby. Ukládáme ho do tenant-segregované cesty,
/// aby byl auditovatelný a oddělený mezi agenturami.
class SignatureService {
  SignatureService._();

  static const String _bucket = 'falconest_media';

  /// Nahraje PNG podpis do cesty:
  /// `tenant_id/tasks/signatures/{task_id}_signature.png`.
  ///
  /// Vrací veřejnou URL na nahraný podpis.
  static Future<String> uploadTaskGuestSignature({
    required String tenantId,
    required String taskId,
    required Uint8List pngBytes,
  }) async {
    final path = '$tenantId/tasks/signatures/${taskId}_signature.png';
    final storage = SupabaseService.client.storage.from(_bucket);
    // PROČ: Cílový název je fixní dle zadání; před uploadem smažeme starou verzi, aby
    // opakované podepsání stejného úkolu nepadalo na kolizi souboru.
    await storage.remove([path]);
    await SupabaseService.client.storage.from(_bucket).uploadBinary(
          path,
          pngBytes,
        );
    return SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
  }
}
