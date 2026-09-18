/// Jediný vstup pro deferred import Super Admin / HQ obrazovek (menší web bundle agentury).
///
/// PROČ: `app_router` načte tento soubor přes `deferred as` až při navigaci na /super-admin.
library;

export 'package:falconest/features/super_admin/audit_log_screen.dart';
export 'package:falconest/features/super_admin/onboarding_wizard_screen.dart';
export 'package:falconest/features/super_admin/super_admin_dashboard.dart';
export 'package:falconest/features/super_admin/tenant_detail_screen.dart';
