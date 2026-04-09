import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/models/calendar_feed_token_row.dart';
import 'package:falconest/features/admin/repositories/calendar_feed_tokens_repository.dart';

/// Identifikátor scope pro načtení exportních tokenů v kontextu záložky apartmánu.
///
/// PROČ: [tenantId] musí souhlasit s bytem (RLS + safeFrom); [apartmentId] filtruje řádky
/// „jen tento byt“ vs. „celá agentura“ při zobrazení seznamu.
typedef CalendarFeedTokensScope = ({String tenantId, String apartmentId});

/// Seznam nezrušených tokenů relevantních pro daný apartmán (tenant-wide + apartment-scoped).
final calendarFeedExportTokensProvider = FutureProvider.autoDispose
    .family<List<CalendarFeedTokenRow>, CalendarFeedTokensScope>((ref, scope) async {
  if (scope.tenantId.trim().isEmpty || scope.apartmentId.trim().isEmpty) {
    return [];
  }
  return CalendarFeedTokensRepository.fetchActiveForTenantAndApartment(
    tenantId: scope.tenantId.trim(),
    apartmentId: scope.apartmentId.trim(),
  );
});
