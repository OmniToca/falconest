/// Hodnoty sloupce `apartments.rental_mode` v Supabase (CHECK constraint).
///
/// PROČ: Jedna pravda pro API, migrace i UI – žádné magické řetězce po projektu.
const String kApartmentRentalModeShortTerm = 'short_term';
const String kApartmentRentalModeLongTerm = 'long_term';

/// Režim automatické evidence nájmu u dlouhodobého bytu (`apartments.rent_collection_mode`).
const String kApartmentRentCollectionModeNotification = 'notification';
const String kApartmentRentCollectionModeTask = 'task';
