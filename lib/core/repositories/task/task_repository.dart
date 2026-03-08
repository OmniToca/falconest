/// Abstraktní rozhraní pro repozitář úkolů – Clean Architecture.
///
/// Odděluje datovou vrstvu od UI. Na webu implementace čte ze Supabase,
/// na mobilu z lokální Isar databáze (offline-first).
/// Doménový model WorkerTask nemá žádnou závislost na Isar.

/// Model úkolu pro Worker – platformově nezávislý DTO.
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
}

/// Detail úkolu pro Worker Task Detail Screen (keybox, ownerNotes, photoUrl, metadata, časová razítka).
/// [guestName] a [guestPhone] – z propojené rezervace pro check-in/transfer (kontakt na hosta).
/// [customLocation] a [customTitle] – pro externí úkoly bez bytu (ruční transfer).
/// [clientName] a [clientPhone] – z tabulky clients pro externí úkoly s client_id.
/// [mediaUrls] – pole URL fotek z tasks.media_urls (requires_photo, hlášení závad).
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
  /// JSONB metadata z tasks (amount_to_collect, custom_note, flight_number, expected_audit_total, collection_breakdown).
  /// flight_number = nativní sloupec reservation_services, propašovaný do tasks.metadata při vytvoření úkolu.
  final Map<String, dynamic>? metadata;

  /// Číslo letu pro transfery – z metadata['flight_number']. Pochází z reservation_services.flight_number.
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

  /// Chytrá priorita adresy pro UI: byt → custom_location → prázdno.
  /// PROČ: U úkolů s bytem používáme přesnou adresu apartmánu; u externích custom_location.
  String get displayAddress => (apartmentAddress?.trim().isNotEmpty == true)
      ? apartmentAddress!
      : (customLocation?.trim().isNotEmpty == true ? customLocation! : '');

  /// Chytrá priorita jména pro UI: host z rezervace → klient → custom_title → prázdno.
  /// PROČ: Rezervace má hosta, externí úkol klienta; custom_title je fallback (např. "Transfer pro XY").
  String get displayName => (guestName?.trim().isNotEmpty == true)
      ? guestName!
      : (clientName?.trim().isNotEmpty == true)
          ? clientName!
          : (customTitle?.trim().isNotEmpty == true ? customTitle! : '');
}

/// Repozitář pro čtení úkolů přiřazených pracovníkovi.
///
/// Implementace se vybírá podmíněným importem (web vs. mobil).
abstract class ITaskRepository {
  /// Načte úkoly přiřazené pracovníkovi. Vynechá completed.
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId);

  /// Načte detail úkolu podle Supabase UUID.
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId);

  /// Aktualizuje status úkolu (offline: pending, pak sync).
  /// [startedAt] – nastaví se při přechodu do in_progress (Time Tracking).
  /// [completedAt] – nastaví se při přechodu do completed (Time Tracking).
  /// [metadataOverlay] – volitelně sloučí dodatečné klíče do metadata (např. cash_collection_failed).
  /// [mediaUrls] – URL fotek z Supabase Storage (např. pro úkoly s requires_photo). Nahrání volá klient před voláním.
  /// [localPhotoPaths] – cesty k lokálním souborům při offline (zkopírované do persistent storage).
  /// [existingMediaUrls] – již nahrané URL při offline flow (pro merge v procesoru).
  /// Na webu ignorováno. Na mobilu: enqueue OFFLINE_TASK_COMPLETE_WITH_PHOTOS, aktualizuje Isar.
  Future<void> updateTaskStatus(
    String tenantId,
    String taskId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadataOverlay,
    List<String>? mediaUrls,
    List<String>? localPhotoPaths,
    List<String>? existingMediaUrls,
  });
}
