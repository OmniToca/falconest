import 'package:falconest/core/models/client_model.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';

/// Kontext pro Smart Template Selector – určuje zdroj dat (host, rezervace, úkol) a preferované kategorie šablon.
///
/// Jedna z třech variant: Worker úkol, Admin rezervace, Admin úkol. Gettery [placeholders], [guestPhone]
/// a [preferredContexts] delegují na [TemplatePlaceholderService] podle typu kontextu.
sealed class MessageTemplateSelectorContext {
  MessageTemplateSelectorContext._();

  /// Preferovaný jazyk hosta (cs/en/es) pro výběr textu z `translations` šablony.
  ///
  /// PROČ: Jedna šablona obsahuje více jazyků v JSONB; při odeslání bereme text
  /// odpovídající jazyku rezervace/klienta (Worker bez detailu jazyka padá na `en`).
  String get preferredGuestLanguageCode;

  /// Preferované hodnoty trigger_context (kódy z task_categories + null pro obecné).
  /// Selector zobrazí primárně šablony s těmito kontexty.
  List<String?> get preferredContexts;

  /// Mapa placeholderů pro merge do těla šablony (stejné klíče jako [TemplatePlaceholderService.supportedPlaceholders]).
  Map<String, String> get placeholders;

  /// Telefon hosta/klienta pro wa.me; null pokud není k dispozici – před odesláním nutno zkontrolovat.
  String? get guestPhone;

  /// ID rezervace pro zápis last_communication_* (pouze u Reservation kontextu; u Worker/Admin úkolu null).
  String? get reservationId;

  /// ID úkolu pro zápis last_communication_* do tabulky tasks (pouze u Worker/Admin úkolu; u rezervace null).
  String? get taskId;

  /// Worker: detail úkolu. Preferované kontexty = [taskType] + null (obecné).
  factory MessageTemplateSelectorContext.fromWorkerTask(
    WorkerTaskDetail detail, {
    ReservationPlaceholderContext? reservation,
    ApartmentPlaceholderContext? apartment,
    String? tenantIanaTimezone,
  }) = WorkerTaskTemplateContext;

  /// Admin: rezervace (Kanban, Edit rezervace). Preferované = check_in, check_out, transfer_in, transfer_out + null.
  factory MessageTemplateSelectorContext.fromReservation(
    ReservationRow reservation, {
    ApartmentPlaceholderContext? apartment,
    ClientModel? client,
    String? tenantIanaTimezone,
  }) = ReservationTemplateContext;

  /// Admin: úkol (Detail úkolu / Edit task). Preferované = [task.taskType] + null.
  factory MessageTemplateSelectorContext.fromAdminTask(
    TaskRow task, {
    ReservationRow? reservation,
    ApartmentPlaceholderContext? apartment,
    ClientModel? client,
    String? tenantIanaTimezone,
  }) = AdminTaskTemplateContext;
}

/// Kontext z Worker detailu úkolu (Úklid, Transfer, Check-in, …).
final class WorkerTaskTemplateContext extends MessageTemplateSelectorContext {
  WorkerTaskTemplateContext(
    this.detail, {
    this.reservation,
    this.apartment,
    this.tenantIanaTimezone,
  }) : super._();

  final WorkerTaskDetail detail;
  final ReservationPlaceholderContext? reservation;
  final ApartmentPlaceholderContext? apartment;
  final String? tenantIanaTimezone;

  @override
  String get preferredGuestLanguageCode {
    // PROČ: Drift/sync nese guest_language z rezervace; jinak bezpečný fallback pro výběr překladu šablony.
    final g = detail.guestLanguage?.trim().toLowerCase();
    if (g != null && g.isNotEmpty) return g;
    return 'en';
  }

  @override
  List<String?> get preferredContexts {
    final type = detail.taskType.trim();
    if (type.isEmpty) return [null];
    return [type, null];
  }

  @override
  Map<String, String> get placeholders =>
      TemplatePlaceholderService.buildContextFromTask(
        detail,
        reservation: reservation,
        apartment: apartment,
        tenantIanaTimezone: tenantIanaTimezone,
      );

  @override
  String? get guestPhone =>
      TemplatePlaceholderService.resolveGuestPhone(detail, reservation: reservation);

  @override
  String? get reservationId => null;

  @override
  String? get taskId => detail.id;
}

/// Kontext z Admin rezervace (karta, edit dialog).
final class ReservationTemplateContext extends MessageTemplateSelectorContext {
  ReservationTemplateContext(
    this.reservation, {
    this.apartment,
    this.client,
    this.tenantIanaTimezone,
  }) : super._();

  final ReservationRow reservation;
  final ApartmentPlaceholderContext? apartment;
  final ClientModel? client;
  final String? tenantIanaTimezone;

  @override
  String get preferredGuestLanguageCode {
    final g = reservation.guestLanguage?.trim().toLowerCase();
    if (g != null && g.isNotEmpty) return g;
    final c = client?.languageCode?.trim().toLowerCase();
    if (c != null && c.isNotEmpty) return c;
    return 'en';
  }

  static const _reservationPreferredContexts = [
    'check_in',
    'check_out',
    'transfer_in',
    'transfer_out',
  ];

  @override
  List<String?> get preferredContexts =>
      [..._reservationPreferredContexts, null];

  @override
  Map<String, String> get placeholders =>
      TemplatePlaceholderService.buildContextFromReservation(
        reservation,
        apartment: apartment,
        client: client,
        tenantIanaTimezone: tenantIanaTimezone,
      );

  @override
  String? get guestPhone =>
      TemplatePlaceholderService.resolveGuestPhoneFromReservation(
        reservation,
        client: client,
      );

  @override
  String? get reservationId => reservation.id;

  @override
  String? get taskId => null;
}

/// Kontext z Admin detailu úkolu (Edit task dialog).
final class AdminTaskTemplateContext extends MessageTemplateSelectorContext {
  AdminTaskTemplateContext(
    this.task, {
    this.reservation,
    this.apartment,
    this.client,
    this.tenantIanaTimezone,
  }) : super._();

  final TaskRow task;
  final ReservationRow? reservation;
  final ApartmentPlaceholderContext? apartment;
  final ClientModel? client;
  final String? tenantIanaTimezone;

  @override
  String get preferredGuestLanguageCode {
    final g = reservation?.guestLanguage?.trim().toLowerCase();
    if (g != null && g.isNotEmpty) return g;
    final c = client?.languageCode?.trim().toLowerCase();
    if (c != null && c.isNotEmpty) return c;
    return 'en';
  }

  @override
  List<String?> get preferredContexts {
    final type = task.taskType.trim();
    if (type.isEmpty) return [null];
    return [type, null];
  }

  @override
  Map<String, String> get placeholders =>
      TemplatePlaceholderService.buildContextFromAdminTask(
        task,
        reservation: reservation,
        apartment: apartment,
        client: client,
        tenantIanaTimezone: tenantIanaTimezone,
      );

  @override
  String? get guestPhone {
    final phone = reservation?.guestPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    final clientPhone = client?.phone?.trim();
    return (clientPhone != null && clientPhone.isNotEmpty) ? clientPhone : null;
  }

  @override
  String? get reservationId => reservation?.id;

  @override
  String? get taskId => task.id;
}
