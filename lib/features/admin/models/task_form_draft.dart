/// Režim úkolu vrácený z AI parsování – mapuje se na [_TaskFormMode] v admin dialogu.
enum TaskFormDraftMode {
  apartmentBound,
  externalService,
  unknown;

  static TaskFormDraftMode? fromApi(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return switch (v) {
      'apartment_bound' || 'apartmentbound' => TaskFormDraftMode.apartmentBound,
      'external_service' || 'externalservice' => TaskFormDraftMode.externalService,
      'unknown' || '' => TaskFormDraftMode.unknown,
      _ => null,
    };
  }

  String toApi() => switch (this) {
        TaskFormDraftMode.apartmentBound => 'apartment_bound',
        TaskFormDraftMode.externalService => 'external_service',
        TaskFormDraftMode.unknown => 'unknown',
      };
}

/// Parsuje wall-clock čas z Edge (bez Z) jako lokální [DateTime] – bez UTC→toLocal posunu.
///
/// PROČ: `DateTime.tryParse('…Z')` vytvoří UTC; ve formuláři by `toLocal()` posunulo
/// „11:15“ na „13:15“ (CEST). Edge má vracet `YYYY-MM-DDTHH:mm:ss` bez offsetu.
DateTime? parseTaskDraftWallClockLocal(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceFirst(RegExp(r'[Zz]$'), '');
  s = s.replaceFirst(RegExp(r'[+-]\d{2}:?\d{2}$'), '');
  final m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(s);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6) ?? '0'),
  );
}

/// Kandidát na apartmán / klienta / službu – server vrátí více možností při nejistém párování.
class TaskFormDraftCandidate {
  const TaskFormDraftCandidate({
    required this.id,
    required this.label,
    this.subtitle,
    this.confidence = 0,
  });

  final String id;
  final String label;
  final String? subtitle;

  /// 0–1 jistota shody (0 = neznámá).
  final double confidence;

  factory TaskFormDraftCandidate.fromJson(Map<String, dynamic> json) {
    final confRaw = json['confidence'];
    double confidence = 0;
    if (confRaw is num) {
      confidence = confRaw.toDouble();
    } else if (confRaw is String) {
      confidence = double.tryParse(confRaw) ?? 0;
    }
    return TaskFormDraftCandidate(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      confidence: confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (subtitle != null) 'subtitle': subtitle,
        'confidence': confidence,
      };
}

List<TaskFormDraftCandidate> _parseCandidates(dynamic raw) {
  final out = <TaskFormDraftCandidate>[];
  if (raw is! List) return out;
  for (final item in raw) {
    if (item is Map) {
      out.add(TaskFormDraftCandidate.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return out;
}

double? _parseConfidence(dynamic confRaw) {
  if (confRaw is num) return confRaw.toDouble();
  if (confRaw is String) return double.tryParse(confRaw);
  return null;
}

/// Návrh předvyplnění formuláře úkolu z volného textu (WhatsApp, e-mail…).
///
/// PROČ immutable model: Edge Function vrátí JSON, preview dialog umožní úpravu
/// (např. výběr apartmánu z kandidátů) a teprve pak se předá do [_AddTaskDialog].
/// Žádný zápis do DB – human-in-the-loop.
class TaskFormDraft {
  const TaskFormDraft({
    this.taskMode = TaskFormDraftMode.unknown,
    this.title,
    this.description,
    this.scheduledStart,
    this.durationMinutes,
    this.apartmentId,
    this.apartmentMatchConfidence,
    this.clientId,
    this.clientMatchConfidence,
    this.serviceId,
    this.serviceMatchConfidence,
    this.customLocationHint,
    this.price,
    this.isCashPayment,
    this.rawSourceText,
    this.apartmentCandidates = const [],
    this.clientCandidates = const [],
    this.serviceCandidates = const [],
    this.warnings = const [],
  });

  final TaskFormDraftMode taskMode;
  final String? title;
  final String? description;

  /// Plánovaný začátek – wall-clock lokální čas z Edge (bez UTC posunu).
  final DateTime? scheduledStart;
  final int? durationMinutes;

  /// UUID apartmánu po server-side resolution (může být null při nízké jistotě).
  final String? apartmentId;
  final double? apartmentMatchConfidence;
  final String? clientId;
  final double? clientMatchConfidence;
  final String? serviceId;
  final double? serviceMatchConfidence;
  final String? customLocationHint;

  /// Domluvená cena z textu (WhatsApp) – má přednost před katalogem.
  final double? price;

  /// true = hotovost na místě, false = faktura/předem, null = neuvedeno.
  final bool? isCashPayment;
  final String? rawSourceText;
  final List<TaskFormDraftCandidate> apartmentCandidates;
  final List<TaskFormDraftCandidate> clientCandidates;
  final List<TaskFormDraftCandidate> serviceCandidates;
  final List<String> warnings;

  /// Nízká jistota párování apartmánu – zobrazí se varování v preview i ve formuláři.
  bool get hasLowConfidenceApartmentMatch {
    if (apartmentId == null || apartmentId!.isEmpty) return true;
    final c = apartmentMatchConfidence;
    if (c == null) return false;
    return c < 0.85;
  }

  bool get hasLowConfidenceClientMatch {
    if (clientId == null || clientId!.isEmpty) return true;
    final c = clientMatchConfidence;
    if (c == null) return false;
    return c < 0.85;
  }

  bool get hasMatchedService =>
      serviceId != null && serviceId!.trim().isNotEmpty;

  TaskFormDraft copyWith({
    TaskFormDraftMode? taskMode,
    String? title,
    String? description,
    DateTime? scheduledStart,
    int? durationMinutes,
    String? apartmentId,
    double? apartmentMatchConfidence,
    String? clientId,
    double? clientMatchConfidence,
    String? serviceId,
    double? serviceMatchConfidence,
    String? customLocationHint,
    double? price,
    bool? isCashPayment,
    String? rawSourceText,
    List<TaskFormDraftCandidate>? apartmentCandidates,
    List<TaskFormDraftCandidate>? clientCandidates,
    List<TaskFormDraftCandidate>? serviceCandidates,
    List<String>? warnings,
  }) {
    return TaskFormDraft(
      taskMode: taskMode ?? this.taskMode,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      apartmentId: apartmentId ?? this.apartmentId,
      apartmentMatchConfidence:
          apartmentMatchConfidence ?? this.apartmentMatchConfidence,
      clientId: clientId ?? this.clientId,
      clientMatchConfidence:
          clientMatchConfidence ?? this.clientMatchConfidence,
      serviceId: serviceId ?? this.serviceId,
      serviceMatchConfidence:
          serviceMatchConfidence ?? this.serviceMatchConfidence,
      customLocationHint: customLocationHint ?? this.customLocationHint,
      price: price ?? this.price,
      isCashPayment: isCashPayment ?? this.isCashPayment,
      rawSourceText: rawSourceText ?? this.rawSourceText,
      apartmentCandidates: apartmentCandidates ?? this.apartmentCandidates,
      clientCandidates: clientCandidates ?? this.clientCandidates,
      serviceCandidates: serviceCandidates ?? this.serviceCandidates,
      warnings: warnings ?? this.warnings,
    );
  }

  factory TaskFormDraft.fromEdgeResponse(Map<String, dynamic> json) {
    final draft = json['draft'];
    if (draft is! Map) {
      throw FormatException('Missing draft object in parse-task-draft response');
    }
    final d = Map<String, dynamic>.from(draft);

    DateTime? scheduledStart;
    final schedRaw = d['scheduled_start_iso']?.toString();
    if (schedRaw != null && schedRaw.isNotEmpty) {
      // PROČ: Edge vrací wall-clock bez Z (11:15). DateTime.tryParse s 'Z' by byl UTC
      // a toLocal() ve formuláři by posunul o timezone (+1/+2h).
      scheduledStart = parseTaskDraftWallClockLocal(schedRaw);
    }

    int? durationMinutes;
    final durRaw = d['duration_minutes'];
    if (durRaw is int) {
      durationMinutes = durRaw;
    } else if (durRaw is num) {
      durationMinutes = durRaw.toInt();
    } else if (durRaw is String) {
      durationMinutes = int.tryParse(durRaw);
    }

    final warningsRaw = json['warnings'];
    final warnings = <String>[];
    if (warningsRaw is List) {
      for (final w in warningsRaw) {
        if (w != null && w.toString().isNotEmpty) {
          warnings.add(w.toString());
        }
      }
    }

    double? price;
    final priceRaw = d['price'];
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw is String) {
      price = double.tryParse(priceRaw.replaceAll(',', '.'));
    }
    if (price != null && price <= 0) price = null;

    bool? isCashPayment;
    final cashRaw = d['is_cash_payment'];
    if (cashRaw is bool) {
      isCashPayment = cashRaw;
    } else if (cashRaw is String) {
      final c = cashRaw.trim().toLowerCase();
      if (c == 'true' || c == '1' || c == 'yes') isCashPayment = true;
      if (c == 'false' || c == '0' || c == 'no') isCashPayment = false;
    }

    return TaskFormDraft(
      taskMode:
          TaskFormDraftMode.fromApi(d['task_mode']?.toString()) ??
          TaskFormDraftMode.unknown,
      title: d['title']?.toString(),
      description: d['description']?.toString(),
      scheduledStart: scheduledStart,
      durationMinutes: durationMinutes,
      apartmentId: d['apartment_id']?.toString(),
      apartmentMatchConfidence: _parseConfidence(d['apartment_match_confidence']),
      clientId: d['client_id']?.toString(),
      clientMatchConfidence: _parseConfidence(d['client_match_confidence']),
      serviceId: d['service_id']?.toString(),
      serviceMatchConfidence: _parseConfidence(d['service_match_confidence']),
      customLocationHint: d['custom_location_hint']?.toString(),
      price: price,
      isCashPayment: isCashPayment,
      rawSourceText: d['raw_source_text']?.toString(),
      apartmentCandidates: _parseCandidates(json['apartment_candidates']),
      clientCandidates: _parseCandidates(json['client_candidates']),
      serviceCandidates: _parseCandidates(json['service_candidates']),
      warnings: warnings,
    );
  }
}
