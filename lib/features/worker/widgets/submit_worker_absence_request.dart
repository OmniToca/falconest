/// Odeslání žádosti o absenci – mobil Drift+fronta, web Supabase (+ fronta při chybě).
library;

export 'submit_worker_absence_request_io.dart' if (dart.library.html) 'submit_worker_absence_request_web.dart';
