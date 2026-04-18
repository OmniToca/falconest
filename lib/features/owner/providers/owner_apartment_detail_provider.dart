import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/constants/apartment_rental_constants.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Model detailu apartmánu pro read-only zobrazení majiteli.
///
/// Obsahuje všechna pole z tabulky apartments relevantní pro majitele.
class OwnerApartmentDetail {
  const OwnerApartmentDetail({
    required this.id,
    required this.name,
    this.address,
    this.keybox,
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.standardCleaningDuration,
    this.ownerNotes,
    this.reviewLink,
    this.calendarFeedUrl,
    this.parkingInstructions,
    this.unitCode,
    this.monthlyManagementFee,
    this.managedFrom,
    this.investmentTrackingEnabled = false,
    this.rentalMode = kApartmentRentalModeShortTerm,
    this.rentCollectionMode = kApartmentRentCollectionModeNotification,
    this.rentAmount = 0.0,
  });

  final String id;
  final String name;
  final String? address;
  final String? keybox;
  final String? status;
  final String? checkInTime;
  final String? checkOutTime;
  final int? standardCleaningDuration;
  final String? ownerNotes;

  /// Odkaz na recenze (Booking/Airbnb) – z [apartments.review_link].
  final String? reviewLink;

  /// Veřejný iCal odkaz z RPC [get_owner_calendar_feed_url_for_apartment], pokud agentura token založila.
  final String? calendarFeedUrl;

  /// Instrukce k parkování pro personál – [apartments.parking_instructions].
  final String? parkingInstructions;

  /// Interní kód jednotky – [apartments.code].
  final String? unitCode;

  /// Poplatek za správu (měsíčně) – [apartments.monthly_management_fee].
  final double? monthlyManagementFee;

  /// Správa od data – [apartments.managed_from].
  final DateTime? managedFrom;

  /// Příznak modulu investičního přehledu – [apartments.investment_tracking_enabled].
  final bool investmentTrackingEnabled;

  /// Režim pronájmu – [apartments.rental_mode].
  final String rentalMode;

  /// Připomínka vs. úkol výběru nájmu – [apartments.rent_collection_mode].
  final String rentCollectionMode;

  /// Měsíční nájem u dlouhodobého bytu – [apartments.rent_amount].
  final double rentAmount;
}

/// Provider načítající detail apartmánu pro Klientský portál.
///
/// SECURITY: Double Guard – načte apartmán jen pokud je v seznamu vlastněných bytů.
/// Pokud apartmentId není mezi ownedApartmentIds, vrátí null (404).
final ownerApartmentDetailProvider =
    FutureProvider.autoDispose.family<OwnerApartmentDetail?, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return null;

  final apartments = await ref.read(ownerApartmentsProvider.future);
  final ownedIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toSet();

  if (!ownedIds.contains(apartmentId)) return null;

  try {
    final res = await SupabaseService.client
        .from('apartments')
        .select(
          'id, name, address, keybox, status, check_in_time, check_out_time, '
          'standard_cleaning_duration, owner_notes, review_link, '
          'parking_instructions, code, monthly_management_fee, managed_from, '
          'investment_tracking_enabled, rental_mode, rent_collection_mode, rent_amount',
        )
        .eq('id', apartmentId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (res == null) return null;
    final map = Map<String, dynamic>.from(res as Map);

    final reviewLink = () {
      final v = (map['review_link']?.toString() ?? '').trim();
      return v.isEmpty ? null : v;
    }();

    // PROČ: Surový token v DB není; URL se čte přes SECURITY DEFINER RPC (pouze vlastník bytu).
    String? calendarFeedUrl;
    try {
      final raw = await SupabaseService.client.rpc(
        'get_owner_calendar_feed_url_for_apartment',
        params: {'p_apartment_id': apartmentId},
      );
      if (raw != null) {
        final s = raw.toString().trim();
        if (s.isNotEmpty) calendarFeedUrl = s;
      }
    } catch (e, st) {
      AppLogger.error('ownerApartmentDetailProvider: RPC get_owner_calendar_feed_url selhalo', e, st);
      calendarFeedUrl = null;
    }

    return OwnerApartmentDetail(
      id: (map['id']?.toString() ?? '').trim(),
      name: (map['name']?.toString() ?? '').trim(),
      address: () {
        final v = (map['address']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      keybox: () {
        final v = (map['keybox']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      status: () {
        final v = (map['status']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      checkInTime: () {
        final v = (map['check_in_time']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      checkOutTime: () {
        final v = (map['check_out_time']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      standardCleaningDuration: map['standard_cleaning_duration'] is int
          ? map['standard_cleaning_duration'] as int
          : (int.tryParse(map['standard_cleaning_duration']?.toString() ?? '')),
      ownerNotes: () {
        final v = (map['owner_notes']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      reviewLink: reviewLink,
      calendarFeedUrl: calendarFeedUrl,
      parkingInstructions: () {
        final v = (map['parking_instructions']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      unitCode: () {
        final v = (map['code']?.toString() ?? '').trim();
        return v.isEmpty ? null : v;
      }(),
      monthlyManagementFee: () {
        final raw = map['monthly_management_fee'];
        if (raw == null) return null;
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw.toString());
      }(),
      managedFrom: () {
        final raw = map['managed_from'];
        if (raw == null) return null;
        if (raw is DateTime) return raw;
        if (raw is String) return DateTime.tryParse(raw);
        return null;
      }(),
      investmentTrackingEnabled: () {
        final v = map['investment_tracking_enabled'];
        if (v is bool) return v;
        return v?.toString().toLowerCase() == 'true';
      }(),
      rentalMode: () {
        final s = (map['rental_mode']?.toString() ?? '').trim().toLowerCase();
        return s == kApartmentRentalModeLongTerm ? kApartmentRentalModeLongTerm : kApartmentRentalModeShortTerm;
      }(),
      rentCollectionMode: () {
        final s = (map['rent_collection_mode']?.toString() ?? '').trim().toLowerCase();
        return s == kApartmentRentCollectionModeTask
            ? kApartmentRentCollectionModeTask
            : kApartmentRentCollectionModeNotification;
      }(),
      rentAmount: () {
        final raw = map['rent_amount'];
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw?.toString() ?? '') ?? 0.0;
      }(),
    );
  } catch (e, st) {
    AppLogger.error('ownerApartmentDetailProvider: načtení detailu bytu selhalo', e, st);
    return null;
  }
});
