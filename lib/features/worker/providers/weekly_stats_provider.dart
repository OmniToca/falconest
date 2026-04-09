/// Týdenní statistiky workera – mobil: dokončené úkoly z Driftu, web: plán z Supabase.
library;

export 'weekly_stats_types.dart';
export 'weekly_stats_provider_io.dart' if (dart.library.html) 'weekly_stats_provider_web.dart';
