/// Model záznamu tabulky [apartment_services] – přiřazení služby z katalogu k bytu (Override Pattern úroveň 2).
///
/// [customPrice] a [customDescription] přepisují výchozí hodnoty z tenant_services.
/// Ceny v DB jsou v EUR; v UI se přepočítávají podle preferované měny uživatele.
class ApartmentServiceRow {
  const ApartmentServiceRow({
    required this.id,
    required this.tenantId,
    required this.apartmentId,
    required this.serviceId,
    this.customPrice,
    this.customDescription,
    required this.triggerType,
    this.scheduleInterval,
    this.isMandatory = false,
    this.payerType = 'guest',
  });

  final String id;
  final String tenantId;
  final String apartmentId;
  final String serviceId;
  final num? customPrice;
  final String? customDescription;
  final String triggerType;
  final String? scheduleInterval;
  /// Pokud true, službu nelze v rezervaci odškrtnout (checkbox zamčený).
  final bool isMandatory;
  /// Kdo platí službu: 'owner' (majitel – faktura) nebo 'guest' (host – na místě).
  final String payerType;

  factory ApartmentServiceRow.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['custom_price'];
    num? price;
    if (rawPrice != null) {
      if (rawPrice is num) {
        price = rawPrice;
      } else if (rawPrice is String) {
        price = num.tryParse(rawPrice);
      }
    }
    final rawMandatory = json['is_mandatory'];
    final isMandatory = rawMandatory is bool
        ? rawMandatory
        : (rawMandatory == true || (rawMandatory is String && rawMandatory == 'true'));
    return ApartmentServiceRow(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      serviceId: json['service_id'] as String? ?? '',
      customPrice: price,
      customDescription: () {
        final s = (json['custom_description'] as String?)?.trim();
        return (s != null && s.isNotEmpty) ? s : null;
      }(),
      triggerType: () {
        final v = (json['trigger_type'] as String?)?.trim();
        const allowed = ['on_demand', 'before_checkin', 'after_checkout', 'both_ways', 'scheduled'];
        if (v != null && v.isNotEmpty && allowed.contains(v)) return v;
        return 'on_demand'; // fallback pro starou hodnotu 'manual' nebo neznámou
      }(),
      scheduleInterval: () {
        final s = (json['schedule_interval'] as String?)?.trim();
        if (s == null || s.isEmpty) return null;
        const oldToNew = {'weekly': '1_week', 'biweekly': '2_weeks', 'monthly': '1_month', 'biannually': '6_months'};
        return oldToNew[s] ?? s;
      }(),
      isMandatory: isMandatory,
      payerType: () {
        final v = (json['payer_type'] as String?)?.trim();
        return (v == 'owner' || v == 'guest') ? v! : 'guest';
      }(),
    );
  }
}

/// Lokální stav jedné služby v dialogu bytu – zda je aktivní a přepisové hodnoty.
/// Klíč v mapě = service_id (tenant_services.id).
class ApartmentServiceEditState {
  const ApartmentServiceEditState({
    required this.serviceId,
    required this.serviceName,
    this.defaultPriceEur,
    this.enabled = false,
    this.customPriceEur,
    this.customDescription,
    this.triggerType = 'on_demand',
    this.scheduleInterval,
    this.isMandatory = false,
    this.payerType = 'guest',
  });

  final String serviceId;
  final String serviceName;
  final num? defaultPriceEur;
  final bool enabled;
  final double? customPriceEur;
  final String? customDescription;
  final String triggerType;
  final String? scheduleInterval;
  /// Povinná služba – v rezervaci nelze odškrtnout.
  final bool isMandatory;
  /// Kdo platí službu: 'owner' (majitel) nebo 'guest' (host).
  final String payerType;

  ApartmentServiceEditState copyWith({
    bool? enabled,
    double? customPriceEur,
    String? customDescription,
    String? triggerType,
    String? scheduleInterval,
    bool? isMandatory,
    String? payerType,
  }) {
    return ApartmentServiceEditState(
      serviceId: serviceId,
      serviceName: serviceName,
      defaultPriceEur: defaultPriceEur,
      enabled: enabled ?? this.enabled,
      customPriceEur: customPriceEur ?? this.customPriceEur,
      customDescription: customDescription ?? this.customDescription,
      triggerType: triggerType ?? this.triggerType,
      scheduleInterval: scheduleInterval ?? this.scheduleInterval,
      isMandatory: isMandatory ?? this.isMandatory,
      payerType: payerType ?? this.payerType,
    );
  }
}
