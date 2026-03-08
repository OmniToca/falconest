import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
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
          'standard_cleaning_duration, owner_notes',
        )
        .eq('id', apartmentId)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (res == null) return null;
    final map = Map<String, dynamic>.from(res as Map);

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
    );
  } catch (_) {
    return null;
  }
});
