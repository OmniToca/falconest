import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Požadovaný index interních záložek na obrazovce `AdminAutomationsScreen`.
///
/// PROČ: Dashboard potřebuje z KPI karet pro rychlou orientaci otevřít přímo
/// konkrétní záložku „Čekárna“ (fronta) nebo „Historie“ (log), aniž by uživatel
/// musel ručně přepínat TabBar.
///
/// - 0 = Pravidla
/// - 1 = Čekárna / Fronta
/// - 2 = Historie / Log
final adminAutomationTabIndexProvider = StateProvider<int>((ref) => 0);

