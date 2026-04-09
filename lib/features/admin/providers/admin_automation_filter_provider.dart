import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Požadovaný předfiltr obrazovky Automatizace při vstupu z Dashboard KPI.
///
/// PROČ: Z dashboardu manažer často řeší incident (selhání queue/log). Tímto
/// stavem předáme kontext do `AdminAutomationsScreen`, aby se otevřela správná
/// záložka a seznam byl předfiltrovaný na relevantní stav.
class AdminAutomationFilterState {
  const AdminAutomationFilterState({
    required this.preferredTabIndex,
    required this.showFailedQueue,
    required this.showFailedLog,
  });

  /// 0=Pravidla, 1=Čekárna, 2=Historie.
  final int preferredTabIndex;
  final bool showFailedQueue;
  final bool showFailedLog;
}

/// Jednorázový filtr pro `AdminAutomationsScreen`.
final adminAutomationFilterProvider =
    StateProvider<AdminAutomationFilterState?>((ref) => null);

