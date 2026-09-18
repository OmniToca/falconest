import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/legal_spain/models/apartment_legal_settings.dart';
import 'package:falconest/features/legal_spain/models/guest_checkin.dart';
import 'package:falconest/features/legal_spain/models/reservation_guest.dart';
import 'package:falconest/features/legal_spain/repositories/legal_spain_repository.dart';

/// True, pokud má aktuální tenant zaplacený / trial modul legal_spain.
bool isLegalSpainModuleActive(WidgetRef ref) =>
    isModuleActive(ref, kLegalSpainModuleKey);

final legalSpainRepositoryProvider = Provider<LegalSpainRepository>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  return LegalSpainRepository(tenantId);
});

/// Hosté jedné rezervace.
final reservationGuestsProvider =
    FutureProvider.autoDispose.family<List<ReservationGuest>, String>(
        (ref, reservationId) async {
  if (reservationId.isEmpty) return [];
  return ref.watch(legalSpainRepositoryProvider).listGuests(reservationId);
});

final guestCheckinProvider =
    FutureProvider.autoDispose.family<GuestCheckin?, String>(
        (ref, reservationId) async {
  if (reservationId.isEmpty) return null;
  return ref.watch(legalSpainRepositoryProvider).getCheckin(reservationId);
});

final apartmentLegalSettingsProvider = FutureProvider.autoDispose
    .family<ApartmentLegalSettings?, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return null;
  return ref.watch(legalSpainRepositoryProvider).loadApartmentSettings(apartmentId);
});

/// Přehled compliance. [apartmentIdsCsv] prázdné = celý tenant (admin).
final legalComplianceDashboardProvider =
    FutureProvider.autoDispose.family<List<LegalComplianceRow>, String>(
        (ref, apartmentIdsCsv) async {
  final ids = apartmentIdsCsv
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return ref.watch(legalSpainRepositoryProvider).loadDashboardRows(
        apartmentIds: ids.isEmpty ? null : ids,
      );
});

final legalVisitorBookProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(legalSpainRepositoryProvider).loadVisitorBookRows();
});
