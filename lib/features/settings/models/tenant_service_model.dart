/// Model položky katalogu služeb agentury z tabulky [tenant_services].
///
/// Služby jsou úroveň 1 v 3-úrovňovém modelu (Override Pattern): výchozí cena a popis,
/// které lze na úrovni bytu (apartment_services) a rezervace (reservation_services) přepsat.
/// [orderIndex] určuje pořadí v seznamu (0 = první). [serviceType] = cleaning | transfer | maintenance | extra.
/// [requiredRole] určuje, kdo službu vykonává (any, cleaner, driver, maintenance, checkin_agent) – pro Task Automator.
/// [durationMinutes] – časová náročnost / rezerva v minutách. U úklidu vata nad standardCleaningDuration, u ostatních fixní doba.
/// [requiresPhoto] – pracovník musí při dokončení úkolu nahrát fotku (stav apartmánu, pasy). Propaguje se do tasks.metadata.
class TenantServiceModel {
  const TenantServiceModel({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    required this.serviceType,
    this.defaultPrice,
    this.isActive = true,
    this.deletedAt,
    this.orderIndex = 0,
    this.requiredRole,
    this.durationMinutes,
    this.requiresPhoto = false,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final String serviceType;
  final num? defaultPrice;
  final bool isActive;
  final DateTime? deletedAt;
  final int orderIndex;
  /// Požadovaná profese pro vykonání služby: any | cleaner | driver | maintenance | checkin_agent.
  final String? requiredRole;
  /// Časová náročnost / rezerva v minutách. U úklidu vata nad standardCleaningDuration, u transfer/maintenance/extra fixní doba.
  final int? durationMinutes;
  /// Vyžadovat fotodokumentaci při dokončení úkolu (např. stav apartmánu, ofocené pasy).
  final bool requiresPhoto;

  factory TenantServiceModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['default_price'];
    num? price;
    if (rawPrice != null) {
      if (rawPrice is num) {
        price = rawPrice;
      } else if (rawPrice is String) {
        price = num.tryParse(rawPrice);
      }
    }
    final rawActive = json['is_active'];
    final isActive = rawActive == null ? true : (rawActive == true || rawActive == 1);
    final rawOrder = json['order_index'];
    int order = 0;
    if (rawOrder != null) {
      if (rawOrder is int) {
        order = rawOrder;
      } else if (rawOrder is num) {
        order = rawOrder.toInt();
      }
    }
    DateTime? deletedAt;
    final rawDeleted = json['deleted_at'];
    if (rawDeleted != null && rawDeleted is String) {
      deletedAt = DateTime.tryParse(rawDeleted);
    }
    final rawRequired = (json['required_role'] as String?)?.trim();
    final requiredRole = (rawRequired != null && rawRequired.isNotEmpty) ? rawRequired : null;
    final rawDuration = json['duration_minutes'];
    int? durationMinutes;
    if (rawDuration != null) {
      if (rawDuration is int) {
        durationMinutes = rawDuration;
      } else if (rawDuration is num) {
        durationMinutes = rawDuration.toInt();
      }
    }
    final rawRequiresPhoto = json['requires_photo'];
    final requiresPhoto = rawRequiresPhoto == true || rawRequiresPhoto == 1;
    return TenantServiceModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      description: () {
        final s = (json['description'] as String?)?.trim();
        return (s != null && s.isNotEmpty) ? s : null;
      }(),
      serviceType: (json['service_type'] as String?)?.trim() ?? 'extra',
      defaultPrice: price,
      isActive: isActive,
      deletedAt: deletedAt,
      orderIndex: order,
      requiredRole: requiredRole,
      durationMinutes: durationMinutes,
      requiresPhoto: requiresPhoto,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'name': name.trim(),
        if (description != null && description!.isNotEmpty) 'description': description,
        'service_type': serviceType,
        'default_price': defaultPrice,
        'is_active': isActive,
        'order_index': orderIndex,
        if (requiredRole != null && requiredRole!.isNotEmpty) 'required_role': requiredRole,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        'requires_photo': requiresPhoto,
      };
}
