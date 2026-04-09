import 'package:flutter/material.dart';

/// Globální [ScaffoldMessenger] pro SnackBar z kódu bez [BuildContext]
/// (např. [AuthNotifier], [UserDeviceRepository] při selhání zápisu FCM tokenu).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
