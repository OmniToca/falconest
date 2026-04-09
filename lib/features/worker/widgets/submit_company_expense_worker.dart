/// Odeslání firemního výdaje – mobil Drift+fronta při výpadku, web jen Supabase.
library;

export 'submit_company_expense_worker_io.dart' if (dart.library.html) 'submit_company_expense_worker_web.dart';
