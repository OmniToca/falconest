/// Zpětná kompatibilita pro staré záznamy – parsuje prefix [FLIGHT:XXX] z custom_note.
/// DEPRECATED: DB má nativní sloupec flight_number. Používá se jen při načítání starých záznamů,
/// kde flight_number je NULL a custom_note obsahoval [FLIGHT:FR1495]\nzbytek.
(String? flightNumber, String? noteRest) parseFlightFromCustomNote(String? raw) {
  if (raw == null || raw.trim().isEmpty) return (null, null);
  final trimmed = raw.trim();
  final match = RegExp(r'^\[FLIGHT:([^\]]+)\]\s*\n?(.*)$', dotAll: true).firstMatch(trimmed);
  if (match != null) {
    final flight = match.group(1)?.trim();
    final rest = match.group(2)?.trim();
    return (flight?.isEmpty == true ? null : flight, rest?.isEmpty == true ? null : rest);
  }
  return (null, trimmed);
}

/// Model záznamu tabulky [reservation_services] – služba přiřazená k rezervaci (Override Pattern úroveň 3).
///
/// [charged_price] je skutečně účtovaná cena za tuto službu u této rezervace (v EUR).
/// [custom_note] je poznámka klienta k službě (např. „Dětská sedačka“ u transferu).
/// [requiresPhoto] – null = dopočítat z bytu/katalogu, true/false = snapshot pro tuto rezervaci.
class ReservationServiceRow {
  const ReservationServiceRow({
    required this.id,
    required this.tenantId,
    required this.reservationId,
    required this.apartmentServiceId,
    this.chargedPrice,
    this.transitCashToCollect,
    this.customNote,
    this.flightNumber,
    this.payerType,
    this.requiresPhoto,
  });

  final String id;
  final String tenantId;
  final String reservationId;
  final String apartmentServiceId;
  final num? chargedPrice;
  /// Hotovost za ubytování (průtok majiteli), EUR – odděleně od [chargedPrice].
  final num? transitCashToCollect;
  final String? customNote;
  /// Číslo letu – přednostně ze sloupce flight_number, zpětně z custom_note (prefix [FLIGHT:XXX]).
  final String? flightNumber;
  /// Kdo platí službu u této rezervace (override); null = použít z apartment_services.
  final String? payerType;
  /// Snapshot focení: null = dopočítat z bytu/katalogu, true/false = explicitní pro tuto rezervaci.
  final bool? requiresPhoto;

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
    final flightNum = (json['flight_number'] as String?)?.trim();
    final (parsedFlight, _) = parseFlightFromCustomNote(note);
    final rawId = (json['id'] as String?)?.trim() ?? '';
    final rawTenantId = (json['tenant_id'] as String?)?.trim() ?? '';
    final rawReservationId = (json['reservation_id'] as String?)?.trim() ?? '';
    final rawApartmentServiceId = (json['apartment_service_id'] as String?)?.trim() ?? '';
    final rawTransit = json['transit_cash_to_collect'];
    num? transit;
    if (rawTransit != null) {
      if (rawTransit is num) {
        transit = rawTransit;
      } else {
        transit = num.tryParse(rawTransit.toString());
      }
    }
    return ReservationServiceRow(
      id: rawId,
      tenantId: rawTenantId,
      reservationId: rawReservationId,
      apartmentServiceId: rawApartmentServiceId,
      chargedPrice: price,
      transitCashToCollect: transit,
      customNote: (note != null && note.isNotEmpty) ? note : null,
      flightNumber: (flightNum != null && flightNum.isNotEmpty) ? flightNum : parsedFlight,
      payerType: () {
        final v = (json['payer_type'] as String?)?.trim();
        return (v == 'owner' || v == 'guest') ? v : null;
      }(),
      requiresPhoto: _parseBoolNullable(json['requires_photo']),
    );
  }

  static bool? _parseBoolNullable(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final l = v.toLowerCase();
      if (l == 'true' || l == '1') return true;
      if (l == 'false' || l == '0') return false;
    }
    return null;
  }
}

/// Položka služby bytu s názvem a výchozí cenou – pro výběr v Tabu „Služby a požadavky“.
/// [apartmentServiceId] = id z apartment_services, [serviceName] a [defaultPriceEur] z katalogu/bytu.
/// [isMandatory] = pokud true, v rezervaci nelze službu odškrtnout (checkbox zamčený).
/// [durationMinutes] = časová náročnost služby z tenant_services – pro výpočet Cleaning Buffer (kolizí rezervací).
/// [requiresPhotoFromApartment] = override z apartment_services; null = dědit z katalogu.
/// [requiresPhotoFromCatalog] = hodnota z tenant_services (fallback při null v bytu).
class ApartmentServiceOption {
  const ApartmentServiceOption({
    required this.apartmentServiceId,
    required this.serviceId,
    required this.serviceName,
    required this.defaultPriceEur,
    this.serviceType = 'extra',
    this.isMandatory = false,
    this.payerType = 'guest',
    this.durationMinutes = 0,
    this.requiresPhotoFromApartment,
    this.requiresPhotoFromCatalog = false,
    /// Spouštěč z [apartment_services.trigger_type] – pro read-only náhled v dialogu rezervace.
    this.triggerType = 'on_demand',
    /// Šablona checklistu z [apartment_services.checklist_template_id]; null = u bytu nepřiřazeno.
    this.checklistTemplateId,
  });

  final String apartmentServiceId;
  final String serviceId;
  final String serviceName;
  final double defaultPriceEur;
  /// Typ služby z katalogu – pro podmíněné zobrazení pole Číslo letu (transfer_in, transfer_out, transfer).
  final String serviceType;
  final bool isMandatory;
  /// Výchozí plátce z apartment_services (pro předvyplnění v dialogu rezervace).
  final String payerType;
  /// Časová náročnost / rezerva v minutách z tenant_services. Pro výpočet celkového času úklidu při kontrole kolizí.
  final int durationMinutes;
  /// Override z apartment_services; null = dědit z katalogu.
  final bool? requiresPhotoFromApartment;
  /// Hodnota z tenant_services (fallback při null v bytu).
  final bool requiresPhotoFromCatalog;
  /// Hodnota z apartment_services – zobrazí se dispečerovi v rezervaci bez prokliku do bytu.
  final String triggerType;
  /// ID šablony checklistu z apartment_services; název se v UI dopočítá ze seznamu šablon tenanta.
  final String? checklistTemplateId;
}

/// Lokální stav jedné služby v dialogu rezervace – zaškrtnutí a účtovaná cena / poznámka.
/// [flightNumber] = číslo letu (jen u transferů). Ukládá se do nativního sloupce reservation_services.flight_number.
/// [customNote] = zbytek poznámky (bez prefixu). V UI se zobrazuje odděleně od čísla letu.
class ReservationServiceEditState {
  const ReservationServiceEditState({
    required this.apartmentServiceId,
    required this.serviceName,
    this.defaultPriceEur = 0,
    this.enabled = false,
    this.chargedPriceEur,
    this.transitCashToCollectEur,
    this.customNote,
    this.flightNumber,
    this.payerType = 'guest',
    this.requiresPhoto,
  });

  final String apartmentServiceId;
  final String serviceName;
  final double defaultPriceEur;
  final bool enabled;
  final double? chargedPriceEur;
  /// Průtoková hotovost za ubytování (majitel), EUR – mimo příjem agentury za službu.
  final double? transitCashToCollectEur;
  final String? customNote;
  /// Číslo letu pro transfery – v DB se ukládá do custom_note s prefixem, v UI samostatné pole.
  final String? flightNumber;
  /// Kdo platí službu: 'owner' (majitel) nebo 'guest' (host).
  final String payerType;
  /// Snapshot focení: null = dopočítat z bytu/katalogu, true/false = explicitní pro tuto rezervaci.
  final bool? requiresPhoto;

  ReservationServiceEditState copyWith({
    bool? enabled,
    double? chargedPriceEur,
    double? transitCashToCollectEur,
    String? customNote,
    String? flightNumber,
    String? payerType,
    bool? requiresPhoto,
    bool clearRequiresPhoto = false,
    bool clearFlightNumber = false,
    bool clearTransitCashToCollect = false,
  }) {
    return ReservationServiceEditState(
      apartmentServiceId: apartmentServiceId,
      serviceName: serviceName,
      defaultPriceEur: defaultPriceEur,
      enabled: enabled ?? this.enabled,
      chargedPriceEur: chargedPriceEur ?? this.chargedPriceEur,
      transitCashToCollectEur: clearTransitCashToCollect
          ? null
          : (transitCashToCollectEur ?? this.transitCashToCollectEur),
      customNote: customNote ?? this.customNote,
      flightNumber: clearFlightNumber ? null : (flightNumber ?? this.flightNumber),
      payerType: payerType ?? this.payerType,
      requiresPhoto: clearRequiresPhoto ? null : (requiresPhoto ?? this.requiresPhoto),
    );
  }

  /// Zastaralé – dříve kombinoval flightNumber a customNote do custom_note s prefixem [FLIGHT:XXX].
  /// Nyní se flightNumber ukládá do sloupce flight_number, customNote zvlášť do custom_note.
  /// Zachováno pro případné starší volající; repository používá přímo flightNumber a customNote.
  String? get customNoteForDb {
    final fn = flightNumber?.trim();
    final note = customNote?.trim();
    if (fn != null && fn.isNotEmpty) {
      return note != null && note.isNotEmpty ? '[FLIGHT:$fn]\n$note' : '[FLIGHT:$fn]';
    }
    return note != null && note.isNotEmpty ? note : null;
  }
}
