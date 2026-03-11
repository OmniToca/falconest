/// Podmíněný export AuditLogRepository.
///
/// Na webu – Supabase přímo, žádný Isar.
/// Na mobilu – Isar offline-first s PendingAuditAction.
library;
export 'audit_log_shared.dart';
export 'audit_log_repository_web.dart'
    if (dart.library.io) 'audit_log_repository_mobile.dart';
