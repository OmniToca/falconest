/// Podmíněný export messageTemplatesForWorkerProvider.
///
/// Na webu → prázdný seznam (Worker UI na webu nečte lokální šablony).
/// Na mobilu → Drift (SQLite), Isar odstraněn.
export 'message_templates_provider_web.dart'
    if (dart.library.io) 'message_templates_provider_mobile.dart';
