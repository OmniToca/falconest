// Zapouzdření zápisů checklistu (mobil: Drift + fronta; web: no-op).
export 'worker_task_checklist_ops_provider_stub.dart'
    if (dart.library.io) 'worker_task_checklist_ops_provider_io.dart';
