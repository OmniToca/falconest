/// Model Oblasti (zóny) z Supabase – tabulka zones.
///
/// Každá agentura (tenant) si může vytvořit vlastní Oblasti (např. La Mata, Guardamar).
/// Apartmány a zaměstnanci jsou propojeni s oblastmi – pro inteligentní přidělování úkolů.
class ZoneRow {
  const ZoneRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.createdAt,
    this.deletedAt,
  });

  /// UUID záznamu
  final String id;
  /// Tenant (agentura), kterému oblast patří
  final String tenantId;
  /// Název oblasti (např. La Mata)
  final String name;
  /// Čas vytvoření (volitelné pro čtení)
  final DateTime? createdAt;
  /// Soft delete: když není null, oblast je skrytá z katalogu
  final DateTime? deletedAt;

  factory ZoneRow.fromJson(Map<String, dynamic> json) {
    return ZoneRow(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      createdAt: _parseOptionalDateTime(json['created_at']),
      deletedAt: _parseOptionalDateTime(json['deleted_at']),
    );
  }

  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'name': name,
      };

  ZoneRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) =>
      ZoneRow(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}
