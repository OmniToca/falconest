/// Motivační měsíční statistiky workera – mobil Drift (stream), web Supabase (future).
library;

export 'worker_motivation_stats_provider_io.dart'
    if (dart.library.html) 'worker_motivation_stats_provider_web.dart';
