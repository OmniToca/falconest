/// Podmíněný export todays_tasks_provider – web vs. mobil.
///
/// Na webu vrací prázdný seznam (aktivní dashboard používá worker_dashboard_provider).
/// Na mobilu čte z Isar a mapuje na List<WorkerTask>.
library;
export 'todays_tasks_provider_stub.dart'
    if (dart.library.html) 'todays_tasks_provider_web.dart'
    if (dart.library.io) 'todays_tasks_provider_mobile.dart';
