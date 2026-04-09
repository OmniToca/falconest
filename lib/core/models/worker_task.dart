/// Model úkolu pro Worker – platformově nezávislý DTO.
///
/// PROČ: Dashboard a synchronní vrstva potřebují stejná pole bez vazby na konkrétní úložiště.
/// [latitude] / [longitude] pocházejí z PostGIS `geo_location` (priorita bod úkolu, jinak bod bytu)
/// při čtení ze Supabase; v čistě offline Drift vrstvě jsou zatím typicky `null`, protože lokální
/// schéma úkolů/bytů GeoJSON zatím neukládá – doplní se samostatnou migrací Drift.
class WorkerTask {
  const WorkerTask({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    required this.status,
    required this.apartmentId,
    this.referenceNumber,
    this.apartmentName,
    this.apartmentAddress,
    this.clientName,
    this.customLocation,
    this.customTitle,
    this.metadata,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String status;
  final String apartmentId;

  /// Referenční číslo úkolu (např. TSK-X7M2P4). Pro zobrazení v UI.
  final String? referenceNumber;
  final String? apartmentName;
  final String? apartmentAddress;

  /// Jméno klienta – pro externí úkoly bez bytu (client_id).
  final String? clientName;

  /// Adresa pro externí úkoly (tasks.custom_location).
  final String? customLocation;

  /// Název pro externí úkoly (tasks.custom_title).
  final String? customTitle;

  /// Metadata (guest_name, client_name, address atd.) pro fallback zobrazení.
  final Map<String, dynamic>? metadata;

  /// WGS 84 – z GeoJSON úkolu nebo bytu (Supabase). Offline Drift: zatím často null.
  final double? latitude;

  /// WGS 84 – z GeoJSON úkolu nebo bytu (Supabase). Offline Drift: zatím často null.
  final double? longitude;

  /// True, pokud máme spolehlivý bod pro navigaci (Google Maps `lat,lon`).
  bool get hasGps => latitude != null && longitude != null;

  /// Stejná priorita jako na kartě dashboardu – byt → custom_location → metadata.address.
  String get displayAddress {
    if (apartmentAddress != null && apartmentAddress!.trim().isNotEmpty) {
      return apartmentAddress!.trim();
    }
    if (customLocation != null && customLocation!.trim().isNotEmpty) {
      return customLocation!.trim();
    }
    final addr = metadata?['address']?.toString().trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return '';
  }

  WorkerTask copyWith({
    String? id,
    String? title,
    String? description,
    String? taskType,
    DateTime? scheduledStart,
    String? status,
    String? apartmentId,
    String? referenceNumber,
    String? apartmentName,
    String? apartmentAddress,
    String? clientName,
    String? customLocation,
    String? customTitle,
    Map<String, dynamic>? metadata,
    double? latitude,
    double? longitude,
  }) {
    return WorkerTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      status: status ?? this.status,
      apartmentId: apartmentId ?? this.apartmentId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      apartmentName: apartmentName ?? this.apartmentName,
      apartmentAddress: apartmentAddress ?? this.apartmentAddress,
      clientName: clientName ?? this.clientName,
      customLocation: customLocation ?? this.customLocation,
      customTitle: customTitle ?? this.customTitle,
      metadata: metadata ?? this.metadata,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
