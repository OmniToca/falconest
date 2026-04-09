/// Worker peněženka: mobil Drift, web Supabase Realtime.
library;

export 'finance_cash_worker_wallet_io.dart' if (dart.library.html) 'finance_cash_worker_wallet_web.dart';
