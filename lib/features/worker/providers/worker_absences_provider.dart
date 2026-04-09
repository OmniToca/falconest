/// Provider nepřítomností workera – mobil: Drift stream, web: Supabase.
library;

export 'worker_absences_format.dart';
export 'worker_absences_provider_io.dart' if (dart.library.html) 'worker_absences_provider_web.dart';
