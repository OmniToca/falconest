/// Model záznamu tabulky [reservation_services] – služba přiřazená k rezervaci (Override Pattern úroveň 3).
///
/// [charged_price] je skutečně účtovaná cena za tuto službu u této rezervace (v EUR).
/// [custom_note] je poznámka klienta k službě (např. „Dětská sedačka“ u transferu).
class ReservationServiceRow {
  const ReservationServiceRow({
    required this.id,
    required this.tenantId,
    required this.reservationId,
    required this.apartmentServiceId,
    this.chargedPrice,
    this.customNote,
    this.payerType,
  });

  final String id;
  final String tenantId;
  final String reservationId;
  final String apartmentServiceId;
  final num? chargedPrice;
  final String? customNote;
  /// Kdo platí službu u této rezervace (override); null = použít z apartment_services.
  final String? payerType;

  factory ReservationServiceRow.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['charged_price'];
    num? price;
    if (rawPrice != null) {
      if (rawPrice is num) {
        price = rawPrice;
      } else if (rawPrice is String) {
        price = num.tryParse(rawPrice);
      }
    }
    final note = (json['custom_note'] as String?)?.trim();
    return ReservationServiceRow(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      reservationId: json['reservation_id'] as String? ?? '',
      apartmentServiceId: json['apartment_service_id'] as String? ?? '',
      chargedPrice: price,
      customNote: (note != null && note.isNotEmpty) ? note : null,
      payerType: () {
        final v = (json['payer_type'] as String?)?.trim();
        return (v == 'owner' || v == 'guest') ? v : null;
      }(),
    );
  }
}

/// Položka služby bytu s názvem a výchozí cenou – pro výběr v Tabu „Služby a požadavky“.
/// [apartmentServiceId] = id z apartment_services, [serviceName] a [defaultPriceEur] z katalogu/bytu.
/// [isMandatory] = pokud true, v rezervaci nelze službu odškrtnout (checkbox zamčený).
/// [durationMinutes] = časová náročnost služby z tenant_services – pro výpočet Cleaning Buffer (kolize rezervací).
class ApartmentServiceOption {
  const ApartmentServiceOption({
    required this.apartmentServiceId,
    required this.serviceId,
    required this.serviceName,
    required this.defaultPriceEur,
    this.isMandatory = false,
    this.payerType = 'guest',
    this.durationMinutes = 0,
  });

  final String apartmentServiceId;
  final String serviceId;
  final String serviceName;
  final double defaultPriceEur;
  final bool isMandatory;
  /// Výchozí plátce z apartment_services (pro předvyplnění v dialogu rezervace).
  final String payerType;
  /// Časová náročnost / rezerva v minutách z tenant_services. Pro výpočet celkového času úklidu při kontrole kolizí.
  final int durationMinutes;
}

/// Lokální stav jedné služby v dialogu rezervace – zaškrtnutí a účtovaná cena / poznámka.
class ReservationServiceEditState {
  const ReservationServiceEditState({
    required this.apartmentServiceId,
    required this.serviceName,
    this.defaultPriceEur = 0,
    this.enabled = false,
    this.chargedPriceEur,
    this.customNote,
    this.payerType = 'guest',
  });

  final String apartmentServiceId;
  final String serviceName;
  final double defaultPriceEur;
  final bool enabled;
  final double? chargedPriceEur;
  final String? customNote;
  /// Kdo platí službu: 'owner' (majitel) nebo 'guest' (host).
  final String payerType;

  ReservationServiceEditState copyWith({
    bool? enabled,
    double? chargedPriceEur,
    String? customNote,
    String? payerType,
  }) {
    return ReservationServiceEditState(
      apartmentServiceId: apartmentServiceId,
      serviceName: serviceName,
      defaultPriceEur: defaultPriceEur,
      enabled: enabled ?? this.enabled,
      chargedPriceEur: chargedPriceEur ?? this.chargedPriceEur,
      customNote: customNote ?? this.customNote,
      payerType: payerType ?? this.payerType,
    );
  }
}
