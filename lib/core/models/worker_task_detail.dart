/// Detail úkolu pro Worker Task Detail Screen (keybox, ownerNotes, photoUrl, metadata, časová razítka).
///
/// [guestName] a [guestPhone] – z propojené rezervace pro check-in/transfer (kontakt na hosta).
/// [customLocation] a [customTitle] – pro externí úkoly bez bytu (ruční transfer).
/// [clientName] a [clientPhone] – z tabulky clients pro externí úkoly s client_id.
/// [mediaUrls] – pole URL fotek z tasks.media_urls (requires_photo, hlášení závad).
/// [specialRequests] – z rezervace (`special_requests`), Fáze 2 offline.
/// [apartmentCheckInTime] / [apartmentCheckOutTime] / [apartmentZoneId] – z bytu pro kontext v terénu.
/// [parkingInstructions] – z bytu (Drift / Supabase), offline parkování.
/// [dueDate], [unassignedInfo] – z úkolu; [guestLanguage] z rezervace, pokud [hasLinkedReservation].
/// [latitude] / [longitude] – WGS 84 z PostGIS (`geo_location`), priorita úkol > byt při naplnění z API.
class WorkerTaskDetail {
  const WorkerTaskDetail({
    required this.id,
    required this.title,
    this.referenceNumber,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    required this.status,
    required this.apartmentId,
    this.apartmentName,
    this.apartmentAddress,
    this.customLocation,
    this.customTitle,
    this.clientName,
    this.clientPhone,
    this.keybox,
    this.ownerNotes,
    this.guestName,
    this.guestPhone,
    this.photoUrl,
    this.mediaUrls = const [],
    this.metadata,
    this.startedAt,
    this.completedAt,
    this.specialRequests,
    this.apartmentCheckInTime,
    this.apartmentCheckOutTime,
    this.apartmentZoneId,
    this.parkingInstructions,
    this.dueDate,
    this.unassignedInfo,
    this.guestLanguage,
    this.hasLinkedReservation = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String title;

  /// Referenční číslo úkolu (např. TSK-X7M2P4). Pro zobrazení v AppBar detailu.
  final String? referenceNumber;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String status;
  final String apartmentId;
  final String? apartmentName;
  final String? apartmentAddress;

  /// Adresa/lokace pro externí úkoly (tasks.custom_location) – když nemáme byt.
  final String? customLocation;

  /// Název pro externí úkoly (tasks.custom_title) – např. "Transfer letiště".
  final String? customTitle;

  /// Jméno klienta z tabulky clients – pro externí úkoly s client_id.
  final String? clientName;

  /// Telefon klienta z tabulky clients – fallback pro externí úkoly bez rezervace.
  final String? clientPhone;
  final String? keybox;
  final String? ownerNotes;

  /// Jméno hosta z propojené rezervace (Check-in, Transfer).
  final String? guestName;

  /// Telefon hosta z propojené rezervace – pro tel: link.
  final String? guestPhone;
  final String? photoUrl;

  /// URL fotek z tasks.media_urls – pro zobrazení existujících a requires_photo.
  final List<String> mediaUrls;

  /// JSONB metadata z tasks (amount_to_collect, custom_note, flight_number, …).
  final Map<String, dynamic>? metadata;

  /// Číslo letu pro transfery – z metadata['flight_number'].
  String? get flightNumber {
    final v = metadata?['flight_number'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Reálný čas zahájení práce (UTC).
  final DateTime? startedAt;

  /// Reálný čas dokončení úkolu (UTC).
  final DateTime? completedAt;

  /// Speciální požadavky hosta z rezervace (offline Drift / Supabase).
  final String? specialRequests;

  /// Standardní čas příjezdu z profilu bytu (text, např. „15:00“).
  final String? apartmentCheckInTime;

  /// Standardní čas odjezdu z profilu bytu.
  final String? apartmentCheckOutTime;

  /// UUID zóny (parkování apod.) z bytu – pro budoucí mapy / navigaci.
  final String? apartmentZoneId;

  /// Instrukce k parkování u bytu (offline sync).
  final String? parkingInstructions;

  /// Termín splnění úkolu (`tasks.due_date`), pokud je v DB/sync k dispozici.
  final DateTime? dueDate;

  /// JSON/text z `tasks.unassigned_info` – kontext nepřiřazeného úkolu z dispečinku.
  final String? unassignedInfo;

  /// Kód jazyka hosta z rezervace (např. `cs`, `en`).
  final String? guestLanguage;

  /// True, pokud byl k úkolu načten záznam rezervace (i když je host prázdný).
  final bool hasLinkedReservation;

  /// WGS 84 z PostGIS – priorita geometrie úkolu, jinak bytu (Supabase). Drift: zatím často null.
  final double? latitude;

  /// WGS 84 z PostGIS – priorita geometrie úkolu, jinak bytu (Supabase). Drift: zatím často null.
  final double? longitude;

  /// Spolehlivý bod pro Google Maps (`lat,lon` v query).
  bool get hasGps => latitude != null && longitude != null;

  /// Chytrá priorita adresy pro UI: byt → custom_location → prázdno.
  String get displayAddress => (apartmentAddress?.trim().isNotEmpty == true)
      ? apartmentAddress!
      : (customLocation?.trim().isNotEmpty == true ? customLocation! : '');

  /// Chytrá priorita jména pro UI: host z rezervace → klient → custom_title → prázdno.
  String get displayName => (guestName?.trim().isNotEmpty == true)
      ? guestName!
      : (clientName?.trim().isNotEmpty == true)
          ? clientName!
          : (customTitle?.trim().isNotEmpty == true ? customTitle! : '');

  WorkerTaskDetail copyWith({
    String? id,
    String? title,
    String? referenceNumber,
    String? description,
    String? taskType,
    DateTime? scheduledStart,
    String? status,
    String? apartmentId,
    String? apartmentName,
    String? apartmentAddress,
    String? customLocation,
    String? customTitle,
    String? clientName,
    String? clientPhone,
    String? keybox,
    String? ownerNotes,
    String? guestName,
    String? guestPhone,
    String? photoUrl,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
    DateTime? startedAt,
    DateTime? completedAt,
    String? specialRequests,
    String? apartmentCheckInTime,
    String? apartmentCheckOutTime,
    String? apartmentZoneId,
    String? parkingInstructions,
    DateTime? dueDate,
    String? unassignedInfo,
    String? guestLanguage,
    bool? hasLinkedReservation,
    double? latitude,
    double? longitude,
  }) {
    return WorkerTaskDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      status: status ?? this.status,
      apartmentId: apartmentId ?? this.apartmentId,
      apartmentName: apartmentName ?? this.apartmentName,
      apartmentAddress: apartmentAddress ?? this.apartmentAddress,
      customLocation: customLocation ?? this.customLocation,
      customTitle: customTitle ?? this.customTitle,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      keybox: keybox ?? this.keybox,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      guestName: guestName ?? this.guestName,
      guestPhone: guestPhone ?? this.guestPhone,
      photoUrl: photoUrl ?? this.photoUrl,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      metadata: metadata ?? this.metadata,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      specialRequests: specialRequests ?? this.specialRequests,
      apartmentCheckInTime: apartmentCheckInTime ?? this.apartmentCheckInTime,
      apartmentCheckOutTime: apartmentCheckOutTime ?? this.apartmentCheckOutTime,
      apartmentZoneId: apartmentZoneId ?? this.apartmentZoneId,
      parkingInstructions: parkingInstructions ?? this.parkingInstructions,
      dueDate: dueDate ?? this.dueDate,
      unassignedInfo: unassignedInfo ?? this.unassignedInfo,
      guestLanguage: guestLanguage ?? this.guestLanguage,
      hasLinkedReservation: hasLinkedReservation ?? this.hasLinkedReservation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
