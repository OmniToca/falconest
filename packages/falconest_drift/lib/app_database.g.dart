// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apartmentSupabaseIdMeta =
      const VerificationMeta('apartmentSupabaseId');
  @override
  late final GeneratedColumn<String> apartmentSupabaseId =
      GeneratedColumn<String>(
        'apartment_supabase_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _clientSupabaseIdMeta = const VerificationMeta(
    'clientSupabaseId',
  );
  @override
  late final GeneratedColumn<String> clientSupabaseId = GeneratedColumn<String>(
    'client_supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customLocationMeta = const VerificationMeta(
    'customLocation',
  );
  @override
  late final GeneratedColumn<String> customLocation = GeneratedColumn<String>(
    'custom_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customTitleMeta = const VerificationMeta(
    'customTitle',
  );
  @override
  late final GeneratedColumn<String> customTitle = GeneratedColumn<String>(
    'custom_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reservationSupabaseIdMeta =
      const VerificationMeta('reservationSupabaseId');
  @override
  late final GeneratedColumn<String> reservationSupabaseId =
      GeneratedColumn<String>(
        'reservation_supabase_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _assignedUserSupabaseIdMeta =
      const VerificationMeta('assignedUserSupabaseId');
  @override
  late final GeneratedColumn<String> assignedUserSupabaseId =
      GeneratedColumn<String>(
        'assigned_user_supabase_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _assignedUserIdsJsonMeta =
      const VerificationMeta('assignedUserIdsJson');
  @override
  late final GeneratedColumn<String> assignedUserIdsJson =
      GeneratedColumn<String>(
        'assigned_user_ids_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceNumberMeta = const VerificationMeta(
    'referenceNumber',
  );
  @override
  late final GeneratedColumn<String> referenceNumber = GeneratedColumn<String>(
    'reference_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _taskTypeMeta = const VerificationMeta(
    'taskType',
  );
  @override
  late final GeneratedColumn<String> taskType = GeneratedColumn<String>(
    'task_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Jiné'),
  );
  static const VerificationMeta _scheduledStartMeta = const VerificationMeta(
    'scheduledStart',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledStart =
      GeneratedColumn<DateTime>(
        'scheduled_start',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unassignedInfoMeta = const VerificationMeta(
    'unassignedInfo',
  );
  @override
  late final GeneratedColumn<String> unassignedInfo = GeneratedColumn<String>(
    'unassigned_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
    'service_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaUrlsJsonMeta = const VerificationMeta(
    'mediaUrlsJson',
  );
  @override
  late final GeneratedColumn<String> mediaUrlsJson = GeneratedColumn<String>(
    'media_urls_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invoicedAtMeta = const VerificationMeta(
    'invoicedAt',
  );
  @override
  late final GeneratedColumn<DateTime> invoicedAt = GeneratedColumn<DateTime>(
    'invoiced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    apartmentSupabaseId,
    clientSupabaseId,
    customLocation,
    customTitle,
    reservationSupabaseId,
    assignedUserSupabaseId,
    assignedUserIdsJson,
    referenceNumber,
    title,
    description,
    taskType,
    scheduledStart,
    dueDate,
    status,
    photoUrl,
    localUpdatedAt,
    lastSyncedAt,
    syncStatus,
    lastUpdated,
    metadataJson,
    unassignedInfo,
    serviceId,
    mediaUrlsJson,
    startedAt,
    completedAt,
    invoicedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('apartment_supabase_id')) {
      context.handle(
        _apartmentSupabaseIdMeta,
        apartmentSupabaseId.isAcceptableOrUnknown(
          data['apartment_supabase_id']!,
          _apartmentSupabaseIdMeta,
        ),
      );
    }
    if (data.containsKey('client_supabase_id')) {
      context.handle(
        _clientSupabaseIdMeta,
        clientSupabaseId.isAcceptableOrUnknown(
          data['client_supabase_id']!,
          _clientSupabaseIdMeta,
        ),
      );
    }
    if (data.containsKey('custom_location')) {
      context.handle(
        _customLocationMeta,
        customLocation.isAcceptableOrUnknown(
          data['custom_location']!,
          _customLocationMeta,
        ),
      );
    }
    if (data.containsKey('custom_title')) {
      context.handle(
        _customTitleMeta,
        customTitle.isAcceptableOrUnknown(
          data['custom_title']!,
          _customTitleMeta,
        ),
      );
    }
    if (data.containsKey('reservation_supabase_id')) {
      context.handle(
        _reservationSupabaseIdMeta,
        reservationSupabaseId.isAcceptableOrUnknown(
          data['reservation_supabase_id']!,
          _reservationSupabaseIdMeta,
        ),
      );
    }
    if (data.containsKey('assigned_user_supabase_id')) {
      context.handle(
        _assignedUserSupabaseIdMeta,
        assignedUserSupabaseId.isAcceptableOrUnknown(
          data['assigned_user_supabase_id']!,
          _assignedUserSupabaseIdMeta,
        ),
      );
    }
    if (data.containsKey('assigned_user_ids_json')) {
      context.handle(
        _assignedUserIdsJsonMeta,
        assignedUserIdsJson.isAcceptableOrUnknown(
          data['assigned_user_ids_json']!,
          _assignedUserIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('reference_number')) {
      context.handle(
        _referenceNumberMeta,
        referenceNumber.isAcceptableOrUnknown(
          data['reference_number']!,
          _referenceNumberMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    }
    if (data.containsKey('scheduled_start')) {
      context.handle(
        _scheduledStartMeta,
        scheduledStart.isAcceptableOrUnknown(
          data['scheduled_start']!,
          _scheduledStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledStartMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('unassigned_info')) {
      context.handle(
        _unassignedInfoMeta,
        unassignedInfo.isAcceptableOrUnknown(
          data['unassigned_info']!,
          _unassignedInfoMeta,
        ),
      );
    }
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    }
    if (data.containsKey('media_urls_json')) {
      context.handle(
        _mediaUrlsJsonMeta,
        mediaUrlsJson.isAcceptableOrUnknown(
          data['media_urls_json']!,
          _mediaUrlsJsonMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('invoiced_at')) {
      context.handle(
        _invoicedAtMeta,
        invoicedAt.isAcceptableOrUnknown(data['invoiced_at']!, _invoicedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      apartmentSupabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}apartment_supabase_id'],
      ),
      clientSupabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_supabase_id'],
      ),
      customLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_location'],
      ),
      customTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_title'],
      ),
      reservationSupabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reservation_supabase_id'],
      ),
      assignedUserSupabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_user_supabase_id'],
      ),
      assignedUserIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_user_ids_json'],
      ),
      referenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_number'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      scheduledStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_start'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      unassignedInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unassigned_info'],
      ),
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_id'],
      ),
      mediaUrlsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_urls_json'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      invoicedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}invoiced_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String? apartmentSupabaseId;
  final String? clientSupabaseId;
  final String? customLocation;
  final String? customTitle;
  final String? reservationSupabaseId;
  final String? assignedUserSupabaseId;

  /// Další přiřazení pracovníci (JSON pole UUID) – pro sdílení úkolu.
  final String? assignedUserIdsJson;
  final String? referenceNumber;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;

  /// Termín splnění z `tasks.due_date` (na serveru text) – po sync parsováno do UTC; null pokud server neposlal nebo nejde parsovat.
  final DateTime? dueDate;
  final String status;
  final String? photoUrl;
  final DateTime localUpdatedAt;
  final DateTime? lastSyncedAt;
  final int syncStatus;
  final DateTime lastUpdated;
  final String? metadataJson;

  /// JSON z `tasks.unassigned_info` (jsonb) jako text – pro offline kontext nepřiřazeného úkolu.
  final String? unassignedInfo;

  /// UUID služby z `tasks.service_id` – text kvůli jednoduchosti v SQLite.
  final String? serviceId;

  /// JSON pole URL fotek (Supabase `tasks.media_urls` typu text[]) – serializace jako JSON string.
  /// Přidáno ve Fázi 2: offline náhled fotek u úkolu (requires_photo, závady, dokumentace).
  final String? mediaUrlsJson;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? invoicedAt;
  const Task({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    this.apartmentSupabaseId,
    this.clientSupabaseId,
    this.customLocation,
    this.customTitle,
    this.reservationSupabaseId,
    this.assignedUserSupabaseId,
    this.assignedUserIdsJson,
    this.referenceNumber,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    this.dueDate,
    required this.status,
    this.photoUrl,
    required this.localUpdatedAt,
    this.lastSyncedAt,
    required this.syncStatus,
    required this.lastUpdated,
    this.metadataJson,
    this.unassignedInfo,
    this.serviceId,
    this.mediaUrlsJson,
    this.startedAt,
    this.completedAt,
    this.invoicedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || apartmentSupabaseId != null) {
      map['apartment_supabase_id'] = Variable<String>(apartmentSupabaseId);
    }
    if (!nullToAbsent || clientSupabaseId != null) {
      map['client_supabase_id'] = Variable<String>(clientSupabaseId);
    }
    if (!nullToAbsent || customLocation != null) {
      map['custom_location'] = Variable<String>(customLocation);
    }
    if (!nullToAbsent || customTitle != null) {
      map['custom_title'] = Variable<String>(customTitle);
    }
    if (!nullToAbsent || reservationSupabaseId != null) {
      map['reservation_supabase_id'] = Variable<String>(reservationSupabaseId);
    }
    if (!nullToAbsent || assignedUserSupabaseId != null) {
      map['assigned_user_supabase_id'] = Variable<String>(
        assignedUserSupabaseId,
      );
    }
    if (!nullToAbsent || assignedUserIdsJson != null) {
      map['assigned_user_ids_json'] = Variable<String>(assignedUserIdsJson);
    }
    if (!nullToAbsent || referenceNumber != null) {
      map['reference_number'] = Variable<String>(referenceNumber);
    }
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['task_type'] = Variable<String>(taskType);
    map['scheduled_start'] = Variable<DateTime>(scheduledStart);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    if (!nullToAbsent || unassignedInfo != null) {
      map['unassigned_info'] = Variable<String>(unassignedInfo);
    }
    if (!nullToAbsent || serviceId != null) {
      map['service_id'] = Variable<String>(serviceId);
    }
    if (!nullToAbsent || mediaUrlsJson != null) {
      map['media_urls_json'] = Variable<String>(mediaUrlsJson);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || invoicedAt != null) {
      map['invoiced_at'] = Variable<DateTime>(invoicedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      apartmentSupabaseId: apartmentSupabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(apartmentSupabaseId),
      clientSupabaseId: clientSupabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientSupabaseId),
      customLocation: customLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(customLocation),
      customTitle: customTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(customTitle),
      reservationSupabaseId: reservationSupabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(reservationSupabaseId),
      assignedUserSupabaseId: assignedUserSupabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedUserSupabaseId),
      assignedUserIdsJson: assignedUserIdsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedUserIdsJson),
      referenceNumber: referenceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNumber),
      title: Value(title),
      description: Value(description),
      taskType: Value(taskType),
      scheduledStart: Value(scheduledStart),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      status: Value(status),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      localUpdatedAt: Value(localUpdatedAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      syncStatus: Value(syncStatus),
      lastUpdated: Value(lastUpdated),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      unassignedInfo: unassignedInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(unassignedInfo),
      serviceId: serviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(serviceId),
      mediaUrlsJson: mediaUrlsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrlsJson),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      invoicedAt: invoicedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(invoicedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      apartmentSupabaseId: serializer.fromJson<String?>(
        json['apartmentSupabaseId'],
      ),
      clientSupabaseId: serializer.fromJson<String?>(json['clientSupabaseId']),
      customLocation: serializer.fromJson<String?>(json['customLocation']),
      customTitle: serializer.fromJson<String?>(json['customTitle']),
      reservationSupabaseId: serializer.fromJson<String?>(
        json['reservationSupabaseId'],
      ),
      assignedUserSupabaseId: serializer.fromJson<String?>(
        json['assignedUserSupabaseId'],
      ),
      assignedUserIdsJson: serializer.fromJson<String?>(
        json['assignedUserIdsJson'],
      ),
      referenceNumber: serializer.fromJson<String?>(json['referenceNumber']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      taskType: serializer.fromJson<String>(json['taskType']),
      scheduledStart: serializer.fromJson<DateTime>(json['scheduledStart']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      status: serializer.fromJson<String>(json['status']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      unassignedInfo: serializer.fromJson<String?>(json['unassignedInfo']),
      serviceId: serializer.fromJson<String?>(json['serviceId']),
      mediaUrlsJson: serializer.fromJson<String?>(json['mediaUrlsJson']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      invoicedAt: serializer.fromJson<DateTime?>(json['invoicedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'apartmentSupabaseId': serializer.toJson<String?>(apartmentSupabaseId),
      'clientSupabaseId': serializer.toJson<String?>(clientSupabaseId),
      'customLocation': serializer.toJson<String?>(customLocation),
      'customTitle': serializer.toJson<String?>(customTitle),
      'reservationSupabaseId': serializer.toJson<String?>(
        reservationSupabaseId,
      ),
      'assignedUserSupabaseId': serializer.toJson<String?>(
        assignedUserSupabaseId,
      ),
      'assignedUserIdsJson': serializer.toJson<String?>(assignedUserIdsJson),
      'referenceNumber': serializer.toJson<String?>(referenceNumber),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'taskType': serializer.toJson<String>(taskType),
      'scheduledStart': serializer.toJson<DateTime>(scheduledStart),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'status': serializer.toJson<String>(status),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'unassignedInfo': serializer.toJson<String?>(unassignedInfo),
      'serviceId': serializer.toJson<String?>(serviceId),
      'mediaUrlsJson': serializer.toJson<String?>(mediaUrlsJson),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'invoicedAt': serializer.toJson<DateTime?>(invoicedAt),
    };
  }

  Task copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    Value<String?> apartmentSupabaseId = const Value.absent(),
    Value<String?> clientSupabaseId = const Value.absent(),
    Value<String?> customLocation = const Value.absent(),
    Value<String?> customTitle = const Value.absent(),
    Value<String?> reservationSupabaseId = const Value.absent(),
    Value<String?> assignedUserSupabaseId = const Value.absent(),
    Value<String?> assignedUserIdsJson = const Value.absent(),
    Value<String?> referenceNumber = const Value.absent(),
    String? title,
    String? description,
    String? taskType,
    DateTime? scheduledStart,
    Value<DateTime?> dueDate = const Value.absent(),
    String? status,
    Value<String?> photoUrl = const Value.absent(),
    DateTime? localUpdatedAt,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    int? syncStatus,
    DateTime? lastUpdated,
    Value<String?> metadataJson = const Value.absent(),
    Value<String?> unassignedInfo = const Value.absent(),
    Value<String?> serviceId = const Value.absent(),
    Value<String?> mediaUrlsJson = const Value.absent(),
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> invoicedAt = const Value.absent(),
  }) => Task(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    apartmentSupabaseId: apartmentSupabaseId.present
        ? apartmentSupabaseId.value
        : this.apartmentSupabaseId,
    clientSupabaseId: clientSupabaseId.present
        ? clientSupabaseId.value
        : this.clientSupabaseId,
    customLocation: customLocation.present
        ? customLocation.value
        : this.customLocation,
    customTitle: customTitle.present ? customTitle.value : this.customTitle,
    reservationSupabaseId: reservationSupabaseId.present
        ? reservationSupabaseId.value
        : this.reservationSupabaseId,
    assignedUserSupabaseId: assignedUserSupabaseId.present
        ? assignedUserSupabaseId.value
        : this.assignedUserSupabaseId,
    assignedUserIdsJson: assignedUserIdsJson.present
        ? assignedUserIdsJson.value
        : this.assignedUserIdsJson,
    referenceNumber: referenceNumber.present
        ? referenceNumber.value
        : this.referenceNumber,
    title: title ?? this.title,
    description: description ?? this.description,
    taskType: taskType ?? this.taskType,
    scheduledStart: scheduledStart ?? this.scheduledStart,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    status: status ?? this.status,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    unassignedInfo: unassignedInfo.present
        ? unassignedInfo.value
        : this.unassignedInfo,
    serviceId: serviceId.present ? serviceId.value : this.serviceId,
    mediaUrlsJson: mediaUrlsJson.present
        ? mediaUrlsJson.value
        : this.mediaUrlsJson,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    invoicedAt: invoicedAt.present ? invoicedAt.value : this.invoicedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      apartmentSupabaseId: data.apartmentSupabaseId.present
          ? data.apartmentSupabaseId.value
          : this.apartmentSupabaseId,
      clientSupabaseId: data.clientSupabaseId.present
          ? data.clientSupabaseId.value
          : this.clientSupabaseId,
      customLocation: data.customLocation.present
          ? data.customLocation.value
          : this.customLocation,
      customTitle: data.customTitle.present
          ? data.customTitle.value
          : this.customTitle,
      reservationSupabaseId: data.reservationSupabaseId.present
          ? data.reservationSupabaseId.value
          : this.reservationSupabaseId,
      assignedUserSupabaseId: data.assignedUserSupabaseId.present
          ? data.assignedUserSupabaseId.value
          : this.assignedUserSupabaseId,
      assignedUserIdsJson: data.assignedUserIdsJson.present
          ? data.assignedUserIdsJson.value
          : this.assignedUserIdsJson,
      referenceNumber: data.referenceNumber.present
          ? data.referenceNumber.value
          : this.referenceNumber,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      scheduledStart: data.scheduledStart.present
          ? data.scheduledStart.value
          : this.scheduledStart,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      status: data.status.present ? data.status.value : this.status,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      unassignedInfo: data.unassignedInfo.present
          ? data.unassignedInfo.value
          : this.unassignedInfo,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      mediaUrlsJson: data.mediaUrlsJson.present
          ? data.mediaUrlsJson.value
          : this.mediaUrlsJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      invoicedAt: data.invoicedAt.present
          ? data.invoicedAt.value
          : this.invoicedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('apartmentSupabaseId: $apartmentSupabaseId, ')
          ..write('clientSupabaseId: $clientSupabaseId, ')
          ..write('customLocation: $customLocation, ')
          ..write('customTitle: $customTitle, ')
          ..write('reservationSupabaseId: $reservationSupabaseId, ')
          ..write('assignedUserSupabaseId: $assignedUserSupabaseId, ')
          ..write('assignedUserIdsJson: $assignedUserIdsJson, ')
          ..write('referenceNumber: $referenceNumber, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('taskType: $taskType, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('unassignedInfo: $unassignedInfo, ')
          ..write('serviceId: $serviceId, ')
          ..write('mediaUrlsJson: $mediaUrlsJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('invoicedAt: $invoicedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    supabaseId,
    tenantId,
    apartmentSupabaseId,
    clientSupabaseId,
    customLocation,
    customTitle,
    reservationSupabaseId,
    assignedUserSupabaseId,
    assignedUserIdsJson,
    referenceNumber,
    title,
    description,
    taskType,
    scheduledStart,
    dueDate,
    status,
    photoUrl,
    localUpdatedAt,
    lastSyncedAt,
    syncStatus,
    lastUpdated,
    metadataJson,
    unassignedInfo,
    serviceId,
    mediaUrlsJson,
    startedAt,
    completedAt,
    invoicedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.apartmentSupabaseId == this.apartmentSupabaseId &&
          other.clientSupabaseId == this.clientSupabaseId &&
          other.customLocation == this.customLocation &&
          other.customTitle == this.customTitle &&
          other.reservationSupabaseId == this.reservationSupabaseId &&
          other.assignedUserSupabaseId == this.assignedUserSupabaseId &&
          other.assignedUserIdsJson == this.assignedUserIdsJson &&
          other.referenceNumber == this.referenceNumber &&
          other.title == this.title &&
          other.description == this.description &&
          other.taskType == this.taskType &&
          other.scheduledStart == this.scheduledStart &&
          other.dueDate == this.dueDate &&
          other.status == this.status &&
          other.photoUrl == this.photoUrl &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.syncStatus == this.syncStatus &&
          other.lastUpdated == this.lastUpdated &&
          other.metadataJson == this.metadataJson &&
          other.unassignedInfo == this.unassignedInfo &&
          other.serviceId == this.serviceId &&
          other.mediaUrlsJson == this.mediaUrlsJson &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.invoicedAt == this.invoicedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String?> apartmentSupabaseId;
  final Value<String?> clientSupabaseId;
  final Value<String?> customLocation;
  final Value<String?> customTitle;
  final Value<String?> reservationSupabaseId;
  final Value<String?> assignedUserSupabaseId;
  final Value<String?> assignedUserIdsJson;
  final Value<String?> referenceNumber;
  final Value<String> title;
  final Value<String> description;
  final Value<String> taskType;
  final Value<DateTime> scheduledStart;
  final Value<DateTime?> dueDate;
  final Value<String> status;
  final Value<String?> photoUrl;
  final Value<DateTime> localUpdatedAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> syncStatus;
  final Value<DateTime> lastUpdated;
  final Value<String?> metadataJson;
  final Value<String?> unassignedInfo;
  final Value<String?> serviceId;
  final Value<String?> mediaUrlsJson;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> invoicedAt;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.apartmentSupabaseId = const Value.absent(),
    this.clientSupabaseId = const Value.absent(),
    this.customLocation = const Value.absent(),
    this.customTitle = const Value.absent(),
    this.reservationSupabaseId = const Value.absent(),
    this.assignedUserSupabaseId = const Value.absent(),
    this.assignedUserIdsJson = const Value.absent(),
    this.referenceNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.taskType = const Value.absent(),
    this.scheduledStart = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.unassignedInfo = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.mediaUrlsJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.invoicedAt = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    this.apartmentSupabaseId = const Value.absent(),
    this.clientSupabaseId = const Value.absent(),
    this.customLocation = const Value.absent(),
    this.customTitle = const Value.absent(),
    this.reservationSupabaseId = const Value.absent(),
    this.assignedUserSupabaseId = const Value.absent(),
    this.assignedUserIdsJson = const Value.absent(),
    this.referenceNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.taskType = const Value.absent(),
    required DateTime scheduledStart,
    this.dueDate = const Value.absent(),
    required String status,
    this.photoUrl = const Value.absent(),
    required DateTime localUpdatedAt,
    this.lastSyncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime lastUpdated,
    this.metadataJson = const Value.absent(),
    this.unassignedInfo = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.mediaUrlsJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.invoicedAt = const Value.absent(),
  }) : tenantId = Value(tenantId),
       scheduledStart = Value(scheduledStart),
       status = Value(status),
       localUpdatedAt = Value(localUpdatedAt),
       lastUpdated = Value(lastUpdated);
  static Insertable<Task> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? apartmentSupabaseId,
    Expression<String>? clientSupabaseId,
    Expression<String>? customLocation,
    Expression<String>? customTitle,
    Expression<String>? reservationSupabaseId,
    Expression<String>? assignedUserSupabaseId,
    Expression<String>? assignedUserIdsJson,
    Expression<String>? referenceNumber,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? taskType,
    Expression<DateTime>? scheduledStart,
    Expression<DateTime>? dueDate,
    Expression<String>? status,
    Expression<String>? photoUrl,
    Expression<DateTime>? localUpdatedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? syncStatus,
    Expression<DateTime>? lastUpdated,
    Expression<String>? metadataJson,
    Expression<String>? unassignedInfo,
    Expression<String>? serviceId,
    Expression<String>? mediaUrlsJson,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? invoicedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (apartmentSupabaseId != null)
        'apartment_supabase_id': apartmentSupabaseId,
      if (clientSupabaseId != null) 'client_supabase_id': clientSupabaseId,
      if (customLocation != null) 'custom_location': customLocation,
      if (customTitle != null) 'custom_title': customTitle,
      if (reservationSupabaseId != null)
        'reservation_supabase_id': reservationSupabaseId,
      if (assignedUserSupabaseId != null)
        'assigned_user_supabase_id': assignedUserSupabaseId,
      if (assignedUserIdsJson != null)
        'assigned_user_ids_json': assignedUserIdsJson,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (taskType != null) 'task_type': taskType,
      if (scheduledStart != null) 'scheduled_start': scheduledStart,
      if (dueDate != null) 'due_date': dueDate,
      if (status != null) 'status': status,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (unassignedInfo != null) 'unassigned_info': unassignedInfo,
      if (serviceId != null) 'service_id': serviceId,
      if (mediaUrlsJson != null) 'media_urls_json': mediaUrlsJson,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (invoicedAt != null) 'invoiced_at': invoicedAt,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String?>? apartmentSupabaseId,
    Value<String?>? clientSupabaseId,
    Value<String?>? customLocation,
    Value<String?>? customTitle,
    Value<String?>? reservationSupabaseId,
    Value<String?>? assignedUserSupabaseId,
    Value<String?>? assignedUserIdsJson,
    Value<String?>? referenceNumber,
    Value<String>? title,
    Value<String>? description,
    Value<String>? taskType,
    Value<DateTime>? scheduledStart,
    Value<DateTime?>? dueDate,
    Value<String>? status,
    Value<String?>? photoUrl,
    Value<DateTime>? localUpdatedAt,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? syncStatus,
    Value<DateTime>? lastUpdated,
    Value<String?>? metadataJson,
    Value<String?>? unassignedInfo,
    Value<String?>? serviceId,
    Value<String?>? mediaUrlsJson,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? invoicedAt,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      apartmentSupabaseId: apartmentSupabaseId ?? this.apartmentSupabaseId,
      clientSupabaseId: clientSupabaseId ?? this.clientSupabaseId,
      customLocation: customLocation ?? this.customLocation,
      customTitle: customTitle ?? this.customTitle,
      reservationSupabaseId:
          reservationSupabaseId ?? this.reservationSupabaseId,
      assignedUserSupabaseId:
          assignedUserSupabaseId ?? this.assignedUserSupabaseId,
      assignedUserIdsJson: assignedUserIdsJson ?? this.assignedUserIdsJson,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadataJson: metadataJson ?? this.metadataJson,
      unassignedInfo: unassignedInfo ?? this.unassignedInfo,
      serviceId: serviceId ?? this.serviceId,
      mediaUrlsJson: mediaUrlsJson ?? this.mediaUrlsJson,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      invoicedAt: invoicedAt ?? this.invoicedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (apartmentSupabaseId.present) {
      map['apartment_supabase_id'] = Variable<String>(
        apartmentSupabaseId.value,
      );
    }
    if (clientSupabaseId.present) {
      map['client_supabase_id'] = Variable<String>(clientSupabaseId.value);
    }
    if (customLocation.present) {
      map['custom_location'] = Variable<String>(customLocation.value);
    }
    if (customTitle.present) {
      map['custom_title'] = Variable<String>(customTitle.value);
    }
    if (reservationSupabaseId.present) {
      map['reservation_supabase_id'] = Variable<String>(
        reservationSupabaseId.value,
      );
    }
    if (assignedUserSupabaseId.present) {
      map['assigned_user_supabase_id'] = Variable<String>(
        assignedUserSupabaseId.value,
      );
    }
    if (assignedUserIdsJson.present) {
      map['assigned_user_ids_json'] = Variable<String>(
        assignedUserIdsJson.value,
      );
    }
    if (referenceNumber.present) {
      map['reference_number'] = Variable<String>(referenceNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (scheduledStart.present) {
      map['scheduled_start'] = Variable<DateTime>(scheduledStart.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (unassignedInfo.present) {
      map['unassigned_info'] = Variable<String>(unassignedInfo.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (mediaUrlsJson.present) {
      map['media_urls_json'] = Variable<String>(mediaUrlsJson.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (invoicedAt.present) {
      map['invoiced_at'] = Variable<DateTime>(invoicedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('apartmentSupabaseId: $apartmentSupabaseId, ')
          ..write('clientSupabaseId: $clientSupabaseId, ')
          ..write('customLocation: $customLocation, ')
          ..write('customTitle: $customTitle, ')
          ..write('reservationSupabaseId: $reservationSupabaseId, ')
          ..write('assignedUserSupabaseId: $assignedUserSupabaseId, ')
          ..write('assignedUserIdsJson: $assignedUserIdsJson, ')
          ..write('referenceNumber: $referenceNumber, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('taskType: $taskType, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('unassignedInfo: $unassignedInfo, ')
          ..write('serviceId: $serviceId, ')
          ..write('mediaUrlsJson: $mediaUrlsJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('invoicedAt: $invoicedAt')
          ..write(')'))
        .toString();
  }
}

class $PendingMutationsTable extends PendingMutations
    with TableInfo<$PendingMutationsTable, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetTable,
    actionType,
    payloadJson,
    recordId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['table_name']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingMutationsTable createAlias(String alias) {
    return $PendingMutationsTable(attachedDatabase, alias);
  }
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final int id;

  /// Název cílové tabulky (např. tasks, cash_wallets). Používáme targetTable,
  /// protože tableName je rezervované v Drift Table base class.
  final String targetTable;
  final String actionType;
  final String payloadJson;
  final String? recordId;
  final DateTime createdAt;
  const PendingMutation({
    required this.id,
    required this.targetTable,
    required this.actionType,
    required this.payloadJson,
    this.recordId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['table_name'] = Variable<String>(targetTable);
    map['action_type'] = Variable<String>(actionType);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || recordId != null) {
      map['record_id'] = Variable<String>(recordId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      id: Value(id),
      targetTable: Value(targetTable),
      actionType: Value(actionType),
      payloadJson: Value(payloadJson),
      recordId: recordId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordId),
      createdAt: Value(createdAt),
    );
  }

  factory PendingMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      id: serializer.fromJson<int>(json['id']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      actionType: serializer.fromJson<String>(json['actionType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      recordId: serializer.fromJson<String?>(json['recordId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetTable': serializer.toJson<String>(targetTable),
      'actionType': serializer.toJson<String>(actionType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'recordId': serializer.toJson<String?>(recordId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingMutation copyWith({
    int? id,
    String? targetTable,
    String? actionType,
    String? payloadJson,
    Value<String?> recordId = const Value.absent(),
    DateTime? createdAt,
  }) => PendingMutation(
    id: id ?? this.id,
    targetTable: targetTable ?? this.targetTable,
    actionType: actionType ?? this.actionType,
    payloadJson: payloadJson ?? this.payloadJson,
    recordId: recordId.present ? recordId.value : this.recordId,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      id: data.id.present ? data.id.value : this.id,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('actionType: $actionType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('recordId: $recordId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetTable,
    actionType,
    payloadJson,
    recordId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.id == this.id &&
          other.targetTable == this.targetTable &&
          other.actionType == this.actionType &&
          other.payloadJson == this.payloadJson &&
          other.recordId == this.recordId &&
          other.createdAt == this.createdAt);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<int> id;
  final Value<String> targetTable;
  final Value<String> actionType;
  final Value<String> payloadJson;
  final Value<String?> recordId;
  final Value<DateTime> createdAt;
  const PendingMutationsCompanion({
    this.id = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.actionType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.recordId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    this.id = const Value.absent(),
    required String targetTable,
    required String actionType,
    required String payloadJson,
    this.recordId = const Value.absent(),
    required DateTime createdAt,
  }) : targetTable = Value(targetTable),
       actionType = Value(actionType),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<PendingMutation> custom({
    Expression<int>? id,
    Expression<String>? targetTable,
    Expression<String>? actionType,
    Expression<String>? payloadJson,
    Expression<String>? recordId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTable != null) 'table_name': targetTable,
      if (actionType != null) 'action_type': actionType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (recordId != null) 'record_id': recordId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingMutationsCompanion copyWith({
    Value<int>? id,
    Value<String>? targetTable,
    Value<String>? actionType,
    Value<String>? payloadJson,
    Value<String?>? recordId,
    Value<DateTime>? createdAt,
  }) {
    return PendingMutationsCompanion(
      id: id ?? this.id,
      targetTable: targetTable ?? this.targetTable,
      actionType: actionType ?? this.actionType,
      payloadJson: payloadJson ?? this.payloadJson,
      recordId: recordId ?? this.recordId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetTable.present) {
      map['table_name'] = Variable<String>(targetTable.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('actionType: $actionType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('recordId: $recordId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ApartmentsTable extends Apartments
    with TableInfo<$ApartmentsTable, Apartment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApartmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyboxMeta = const VerificationMeta('keybox');
  @override
  late final GeneratedColumn<String> keybox = GeneratedColumn<String>(
    'keybox',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerNotesMeta = const VerificationMeta(
    'ownerNotes',
  );
  @override
  late final GeneratedColumn<String> ownerNotes = GeneratedColumn<String>(
    'owner_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkInTimeMeta = const VerificationMeta(
    'checkInTime',
  );
  @override
  late final GeneratedColumn<String> checkInTime = GeneratedColumn<String>(
    'check_in_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkOutTimeMeta = const VerificationMeta(
    'checkOutTime',
  );
  @override
  late final GeneratedColumn<String> checkOutTime = GeneratedColumn<String>(
    'check_out_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parkingInstructionsMeta =
      const VerificationMeta('parkingInstructions');
  @override
  late final GeneratedColumn<String> parkingInstructions =
      GeneratedColumn<String>(
        'parking_instructions',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _investmentTrackingEnabledMeta =
      const VerificationMeta('investmentTrackingEnabled');
  @override
  late final GeneratedColumn<bool> investmentTrackingEnabled =
      GeneratedColumn<bool>(
        'investment_tracking_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("investment_tracking_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _rentalModeMeta = const VerificationMeta(
    'rentalMode',
  );
  @override
  late final GeneratedColumn<String> rentalMode = GeneratedColumn<String>(
    'rental_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('short_term'),
  );
  static const VerificationMeta _leaseStartDateMeta = const VerificationMeta(
    'leaseStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> leaseStartDate =
      GeneratedColumn<DateTime>(
        'lease_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _leaseEndDateMeta = const VerificationMeta(
    'leaseEndDate',
  );
  @override
  late final GeneratedColumn<DateTime> leaseEndDate = GeneratedColumn<DateTime>(
    'lease_end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rentAmountMeta = const VerificationMeta(
    'rentAmount',
  );
  @override
  late final GeneratedColumn<double> rentAmount = GeneratedColumn<double>(
    'rent_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rentDueDayMeta = const VerificationMeta(
    'rentDueDay',
  );
  @override
  late final GeneratedColumn<int> rentDueDay = GeneratedColumn<int>(
    'rent_due_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _rentCollectionModeMeta =
      const VerificationMeta('rentCollectionMode');
  @override
  late final GeneratedColumn<String> rentCollectionMode =
      GeneratedColumn<String>(
        'rent_collection_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('notification'),
      );
  static const VerificationMeta _rentTaskAssigneeIdMeta =
      const VerificationMeta('rentTaskAssigneeId');
  @override
  late final GeneratedColumn<String> rentTaskAssigneeId =
      GeneratedColumn<String>(
        'rent_task_assignee_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    name,
    address,
    keybox,
    code,
    ownerNotes,
    checkInTime,
    checkOutTime,
    zoneId,
    parkingInstructions,
    investmentTrackingEnabled,
    rentalMode,
    leaseStartDate,
    leaseEndDate,
    rentAmount,
    rentDueDay,
    rentCollectionMode,
    rentTaskAssigneeId,
    syncStatus,
    localUpdatedAt,
    lastSyncedAt,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'apartments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Apartment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('keybox')) {
      context.handle(
        _keyboxMeta,
        keybox.isAcceptableOrUnknown(data['keybox']!, _keyboxMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('owner_notes')) {
      context.handle(
        _ownerNotesMeta,
        ownerNotes.isAcceptableOrUnknown(data['owner_notes']!, _ownerNotesMeta),
      );
    }
    if (data.containsKey('check_in_time')) {
      context.handle(
        _checkInTimeMeta,
        checkInTime.isAcceptableOrUnknown(
          data['check_in_time']!,
          _checkInTimeMeta,
        ),
      );
    }
    if (data.containsKey('check_out_time')) {
      context.handle(
        _checkOutTimeMeta,
        checkOutTime.isAcceptableOrUnknown(
          data['check_out_time']!,
          _checkOutTimeMeta,
        ),
      );
    }
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    }
    if (data.containsKey('parking_instructions')) {
      context.handle(
        _parkingInstructionsMeta,
        parkingInstructions.isAcceptableOrUnknown(
          data['parking_instructions']!,
          _parkingInstructionsMeta,
        ),
      );
    }
    if (data.containsKey('investment_tracking_enabled')) {
      context.handle(
        _investmentTrackingEnabledMeta,
        investmentTrackingEnabled.isAcceptableOrUnknown(
          data['investment_tracking_enabled']!,
          _investmentTrackingEnabledMeta,
        ),
      );
    }
    if (data.containsKey('rental_mode')) {
      context.handle(
        _rentalModeMeta,
        rentalMode.isAcceptableOrUnknown(data['rental_mode']!, _rentalModeMeta),
      );
    }
    if (data.containsKey('lease_start_date')) {
      context.handle(
        _leaseStartDateMeta,
        leaseStartDate.isAcceptableOrUnknown(
          data['lease_start_date']!,
          _leaseStartDateMeta,
        ),
      );
    }
    if (data.containsKey('lease_end_date')) {
      context.handle(
        _leaseEndDateMeta,
        leaseEndDate.isAcceptableOrUnknown(
          data['lease_end_date']!,
          _leaseEndDateMeta,
        ),
      );
    }
    if (data.containsKey('rent_amount')) {
      context.handle(
        _rentAmountMeta,
        rentAmount.isAcceptableOrUnknown(data['rent_amount']!, _rentAmountMeta),
      );
    }
    if (data.containsKey('rent_due_day')) {
      context.handle(
        _rentDueDayMeta,
        rentDueDay.isAcceptableOrUnknown(
          data['rent_due_day']!,
          _rentDueDayMeta,
        ),
      );
    }
    if (data.containsKey('rent_collection_mode')) {
      context.handle(
        _rentCollectionModeMeta,
        rentCollectionMode.isAcceptableOrUnknown(
          data['rent_collection_mode']!,
          _rentCollectionModeMeta,
        ),
      );
    }
    if (data.containsKey('rent_task_assignee_id')) {
      context.handle(
        _rentTaskAssigneeIdMeta,
        rentTaskAssigneeId.isAcceptableOrUnknown(
          data['rent_task_assignee_id']!,
          _rentTaskAssigneeIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Apartment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Apartment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      keybox: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keybox'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      ownerNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_notes'],
      ),
      checkInTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_in_time'],
      ),
      checkOutTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_out_time'],
      ),
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      ),
      parkingInstructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parking_instructions'],
      ),
      investmentTrackingEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}investment_tracking_enabled'],
      )!,
      rentalMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rental_mode'],
      )!,
      leaseStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_start_date'],
      ),
      leaseEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_end_date'],
      ),
      rentAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rent_amount'],
      )!,
      rentDueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rent_due_day'],
      )!,
      rentCollectionMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rent_collection_mode'],
      )!,
      rentTaskAssigneeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rent_task_assignee_id'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $ApartmentsTable createAlias(String alias) {
    return $ApartmentsTable(attachedDatabase, alias);
  }
}

class Apartment extends DataClass implements Insertable<Apartment> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String name;
  final String? address;
  final String? keybox;
  final String? code;
  final String? ownerNotes;

  /// Standardní čas příjezdu hosta (např. „15:00“) – z `apartments.check_in_time`.
  final String? checkInTime;

  /// Standardní čas odjezdu (check-out) – z `apartments.check_out_time`.
  final String? checkOutTime;

  /// UUID zóny (např. parkování) – z `apartments.zone_id`, text pro jednoduchost v SQLite.
  final String? zoneId;

  /// Instrukce k parkování pro offline zobrazení – z `apartments.parking_instructions`.
  final String? parkingInstructions;

  /// Příznak investičního modulu – z `apartments.investment_tracking_enabled`.
  final bool investmentTrackingEnabled;

  /// `short_term` | `long_term` – z `apartments.rental_mode`.
  final String rentalMode;

  /// Platnost smlouvy od (nullable) – z `apartments.lease_start_date`.
  final DateTime? leaseStartDate;

  /// Platnost smlouvy do – z `apartments.lease_end_date`.
  final DateTime? leaseEndDate;

  /// Měsíční nájem (dlouhodobý) – z `apartments.rent_amount`.
  final double rentAmount;

  /// Den splatnosti 1–31 – z `apartments.rent_due_day`.
  final int rentDueDay;

  /// `notification` | `task` – z `apartments.rent_collection_mode`.
  final String rentCollectionMode;

  /// Odpovědný pracovník (profiles.id) – z `apartments.rent_task_assignee_id`.
  final String? rentTaskAssigneeId;
  final int syncStatus;
  final DateTime localUpdatedAt;
  final DateTime? lastSyncedAt;
  final DateTime lastUpdated;
  const Apartment({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    required this.name,
    this.address,
    this.keybox,
    this.code,
    this.ownerNotes,
    this.checkInTime,
    this.checkOutTime,
    this.zoneId,
    this.parkingInstructions,
    required this.investmentTrackingEnabled,
    required this.rentalMode,
    this.leaseStartDate,
    this.leaseEndDate,
    required this.rentAmount,
    required this.rentDueDay,
    required this.rentCollectionMode,
    this.rentTaskAssigneeId,
    required this.syncStatus,
    required this.localUpdatedAt,
    this.lastSyncedAt,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || keybox != null) {
      map['keybox'] = Variable<String>(keybox);
    }
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || ownerNotes != null) {
      map['owner_notes'] = Variable<String>(ownerNotes);
    }
    if (!nullToAbsent || checkInTime != null) {
      map['check_in_time'] = Variable<String>(checkInTime);
    }
    if (!nullToAbsent || checkOutTime != null) {
      map['check_out_time'] = Variable<String>(checkOutTime);
    }
    if (!nullToAbsent || zoneId != null) {
      map['zone_id'] = Variable<String>(zoneId);
    }
    if (!nullToAbsent || parkingInstructions != null) {
      map['parking_instructions'] = Variable<String>(parkingInstructions);
    }
    map['investment_tracking_enabled'] = Variable<bool>(
      investmentTrackingEnabled,
    );
    map['rental_mode'] = Variable<String>(rentalMode);
    if (!nullToAbsent || leaseStartDate != null) {
      map['lease_start_date'] = Variable<DateTime>(leaseStartDate);
    }
    if (!nullToAbsent || leaseEndDate != null) {
      map['lease_end_date'] = Variable<DateTime>(leaseEndDate);
    }
    map['rent_amount'] = Variable<double>(rentAmount);
    map['rent_due_day'] = Variable<int>(rentDueDay);
    map['rent_collection_mode'] = Variable<String>(rentCollectionMode);
    if (!nullToAbsent || rentTaskAssigneeId != null) {
      map['rent_task_assignee_id'] = Variable<String>(rentTaskAssigneeId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  ApartmentsCompanion toCompanion(bool nullToAbsent) {
    return ApartmentsCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      keybox: keybox == null && nullToAbsent
          ? const Value.absent()
          : Value(keybox),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      ownerNotes: ownerNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerNotes),
      checkInTime: checkInTime == null && nullToAbsent
          ? const Value.absent()
          : Value(checkInTime),
      checkOutTime: checkOutTime == null && nullToAbsent
          ? const Value.absent()
          : Value(checkOutTime),
      zoneId: zoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(zoneId),
      parkingInstructions: parkingInstructions == null && nullToAbsent
          ? const Value.absent()
          : Value(parkingInstructions),
      investmentTrackingEnabled: Value(investmentTrackingEnabled),
      rentalMode: Value(rentalMode),
      leaseStartDate: leaseStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseStartDate),
      leaseEndDate: leaseEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseEndDate),
      rentAmount: Value(rentAmount),
      rentDueDay: Value(rentDueDay),
      rentCollectionMode: Value(rentCollectionMode),
      rentTaskAssigneeId: rentTaskAssigneeId == null && nullToAbsent
          ? const Value.absent()
          : Value(rentTaskAssigneeId),
      syncStatus: Value(syncStatus),
      localUpdatedAt: Value(localUpdatedAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory Apartment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Apartment(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      keybox: serializer.fromJson<String?>(json['keybox']),
      code: serializer.fromJson<String?>(json['code']),
      ownerNotes: serializer.fromJson<String?>(json['ownerNotes']),
      checkInTime: serializer.fromJson<String?>(json['checkInTime']),
      checkOutTime: serializer.fromJson<String?>(json['checkOutTime']),
      zoneId: serializer.fromJson<String?>(json['zoneId']),
      parkingInstructions: serializer.fromJson<String?>(
        json['parkingInstructions'],
      ),
      investmentTrackingEnabled: serializer.fromJson<bool>(
        json['investmentTrackingEnabled'],
      ),
      rentalMode: serializer.fromJson<String>(json['rentalMode']),
      leaseStartDate: serializer.fromJson<DateTime?>(json['leaseStartDate']),
      leaseEndDate: serializer.fromJson<DateTime?>(json['leaseEndDate']),
      rentAmount: serializer.fromJson<double>(json['rentAmount']),
      rentDueDay: serializer.fromJson<int>(json['rentDueDay']),
      rentCollectionMode: serializer.fromJson<String>(
        json['rentCollectionMode'],
      ),
      rentTaskAssigneeId: serializer.fromJson<String?>(
        json['rentTaskAssigneeId'],
      ),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'keybox': serializer.toJson<String?>(keybox),
      'code': serializer.toJson<String?>(code),
      'ownerNotes': serializer.toJson<String?>(ownerNotes),
      'checkInTime': serializer.toJson<String?>(checkInTime),
      'checkOutTime': serializer.toJson<String?>(checkOutTime),
      'zoneId': serializer.toJson<String?>(zoneId),
      'parkingInstructions': serializer.toJson<String?>(parkingInstructions),
      'investmentTrackingEnabled': serializer.toJson<bool>(
        investmentTrackingEnabled,
      ),
      'rentalMode': serializer.toJson<String>(rentalMode),
      'leaseStartDate': serializer.toJson<DateTime?>(leaseStartDate),
      'leaseEndDate': serializer.toJson<DateTime?>(leaseEndDate),
      'rentAmount': serializer.toJson<double>(rentAmount),
      'rentDueDay': serializer.toJson<int>(rentDueDay),
      'rentCollectionMode': serializer.toJson<String>(rentCollectionMode),
      'rentTaskAssigneeId': serializer.toJson<String?>(rentTaskAssigneeId),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  Apartment copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    String? name,
    Value<String?> address = const Value.absent(),
    Value<String?> keybox = const Value.absent(),
    Value<String?> code = const Value.absent(),
    Value<String?> ownerNotes = const Value.absent(),
    Value<String?> checkInTime = const Value.absent(),
    Value<String?> checkOutTime = const Value.absent(),
    Value<String?> zoneId = const Value.absent(),
    Value<String?> parkingInstructions = const Value.absent(),
    bool? investmentTrackingEnabled,
    String? rentalMode,
    Value<DateTime?> leaseStartDate = const Value.absent(),
    Value<DateTime?> leaseEndDate = const Value.absent(),
    double? rentAmount,
    int? rentDueDay,
    String? rentCollectionMode,
    Value<String?> rentTaskAssigneeId = const Value.absent(),
    int? syncStatus,
    DateTime? localUpdatedAt,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    DateTime? lastUpdated,
  }) => Apartment(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    address: address.present ? address.value : this.address,
    keybox: keybox.present ? keybox.value : this.keybox,
    code: code.present ? code.value : this.code,
    ownerNotes: ownerNotes.present ? ownerNotes.value : this.ownerNotes,
    checkInTime: checkInTime.present ? checkInTime.value : this.checkInTime,
    checkOutTime: checkOutTime.present ? checkOutTime.value : this.checkOutTime,
    zoneId: zoneId.present ? zoneId.value : this.zoneId,
    parkingInstructions: parkingInstructions.present
        ? parkingInstructions.value
        : this.parkingInstructions,
    investmentTrackingEnabled:
        investmentTrackingEnabled ?? this.investmentTrackingEnabled,
    rentalMode: rentalMode ?? this.rentalMode,
    leaseStartDate: leaseStartDate.present
        ? leaseStartDate.value
        : this.leaseStartDate,
    leaseEndDate: leaseEndDate.present ? leaseEndDate.value : this.leaseEndDate,
    rentAmount: rentAmount ?? this.rentAmount,
    rentDueDay: rentDueDay ?? this.rentDueDay,
    rentCollectionMode: rentCollectionMode ?? this.rentCollectionMode,
    rentTaskAssigneeId: rentTaskAssigneeId.present
        ? rentTaskAssigneeId.value
        : this.rentTaskAssigneeId,
    syncStatus: syncStatus ?? this.syncStatus,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  Apartment copyWithCompanion(ApartmentsCompanion data) {
    return Apartment(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      keybox: data.keybox.present ? data.keybox.value : this.keybox,
      code: data.code.present ? data.code.value : this.code,
      ownerNotes: data.ownerNotes.present
          ? data.ownerNotes.value
          : this.ownerNotes,
      checkInTime: data.checkInTime.present
          ? data.checkInTime.value
          : this.checkInTime,
      checkOutTime: data.checkOutTime.present
          ? data.checkOutTime.value
          : this.checkOutTime,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
      parkingInstructions: data.parkingInstructions.present
          ? data.parkingInstructions.value
          : this.parkingInstructions,
      investmentTrackingEnabled: data.investmentTrackingEnabled.present
          ? data.investmentTrackingEnabled.value
          : this.investmentTrackingEnabled,
      rentalMode: data.rentalMode.present
          ? data.rentalMode.value
          : this.rentalMode,
      leaseStartDate: data.leaseStartDate.present
          ? data.leaseStartDate.value
          : this.leaseStartDate,
      leaseEndDate: data.leaseEndDate.present
          ? data.leaseEndDate.value
          : this.leaseEndDate,
      rentAmount: data.rentAmount.present
          ? data.rentAmount.value
          : this.rentAmount,
      rentDueDay: data.rentDueDay.present
          ? data.rentDueDay.value
          : this.rentDueDay,
      rentCollectionMode: data.rentCollectionMode.present
          ? data.rentCollectionMode.value
          : this.rentCollectionMode,
      rentTaskAssigneeId: data.rentTaskAssigneeId.present
          ? data.rentTaskAssigneeId.value
          : this.rentTaskAssigneeId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Apartment(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('keybox: $keybox, ')
          ..write('code: $code, ')
          ..write('ownerNotes: $ownerNotes, ')
          ..write('checkInTime: $checkInTime, ')
          ..write('checkOutTime: $checkOutTime, ')
          ..write('zoneId: $zoneId, ')
          ..write('parkingInstructions: $parkingInstructions, ')
          ..write('investmentTrackingEnabled: $investmentTrackingEnabled, ')
          ..write('rentalMode: $rentalMode, ')
          ..write('leaseStartDate: $leaseStartDate, ')
          ..write('leaseEndDate: $leaseEndDate, ')
          ..write('rentAmount: $rentAmount, ')
          ..write('rentDueDay: $rentDueDay, ')
          ..write('rentCollectionMode: $rentCollectionMode, ')
          ..write('rentTaskAssigneeId: $rentTaskAssigneeId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    supabaseId,
    tenantId,
    name,
    address,
    keybox,
    code,
    ownerNotes,
    checkInTime,
    checkOutTime,
    zoneId,
    parkingInstructions,
    investmentTrackingEnabled,
    rentalMode,
    leaseStartDate,
    leaseEndDate,
    rentAmount,
    rentDueDay,
    rentCollectionMode,
    rentTaskAssigneeId,
    syncStatus,
    localUpdatedAt,
    lastSyncedAt,
    lastUpdated,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Apartment &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.address == this.address &&
          other.keybox == this.keybox &&
          other.code == this.code &&
          other.ownerNotes == this.ownerNotes &&
          other.checkInTime == this.checkInTime &&
          other.checkOutTime == this.checkOutTime &&
          other.zoneId == this.zoneId &&
          other.parkingInstructions == this.parkingInstructions &&
          other.investmentTrackingEnabled == this.investmentTrackingEnabled &&
          other.rentalMode == this.rentalMode &&
          other.leaseStartDate == this.leaseStartDate &&
          other.leaseEndDate == this.leaseEndDate &&
          other.rentAmount == this.rentAmount &&
          other.rentDueDay == this.rentDueDay &&
          other.rentCollectionMode == this.rentCollectionMode &&
          other.rentTaskAssigneeId == this.rentTaskAssigneeId &&
          other.syncStatus == this.syncStatus &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.lastUpdated == this.lastUpdated);
}

class ApartmentsCompanion extends UpdateCompanion<Apartment> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> address;
  final Value<String?> keybox;
  final Value<String?> code;
  final Value<String?> ownerNotes;
  final Value<String?> checkInTime;
  final Value<String?> checkOutTime;
  final Value<String?> zoneId;
  final Value<String?> parkingInstructions;
  final Value<bool> investmentTrackingEnabled;
  final Value<String> rentalMode;
  final Value<DateTime?> leaseStartDate;
  final Value<DateTime?> leaseEndDate;
  final Value<double> rentAmount;
  final Value<int> rentDueDay;
  final Value<String> rentCollectionMode;
  final Value<String?> rentTaskAssigneeId;
  final Value<int> syncStatus;
  final Value<DateTime> localUpdatedAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime> lastUpdated;
  const ApartmentsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.keybox = const Value.absent(),
    this.code = const Value.absent(),
    this.ownerNotes = const Value.absent(),
    this.checkInTime = const Value.absent(),
    this.checkOutTime = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.parkingInstructions = const Value.absent(),
    this.investmentTrackingEnabled = const Value.absent(),
    this.rentalMode = const Value.absent(),
    this.leaseStartDate = const Value.absent(),
    this.leaseEndDate = const Value.absent(),
    this.rentAmount = const Value.absent(),
    this.rentDueDay = const Value.absent(),
    this.rentCollectionMode = const Value.absent(),
    this.rentTaskAssigneeId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  ApartmentsCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.keybox = const Value.absent(),
    this.code = const Value.absent(),
    this.ownerNotes = const Value.absent(),
    this.checkInTime = const Value.absent(),
    this.checkOutTime = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.parkingInstructions = const Value.absent(),
    this.investmentTrackingEnabled = const Value.absent(),
    this.rentalMode = const Value.absent(),
    this.leaseStartDate = const Value.absent(),
    this.leaseEndDate = const Value.absent(),
    this.rentAmount = const Value.absent(),
    this.rentDueDay = const Value.absent(),
    this.rentCollectionMode = const Value.absent(),
    this.rentTaskAssigneeId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime localUpdatedAt,
    this.lastSyncedAt = const Value.absent(),
    required DateTime lastUpdated,
  }) : tenantId = Value(tenantId),
       localUpdatedAt = Value(localUpdatedAt),
       lastUpdated = Value(lastUpdated);
  static Insertable<Apartment> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? keybox,
    Expression<String>? code,
    Expression<String>? ownerNotes,
    Expression<String>? checkInTime,
    Expression<String>? checkOutTime,
    Expression<String>? zoneId,
    Expression<String>? parkingInstructions,
    Expression<bool>? investmentTrackingEnabled,
    Expression<String>? rentalMode,
    Expression<DateTime>? leaseStartDate,
    Expression<DateTime>? leaseEndDate,
    Expression<double>? rentAmount,
    Expression<int>? rentDueDay,
    Expression<String>? rentCollectionMode,
    Expression<String>? rentTaskAssigneeId,
    Expression<int>? syncStatus,
    Expression<DateTime>? localUpdatedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (keybox != null) 'keybox': keybox,
      if (code != null) 'code': code,
      if (ownerNotes != null) 'owner_notes': ownerNotes,
      if (checkInTime != null) 'check_in_time': checkInTime,
      if (checkOutTime != null) 'check_out_time': checkOutTime,
      if (zoneId != null) 'zone_id': zoneId,
      if (parkingInstructions != null)
        'parking_instructions': parkingInstructions,
      if (investmentTrackingEnabled != null)
        'investment_tracking_enabled': investmentTrackingEnabled,
      if (rentalMode != null) 'rental_mode': rentalMode,
      if (leaseStartDate != null) 'lease_start_date': leaseStartDate,
      if (leaseEndDate != null) 'lease_end_date': leaseEndDate,
      if (rentAmount != null) 'rent_amount': rentAmount,
      if (rentDueDay != null) 'rent_due_day': rentDueDay,
      if (rentCollectionMode != null)
        'rent_collection_mode': rentCollectionMode,
      if (rentTaskAssigneeId != null)
        'rent_task_assignee_id': rentTaskAssigneeId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  ApartmentsCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? address,
    Value<String?>? keybox,
    Value<String?>? code,
    Value<String?>? ownerNotes,
    Value<String?>? checkInTime,
    Value<String?>? checkOutTime,
    Value<String?>? zoneId,
    Value<String?>? parkingInstructions,
    Value<bool>? investmentTrackingEnabled,
    Value<String>? rentalMode,
    Value<DateTime?>? leaseStartDate,
    Value<DateTime?>? leaseEndDate,
    Value<double>? rentAmount,
    Value<int>? rentDueDay,
    Value<String>? rentCollectionMode,
    Value<String?>? rentTaskAssigneeId,
    Value<int>? syncStatus,
    Value<DateTime>? localUpdatedAt,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime>? lastUpdated,
  }) {
    return ApartmentsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      address: address ?? this.address,
      keybox: keybox ?? this.keybox,
      code: code ?? this.code,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      zoneId: zoneId ?? this.zoneId,
      parkingInstructions: parkingInstructions ?? this.parkingInstructions,
      investmentTrackingEnabled:
          investmentTrackingEnabled ?? this.investmentTrackingEnabled,
      rentalMode: rentalMode ?? this.rentalMode,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      leaseEndDate: leaseEndDate ?? this.leaseEndDate,
      rentAmount: rentAmount ?? this.rentAmount,
      rentDueDay: rentDueDay ?? this.rentDueDay,
      rentCollectionMode: rentCollectionMode ?? this.rentCollectionMode,
      rentTaskAssigneeId: rentTaskAssigneeId ?? this.rentTaskAssigneeId,
      syncStatus: syncStatus ?? this.syncStatus,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (keybox.present) {
      map['keybox'] = Variable<String>(keybox.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (ownerNotes.present) {
      map['owner_notes'] = Variable<String>(ownerNotes.value);
    }
    if (checkInTime.present) {
      map['check_in_time'] = Variable<String>(checkInTime.value);
    }
    if (checkOutTime.present) {
      map['check_out_time'] = Variable<String>(checkOutTime.value);
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    if (parkingInstructions.present) {
      map['parking_instructions'] = Variable<String>(parkingInstructions.value);
    }
    if (investmentTrackingEnabled.present) {
      map['investment_tracking_enabled'] = Variable<bool>(
        investmentTrackingEnabled.value,
      );
    }
    if (rentalMode.present) {
      map['rental_mode'] = Variable<String>(rentalMode.value);
    }
    if (leaseStartDate.present) {
      map['lease_start_date'] = Variable<DateTime>(leaseStartDate.value);
    }
    if (leaseEndDate.present) {
      map['lease_end_date'] = Variable<DateTime>(leaseEndDate.value);
    }
    if (rentAmount.present) {
      map['rent_amount'] = Variable<double>(rentAmount.value);
    }
    if (rentDueDay.present) {
      map['rent_due_day'] = Variable<int>(rentDueDay.value);
    }
    if (rentCollectionMode.present) {
      map['rent_collection_mode'] = Variable<String>(rentCollectionMode.value);
    }
    if (rentTaskAssigneeId.present) {
      map['rent_task_assignee_id'] = Variable<String>(rentTaskAssigneeId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApartmentsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('keybox: $keybox, ')
          ..write('code: $code, ')
          ..write('ownerNotes: $ownerNotes, ')
          ..write('checkInTime: $checkInTime, ')
          ..write('checkOutTime: $checkOutTime, ')
          ..write('zoneId: $zoneId, ')
          ..write('parkingInstructions: $parkingInstructions, ')
          ..write('investmentTrackingEnabled: $investmentTrackingEnabled, ')
          ..write('rentalMode: $rentalMode, ')
          ..write('leaseStartDate: $leaseStartDate, ')
          ..write('leaseEndDate: $leaseEndDate, ')
          ..write('rentAmount: $rentAmount, ')
          ..write('rentDueDay: $rentDueDay, ')
          ..write('rentCollectionMode: $rentCollectionMode, ')
          ..write('rentTaskAssigneeId: $rentTaskAssigneeId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $ClientsTable extends Clients with TableInfo<$ClientsTable, Client> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, supabaseId, tenantId, name, phone];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Client> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Client map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Client(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }
}

class Client extends DataClass implements Insertable<Client> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String name;
  final String? phone;
  const Client({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    required this.name,
    this.phone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
    );
  }

  factory Client.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Client(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
    };
  }

  Client copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    String? name,
    Value<String?> phone = const Value.absent(),
  }) => Client(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
  );
  Client copyWithCompanion(ClientsCompanion data) {
    return Client(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Client(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('phone: $phone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, supabaseId, tenantId, name, phone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Client &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.phone == this.phone);
}

class ClientsCompanion extends UpdateCompanion<Client> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> phone;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
  });
  ClientsCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
  }) : tenantId = Value(tenantId);
  static Insertable<Client> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? phone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    });
  }

  ClientsCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? phone,
  }) {
    return ClientsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('phone: $phone')
          ..write(')'))
        .toString();
  }
}

class $ReservationsTable extends Reservations
    with TableInfo<$ReservationsTable, Reservation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReservationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _guestNameMeta = const VerificationMeta(
    'guestName',
  );
  @override
  late final GeneratedColumn<String> guestName = GeneratedColumn<String>(
    'guest_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _guestPhoneMeta = const VerificationMeta(
    'guestPhone',
  );
  @override
  late final GeneratedColumn<String> guestPhone = GeneratedColumn<String>(
    'guest_phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceNumberMeta = const VerificationMeta(
    'referenceNumber',
  );
  @override
  late final GeneratedColumn<String> referenceNumber = GeneratedColumn<String>(
    'reference_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _specialRequestsMeta = const VerificationMeta(
    'specialRequests',
  );
  @override
  late final GeneratedColumn<String> specialRequests = GeneratedColumn<String>(
    'special_requests',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _guestLanguageMeta = const VerificationMeta(
    'guestLanguage',
  );
  @override
  late final GeneratedColumn<String> guestLanguage = GeneratedColumn<String>(
    'guest_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    status,
    guestName,
    guestPhone,
    referenceNumber,
    specialRequests,
    guestLanguage,
    startDate,
    endDate,
    localUpdatedAt,
    lastSyncedAt,
    syncStatus,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reservations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reservation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('guest_name')) {
      context.handle(
        _guestNameMeta,
        guestName.isAcceptableOrUnknown(data['guest_name']!, _guestNameMeta),
      );
    }
    if (data.containsKey('guest_phone')) {
      context.handle(
        _guestPhoneMeta,
        guestPhone.isAcceptableOrUnknown(data['guest_phone']!, _guestPhoneMeta),
      );
    }
    if (data.containsKey('reference_number')) {
      context.handle(
        _referenceNumberMeta,
        referenceNumber.isAcceptableOrUnknown(
          data['reference_number']!,
          _referenceNumberMeta,
        ),
      );
    }
    if (data.containsKey('special_requests')) {
      context.handle(
        _specialRequestsMeta,
        specialRequests.isAcceptableOrUnknown(
          data['special_requests']!,
          _specialRequestsMeta,
        ),
      );
    }
    if (data.containsKey('guest_language')) {
      context.handle(
        _guestLanguageMeta,
        guestLanguage.isAcceptableOrUnknown(
          data['guest_language']!,
          _guestLanguageMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reservation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reservation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      guestName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guest_name'],
      ),
      guestPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guest_phone'],
      ),
      referenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_number'],
      ),
      specialRequests: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}special_requests'],
      ),
      guestLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guest_language'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $ReservationsTable createAlias(String alias) {
    return $ReservationsTable(attachedDatabase, alias);
  }
}

class Reservation extends DataClass implements Insertable<Reservation> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String status;
  final String? guestName;
  final String? guestPhone;
  final String? referenceNumber;

  /// Speciální požadavky hosta – z `reservations.special_requests`.
  final String? specialRequests;

  /// Preferovaný jazyk hosta (např. šablony SMS) – z `reservations.guest_language`.
  final String? guestLanguage;

  /// Začátek pobytu – z `reservations.start_date` (PostgreSQL date → UTC půlnoc).
  final DateTime? startDate;

  /// Konec pobytu – z `reservations.end_date`.
  final DateTime? endDate;
  final DateTime localUpdatedAt;
  final DateTime? lastSyncedAt;
  final int syncStatus;
  final DateTime lastUpdated;
  const Reservation({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    required this.status,
    this.guestName,
    this.guestPhone,
    this.referenceNumber,
    this.specialRequests,
    this.guestLanguage,
    this.startDate,
    this.endDate,
    required this.localUpdatedAt,
    this.lastSyncedAt,
    required this.syncStatus,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || guestName != null) {
      map['guest_name'] = Variable<String>(guestName);
    }
    if (!nullToAbsent || guestPhone != null) {
      map['guest_phone'] = Variable<String>(guestPhone);
    }
    if (!nullToAbsent || referenceNumber != null) {
      map['reference_number'] = Variable<String>(referenceNumber);
    }
    if (!nullToAbsent || specialRequests != null) {
      map['special_requests'] = Variable<String>(specialRequests);
    }
    if (!nullToAbsent || guestLanguage != null) {
      map['guest_language'] = Variable<String>(guestLanguage);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  ReservationsCompanion toCompanion(bool nullToAbsent) {
    return ReservationsCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      status: Value(status),
      guestName: guestName == null && nullToAbsent
          ? const Value.absent()
          : Value(guestName),
      guestPhone: guestPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(guestPhone),
      referenceNumber: referenceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceNumber),
      specialRequests: specialRequests == null && nullToAbsent
          ? const Value.absent()
          : Value(specialRequests),
      guestLanguage: guestLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(guestLanguage),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      localUpdatedAt: Value(localUpdatedAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      syncStatus: Value(syncStatus),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory Reservation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reservation(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      status: serializer.fromJson<String>(json['status']),
      guestName: serializer.fromJson<String?>(json['guestName']),
      guestPhone: serializer.fromJson<String?>(json['guestPhone']),
      referenceNumber: serializer.fromJson<String?>(json['referenceNumber']),
      specialRequests: serializer.fromJson<String?>(json['specialRequests']),
      guestLanguage: serializer.fromJson<String?>(json['guestLanguage']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'status': serializer.toJson<String>(status),
      'guestName': serializer.toJson<String?>(guestName),
      'guestPhone': serializer.toJson<String?>(guestPhone),
      'referenceNumber': serializer.toJson<String?>(referenceNumber),
      'specialRequests': serializer.toJson<String?>(specialRequests),
      'guestLanguage': serializer.toJson<String?>(guestLanguage),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  Reservation copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    String? status,
    Value<String?> guestName = const Value.absent(),
    Value<String?> guestPhone = const Value.absent(),
    Value<String?> referenceNumber = const Value.absent(),
    Value<String?> specialRequests = const Value.absent(),
    Value<String?> guestLanguage = const Value.absent(),
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    DateTime? localUpdatedAt,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    int? syncStatus,
    DateTime? lastUpdated,
  }) => Reservation(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    status: status ?? this.status,
    guestName: guestName.present ? guestName.value : this.guestName,
    guestPhone: guestPhone.present ? guestPhone.value : this.guestPhone,
    referenceNumber: referenceNumber.present
        ? referenceNumber.value
        : this.referenceNumber,
    specialRequests: specialRequests.present
        ? specialRequests.value
        : this.specialRequests,
    guestLanguage: guestLanguage.present
        ? guestLanguage.value
        : this.guestLanguage,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  Reservation copyWithCompanion(ReservationsCompanion data) {
    return Reservation(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      status: data.status.present ? data.status.value : this.status,
      guestName: data.guestName.present ? data.guestName.value : this.guestName,
      guestPhone: data.guestPhone.present
          ? data.guestPhone.value
          : this.guestPhone,
      referenceNumber: data.referenceNumber.present
          ? data.referenceNumber.value
          : this.referenceNumber,
      specialRequests: data.specialRequests.present
          ? data.specialRequests.value
          : this.specialRequests,
      guestLanguage: data.guestLanguage.present
          ? data.guestLanguage.value
          : this.guestLanguage,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reservation(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('status: $status, ')
          ..write('guestName: $guestName, ')
          ..write('guestPhone: $guestPhone, ')
          ..write('referenceNumber: $referenceNumber, ')
          ..write('specialRequests: $specialRequests, ')
          ..write('guestLanguage: $guestLanguage, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    status,
    guestName,
    guestPhone,
    referenceNumber,
    specialRequests,
    guestLanguage,
    startDate,
    endDate,
    localUpdatedAt,
    lastSyncedAt,
    syncStatus,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reservation &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.status == this.status &&
          other.guestName == this.guestName &&
          other.guestPhone == this.guestPhone &&
          other.referenceNumber == this.referenceNumber &&
          other.specialRequests == this.specialRequests &&
          other.guestLanguage == this.guestLanguage &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.syncStatus == this.syncStatus &&
          other.lastUpdated == this.lastUpdated);
}

class ReservationsCompanion extends UpdateCompanion<Reservation> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String> status;
  final Value<String?> guestName;
  final Value<String?> guestPhone;
  final Value<String?> referenceNumber;
  final Value<String?> specialRequests;
  final Value<String?> guestLanguage;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime> localUpdatedAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> syncStatus;
  final Value<DateTime> lastUpdated;
  const ReservationsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.status = const Value.absent(),
    this.guestName = const Value.absent(),
    this.guestPhone = const Value.absent(),
    this.referenceNumber = const Value.absent(),
    this.specialRequests = const Value.absent(),
    this.guestLanguage = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  ReservationsCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    this.status = const Value.absent(),
    this.guestName = const Value.absent(),
    this.guestPhone = const Value.absent(),
    this.referenceNumber = const Value.absent(),
    this.specialRequests = const Value.absent(),
    this.guestLanguage = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    required DateTime localUpdatedAt,
    this.lastSyncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime lastUpdated,
  }) : tenantId = Value(tenantId),
       localUpdatedAt = Value(localUpdatedAt),
       lastUpdated = Value(lastUpdated);
  static Insertable<Reservation> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? status,
    Expression<String>? guestName,
    Expression<String>? guestPhone,
    Expression<String>? referenceNumber,
    Expression<String>? specialRequests,
    Expression<String>? guestLanguage,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? localUpdatedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? syncStatus,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (status != null) 'status': status,
      if (guestName != null) 'guest_name': guestName,
      if (guestPhone != null) 'guest_phone': guestPhone,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (specialRequests != null) 'special_requests': specialRequests,
      if (guestLanguage != null) 'guest_language': guestLanguage,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  ReservationsCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String>? status,
    Value<String?>? guestName,
    Value<String?>? guestPhone,
    Value<String?>? referenceNumber,
    Value<String?>? specialRequests,
    Value<String?>? guestLanguage,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
    Value<DateTime>? localUpdatedAt,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? syncStatus,
    Value<DateTime>? lastUpdated,
  }) {
    return ReservationsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      status: status ?? this.status,
      guestName: guestName ?? this.guestName,
      guestPhone: guestPhone ?? this.guestPhone,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      specialRequests: specialRequests ?? this.specialRequests,
      guestLanguage: guestLanguage ?? this.guestLanguage,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (guestName.present) {
      map['guest_name'] = Variable<String>(guestName.value);
    }
    if (guestPhone.present) {
      map['guest_phone'] = Variable<String>(guestPhone.value);
    }
    if (referenceNumber.present) {
      map['reference_number'] = Variable<String>(referenceNumber.value);
    }
    if (specialRequests.present) {
      map['special_requests'] = Variable<String>(specialRequests.value);
    }
    if (guestLanguage.present) {
      map['guest_language'] = Variable<String>(guestLanguage.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReservationsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('status: $status, ')
          ..write('guestName: $guestName, ')
          ..write('guestPhone: $guestPhone, ')
          ..write('referenceNumber: $referenceNumber, ')
          ..write('specialRequests: $specialRequests, ')
          ..write('guestLanguage: $guestLanguage, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $TenantsTable extends Tenants with TableInfo<$TenantsTable, Tenant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TenantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, supabaseId, currency];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tenants';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tenant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supabaseIdMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tenant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tenant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
    );
  }

  @override
  $TenantsTable createAlias(String alias) {
    return $TenantsTable(attachedDatabase, alias);
  }
}

class Tenant extends DataClass implements Insertable<Tenant> {
  final int id;
  final String supabaseId;
  final String? currency;
  const Tenant({required this.id, required this.supabaseId, this.currency});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supabase_id'] = Variable<String>(supabaseId);
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    return map;
  }

  TenantsCompanion toCompanion(bool nullToAbsent) {
    return TenantsCompanion(
      id: Value(id),
      supabaseId: Value(supabaseId),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
    );
  }

  factory Tenant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tenant(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String>(json['supabaseId']),
      currency: serializer.fromJson<String?>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String>(supabaseId),
      'currency': serializer.toJson<String?>(currency),
    };
  }

  Tenant copyWith({
    int? id,
    String? supabaseId,
    Value<String?> currency = const Value.absent(),
  }) => Tenant(
    id: id ?? this.id,
    supabaseId: supabaseId ?? this.supabaseId,
    currency: currency.present ? currency.value : this.currency,
  );
  Tenant copyWithCompanion(TenantsCompanion data) {
    return Tenant(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tenant(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, supabaseId, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tenant &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.currency == this.currency);
}

class TenantsCompanion extends UpdateCompanion<Tenant> {
  final Value<int> id;
  final Value<String> supabaseId;
  final Value<String?> currency;
  const TenantsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.currency = const Value.absent(),
  });
  TenantsCompanion.insert({
    this.id = const Value.absent(),
    required String supabaseId,
    this.currency = const Value.absent(),
  }) : supabaseId = Value(supabaseId);
  static Insertable<Tenant> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? currency,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (currency != null) 'currency': currency,
    });
  }

  TenantsCompanion copyWith({
    Value<int>? id,
    Value<String>? supabaseId,
    Value<String?>? currency,
  }) {
    return TenantsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      currency: currency ?? this.currency,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TenantsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }
}

class $MessageTemplatesTable extends MessageTemplates
    with TableInfo<$MessageTemplatesTable, MessageTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailSubjectMeta = const VerificationMeta(
    'emailSubject',
  );
  @override
  late final GeneratedColumn<String> emailSubject = GeneratedColumn<String>(
    'email_subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _translationsJsonMeta = const VerificationMeta(
    'translationsJson',
  );
  @override
  late final GeneratedColumn<String> translationsJson = GeneratedColumn<String>(
    'translations_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerContextMeta = const VerificationMeta(
    'triggerContext',
  );
  @override
  late final GeneratedColumn<String> triggerContext = GeneratedColumn<String>(
    'trigger_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    key,
    name,
    channel,
    emailSubject,
    translationsJson,
    triggerContext,
    orderIndex,
    syncStatus,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    }
    if (data.containsKey('email_subject')) {
      context.handle(
        _emailSubjectMeta,
        emailSubject.isAcceptableOrUnknown(
          data['email_subject']!,
          _emailSubjectMeta,
        ),
      );
    }
    if (data.containsKey('translations_json')) {
      context.handle(
        _translationsJsonMeta,
        translationsJson.isAcceptableOrUnknown(
          data['translations_json']!,
          _translationsJsonMeta,
        ),
      );
    }
    if (data.containsKey('trigger_context')) {
      context.handle(
        _triggerContextMeta,
        triggerContext.isAcceptableOrUnknown(
          data['trigger_context']!,
          _triggerContextMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      ),
      emailSubject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email_subject'],
      ),
      translationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translations_json'],
      ),
      triggerContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_context'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $MessageTemplatesTable createAlias(String alias) {
    return $MessageTemplatesTable(attachedDatabase, alias);
  }
}

class MessageTemplate extends DataClass implements Insertable<MessageTemplate> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String key;
  final String name;
  final String? channel;
  final String? emailSubject;
  final String? translationsJson;
  final String? triggerContext;
  final int orderIndex;
  final int syncStatus;
  final DateTime? lastSyncedAt;
  const MessageTemplate({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    required this.key,
    required this.name,
    this.channel,
    this.emailSubject,
    this.translationsJson,
    this.triggerContext,
    required this.orderIndex,
    required this.syncStatus,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['key'] = Variable<String>(key);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || channel != null) {
      map['channel'] = Variable<String>(channel);
    }
    if (!nullToAbsent || emailSubject != null) {
      map['email_subject'] = Variable<String>(emailSubject);
    }
    if (!nullToAbsent || translationsJson != null) {
      map['translations_json'] = Variable<String>(translationsJson);
    }
    if (!nullToAbsent || triggerContext != null) {
      map['trigger_context'] = Variable<String>(triggerContext);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  MessageTemplatesCompanion toCompanion(bool nullToAbsent) {
    return MessageTemplatesCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      key: Value(key),
      name: Value(name),
      channel: channel == null && nullToAbsent
          ? const Value.absent()
          : Value(channel),
      emailSubject: emailSubject == null && nullToAbsent
          ? const Value.absent()
          : Value(emailSubject),
      translationsJson: translationsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(translationsJson),
      triggerContext: triggerContext == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerContext),
      orderIndex: Value(orderIndex),
      syncStatus: Value(syncStatus),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory MessageTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageTemplate(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      key: serializer.fromJson<String>(json['key']),
      name: serializer.fromJson<String>(json['name']),
      channel: serializer.fromJson<String?>(json['channel']),
      emailSubject: serializer.fromJson<String?>(json['emailSubject']),
      translationsJson: serializer.fromJson<String?>(json['translationsJson']),
      triggerContext: serializer.fromJson<String?>(json['triggerContext']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'key': serializer.toJson<String>(key),
      'name': serializer.toJson<String>(name),
      'channel': serializer.toJson<String?>(channel),
      'emailSubject': serializer.toJson<String?>(emailSubject),
      'translationsJson': serializer.toJson<String?>(translationsJson),
      'triggerContext': serializer.toJson<String?>(triggerContext),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  MessageTemplate copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    String? key,
    String? name,
    Value<String?> channel = const Value.absent(),
    Value<String?> emailSubject = const Value.absent(),
    Value<String?> translationsJson = const Value.absent(),
    Value<String?> triggerContext = const Value.absent(),
    int? orderIndex,
    int? syncStatus,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => MessageTemplate(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    key: key ?? this.key,
    name: name ?? this.name,
    channel: channel.present ? channel.value : this.channel,
    emailSubject: emailSubject.present ? emailSubject.value : this.emailSubject,
    translationsJson: translationsJson.present
        ? translationsJson.value
        : this.translationsJson,
    triggerContext: triggerContext.present
        ? triggerContext.value
        : this.triggerContext,
    orderIndex: orderIndex ?? this.orderIndex,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  MessageTemplate copyWithCompanion(MessageTemplatesCompanion data) {
    return MessageTemplate(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      key: data.key.present ? data.key.value : this.key,
      name: data.name.present ? data.name.value : this.name,
      channel: data.channel.present ? data.channel.value : this.channel,
      emailSubject: data.emailSubject.present
          ? data.emailSubject.value
          : this.emailSubject,
      translationsJson: data.translationsJson.present
          ? data.translationsJson.value
          : this.translationsJson,
      triggerContext: data.triggerContext.present
          ? data.triggerContext.value
          : this.triggerContext,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageTemplate(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('channel: $channel, ')
          ..write('emailSubject: $emailSubject, ')
          ..write('translationsJson: $translationsJson, ')
          ..write('triggerContext: $triggerContext, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    key,
    name,
    channel,
    emailSubject,
    translationsJson,
    triggerContext,
    orderIndex,
    syncStatus,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageTemplate &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.key == this.key &&
          other.name == this.name &&
          other.channel == this.channel &&
          other.emailSubject == this.emailSubject &&
          other.translationsJson == this.translationsJson &&
          other.triggerContext == this.triggerContext &&
          other.orderIndex == this.orderIndex &&
          other.syncStatus == this.syncStatus &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class MessageTemplatesCompanion extends UpdateCompanion<MessageTemplate> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String> key;
  final Value<String> name;
  final Value<String?> channel;
  final Value<String?> emailSubject;
  final Value<String?> translationsJson;
  final Value<String?> triggerContext;
  final Value<int> orderIndex;
  final Value<int> syncStatus;
  final Value<DateTime?> lastSyncedAt;
  const MessageTemplatesCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.channel = const Value.absent(),
    this.emailSubject = const Value.absent(),
    this.translationsJson = const Value.absent(),
    this.triggerContext = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  });
  MessageTemplatesCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    this.key = const Value.absent(),
    this.name = const Value.absent(),
    this.channel = const Value.absent(),
    this.emailSubject = const Value.absent(),
    this.translationsJson = const Value.absent(),
    this.triggerContext = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
  }) : tenantId = Value(tenantId);
  static Insertable<MessageTemplate> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? key,
    Expression<String>? name,
    Expression<String>? channel,
    Expression<String>? emailSubject,
    Expression<String>? translationsJson,
    Expression<String>? triggerContext,
    Expression<int>? orderIndex,
    Expression<int>? syncStatus,
    Expression<DateTime>? lastSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (key != null) 'key': key,
      if (name != null) 'name': name,
      if (channel != null) 'channel': channel,
      if (emailSubject != null) 'email_subject': emailSubject,
      if (translationsJson != null) 'translations_json': translationsJson,
      if (triggerContext != null) 'trigger_context': triggerContext,
      if (orderIndex != null) 'order_index': orderIndex,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    });
  }

  MessageTemplatesCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String>? key,
    Value<String>? name,
    Value<String?>? channel,
    Value<String?>? emailSubject,
    Value<String?>? translationsJson,
    Value<String?>? triggerContext,
    Value<int>? orderIndex,
    Value<int>? syncStatus,
    Value<DateTime?>? lastSyncedAt,
  }) {
    return MessageTemplatesCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      key: key ?? this.key,
      name: name ?? this.name,
      channel: channel ?? this.channel,
      emailSubject: emailSubject ?? this.emailSubject,
      translationsJson: translationsJson ?? this.translationsJson,
      triggerContext: triggerContext ?? this.triggerContext,
      orderIndex: orderIndex ?? this.orderIndex,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (emailSubject.present) {
      map['email_subject'] = Variable<String>(emailSubject.value);
    }
    if (translationsJson.present) {
      map['translations_json'] = Variable<String>(translationsJson.value);
    }
    if (triggerContext.present) {
      map['trigger_context'] = Variable<String>(triggerContext.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('name: $name, ')
          ..write('channel: $channel, ')
          ..write('emailSubject: $emailSubject, ')
          ..write('translationsJson: $translationsJson, ')
          ..write('triggerContext: $triggerContext, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $PendingAuditActionsTable extends PendingAuditActions
    with TableInfo<$PendingAuditActionsTable, PendingAuditAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingAuditActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actionType,
    targetTable,
    recordId,
    tenantId,
    createdAtUtc,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_audit_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAuditAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['table_name']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAuditAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAuditAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $PendingAuditActionsTable createAlias(String alias) {
    return $PendingAuditActionsTable(attachedDatabase, alias);
  }
}

class PendingAuditAction extends DataClass
    implements Insertable<PendingAuditAction> {
  final int id;
  final String actionType;
  final String targetTable;
  final String recordId;
  final String? tenantId;
  final DateTime createdAtUtc;
  final int syncStatus;
  const PendingAuditAction({
    required this.id,
    required this.actionType,
    required this.targetTable,
    required this.recordId,
    this.tenantId,
    required this.createdAtUtc,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action_type'] = Variable<String>(actionType);
    map['table_name'] = Variable<String>(targetTable);
    map['record_id'] = Variable<String>(recordId);
    if (!nullToAbsent || tenantId != null) {
      map['tenant_id'] = Variable<String>(tenantId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  PendingAuditActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingAuditActionsCompanion(
      id: Value(id),
      actionType: Value(actionType),
      targetTable: Value(targetTable),
      recordId: Value(recordId),
      tenantId: tenantId == null && nullToAbsent
          ? const Value.absent()
          : Value(tenantId),
      createdAtUtc: Value(createdAtUtc),
      syncStatus: Value(syncStatus),
    );
  }

  factory PendingAuditAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAuditAction(
      id: serializer.fromJson<int>(json['id']),
      actionType: serializer.fromJson<String>(json['actionType']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      recordId: serializer.fromJson<String>(json['recordId']),
      tenantId: serializer.fromJson<String?>(json['tenantId']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'actionType': serializer.toJson<String>(actionType),
      'targetTable': serializer.toJson<String>(targetTable),
      'recordId': serializer.toJson<String>(recordId),
      'tenantId': serializer.toJson<String?>(tenantId),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  PendingAuditAction copyWith({
    int? id,
    String? actionType,
    String? targetTable,
    String? recordId,
    Value<String?> tenantId = const Value.absent(),
    DateTime? createdAtUtc,
    int? syncStatus,
  }) => PendingAuditAction(
    id: id ?? this.id,
    actionType: actionType ?? this.actionType,
    targetTable: targetTable ?? this.targetTable,
    recordId: recordId ?? this.recordId,
    tenantId: tenantId.present ? tenantId.value : this.tenantId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  PendingAuditAction copyWithCompanion(PendingAuditActionsCompanion data) {
    return PendingAuditAction(
      id: data.id.present ? data.id.value : this.id,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAuditAction(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('targetTable: $targetTable, ')
          ..write('recordId: $recordId, ')
          ..write('tenantId: $tenantId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    actionType,
    targetTable,
    recordId,
    tenantId,
    createdAtUtc,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAuditAction &&
          other.id == this.id &&
          other.actionType == this.actionType &&
          other.targetTable == this.targetTable &&
          other.recordId == this.recordId &&
          other.tenantId == this.tenantId &&
          other.createdAtUtc == this.createdAtUtc &&
          other.syncStatus == this.syncStatus);
}

class PendingAuditActionsCompanion extends UpdateCompanion<PendingAuditAction> {
  final Value<int> id;
  final Value<String> actionType;
  final Value<String> targetTable;
  final Value<String> recordId;
  final Value<String?> tenantId;
  final Value<DateTime> createdAtUtc;
  final Value<int> syncStatus;
  const PendingAuditActionsCompanion({
    this.id = const Value.absent(),
    this.actionType = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.recordId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  PendingAuditActionsCompanion.insert({
    this.id = const Value.absent(),
    required String actionType,
    required String targetTable,
    required String recordId,
    this.tenantId = const Value.absent(),
    required DateTime createdAtUtc,
    this.syncStatus = const Value.absent(),
  }) : actionType = Value(actionType),
       targetTable = Value(targetTable),
       recordId = Value(recordId),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<PendingAuditAction> custom({
    Expression<int>? id,
    Expression<String>? actionType,
    Expression<String>? targetTable,
    Expression<String>? recordId,
    Expression<String>? tenantId,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actionType != null) 'action_type': actionType,
      if (targetTable != null) 'table_name': targetTable,
      if (recordId != null) 'record_id': recordId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  PendingAuditActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? actionType,
    Value<String>? targetTable,
    Value<String>? recordId,
    Value<String?>? tenantId,
    Value<DateTime>? createdAtUtc,
    Value<int>? syncStatus,
  }) {
    return PendingAuditActionsCompanion(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      targetTable: targetTable ?? this.targetTable,
      recordId: recordId ?? this.recordId,
      tenantId: tenantId ?? this.tenantId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (targetTable.present) {
      map['table_name'] = Variable<String>(targetTable.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingAuditActionsCompanion(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('targetTable: $targetTable, ')
          ..write('recordId: $recordId, ')
          ..write('tenantId: $tenantId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $TaskChecklistsTable extends TaskChecklists
    with TableInfo<$TaskChecklistsTable, TaskChecklist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskChecklistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    taskId,
    templateId,
    localUpdatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_checklists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskChecklist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskChecklist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskChecklist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $TaskChecklistsTable createAlias(String alias) {
    return $TaskChecklistsTable(attachedDatabase, alias);
  }
}

class TaskChecklist extends DataClass implements Insertable<TaskChecklist> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String taskId;
  final String? templateId;
  final DateTime localUpdatedAt;
  final int syncStatus;
  const TaskChecklist({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    required this.taskId,
    this.templateId,
    required this.localUpdatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  TaskChecklistsCompanion toCompanion(bool nullToAbsent) {
    return TaskChecklistsCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      taskId: Value(taskId),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      localUpdatedAt: Value(localUpdatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory TaskChecklist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskChecklist(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'taskId': serializer.toJson<String>(taskId),
      'templateId': serializer.toJson<String?>(templateId),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  TaskChecklist copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    String? taskId,
    Value<String?> templateId = const Value.absent(),
    DateTime? localUpdatedAt,
    int? syncStatus,
  }) => TaskChecklist(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    taskId: taskId ?? this.taskId,
    templateId: templateId.present ? templateId.value : this.templateId,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  TaskChecklist copyWithCompanion(TaskChecklistsCompanion data) {
    return TaskChecklist(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskChecklist(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskId: $taskId, ')
          ..write('templateId: $templateId, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    taskId,
    templateId,
    localUpdatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskChecklist &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.taskId == this.taskId &&
          other.templateId == this.templateId &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.syncStatus == this.syncStatus);
}

class TaskChecklistsCompanion extends UpdateCompanion<TaskChecklist> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String> taskId;
  final Value<String?> templateId;
  final Value<DateTime> localUpdatedAt;
  final Value<int> syncStatus;
  const TaskChecklistsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  TaskChecklistsCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    required String taskId,
    this.templateId = const Value.absent(),
    required DateTime localUpdatedAt,
    this.syncStatus = const Value.absent(),
  }) : tenantId = Value(tenantId),
       taskId = Value(taskId),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<TaskChecklist> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? taskId,
    Expression<String>? templateId,
    Expression<DateTime>? localUpdatedAt,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (taskId != null) 'task_id': taskId,
      if (templateId != null) 'template_id': templateId,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  TaskChecklistsCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String>? taskId,
    Value<String?>? templateId,
    Value<DateTime>? localUpdatedAt,
    Value<int>? syncStatus,
  }) {
    return TaskChecklistsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      taskId: taskId ?? this.taskId,
      templateId: templateId ?? this.templateId,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskChecklistsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskId: $taskId, ')
          ..write('templateId: $templateId, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $TaskChecklistItemsTable extends TaskChecklistItems
    with TableInfo<$TaskChecklistItemsTable, TaskChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskChecklistIdMeta = const VerificationMeta(
    'taskChecklistId',
  );
  @override
  late final GeneratedColumn<String> taskChecklistId = GeneratedColumn<String>(
    'task_checklist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isPhotoRequiredMeta = const VerificationMeta(
    'isPhotoRequired',
  );
  @override
  late final GeneratedColumn<bool> isPhotoRequired = GeneratedColumn<bool>(
    'is_photo_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_photo_required" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedByMeta = const VerificationMeta(
    'completedBy',
  );
  @override
  late final GeneratedColumn<String> completedBy = GeneratedColumn<String>(
    'completed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPhotoPathMeta = const VerificationMeta(
    'localPhotoPath',
  );
  @override
  late final GeneratedColumn<String> localPhotoPath = GeneratedColumn<String>(
    'local_photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    taskChecklistId,
    title,
    isPhotoRequired,
    sortOrder,
    isCompleted,
    completedAt,
    completedBy,
    photoUrl,
    localPhotoPath,
    localUpdatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_checklist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskChecklistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('task_checklist_id')) {
      context.handle(
        _taskChecklistIdMeta,
        taskChecklistId.isAcceptableOrUnknown(
          data['task_checklist_id']!,
          _taskChecklistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taskChecklistIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('is_photo_required')) {
      context.handle(
        _isPhotoRequiredMeta,
        isPhotoRequired.isAcceptableOrUnknown(
          data['is_photo_required']!,
          _isPhotoRequiredMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_by')) {
      context.handle(
        _completedByMeta,
        completedBy.isAcceptableOrUnknown(
          data['completed_by']!,
          _completedByMeta,
        ),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('local_photo_path')) {
      context.handle(
        _localPhotoPathMeta,
        localPhotoPath.isAcceptableOrUnknown(
          data['local_photo_path']!,
          _localPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskChecklistItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      taskChecklistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_checklist_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isPhotoRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_photo_required'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      completedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_by'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      localPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_photo_path'],
      ),
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $TaskChecklistItemsTable createAlias(String alias) {
    return $TaskChecklistItemsTable(attachedDatabase, alias);
  }
}

class TaskChecklistItem extends DataClass
    implements Insertable<TaskChecklistItem> {
  final int id;
  final String? supabaseId;
  final String tenantId;
  final String taskChecklistId;
  final String title;
  final bool isPhotoRequired;
  final int sortOrder;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedBy;
  final String? photoUrl;

  /// Lokální cesta nebo demo řetězec (stub) – na Supabase neposíláme; server drží jen [photoUrl] z úložiště.
  ///
  /// PROČ: Worker v terénu může mít offline náhled / simulaci přiložení bez okamžitého uploadu.
  final String? localPhotoPath;
  final DateTime localUpdatedAt;
  final int syncStatus;
  const TaskChecklistItem({
    required this.id,
    this.supabaseId,
    required this.tenantId,
    required this.taskChecklistId,
    required this.title,
    required this.isPhotoRequired,
    required this.sortOrder,
    required this.isCompleted,
    this.completedAt,
    this.completedBy,
    this.photoUrl,
    this.localPhotoPath,
    required this.localUpdatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    map['tenant_id'] = Variable<String>(tenantId);
    map['task_checklist_id'] = Variable<String>(taskChecklistId);
    map['title'] = Variable<String>(title);
    map['is_photo_required'] = Variable<bool>(isPhotoRequired);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || completedBy != null) {
      map['completed_by'] = Variable<String>(completedBy);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    if (!nullToAbsent || localPhotoPath != null) {
      map['local_photo_path'] = Variable<String>(localPhotoPath);
    }
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  TaskChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return TaskChecklistItemsCompanion(
      id: Value(id),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      tenantId: Value(tenantId),
      taskChecklistId: Value(taskChecklistId),
      title: Value(title),
      isPhotoRequired: Value(isPhotoRequired),
      sortOrder: Value(sortOrder),
      isCompleted: Value(isCompleted),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      completedBy: completedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(completedBy),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      localPhotoPath: localPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPhotoPath),
      localUpdatedAt: Value(localUpdatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory TaskChecklistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskChecklistItem(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      taskChecklistId: serializer.fromJson<String>(json['taskChecklistId']),
      title: serializer.fromJson<String>(json['title']),
      isPhotoRequired: serializer.fromJson<bool>(json['isPhotoRequired']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      completedBy: serializer.fromJson<String?>(json['completedBy']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      localPhotoPath: serializer.fromJson<String?>(json['localPhotoPath']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'taskChecklistId': serializer.toJson<String>(taskChecklistId),
      'title': serializer.toJson<String>(title),
      'isPhotoRequired': serializer.toJson<bool>(isPhotoRequired),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'completedBy': serializer.toJson<String?>(completedBy),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'localPhotoPath': serializer.toJson<String?>(localPhotoPath),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  TaskChecklistItem copyWith({
    int? id,
    Value<String?> supabaseId = const Value.absent(),
    String? tenantId,
    String? taskChecklistId,
    String? title,
    bool? isPhotoRequired,
    int? sortOrder,
    bool? isCompleted,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> completedBy = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    Value<String?> localPhotoPath = const Value.absent(),
    DateTime? localUpdatedAt,
    int? syncStatus,
  }) => TaskChecklistItem(
    id: id ?? this.id,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    taskChecklistId: taskChecklistId ?? this.taskChecklistId,
    title: title ?? this.title,
    isPhotoRequired: isPhotoRequired ?? this.isPhotoRequired,
    sortOrder: sortOrder ?? this.sortOrder,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    completedBy: completedBy.present ? completedBy.value : this.completedBy,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    localPhotoPath: localPhotoPath.present
        ? localPhotoPath.value
        : this.localPhotoPath,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  TaskChecklistItem copyWithCompanion(TaskChecklistItemsCompanion data) {
    return TaskChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      taskChecklistId: data.taskChecklistId.present
          ? data.taskChecklistId.value
          : this.taskChecklistId,
      title: data.title.present ? data.title.value : this.title,
      isPhotoRequired: data.isPhotoRequired.present
          ? data.isPhotoRequired.value
          : this.isPhotoRequired,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completedBy: data.completedBy.present
          ? data.completedBy.value
          : this.completedBy,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      localPhotoPath: data.localPhotoPath.present
          ? data.localPhotoPath.value
          : this.localPhotoPath,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskChecklistItem(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskChecklistId: $taskChecklistId, ')
          ..write('title: $title, ')
          ..write('isPhotoRequired: $isPhotoRequired, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('localPhotoPath: $localPhotoPath, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    taskChecklistId,
    title,
    isPhotoRequired,
    sortOrder,
    isCompleted,
    completedAt,
    completedBy,
    photoUrl,
    localPhotoPath,
    localUpdatedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskChecklistItem &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.taskChecklistId == this.taskChecklistId &&
          other.title == this.title &&
          other.isPhotoRequired == this.isPhotoRequired &&
          other.sortOrder == this.sortOrder &&
          other.isCompleted == this.isCompleted &&
          other.completedAt == this.completedAt &&
          other.completedBy == this.completedBy &&
          other.photoUrl == this.photoUrl &&
          other.localPhotoPath == this.localPhotoPath &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.syncStatus == this.syncStatus);
}

class TaskChecklistItemsCompanion extends UpdateCompanion<TaskChecklistItem> {
  final Value<int> id;
  final Value<String?> supabaseId;
  final Value<String> tenantId;
  final Value<String> taskChecklistId;
  final Value<String> title;
  final Value<bool> isPhotoRequired;
  final Value<int> sortOrder;
  final Value<bool> isCompleted;
  final Value<DateTime?> completedAt;
  final Value<String?> completedBy;
  final Value<String?> photoUrl;
  final Value<String?> localPhotoPath;
  final Value<DateTime> localUpdatedAt;
  final Value<int> syncStatus;
  const TaskChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.taskChecklistId = const Value.absent(),
    this.title = const Value.absent(),
    this.isPhotoRequired = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.localPhotoPath = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  TaskChecklistItemsCompanion.insert({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    required String tenantId,
    required String taskChecklistId,
    this.title = const Value.absent(),
    this.isPhotoRequired = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.localPhotoPath = const Value.absent(),
    required DateTime localUpdatedAt,
    this.syncStatus = const Value.absent(),
  }) : tenantId = Value(tenantId),
       taskChecklistId = Value(taskChecklistId),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<TaskChecklistItem> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? taskChecklistId,
    Expression<String>? title,
    Expression<bool>? isPhotoRequired,
    Expression<int>? sortOrder,
    Expression<bool>? isCompleted,
    Expression<DateTime>? completedAt,
    Expression<String>? completedBy,
    Expression<String>? photoUrl,
    Expression<String>? localPhotoPath,
    Expression<DateTime>? localUpdatedAt,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (taskChecklistId != null) 'task_checklist_id': taskChecklistId,
      if (title != null) 'title': title,
      if (isPhotoRequired != null) 'is_photo_required': isPhotoRequired,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt,
      if (completedBy != null) 'completed_by': completedBy,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (localPhotoPath != null) 'local_photo_path': localPhotoPath,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  TaskChecklistItemsCompanion copyWith({
    Value<int>? id,
    Value<String?>? supabaseId,
    Value<String>? tenantId,
    Value<String>? taskChecklistId,
    Value<String>? title,
    Value<bool>? isPhotoRequired,
    Value<int>? sortOrder,
    Value<bool>? isCompleted,
    Value<DateTime?>? completedAt,
    Value<String?>? completedBy,
    Value<String?>? photoUrl,
    Value<String?>? localPhotoPath,
    Value<DateTime>? localUpdatedAt,
    Value<int>? syncStatus,
  }) {
    return TaskChecklistItemsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      taskChecklistId: taskChecklistId ?? this.taskChecklistId,
      title: title ?? this.title,
      isPhotoRequired: isPhotoRequired ?? this.isPhotoRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      photoUrl: photoUrl ?? this.photoUrl,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (taskChecklistId.present) {
      map['task_checklist_id'] = Variable<String>(taskChecklistId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isPhotoRequired.present) {
      map['is_photo_required'] = Variable<bool>(isPhotoRequired.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completedBy.present) {
      map['completed_by'] = Variable<String>(completedBy.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (localPhotoPath.present) {
      map['local_photo_path'] = Variable<String>(localPhotoPath.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskChecklistId: $taskChecklistId, ')
          ..write('title: $title, ')
          ..write('isPhotoRequired: $isPhotoRequired, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('localPhotoPath: $localPhotoPath, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $TaskPayoutsTable extends TaskPayouts
    with TableInfo<$TaskPayoutsTable, TaskPayout> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskPayoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    taskId,
    profileId,
    amount,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_payouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskPayout> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supabaseIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskPayout map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskPayout(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskPayoutsTable createAlias(String alias) {
    return $TaskPayoutsTable(attachedDatabase, alias);
  }
}

class TaskPayout extends DataClass implements Insertable<TaskPayout> {
  final int id;
  final String supabaseId;
  final String tenantId;
  final String taskId;
  final String profileId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TaskPayout({
    required this.id,
    required this.supabaseId,
    required this.tenantId,
    required this.taskId,
    required this.profileId,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supabase_id'] = Variable<String>(supabaseId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['task_id'] = Variable<String>(taskId);
    map['profile_id'] = Variable<String>(profileId);
    map['amount'] = Variable<double>(amount);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TaskPayoutsCompanion toCompanion(bool nullToAbsent) {
    return TaskPayoutsCompanion(
      id: Value(id),
      supabaseId: Value(supabaseId),
      tenantId: Value(tenantId),
      taskId: Value(taskId),
      profileId: Value(profileId),
      amount: Value(amount),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskPayout.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskPayout(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      amount: serializer.fromJson<double>(json['amount']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'taskId': serializer.toJson<String>(taskId),
      'profileId': serializer.toJson<String>(profileId),
      'amount': serializer.toJson<double>(amount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TaskPayout copyWith({
    int? id,
    String? supabaseId,
    String? tenantId,
    String? taskId,
    String? profileId,
    double? amount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaskPayout(
    id: id ?? this.id,
    supabaseId: supabaseId ?? this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    taskId: taskId ?? this.taskId,
    profileId: profileId ?? this.profileId,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskPayout copyWithCompanion(TaskPayoutsCompanion data) {
    return TaskPayout(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      amount: data.amount.present ? data.amount.value : this.amount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskPayout(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskId: $taskId, ')
          ..write('profileId: $profileId, ')
          ..write('amount: $amount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    taskId,
    profileId,
    amount,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskPayout &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.taskId == this.taskId &&
          other.profileId == this.profileId &&
          other.amount == this.amount &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskPayoutsCompanion extends UpdateCompanion<TaskPayout> {
  final Value<int> id;
  final Value<String> supabaseId;
  final Value<String> tenantId;
  final Value<String> taskId;
  final Value<String> profileId;
  final Value<double> amount;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TaskPayoutsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.amount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TaskPayoutsCompanion.insert({
    this.id = const Value.absent(),
    required String supabaseId,
    required String tenantId,
    required String taskId,
    required String profileId,
    required double amount,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : supabaseId = Value(supabaseId),
       tenantId = Value(tenantId),
       taskId = Value(taskId),
       profileId = Value(profileId),
       amount = Value(amount),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskPayout> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? taskId,
    Expression<String>? profileId,
    Expression<double>? amount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (taskId != null) 'task_id': taskId,
      if (profileId != null) 'profile_id': profileId,
      if (amount != null) 'amount': amount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TaskPayoutsCompanion copyWith({
    Value<int>? id,
    Value<String>? supabaseId,
    Value<String>? tenantId,
    Value<String>? taskId,
    Value<String>? profileId,
    Value<double>? amount,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TaskPayoutsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      taskId: taskId ?? this.taskId,
      profileId: profileId ?? this.profileId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskPayoutsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskId: $taskId, ')
          ..write('profileId: $profileId, ')
          ..write('amount: $amount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TaskCommissionsTable extends TaskCommissions
    with TableInfo<$TaskCommissionsTable, TaskCommission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskCommissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    taskId,
    profileId,
    clientId,
    amount,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_commissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskCommission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supabaseIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskCommission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskCommission(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskCommissionsTable createAlias(String alias) {
    return $TaskCommissionsTable(attachedDatabase, alias);
  }
}

class TaskCommission extends DataClass implements Insertable<TaskCommission> {
  final int id;
  final String supabaseId;
  final String tenantId;
  final String taskId;
  final String? profileId;
  final String? clientId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TaskCommission({
    required this.id,
    required this.supabaseId,
    required this.tenantId,
    required this.taskId,
    this.profileId,
    this.clientId,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supabase_id'] = Variable<String>(supabaseId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<String>(clientId);
    }
    map['amount'] = Variable<double>(amount);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TaskCommissionsCompanion toCompanion(bool nullToAbsent) {
    return TaskCommissionsCompanion(
      id: Value(id),
      supabaseId: Value(supabaseId),
      tenantId: Value(tenantId),
      taskId: Value(taskId),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      clientId: clientId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientId),
      amount: Value(amount),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskCommission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskCommission(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      clientId: serializer.fromJson<String?>(json['clientId']),
      amount: serializer.fromJson<double>(json['amount']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'taskId': serializer.toJson<String>(taskId),
      'profileId': serializer.toJson<String?>(profileId),
      'clientId': serializer.toJson<String?>(clientId),
      'amount': serializer.toJson<double>(amount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TaskCommission copyWith({
    int? id,
    String? supabaseId,
    String? tenantId,
    String? taskId,
    Value<String?> profileId = const Value.absent(),
    Value<String?> clientId = const Value.absent(),
    double? amount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaskCommission(
    id: id ?? this.id,
    supabaseId: supabaseId ?? this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    taskId: taskId ?? this.taskId,
    profileId: profileId.present ? profileId.value : this.profileId,
    clientId: clientId.present ? clientId.value : this.clientId,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskCommission copyWithCompanion(TaskCommissionsCompanion data) {
    return TaskCommission(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      amount: data.amount.present ? data.amount.value : this.amount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskCommission(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskId: $taskId, ')
          ..write('profileId: $profileId, ')
          ..write('clientId: $clientId, ')
          ..write('amount: $amount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    taskId,
    profileId,
    clientId,
    amount,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskCommission &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.taskId == this.taskId &&
          other.profileId == this.profileId &&
          other.clientId == this.clientId &&
          other.amount == this.amount &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskCommissionsCompanion extends UpdateCompanion<TaskCommission> {
  final Value<int> id;
  final Value<String> supabaseId;
  final Value<String> tenantId;
  final Value<String> taskId;
  final Value<String?> profileId;
  final Value<String?> clientId;
  final Value<double> amount;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TaskCommissionsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.amount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TaskCommissionsCompanion.insert({
    this.id = const Value.absent(),
    required String supabaseId,
    required String tenantId,
    required String taskId,
    this.profileId = const Value.absent(),
    this.clientId = const Value.absent(),
    required double amount,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : supabaseId = Value(supabaseId),
       tenantId = Value(tenantId),
       taskId = Value(taskId),
       amount = Value(amount),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskCommission> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? taskId,
    Expression<String>? profileId,
    Expression<String>? clientId,
    Expression<double>? amount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (taskId != null) 'task_id': taskId,
      if (profileId != null) 'profile_id': profileId,
      if (clientId != null) 'client_id': clientId,
      if (amount != null) 'amount': amount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TaskCommissionsCompanion copyWith({
    Value<int>? id,
    Value<String>? supabaseId,
    Value<String>? tenantId,
    Value<String>? taskId,
    Value<String?>? profileId,
    Value<String?>? clientId,
    Value<double>? amount,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TaskCommissionsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      taskId: taskId ?? this.taskId,
      profileId: profileId ?? this.profileId,
      clientId: clientId ?? this.clientId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskCommissionsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('taskId: $taskId, ')
          ..write('profileId: $profileId, ')
          ..write('clientId: $clientId, ')
          ..write('amount: $amount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $StaffAbsencesTable extends StaffAbsences
    with TableInfo<$StaffAbsencesTable, DriftStaffAbsence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StaffAbsencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invitationIdMeta = const VerificationMeta(
    'invitationId',
  );
  @override
  late final GeneratedColumn<String> invitationId = GeneratedColumn<String>(
    'invitation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    profileId,
    invitationId,
    startDate,
    endDate,
    reason,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'staff_absences';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftStaffAbsence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supabaseIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('invitation_id')) {
      context.handle(
        _invitationIdMeta,
        invitationId.isAcceptableOrUnknown(
          data['invitation_id']!,
          _invitationIdMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftStaffAbsence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftStaffAbsence(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      invitationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invitation_id'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StaffAbsencesTable createAlias(String alias) {
    return $StaffAbsencesTable(attachedDatabase, alias);
  }
}

class DriftStaffAbsence extends DataClass
    implements Insertable<DriftStaffAbsence> {
  final int id;
  final String supabaseId;
  final String tenantId;
  final String profileId;
  final String? invitationId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DriftStaffAbsence({
    required this.id,
    required this.supabaseId,
    required this.tenantId,
    required this.profileId,
    this.invitationId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supabase_id'] = Variable<String>(supabaseId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || invitationId != null) {
      map['invitation_id'] = Variable<String>(invitationId);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['reason'] = Variable<String>(reason);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StaffAbsencesCompanion toCompanion(bool nullToAbsent) {
    return StaffAbsencesCompanion(
      id: Value(id),
      supabaseId: Value(supabaseId),
      tenantId: Value(tenantId),
      profileId: Value(profileId),
      invitationId: invitationId == null && nullToAbsent
          ? const Value.absent()
          : Value(invitationId),
      startDate: Value(startDate),
      endDate: Value(endDate),
      reason: Value(reason),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DriftStaffAbsence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftStaffAbsence(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      invitationId: serializer.fromJson<String?>(json['invitationId']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      reason: serializer.fromJson<String>(json['reason']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'profileId': serializer.toJson<String>(profileId),
      'invitationId': serializer.toJson<String?>(invitationId),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'reason': serializer.toJson<String>(reason),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DriftStaffAbsence copyWith({
    int? id,
    String? supabaseId,
    String? tenantId,
    String? profileId,
    Value<String?> invitationId = const Value.absent(),
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DriftStaffAbsence(
    id: id ?? this.id,
    supabaseId: supabaseId ?? this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    profileId: profileId ?? this.profileId,
    invitationId: invitationId.present ? invitationId.value : this.invitationId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    reason: reason ?? this.reason,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DriftStaffAbsence copyWithCompanion(StaffAbsencesCompanion data) {
    return DriftStaffAbsence(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      invitationId: data.invitationId.present
          ? data.invitationId.value
          : this.invitationId,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      reason: data.reason.present ? data.reason.value : this.reason,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftStaffAbsence(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('profileId: $profileId, ')
          ..write('invitationId: $invitationId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('reason: $reason, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    profileId,
    invitationId,
    startDate,
    endDate,
    reason,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftStaffAbsence &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.profileId == this.profileId &&
          other.invitationId == this.invitationId &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.reason == this.reason &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StaffAbsencesCompanion extends UpdateCompanion<DriftStaffAbsence> {
  final Value<int> id;
  final Value<String> supabaseId;
  final Value<String> tenantId;
  final Value<String> profileId;
  final Value<String?> invitationId;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<String> reason;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const StaffAbsencesCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.invitationId = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.reason = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StaffAbsencesCompanion.insert({
    this.id = const Value.absent(),
    required String supabaseId,
    required String tenantId,
    required String profileId,
    this.invitationId = const Value.absent(),
    required DateTime startDate,
    required DateTime endDate,
    this.reason = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : supabaseId = Value(supabaseId),
       tenantId = Value(tenantId),
       profileId = Value(profileId),
       startDate = Value(startDate),
       endDate = Value(endDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DriftStaffAbsence> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? profileId,
    Expression<String>? invitationId,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? reason,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (profileId != null) 'profile_id': profileId,
      if (invitationId != null) 'invitation_id': invitationId,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (reason != null) 'reason': reason,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StaffAbsencesCompanion copyWith({
    Value<int>? id,
    Value<String>? supabaseId,
    Value<String>? tenantId,
    Value<String>? profileId,
    Value<String?>? invitationId,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<String>? reason,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return StaffAbsencesCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      profileId: profileId ?? this.profileId,
      invitationId: invitationId ?? this.invitationId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (invitationId.present) {
      map['invitation_id'] = Variable<String>(invitationId.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StaffAbsencesCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('profileId: $profileId, ')
          ..write('invitationId: $invitationId, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('reason: $reason, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EmployeeCashWalletsTable extends EmployeeCashWallets
    with TableInfo<$EmployeeCashWalletsTable, DriftEmployeeCashWallet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeeCashWalletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceMeta = const VerificationMeta(
    'balance',
  );
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
    'balance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    profileId,
    balance,
    currencyCode,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employee_cash_wallets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftEmployeeCashWallet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supabaseIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(
        _balanceMeta,
        balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta),
      );
    } else if (isInserting) {
      context.missing(_balanceMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftEmployeeCashWallet map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftEmployeeCashWallet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      balance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}balance'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EmployeeCashWalletsTable createAlias(String alias) {
    return $EmployeeCashWalletsTable(attachedDatabase, alias);
  }
}

class DriftEmployeeCashWallet extends DataClass
    implements Insertable<DriftEmployeeCashWallet> {
  final int id;
  final String supabaseId;
  final String tenantId;
  final String profileId;
  final double balance;

  /// ISO měna z lokálního [Tenants.currency] (např. CZK) – v PostgreSQL u peněženky není.
  final String? currencyCode;
  final DateTime updatedAt;
  const DriftEmployeeCashWallet({
    required this.id,
    required this.supabaseId,
    required this.tenantId,
    required this.profileId,
    required this.balance,
    this.currencyCode,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supabase_id'] = Variable<String>(supabaseId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['profile_id'] = Variable<String>(profileId);
    map['balance'] = Variable<double>(balance);
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EmployeeCashWalletsCompanion toCompanion(bool nullToAbsent) {
    return EmployeeCashWalletsCompanion(
      id: Value(id),
      supabaseId: Value(supabaseId),
      tenantId: Value(tenantId),
      profileId: Value(profileId),
      balance: Value(balance),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      updatedAt: Value(updatedAt),
    );
  }

  factory DriftEmployeeCashWallet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftEmployeeCashWallet(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      balance: serializer.fromJson<double>(json['balance']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'profileId': serializer.toJson<String>(profileId),
      'balance': serializer.toJson<double>(balance),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DriftEmployeeCashWallet copyWith({
    int? id,
    String? supabaseId,
    String? tenantId,
    String? profileId,
    double? balance,
    Value<String?> currencyCode = const Value.absent(),
    DateTime? updatedAt,
  }) => DriftEmployeeCashWallet(
    id: id ?? this.id,
    supabaseId: supabaseId ?? this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    profileId: profileId ?? this.profileId,
    balance: balance ?? this.balance,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DriftEmployeeCashWallet copyWithCompanion(EmployeeCashWalletsCompanion data) {
    return DriftEmployeeCashWallet(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      balance: data.balance.present ? data.balance.value : this.balance,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftEmployeeCashWallet(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('profileId: $profileId, ')
          ..write('balance: $balance, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    profileId,
    balance,
    currencyCode,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftEmployeeCashWallet &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.profileId == this.profileId &&
          other.balance == this.balance &&
          other.currencyCode == this.currencyCode &&
          other.updatedAt == this.updatedAt);
}

class EmployeeCashWalletsCompanion
    extends UpdateCompanion<DriftEmployeeCashWallet> {
  final Value<int> id;
  final Value<String> supabaseId;
  final Value<String> tenantId;
  final Value<String> profileId;
  final Value<double> balance;
  final Value<String?> currencyCode;
  final Value<DateTime> updatedAt;
  const EmployeeCashWalletsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.balance = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EmployeeCashWalletsCompanion.insert({
    this.id = const Value.absent(),
    required String supabaseId,
    required String tenantId,
    required String profileId,
    required double balance,
    this.currencyCode = const Value.absent(),
    required DateTime updatedAt,
  }) : supabaseId = Value(supabaseId),
       tenantId = Value(tenantId),
       profileId = Value(profileId),
       balance = Value(balance),
       updatedAt = Value(updatedAt);
  static Insertable<DriftEmployeeCashWallet> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? profileId,
    Expression<double>? balance,
    Expression<String>? currencyCode,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (profileId != null) 'profile_id': profileId,
      if (balance != null) 'balance': balance,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EmployeeCashWalletsCompanion copyWith({
    Value<int>? id,
    Value<String>? supabaseId,
    Value<String>? tenantId,
    Value<String>? profileId,
    Value<double>? balance,
    Value<String?>? currencyCode,
    Value<DateTime>? updatedAt,
  }) {
    return EmployeeCashWalletsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      profileId: profileId ?? this.profileId,
      balance: balance ?? this.balance,
      currencyCode: currencyCode ?? this.currencyCode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeCashWalletsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('profileId: $profileId, ')
          ..write('balance: $balance, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EmployeeCashTransactionsTable extends EmployeeCashTransactions
    with
        TableInfo<
          $EmployeeCashTransactionsTable,
          DriftEmployeeCashTransaction
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeeCashTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletIdMeta = const VerificationMeta(
    'walletId',
  );
  @override
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionTypeMeta = const VerificationMeta(
    'transactionType',
  );
  @override
  late final GeneratedColumn<String> transactionType = GeneratedColumn<String>(
    'transaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptImageUrlMeta = const VerificationMeta(
    'receiptImageUrl',
  );
  @override
  late final GeneratedColumn<String> receiptImageUrl = GeneratedColumn<String>(
    'receipt_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedAmountMeta = const VerificationMeta(
    'expectedAmount',
  );
  @override
  late final GeneratedColumn<double> expectedAmount = GeneratedColumn<double>(
    'expected_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apartmentIdMeta = const VerificationMeta(
    'apartmentId',
  );
  @override
  late final GeneratedColumn<String> apartmentId = GeneratedColumn<String>(
    'apartment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isShortfallResolvedMeta =
      const VerificationMeta('isShortfallResolved');
  @override
  late final GeneratedColumn<bool> isShortfallResolved = GeneratedColumn<bool>(
    'is_shortfall_resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shortfall_resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _shortfallResolutionTypeMeta =
      const VerificationMeta('shortfallResolutionType');
  @override
  late final GeneratedColumn<String> shortfallResolutionType =
      GeneratedColumn<String>(
        'shortfall_resolution_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shortfallResolutionNoteMeta =
      const VerificationMeta('shortfallResolutionNote');
  @override
  late final GeneratedColumn<String> shortfallResolutionNote =
      GeneratedColumn<String>(
        'shortfall_resolution_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supabaseId,
    tenantId,
    walletId,
    profileId,
    amount,
    transactionType,
    note,
    createdAt,
    taskId,
    createdBy,
    receiptImageUrl,
    expectedAmount,
    apartmentId,
    clientId,
    isShortfallResolved,
    shortfallResolutionType,
    shortfallResolutionNote,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employee_cash_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftEmployeeCashTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supabaseIdMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('wallet_id')) {
      context.handle(
        _walletIdMeta,
        walletId.isAcceptableOrUnknown(data['wallet_id']!, _walletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_walletIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('transaction_type')) {
      context.handle(
        _transactionTypeMeta,
        transactionType.isAcceptableOrUnknown(
          data['transaction_type']!,
          _transactionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionTypeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('receipt_image_url')) {
      context.handle(
        _receiptImageUrlMeta,
        receiptImageUrl.isAcceptableOrUnknown(
          data['receipt_image_url']!,
          _receiptImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('expected_amount')) {
      context.handle(
        _expectedAmountMeta,
        expectedAmount.isAcceptableOrUnknown(
          data['expected_amount']!,
          _expectedAmountMeta,
        ),
      );
    }
    if (data.containsKey('apartment_id')) {
      context.handle(
        _apartmentIdMeta,
        apartmentId.isAcceptableOrUnknown(
          data['apartment_id']!,
          _apartmentIdMeta,
        ),
      );
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    }
    if (data.containsKey('is_shortfall_resolved')) {
      context.handle(
        _isShortfallResolvedMeta,
        isShortfallResolved.isAcceptableOrUnknown(
          data['is_shortfall_resolved']!,
          _isShortfallResolvedMeta,
        ),
      );
    }
    if (data.containsKey('shortfall_resolution_type')) {
      context.handle(
        _shortfallResolutionTypeMeta,
        shortfallResolutionType.isAcceptableOrUnknown(
          data['shortfall_resolution_type']!,
          _shortfallResolutionTypeMeta,
        ),
      );
    }
    if (data.containsKey('shortfall_resolution_note')) {
      context.handle(
        _shortfallResolutionNoteMeta,
        shortfallResolutionNote.isAcceptableOrUnknown(
          data['shortfall_resolution_note']!,
          _shortfallResolutionNoteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftEmployeeCashTransaction map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftEmployeeCashTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      walletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      transactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_type'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      receiptImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_image_url'],
      ),
      expectedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}expected_amount'],
      ),
      apartmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}apartment_id'],
      ),
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      ),
      isShortfallResolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shortfall_resolved'],
      )!,
      shortfallResolutionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shortfall_resolution_type'],
      ),
      shortfallResolutionNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shortfall_resolution_note'],
      ),
    );
  }

  @override
  $EmployeeCashTransactionsTable createAlias(String alias) {
    return $EmployeeCashTransactionsTable(attachedDatabase, alias);
  }
}

class DriftEmployeeCashTransaction extends DataClass
    implements Insertable<DriftEmployeeCashTransaction> {
  final int id;
  final String supabaseId;
  final String tenantId;
  final String walletId;
  final String profileId;
  final double amount;
  final String transactionType;

  /// Odpovídá `note` na serveru (popis / poznámka k výdaji).
  final String? note;
  final DateTime createdAt;
  final String? taskId;
  final String? createdBy;
  final String? receiptImageUrl;
  final double? expectedAmount;
  final String? apartmentId;
  final String? clientId;
  final bool isShortfallResolved;
  final String? shortfallResolutionType;
  final String? shortfallResolutionNote;
  const DriftEmployeeCashTransaction({
    required this.id,
    required this.supabaseId,
    required this.tenantId,
    required this.walletId,
    required this.profileId,
    required this.amount,
    required this.transactionType,
    this.note,
    required this.createdAt,
    this.taskId,
    this.createdBy,
    this.receiptImageUrl,
    this.expectedAmount,
    this.apartmentId,
    this.clientId,
    required this.isShortfallResolved,
    this.shortfallResolutionType,
    this.shortfallResolutionNote,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supabase_id'] = Variable<String>(supabaseId);
    map['tenant_id'] = Variable<String>(tenantId);
    map['wallet_id'] = Variable<String>(walletId);
    map['profile_id'] = Variable<String>(profileId);
    map['amount'] = Variable<double>(amount);
    map['transaction_type'] = Variable<String>(transactionType);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || receiptImageUrl != null) {
      map['receipt_image_url'] = Variable<String>(receiptImageUrl);
    }
    if (!nullToAbsent || expectedAmount != null) {
      map['expected_amount'] = Variable<double>(expectedAmount);
    }
    if (!nullToAbsent || apartmentId != null) {
      map['apartment_id'] = Variable<String>(apartmentId);
    }
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<String>(clientId);
    }
    map['is_shortfall_resolved'] = Variable<bool>(isShortfallResolved);
    if (!nullToAbsent || shortfallResolutionType != null) {
      map['shortfall_resolution_type'] = Variable<String>(
        shortfallResolutionType,
      );
    }
    if (!nullToAbsent || shortfallResolutionNote != null) {
      map['shortfall_resolution_note'] = Variable<String>(
        shortfallResolutionNote,
      );
    }
    return map;
  }

  EmployeeCashTransactionsCompanion toCompanion(bool nullToAbsent) {
    return EmployeeCashTransactionsCompanion(
      id: Value(id),
      supabaseId: Value(supabaseId),
      tenantId: Value(tenantId),
      walletId: Value(walletId),
      profileId: Value(profileId),
      amount: Value(amount),
      transactionType: Value(transactionType),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      receiptImageUrl: receiptImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptImageUrl),
      expectedAmount: expectedAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedAmount),
      apartmentId: apartmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(apartmentId),
      clientId: clientId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientId),
      isShortfallResolved: Value(isShortfallResolved),
      shortfallResolutionType: shortfallResolutionType == null && nullToAbsent
          ? const Value.absent()
          : Value(shortfallResolutionType),
      shortfallResolutionNote: shortfallResolutionNote == null && nullToAbsent
          ? const Value.absent()
          : Value(shortfallResolutionNote),
    );
  }

  factory DriftEmployeeCashTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftEmployeeCashTransaction(
      id: serializer.fromJson<int>(json['id']),
      supabaseId: serializer.fromJson<String>(json['supabaseId']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      walletId: serializer.fromJson<String>(json['walletId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      amount: serializer.fromJson<double>(json['amount']),
      transactionType: serializer.fromJson<String>(json['transactionType']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      receiptImageUrl: serializer.fromJson<String?>(json['receiptImageUrl']),
      expectedAmount: serializer.fromJson<double?>(json['expectedAmount']),
      apartmentId: serializer.fromJson<String?>(json['apartmentId']),
      clientId: serializer.fromJson<String?>(json['clientId']),
      isShortfallResolved: serializer.fromJson<bool>(
        json['isShortfallResolved'],
      ),
      shortfallResolutionType: serializer.fromJson<String?>(
        json['shortfallResolutionType'],
      ),
      shortfallResolutionNote: serializer.fromJson<String?>(
        json['shortfallResolutionNote'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supabaseId': serializer.toJson<String>(supabaseId),
      'tenantId': serializer.toJson<String>(tenantId),
      'walletId': serializer.toJson<String>(walletId),
      'profileId': serializer.toJson<String>(profileId),
      'amount': serializer.toJson<double>(amount),
      'transactionType': serializer.toJson<String>(transactionType),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'taskId': serializer.toJson<String?>(taskId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'receiptImageUrl': serializer.toJson<String?>(receiptImageUrl),
      'expectedAmount': serializer.toJson<double?>(expectedAmount),
      'apartmentId': serializer.toJson<String?>(apartmentId),
      'clientId': serializer.toJson<String?>(clientId),
      'isShortfallResolved': serializer.toJson<bool>(isShortfallResolved),
      'shortfallResolutionType': serializer.toJson<String?>(
        shortfallResolutionType,
      ),
      'shortfallResolutionNote': serializer.toJson<String?>(
        shortfallResolutionNote,
      ),
    };
  }

  DriftEmployeeCashTransaction copyWith({
    int? id,
    String? supabaseId,
    String? tenantId,
    String? walletId,
    String? profileId,
    double? amount,
    String? transactionType,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    Value<String?> taskId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> receiptImageUrl = const Value.absent(),
    Value<double?> expectedAmount = const Value.absent(),
    Value<String?> apartmentId = const Value.absent(),
    Value<String?> clientId = const Value.absent(),
    bool? isShortfallResolved,
    Value<String?> shortfallResolutionType = const Value.absent(),
    Value<String?> shortfallResolutionNote = const Value.absent(),
  }) => DriftEmployeeCashTransaction(
    id: id ?? this.id,
    supabaseId: supabaseId ?? this.supabaseId,
    tenantId: tenantId ?? this.tenantId,
    walletId: walletId ?? this.walletId,
    profileId: profileId ?? this.profileId,
    amount: amount ?? this.amount,
    transactionType: transactionType ?? this.transactionType,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    taskId: taskId.present ? taskId.value : this.taskId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    receiptImageUrl: receiptImageUrl.present
        ? receiptImageUrl.value
        : this.receiptImageUrl,
    expectedAmount: expectedAmount.present
        ? expectedAmount.value
        : this.expectedAmount,
    apartmentId: apartmentId.present ? apartmentId.value : this.apartmentId,
    clientId: clientId.present ? clientId.value : this.clientId,
    isShortfallResolved: isShortfallResolved ?? this.isShortfallResolved,
    shortfallResolutionType: shortfallResolutionType.present
        ? shortfallResolutionType.value
        : this.shortfallResolutionType,
    shortfallResolutionNote: shortfallResolutionNote.present
        ? shortfallResolutionNote.value
        : this.shortfallResolutionNote,
  );
  DriftEmployeeCashTransaction copyWithCompanion(
    EmployeeCashTransactionsCompanion data,
  ) {
    return DriftEmployeeCashTransaction(
      id: data.id.present ? data.id.value : this.id,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      amount: data.amount.present ? data.amount.value : this.amount,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      receiptImageUrl: data.receiptImageUrl.present
          ? data.receiptImageUrl.value
          : this.receiptImageUrl,
      expectedAmount: data.expectedAmount.present
          ? data.expectedAmount.value
          : this.expectedAmount,
      apartmentId: data.apartmentId.present
          ? data.apartmentId.value
          : this.apartmentId,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      isShortfallResolved: data.isShortfallResolved.present
          ? data.isShortfallResolved.value
          : this.isShortfallResolved,
      shortfallResolutionType: data.shortfallResolutionType.present
          ? data.shortfallResolutionType.value
          : this.shortfallResolutionType,
      shortfallResolutionNote: data.shortfallResolutionNote.present
          ? data.shortfallResolutionNote.value
          : this.shortfallResolutionNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftEmployeeCashTransaction(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('walletId: $walletId, ')
          ..write('profileId: $profileId, ')
          ..write('amount: $amount, ')
          ..write('transactionType: $transactionType, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('taskId: $taskId, ')
          ..write('createdBy: $createdBy, ')
          ..write('receiptImageUrl: $receiptImageUrl, ')
          ..write('expectedAmount: $expectedAmount, ')
          ..write('apartmentId: $apartmentId, ')
          ..write('clientId: $clientId, ')
          ..write('isShortfallResolved: $isShortfallResolved, ')
          ..write('shortfallResolutionType: $shortfallResolutionType, ')
          ..write('shortfallResolutionNote: $shortfallResolutionNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    walletId,
    profileId,
    amount,
    transactionType,
    note,
    createdAt,
    taskId,
    createdBy,
    receiptImageUrl,
    expectedAmount,
    apartmentId,
    clientId,
    isShortfallResolved,
    shortfallResolutionType,
    shortfallResolutionNote,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftEmployeeCashTransaction &&
          other.id == this.id &&
          other.supabaseId == this.supabaseId &&
          other.tenantId == this.tenantId &&
          other.walletId == this.walletId &&
          other.profileId == this.profileId &&
          other.amount == this.amount &&
          other.transactionType == this.transactionType &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.taskId == this.taskId &&
          other.createdBy == this.createdBy &&
          other.receiptImageUrl == this.receiptImageUrl &&
          other.expectedAmount == this.expectedAmount &&
          other.apartmentId == this.apartmentId &&
          other.clientId == this.clientId &&
          other.isShortfallResolved == this.isShortfallResolved &&
          other.shortfallResolutionType == this.shortfallResolutionType &&
          other.shortfallResolutionNote == this.shortfallResolutionNote);
}

class EmployeeCashTransactionsCompanion
    extends UpdateCompanion<DriftEmployeeCashTransaction> {
  final Value<int> id;
  final Value<String> supabaseId;
  final Value<String> tenantId;
  final Value<String> walletId;
  final Value<String> profileId;
  final Value<double> amount;
  final Value<String> transactionType;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<String?> taskId;
  final Value<String?> createdBy;
  final Value<String?> receiptImageUrl;
  final Value<double?> expectedAmount;
  final Value<String?> apartmentId;
  final Value<String?> clientId;
  final Value<bool> isShortfallResolved;
  final Value<String?> shortfallResolutionType;
  final Value<String?> shortfallResolutionNote;
  const EmployeeCashTransactionsCompanion({
    this.id = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.walletId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.amount = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.taskId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.receiptImageUrl = const Value.absent(),
    this.expectedAmount = const Value.absent(),
    this.apartmentId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.isShortfallResolved = const Value.absent(),
    this.shortfallResolutionType = const Value.absent(),
    this.shortfallResolutionNote = const Value.absent(),
  });
  EmployeeCashTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String supabaseId,
    required String tenantId,
    required String walletId,
    required String profileId,
    required double amount,
    required String transactionType,
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.taskId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.receiptImageUrl = const Value.absent(),
    this.expectedAmount = const Value.absent(),
    this.apartmentId = const Value.absent(),
    this.clientId = const Value.absent(),
    this.isShortfallResolved = const Value.absent(),
    this.shortfallResolutionType = const Value.absent(),
    this.shortfallResolutionNote = const Value.absent(),
  }) : supabaseId = Value(supabaseId),
       tenantId = Value(tenantId),
       walletId = Value(walletId),
       profileId = Value(profileId),
       amount = Value(amount),
       transactionType = Value(transactionType),
       createdAt = Value(createdAt);
  static Insertable<DriftEmployeeCashTransaction> custom({
    Expression<int>? id,
    Expression<String>? supabaseId,
    Expression<String>? tenantId,
    Expression<String>? walletId,
    Expression<String>? profileId,
    Expression<double>? amount,
    Expression<String>? transactionType,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<String>? taskId,
    Expression<String>? createdBy,
    Expression<String>? receiptImageUrl,
    Expression<double>? expectedAmount,
    Expression<String>? apartmentId,
    Expression<String>? clientId,
    Expression<bool>? isShortfallResolved,
    Expression<String>? shortfallResolutionType,
    Expression<String>? shortfallResolutionNote,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (tenantId != null) 'tenant_id': tenantId,
      if (walletId != null) 'wallet_id': walletId,
      if (profileId != null) 'profile_id': profileId,
      if (amount != null) 'amount': amount,
      if (transactionType != null) 'transaction_type': transactionType,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (taskId != null) 'task_id': taskId,
      if (createdBy != null) 'created_by': createdBy,
      if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
      if (expectedAmount != null) 'expected_amount': expectedAmount,
      if (apartmentId != null) 'apartment_id': apartmentId,
      if (clientId != null) 'client_id': clientId,
      if (isShortfallResolved != null)
        'is_shortfall_resolved': isShortfallResolved,
      if (shortfallResolutionType != null)
        'shortfall_resolution_type': shortfallResolutionType,
      if (shortfallResolutionNote != null)
        'shortfall_resolution_note': shortfallResolutionNote,
    });
  }

  EmployeeCashTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? supabaseId,
    Value<String>? tenantId,
    Value<String>? walletId,
    Value<String>? profileId,
    Value<double>? amount,
    Value<String>? transactionType,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<String?>? taskId,
    Value<String?>? createdBy,
    Value<String?>? receiptImageUrl,
    Value<double?>? expectedAmount,
    Value<String?>? apartmentId,
    Value<String?>? clientId,
    Value<bool>? isShortfallResolved,
    Value<String?>? shortfallResolutionType,
    Value<String?>? shortfallResolutionNote,
  }) {
    return EmployeeCashTransactionsCompanion(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      tenantId: tenantId ?? this.tenantId,
      walletId: walletId ?? this.walletId,
      profileId: profileId ?? this.profileId,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      taskId: taskId ?? this.taskId,
      createdBy: createdBy ?? this.createdBy,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      apartmentId: apartmentId ?? this.apartmentId,
      clientId: clientId ?? this.clientId,
      isShortfallResolved: isShortfallResolved ?? this.isShortfallResolved,
      shortfallResolutionType:
          shortfallResolutionType ?? this.shortfallResolutionType,
      shortfallResolutionNote:
          shortfallResolutionNote ?? this.shortfallResolutionNote,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (transactionType.present) {
      map['transaction_type'] = Variable<String>(transactionType.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (receiptImageUrl.present) {
      map['receipt_image_url'] = Variable<String>(receiptImageUrl.value);
    }
    if (expectedAmount.present) {
      map['expected_amount'] = Variable<double>(expectedAmount.value);
    }
    if (apartmentId.present) {
      map['apartment_id'] = Variable<String>(apartmentId.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (isShortfallResolved.present) {
      map['is_shortfall_resolved'] = Variable<bool>(isShortfallResolved.value);
    }
    if (shortfallResolutionType.present) {
      map['shortfall_resolution_type'] = Variable<String>(
        shortfallResolutionType.value,
      );
    }
    if (shortfallResolutionNote.present) {
      map['shortfall_resolution_note'] = Variable<String>(
        shortfallResolutionNote.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeCashTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('tenantId: $tenantId, ')
          ..write('walletId: $walletId, ')
          ..write('profileId: $profileId, ')
          ..write('amount: $amount, ')
          ..write('transactionType: $transactionType, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('taskId: $taskId, ')
          ..write('createdBy: $createdBy, ')
          ..write('receiptImageUrl: $receiptImageUrl, ')
          ..write('expectedAmount: $expectedAmount, ')
          ..write('apartmentId: $apartmentId, ')
          ..write('clientId: $clientId, ')
          ..write('isShortfallResolved: $isShortfallResolved, ')
          ..write('shortfallResolutionType: $shortfallResolutionType, ')
          ..write('shortfallResolutionNote: $shortfallResolutionNote')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesCacheTable extends UserProfilesCache
    with TableInfo<$UserProfilesCacheTable, DriftUserProfileCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileDisplayNameMeta =
      const VerificationMeta('profileDisplayName');
  @override
  late final GeneratedColumn<String> profileDisplayName =
      GeneratedColumn<String>(
        'profile_display_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    firstName,
    lastName,
    profileDisplayName,
    email,
    avatarUrl,
    role,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftUserProfileCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    }
    if (data.containsKey('profile_display_name')) {
      context.handle(
        _profileDisplayNameMeta,
        profileDisplayName.isAcceptableOrUnknown(
          data['profile_display_name']!,
          _profileDisplayNameMeta,
        ),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftUserProfileCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftUserProfileCache(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      ),
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      ),
      profileDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_display_name'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProfilesCacheTable createAlias(String alias) {
    return $UserProfilesCacheTable(attachedDatabase, alias);
  }
}

class DriftUserProfileCache extends DataClass
    implements Insertable<DriftUserProfileCache> {
  final String id;
  final String tenantId;
  final String? firstName;
  final String? lastName;

  /// Hodnota sloupce `name` v `profiles` (zobrazení, když chybí křestní/příjmení).
  final String? profileDisplayName;
  final String? email;
  final String? avatarUrl;
  final String role;
  final DateTime updatedAt;
  const DriftUserProfileCache({
    required this.id,
    required this.tenantId,
    this.firstName,
    this.lastName,
    this.profileDisplayName,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || firstName != null) {
      map['first_name'] = Variable<String>(firstName);
    }
    if (!nullToAbsent || lastName != null) {
      map['last_name'] = Variable<String>(lastName);
    }
    if (!nullToAbsent || profileDisplayName != null) {
      map['profile_display_name'] = Variable<String>(profileDisplayName);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['role'] = Variable<String>(role);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfilesCacheCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCacheCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      firstName: firstName == null && nullToAbsent
          ? const Value.absent()
          : Value(firstName),
      lastName: lastName == null && nullToAbsent
          ? const Value.absent()
          : Value(lastName),
      profileDisplayName: profileDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(profileDisplayName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      role: Value(role),
      updatedAt: Value(updatedAt),
    );
  }

  factory DriftUserProfileCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftUserProfileCache(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      firstName: serializer.fromJson<String?>(json['firstName']),
      lastName: serializer.fromJson<String?>(json['lastName']),
      profileDisplayName: serializer.fromJson<String?>(
        json['profileDisplayName'],
      ),
      email: serializer.fromJson<String?>(json['email']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      role: serializer.fromJson<String>(json['role']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'firstName': serializer.toJson<String?>(firstName),
      'lastName': serializer.toJson<String?>(lastName),
      'profileDisplayName': serializer.toJson<String?>(profileDisplayName),
      'email': serializer.toJson<String?>(email),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'role': serializer.toJson<String>(role),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DriftUserProfileCache copyWith({
    String? id,
    String? tenantId,
    Value<String?> firstName = const Value.absent(),
    Value<String?> lastName = const Value.absent(),
    Value<String?> profileDisplayName = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    String? role,
    DateTime? updatedAt,
  }) => DriftUserProfileCache(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    firstName: firstName.present ? firstName.value : this.firstName,
    lastName: lastName.present ? lastName.value : this.lastName,
    profileDisplayName: profileDisplayName.present
        ? profileDisplayName.value
        : this.profileDisplayName,
    email: email.present ? email.value : this.email,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    role: role ?? this.role,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DriftUserProfileCache copyWithCompanion(UserProfilesCacheCompanion data) {
    return DriftUserProfileCache(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      profileDisplayName: data.profileDisplayName.present
          ? data.profileDisplayName.value
          : this.profileDisplayName,
      email: data.email.present ? data.email.value : this.email,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      role: data.role.present ? data.role.value : this.role,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftUserProfileCache(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('profileDisplayName: $profileDisplayName, ')
          ..write('email: $email, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    firstName,
    lastName,
    profileDisplayName,
    email,
    avatarUrl,
    role,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftUserProfileCache &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.profileDisplayName == this.profileDisplayName &&
          other.email == this.email &&
          other.avatarUrl == this.avatarUrl &&
          other.role == this.role &&
          other.updatedAt == this.updatedAt);
}

class UserProfilesCacheCompanion
    extends UpdateCompanion<DriftUserProfileCache> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String?> firstName;
  final Value<String?> lastName;
  final Value<String?> profileDisplayName;
  final Value<String?> email;
  final Value<String?> avatarUrl;
  final Value<String> role;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProfilesCacheCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.profileDisplayName = const Value.absent(),
    this.email = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.role = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCacheCompanion.insert({
    required String id,
    required String tenantId,
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.profileDisplayName = const Value.absent(),
    this.email = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.role = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       updatedAt = Value(updatedAt);
  static Insertable<DriftUserProfileCache> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? profileDisplayName,
    Expression<String>? email,
    Expression<String>? avatarUrl,
    Expression<String>? role,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (profileDisplayName != null)
        'profile_display_name': profileDisplayName,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (role != null) 'role': role,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String?>? firstName,
    Value<String?>? lastName,
    Value<String?>? profileDisplayName,
    Value<String?>? email,
    Value<String?>? avatarUrl,
    Value<String>? role,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserProfilesCacheCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileDisplayName: profileDisplayName ?? this.profileDisplayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (profileDisplayName.present) {
      map['profile_display_name'] = Variable<String>(profileDisplayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCacheCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('profileDisplayName: $profileDisplayName, ')
          ..write('email: $email, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TenantUiPreferencesTable extends TenantUiPreferences
    with TableInfo<$TenantUiPreferencesTable, TenantUiPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TenantUiPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _primaryColorMeta = const VerificationMeta(
    'primaryColor',
  );
  @override
  late final GeneratedColumn<String> primaryColor = GeneratedColumn<String>(
    'primary_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondaryColorMeta = const VerificationMeta(
    'secondaryColor',
  );
  @override
  late final GeneratedColumn<String> secondaryColor = GeneratedColumn<String>(
    'secondary_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    primaryColor,
    secondaryColor,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tenant_ui_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TenantUiPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('primary_color')) {
      context.handle(
        _primaryColorMeta,
        primaryColor.isAcceptableOrUnknown(
          data['primary_color']!,
          _primaryColorMeta,
        ),
      );
    }
    if (data.containsKey('secondary_color')) {
      context.handle(
        _secondaryColorMeta,
        secondaryColor.isAcceptableOrUnknown(
          data['secondary_color']!,
          _secondaryColorMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tenantId},
  ];
  @override
  TenantUiPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TenantUiPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      primaryColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_color'],
      ),
      secondaryColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_color'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TenantUiPreferencesTable createAlias(String alias) {
    return $TenantUiPreferencesTable(attachedDatabase, alias);
  }
}

class TenantUiPreference extends DataClass
    implements Insertable<TenantUiPreference> {
  /// Shodné s `tenant_ui_preferences.id` (UUID).
  final String id;
  final String tenantId;
  final String? primaryColor;
  final String? secondaryColor;
  final DateTime updatedAt;
  const TenantUiPreference({
    required this.id,
    required this.tenantId,
    this.primaryColor,
    this.secondaryColor,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || primaryColor != null) {
      map['primary_color'] = Variable<String>(primaryColor);
    }
    if (!nullToAbsent || secondaryColor != null) {
      map['secondary_color'] = Variable<String>(secondaryColor);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TenantUiPreferencesCompanion toCompanion(bool nullToAbsent) {
    return TenantUiPreferencesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      primaryColor: primaryColor == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryColor),
      secondaryColor: secondaryColor == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryColor),
      updatedAt: Value(updatedAt),
    );
  }

  factory TenantUiPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TenantUiPreference(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      primaryColor: serializer.fromJson<String?>(json['primaryColor']),
      secondaryColor: serializer.fromJson<String?>(json['secondaryColor']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'primaryColor': serializer.toJson<String?>(primaryColor),
      'secondaryColor': serializer.toJson<String?>(secondaryColor),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TenantUiPreference copyWith({
    String? id,
    String? tenantId,
    Value<String?> primaryColor = const Value.absent(),
    Value<String?> secondaryColor = const Value.absent(),
    DateTime? updatedAt,
  }) => TenantUiPreference(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    primaryColor: primaryColor.present ? primaryColor.value : this.primaryColor,
    secondaryColor: secondaryColor.present
        ? secondaryColor.value
        : this.secondaryColor,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TenantUiPreference copyWithCompanion(TenantUiPreferencesCompanion data) {
    return TenantUiPreference(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      primaryColor: data.primaryColor.present
          ? data.primaryColor.value
          : this.primaryColor,
      secondaryColor: data.secondaryColor.present
          ? data.secondaryColor.value
          : this.secondaryColor,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TenantUiPreference(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tenantId, primaryColor, secondaryColor, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TenantUiPreference &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.primaryColor == this.primaryColor &&
          other.secondaryColor == this.secondaryColor &&
          other.updatedAt == this.updatedAt);
}

class TenantUiPreferencesCompanion extends UpdateCompanion<TenantUiPreference> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String?> primaryColor;
  final Value<String?> secondaryColor;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TenantUiPreferencesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TenantUiPreferencesCompanion.insert({
    required String id,
    required String tenantId,
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       updatedAt = Value(updatedAt);
  static Insertable<TenantUiPreference> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? primaryColor,
    Expression<String>? secondaryColor,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TenantUiPreferencesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String?>? primaryColor,
    Value<String?>? secondaryColor,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TenantUiPreferencesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (primaryColor.present) {
      map['primary_color'] = Variable<String>(primaryColor.value);
    }
    if (secondaryColor.present) {
      map['secondary_color'] = Variable<String>(secondaryColor.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TenantUiPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $PendingMutationsTable pendingMutations = $PendingMutationsTable(
    this,
  );
  late final $ApartmentsTable apartments = $ApartmentsTable(this);
  late final $ClientsTable clients = $ClientsTable(this);
  late final $ReservationsTable reservations = $ReservationsTable(this);
  late final $TenantsTable tenants = $TenantsTable(this);
  late final $MessageTemplatesTable messageTemplates = $MessageTemplatesTable(
    this,
  );
  late final $PendingAuditActionsTable pendingAuditActions =
      $PendingAuditActionsTable(this);
  late final $TaskChecklistsTable taskChecklists = $TaskChecklistsTable(this);
  late final $TaskChecklistItemsTable taskChecklistItems =
      $TaskChecklistItemsTable(this);
  late final $TaskPayoutsTable taskPayouts = $TaskPayoutsTable(this);
  late final $TaskCommissionsTable taskCommissions = $TaskCommissionsTable(
    this,
  );
  late final $StaffAbsencesTable staffAbsences = $StaffAbsencesTable(this);
  late final $EmployeeCashWalletsTable employeeCashWallets =
      $EmployeeCashWalletsTable(this);
  late final $EmployeeCashTransactionsTable employeeCashTransactions =
      $EmployeeCashTransactionsTable(this);
  late final $UserProfilesCacheTable userProfilesCache =
      $UserProfilesCacheTable(this);
  late final $TenantUiPreferencesTable tenantUiPreferences =
      $TenantUiPreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tasks,
    pendingMutations,
    apartments,
    clients,
    reservations,
    tenants,
    messageTemplates,
    pendingAuditActions,
    taskChecklists,
    taskChecklistItems,
    taskPayouts,
    taskCommissions,
    staffAbsences,
    employeeCashWallets,
    employeeCashTransactions,
    userProfilesCache,
    tenantUiPreferences,
  ];
}

typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      Value<String?> apartmentSupabaseId,
      Value<String?> clientSupabaseId,
      Value<String?> customLocation,
      Value<String?> customTitle,
      Value<String?> reservationSupabaseId,
      Value<String?> assignedUserSupabaseId,
      Value<String?> assignedUserIdsJson,
      Value<String?> referenceNumber,
      Value<String> title,
      Value<String> description,
      Value<String> taskType,
      required DateTime scheduledStart,
      Value<DateTime?> dueDate,
      required String status,
      Value<String?> photoUrl,
      required DateTime localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> syncStatus,
      required DateTime lastUpdated,
      Value<String?> metadataJson,
      Value<String?> unassignedInfo,
      Value<String?> serviceId,
      Value<String?> mediaUrlsJson,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> invoicedAt,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String?> apartmentSupabaseId,
      Value<String?> clientSupabaseId,
      Value<String?> customLocation,
      Value<String?> customTitle,
      Value<String?> reservationSupabaseId,
      Value<String?> assignedUserSupabaseId,
      Value<String?> assignedUserIdsJson,
      Value<String?> referenceNumber,
      Value<String> title,
      Value<String> description,
      Value<String> taskType,
      Value<DateTime> scheduledStart,
      Value<DateTime?> dueDate,
      Value<String> status,
      Value<String?> photoUrl,
      Value<DateTime> localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> syncStatus,
      Value<DateTime> lastUpdated,
      Value<String?> metadataJson,
      Value<String?> unassignedInfo,
      Value<String?> serviceId,
      Value<String?> mediaUrlsJson,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> invoicedAt,
    });

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apartmentSupabaseId => $composableBuilder(
    column: $table.apartmentSupabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientSupabaseId => $composableBuilder(
    column: $table.clientSupabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customLocation => $composableBuilder(
    column: $table.customLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customTitle => $composableBuilder(
    column: $table.customTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reservationSupabaseId => $composableBuilder(
    column: $table.reservationSupabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignedUserSupabaseId => $composableBuilder(
    column: $table.assignedUserSupabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignedUserIdsJson => $composableBuilder(
    column: $table.assignedUserIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unassignedInfo => $composableBuilder(
    column: $table.unassignedInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrlsJson => $composableBuilder(
    column: $table.mediaUrlsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get invoicedAt => $composableBuilder(
    column: $table.invoicedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apartmentSupabaseId => $composableBuilder(
    column: $table.apartmentSupabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientSupabaseId => $composableBuilder(
    column: $table.clientSupabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customLocation => $composableBuilder(
    column: $table.customLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customTitle => $composableBuilder(
    column: $table.customTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reservationSupabaseId => $composableBuilder(
    column: $table.reservationSupabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignedUserSupabaseId => $composableBuilder(
    column: $table.assignedUserSupabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignedUserIdsJson => $composableBuilder(
    column: $table.assignedUserIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unassignedInfo => $composableBuilder(
    column: $table.unassignedInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrlsJson => $composableBuilder(
    column: $table.mediaUrlsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get invoicedAt => $composableBuilder(
    column: $table.invoicedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get apartmentSupabaseId => $composableBuilder(
    column: $table.apartmentSupabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientSupabaseId => $composableBuilder(
    column: $table.clientSupabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customLocation => $composableBuilder(
    column: $table.customLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customTitle => $composableBuilder(
    column: $table.customTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reservationSupabaseId => $composableBuilder(
    column: $table.reservationSupabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assignedUserSupabaseId => $composableBuilder(
    column: $table.assignedUserSupabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assignedUserIdsJson => $composableBuilder(
    column: $table.assignedUserIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unassignedInfo => $composableBuilder(
    column: $table.unassignedInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<String> get mediaUrlsJson => $composableBuilder(
    column: $table.mediaUrlsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get invoicedAt => $composableBuilder(
    column: $table.invoicedAt,
    builder: (column) => column,
  );
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String?> apartmentSupabaseId = const Value.absent(),
                Value<String?> clientSupabaseId = const Value.absent(),
                Value<String?> customLocation = const Value.absent(),
                Value<String?> customTitle = const Value.absent(),
                Value<String?> reservationSupabaseId = const Value.absent(),
                Value<String?> assignedUserSupabaseId = const Value.absent(),
                Value<String?> assignedUserIdsJson = const Value.absent(),
                Value<String?> referenceNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                Value<DateTime> scheduledStart = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<String?> unassignedInfo = const Value.absent(),
                Value<String?> serviceId = const Value.absent(),
                Value<String?> mediaUrlsJson = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> invoicedAt = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                apartmentSupabaseId: apartmentSupabaseId,
                clientSupabaseId: clientSupabaseId,
                customLocation: customLocation,
                customTitle: customTitle,
                reservationSupabaseId: reservationSupabaseId,
                assignedUserSupabaseId: assignedUserSupabaseId,
                assignedUserIdsJson: assignedUserIdsJson,
                referenceNumber: referenceNumber,
                title: title,
                description: description,
                taskType: taskType,
                scheduledStart: scheduledStart,
                dueDate: dueDate,
                status: status,
                photoUrl: photoUrl,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncStatus: syncStatus,
                lastUpdated: lastUpdated,
                metadataJson: metadataJson,
                unassignedInfo: unassignedInfo,
                serviceId: serviceId,
                mediaUrlsJson: mediaUrlsJson,
                startedAt: startedAt,
                completedAt: completedAt,
                invoicedAt: invoicedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                Value<String?> apartmentSupabaseId = const Value.absent(),
                Value<String?> clientSupabaseId = const Value.absent(),
                Value<String?> customLocation = const Value.absent(),
                Value<String?> customTitle = const Value.absent(),
                Value<String?> reservationSupabaseId = const Value.absent(),
                Value<String?> assignedUserSupabaseId = const Value.absent(),
                Value<String?> assignedUserIdsJson = const Value.absent(),
                Value<String?> referenceNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                required DateTime scheduledStart,
                Value<DateTime?> dueDate = const Value.absent(),
                required String status,
                Value<String?> photoUrl = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                required DateTime lastUpdated,
                Value<String?> metadataJson = const Value.absent(),
                Value<String?> unassignedInfo = const Value.absent(),
                Value<String?> serviceId = const Value.absent(),
                Value<String?> mediaUrlsJson = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> invoicedAt = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                apartmentSupabaseId: apartmentSupabaseId,
                clientSupabaseId: clientSupabaseId,
                customLocation: customLocation,
                customTitle: customTitle,
                reservationSupabaseId: reservationSupabaseId,
                assignedUserSupabaseId: assignedUserSupabaseId,
                assignedUserIdsJson: assignedUserIdsJson,
                referenceNumber: referenceNumber,
                title: title,
                description: description,
                taskType: taskType,
                scheduledStart: scheduledStart,
                dueDate: dueDate,
                status: status,
                photoUrl: photoUrl,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncStatus: syncStatus,
                lastUpdated: lastUpdated,
                metadataJson: metadataJson,
                unassignedInfo: unassignedInfo,
                serviceId: serviceId,
                mediaUrlsJson: mediaUrlsJson,
                startedAt: startedAt,
                completedAt: completedAt,
                invoicedAt: invoicedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$PendingMutationsTableCreateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<int> id,
      required String targetTable,
      required String actionType,
      required String payloadJson,
      Value<String?> recordId,
      required DateTime createdAt,
    });
typedef $$PendingMutationsTableUpdateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<int> id,
      Value<String> targetTable,
      Value<String> actionType,
      Value<String> payloadJson,
      Value<String?> recordId,
      Value<DateTime> createdAt,
    });

class $$PendingMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMutationsTable,
          PendingMutation,
          $$PendingMutationsTableFilterComposer,
          $$PendingMutationsTableOrderingComposer,
          $$PendingMutationsTableAnnotationComposer,
          $$PendingMutationsTableCreateCompanionBuilder,
          $$PendingMutationsTableUpdateCompanionBuilder,
          (
            PendingMutation,
            BaseReferences<
              _$AppDatabase,
              $PendingMutationsTable,
              PendingMutation
            >,
          ),
          PendingMutation,
          PrefetchHooks Function()
        > {
  $$PendingMutationsTableTableManager(
    _$AppDatabase db,
    $PendingMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> recordId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingMutationsCompanion(
                id: id,
                targetTable: targetTable,
                actionType: actionType,
                payloadJson: payloadJson,
                recordId: recordId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String targetTable,
                required String actionType,
                required String payloadJson,
                Value<String?> recordId = const Value.absent(),
                required DateTime createdAt,
              }) => PendingMutationsCompanion.insert(
                id: id,
                targetTable: targetTable,
                actionType: actionType,
                payloadJson: payloadJson,
                recordId: recordId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMutationsTable,
      PendingMutation,
      $$PendingMutationsTableFilterComposer,
      $$PendingMutationsTableOrderingComposer,
      $$PendingMutationsTableAnnotationComposer,
      $$PendingMutationsTableCreateCompanionBuilder,
      $$PendingMutationsTableUpdateCompanionBuilder,
      (
        PendingMutation,
        BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation>,
      ),
      PendingMutation,
      PrefetchHooks Function()
    >;
typedef $$ApartmentsTableCreateCompanionBuilder =
    ApartmentsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      Value<String> name,
      Value<String?> address,
      Value<String?> keybox,
      Value<String?> code,
      Value<String?> ownerNotes,
      Value<String?> checkInTime,
      Value<String?> checkOutTime,
      Value<String?> zoneId,
      Value<String?> parkingInstructions,
      Value<bool> investmentTrackingEnabled,
      Value<String> rentalMode,
      Value<DateTime?> leaseStartDate,
      Value<DateTime?> leaseEndDate,
      Value<double> rentAmount,
      Value<int> rentDueDay,
      Value<String> rentCollectionMode,
      Value<String?> rentTaskAssigneeId,
      Value<int> syncStatus,
      required DateTime localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      required DateTime lastUpdated,
    });
typedef $$ApartmentsTableUpdateCompanionBuilder =
    ApartmentsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> address,
      Value<String?> keybox,
      Value<String?> code,
      Value<String?> ownerNotes,
      Value<String?> checkInTime,
      Value<String?> checkOutTime,
      Value<String?> zoneId,
      Value<String?> parkingInstructions,
      Value<bool> investmentTrackingEnabled,
      Value<String> rentalMode,
      Value<DateTime?> leaseStartDate,
      Value<DateTime?> leaseEndDate,
      Value<double> rentAmount,
      Value<int> rentDueDay,
      Value<String> rentCollectionMode,
      Value<String?> rentTaskAssigneeId,
      Value<int> syncStatus,
      Value<DateTime> localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime> lastUpdated,
    });

class $$ApartmentsTableFilterComposer
    extends Composer<_$AppDatabase, $ApartmentsTable> {
  $$ApartmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keybox => $composableBuilder(
    column: $table.keybox,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerNotes => $composableBuilder(
    column: $table.ownerNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkInTime => $composableBuilder(
    column: $table.checkInTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkOutTime => $composableBuilder(
    column: $table.checkOutTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parkingInstructions => $composableBuilder(
    column: $table.parkingInstructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get investmentTrackingEnabled => $composableBuilder(
    column: $table.investmentTrackingEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rentalMode => $composableBuilder(
    column: $table.rentalMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseStartDate => $composableBuilder(
    column: $table.leaseStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseEndDate => $composableBuilder(
    column: $table.leaseEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rentAmount => $composableBuilder(
    column: $table.rentAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rentDueDay => $composableBuilder(
    column: $table.rentDueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rentCollectionMode => $composableBuilder(
    column: $table.rentCollectionMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rentTaskAssigneeId => $composableBuilder(
    column: $table.rentTaskAssigneeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ApartmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $ApartmentsTable> {
  $$ApartmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keybox => $composableBuilder(
    column: $table.keybox,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerNotes => $composableBuilder(
    column: $table.ownerNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkInTime => $composableBuilder(
    column: $table.checkInTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkOutTime => $composableBuilder(
    column: $table.checkOutTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parkingInstructions => $composableBuilder(
    column: $table.parkingInstructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get investmentTrackingEnabled => $composableBuilder(
    column: $table.investmentTrackingEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rentalMode => $composableBuilder(
    column: $table.rentalMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseStartDate => $composableBuilder(
    column: $table.leaseStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseEndDate => $composableBuilder(
    column: $table.leaseEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rentAmount => $composableBuilder(
    column: $table.rentAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rentDueDay => $composableBuilder(
    column: $table.rentDueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rentCollectionMode => $composableBuilder(
    column: $table.rentCollectionMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rentTaskAssigneeId => $composableBuilder(
    column: $table.rentTaskAssigneeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ApartmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApartmentsTable> {
  $$ApartmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get keybox =>
      $composableBuilder(column: $table.keybox, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get ownerNotes => $composableBuilder(
    column: $table.ownerNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkInTime => $composableBuilder(
    column: $table.checkInTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkOutTime => $composableBuilder(
    column: $table.checkOutTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zoneId =>
      $composableBuilder(column: $table.zoneId, builder: (column) => column);

  GeneratedColumn<String> get parkingInstructions => $composableBuilder(
    column: $table.parkingInstructions,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get investmentTrackingEnabled => $composableBuilder(
    column: $table.investmentTrackingEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rentalMode => $composableBuilder(
    column: $table.rentalMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseStartDate => $composableBuilder(
    column: $table.leaseStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseEndDate => $composableBuilder(
    column: $table.leaseEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rentAmount => $composableBuilder(
    column: $table.rentAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rentDueDay => $composableBuilder(
    column: $table.rentDueDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rentCollectionMode => $composableBuilder(
    column: $table.rentCollectionMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rentTaskAssigneeId => $composableBuilder(
    column: $table.rentTaskAssigneeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$ApartmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ApartmentsTable,
          Apartment,
          $$ApartmentsTableFilterComposer,
          $$ApartmentsTableOrderingComposer,
          $$ApartmentsTableAnnotationComposer,
          $$ApartmentsTableCreateCompanionBuilder,
          $$ApartmentsTableUpdateCompanionBuilder,
          (
            Apartment,
            BaseReferences<_$AppDatabase, $ApartmentsTable, Apartment>,
          ),
          Apartment,
          PrefetchHooks Function()
        > {
  $$ApartmentsTableTableManager(_$AppDatabase db, $ApartmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApartmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApartmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApartmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> keybox = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> ownerNotes = const Value.absent(),
                Value<String?> checkInTime = const Value.absent(),
                Value<String?> checkOutTime = const Value.absent(),
                Value<String?> zoneId = const Value.absent(),
                Value<String?> parkingInstructions = const Value.absent(),
                Value<bool> investmentTrackingEnabled = const Value.absent(),
                Value<String> rentalMode = const Value.absent(),
                Value<DateTime?> leaseStartDate = const Value.absent(),
                Value<DateTime?> leaseEndDate = const Value.absent(),
                Value<double> rentAmount = const Value.absent(),
                Value<int> rentDueDay = const Value.absent(),
                Value<String> rentCollectionMode = const Value.absent(),
                Value<String?> rentTaskAssigneeId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
              }) => ApartmentsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                name: name,
                address: address,
                keybox: keybox,
                code: code,
                ownerNotes: ownerNotes,
                checkInTime: checkInTime,
                checkOutTime: checkOutTime,
                zoneId: zoneId,
                parkingInstructions: parkingInstructions,
                investmentTrackingEnabled: investmentTrackingEnabled,
                rentalMode: rentalMode,
                leaseStartDate: leaseStartDate,
                leaseEndDate: leaseEndDate,
                rentAmount: rentAmount,
                rentDueDay: rentDueDay,
                rentCollectionMode: rentCollectionMode,
                rentTaskAssigneeId: rentTaskAssigneeId,
                syncStatus: syncStatus,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                Value<String> name = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> keybox = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> ownerNotes = const Value.absent(),
                Value<String?> checkInTime = const Value.absent(),
                Value<String?> checkOutTime = const Value.absent(),
                Value<String?> zoneId = const Value.absent(),
                Value<String?> parkingInstructions = const Value.absent(),
                Value<bool> investmentTrackingEnabled = const Value.absent(),
                Value<String> rentalMode = const Value.absent(),
                Value<DateTime?> leaseStartDate = const Value.absent(),
                Value<DateTime?> leaseEndDate = const Value.absent(),
                Value<double> rentAmount = const Value.absent(),
                Value<int> rentDueDay = const Value.absent(),
                Value<String> rentCollectionMode = const Value.absent(),
                Value<String?> rentTaskAssigneeId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                required DateTime lastUpdated,
              }) => ApartmentsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                name: name,
                address: address,
                keybox: keybox,
                code: code,
                ownerNotes: ownerNotes,
                checkInTime: checkInTime,
                checkOutTime: checkOutTime,
                zoneId: zoneId,
                parkingInstructions: parkingInstructions,
                investmentTrackingEnabled: investmentTrackingEnabled,
                rentalMode: rentalMode,
                leaseStartDate: leaseStartDate,
                leaseEndDate: leaseEndDate,
                rentAmount: rentAmount,
                rentDueDay: rentDueDay,
                rentCollectionMode: rentCollectionMode,
                rentTaskAssigneeId: rentTaskAssigneeId,
                syncStatus: syncStatus,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ApartmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ApartmentsTable,
      Apartment,
      $$ApartmentsTableFilterComposer,
      $$ApartmentsTableOrderingComposer,
      $$ApartmentsTableAnnotationComposer,
      $$ApartmentsTableCreateCompanionBuilder,
      $$ApartmentsTableUpdateCompanionBuilder,
      (Apartment, BaseReferences<_$AppDatabase, $ApartmentsTable, Apartment>),
      Apartment,
      PrefetchHooks Function()
    >;
typedef $$ClientsTableCreateCompanionBuilder =
    ClientsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      Value<String> name,
      Value<String?> phone,
    });
typedef $$ClientsTableUpdateCompanionBuilder =
    ClientsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> phone,
    });

class $$ClientsTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);
}

class $$ClientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientsTable,
          Client,
          $$ClientsTableFilterComposer,
          $$ClientsTableOrderingComposer,
          $$ClientsTableAnnotationComposer,
          $$ClientsTableCreateCompanionBuilder,
          $$ClientsTableUpdateCompanionBuilder,
          (Client, BaseReferences<_$AppDatabase, $ClientsTable, Client>),
          Client,
          PrefetchHooks Function()
        > {
  $$ClientsTableTableManager(_$AppDatabase db, $ClientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
              }) => ClientsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                name: name,
                phone: phone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
              }) => ClientsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                name: name,
                phone: phone,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientsTable,
      Client,
      $$ClientsTableFilterComposer,
      $$ClientsTableOrderingComposer,
      $$ClientsTableAnnotationComposer,
      $$ClientsTableCreateCompanionBuilder,
      $$ClientsTableUpdateCompanionBuilder,
      (Client, BaseReferences<_$AppDatabase, $ClientsTable, Client>),
      Client,
      PrefetchHooks Function()
    >;
typedef $$ReservationsTableCreateCompanionBuilder =
    ReservationsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      Value<String> status,
      Value<String?> guestName,
      Value<String?> guestPhone,
      Value<String?> referenceNumber,
      Value<String?> specialRequests,
      Value<String?> guestLanguage,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      required DateTime localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> syncStatus,
      required DateTime lastUpdated,
    });
typedef $$ReservationsTableUpdateCompanionBuilder =
    ReservationsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String> status,
      Value<String?> guestName,
      Value<String?> guestPhone,
      Value<String?> referenceNumber,
      Value<String?> specialRequests,
      Value<String?> guestLanguage,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<DateTime> localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> syncStatus,
      Value<DateTime> lastUpdated,
    });

class $$ReservationsTableFilterComposer
    extends Composer<_$AppDatabase, $ReservationsTable> {
  $$ReservationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guestName => $composableBuilder(
    column: $table.guestName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guestPhone => $composableBuilder(
    column: $table.guestPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get specialRequests => $composableBuilder(
    column: $table.specialRequests,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guestLanguage => $composableBuilder(
    column: $table.guestLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReservationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReservationsTable> {
  $$ReservationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guestName => $composableBuilder(
    column: $table.guestName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guestPhone => $composableBuilder(
    column: $table.guestPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get specialRequests => $composableBuilder(
    column: $table.specialRequests,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guestLanguage => $composableBuilder(
    column: $table.guestLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReservationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReservationsTable> {
  $$ReservationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get guestName =>
      $composableBuilder(column: $table.guestName, builder: (column) => column);

  GeneratedColumn<String> get guestPhone => $composableBuilder(
    column: $table.guestPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceNumber => $composableBuilder(
    column: $table.referenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get specialRequests => $composableBuilder(
    column: $table.specialRequests,
    builder: (column) => column,
  );

  GeneratedColumn<String> get guestLanguage => $composableBuilder(
    column: $table.guestLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$ReservationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReservationsTable,
          Reservation,
          $$ReservationsTableFilterComposer,
          $$ReservationsTableOrderingComposer,
          $$ReservationsTableAnnotationComposer,
          $$ReservationsTableCreateCompanionBuilder,
          $$ReservationsTableUpdateCompanionBuilder,
          (
            Reservation,
            BaseReferences<_$AppDatabase, $ReservationsTable, Reservation>,
          ),
          Reservation,
          PrefetchHooks Function()
        > {
  $$ReservationsTableTableManager(_$AppDatabase db, $ReservationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReservationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReservationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReservationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> guestName = const Value.absent(),
                Value<String?> guestPhone = const Value.absent(),
                Value<String?> referenceNumber = const Value.absent(),
                Value<String?> specialRequests = const Value.absent(),
                Value<String?> guestLanguage = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
              }) => ReservationsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                status: status,
                guestName: guestName,
                guestPhone: guestPhone,
                referenceNumber: referenceNumber,
                specialRequests: specialRequests,
                guestLanguage: guestLanguage,
                startDate: startDate,
                endDate: endDate,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncStatus: syncStatus,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                Value<String> status = const Value.absent(),
                Value<String?> guestName = const Value.absent(),
                Value<String?> guestPhone = const Value.absent(),
                Value<String?> referenceNumber = const Value.absent(),
                Value<String?> specialRequests = const Value.absent(),
                Value<String?> guestLanguage = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                required DateTime lastUpdated,
              }) => ReservationsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                status: status,
                guestName: guestName,
                guestPhone: guestPhone,
                referenceNumber: referenceNumber,
                specialRequests: specialRequests,
                guestLanguage: guestLanguage,
                startDate: startDate,
                endDate: endDate,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncStatus: syncStatus,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReservationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReservationsTable,
      Reservation,
      $$ReservationsTableFilterComposer,
      $$ReservationsTableOrderingComposer,
      $$ReservationsTableAnnotationComposer,
      $$ReservationsTableCreateCompanionBuilder,
      $$ReservationsTableUpdateCompanionBuilder,
      (
        Reservation,
        BaseReferences<_$AppDatabase, $ReservationsTable, Reservation>,
      ),
      Reservation,
      PrefetchHooks Function()
    >;
typedef $$TenantsTableCreateCompanionBuilder =
    TenantsCompanion Function({
      Value<int> id,
      required String supabaseId,
      Value<String?> currency,
    });
typedef $$TenantsTableUpdateCompanionBuilder =
    TenantsCompanion Function({
      Value<int> id,
      Value<String> supabaseId,
      Value<String?> currency,
    });

class $$TenantsTableFilterComposer
    extends Composer<_$AppDatabase, $TenantsTable> {
  $$TenantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TenantsTableOrderingComposer
    extends Composer<_$AppDatabase, $TenantsTable> {
  $$TenantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TenantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TenantsTable> {
  $$TenantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$TenantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TenantsTable,
          Tenant,
          $$TenantsTableFilterComposer,
          $$TenantsTableOrderingComposer,
          $$TenantsTableAnnotationComposer,
          $$TenantsTableCreateCompanionBuilder,
          $$TenantsTableUpdateCompanionBuilder,
          (Tenant, BaseReferences<_$AppDatabase, $TenantsTable, Tenant>),
          Tenant,
          PrefetchHooks Function()
        > {
  $$TenantsTableTableManager(_$AppDatabase db, $TenantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TenantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TenantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TenantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> supabaseId = const Value.absent(),
                Value<String?> currency = const Value.absent(),
              }) => TenantsCompanion(
                id: id,
                supabaseId: supabaseId,
                currency: currency,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String supabaseId,
                Value<String?> currency = const Value.absent(),
              }) => TenantsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                currency: currency,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TenantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TenantsTable,
      Tenant,
      $$TenantsTableFilterComposer,
      $$TenantsTableOrderingComposer,
      $$TenantsTableAnnotationComposer,
      $$TenantsTableCreateCompanionBuilder,
      $$TenantsTableUpdateCompanionBuilder,
      (Tenant, BaseReferences<_$AppDatabase, $TenantsTable, Tenant>),
      Tenant,
      PrefetchHooks Function()
    >;
typedef $$MessageTemplatesTableCreateCompanionBuilder =
    MessageTemplatesCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      Value<String> key,
      Value<String> name,
      Value<String?> channel,
      Value<String?> emailSubject,
      Value<String?> translationsJson,
      Value<String?> triggerContext,
      Value<int> orderIndex,
      Value<int> syncStatus,
      Value<DateTime?> lastSyncedAt,
    });
typedef $$MessageTemplatesTableUpdateCompanionBuilder =
    MessageTemplatesCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String> key,
      Value<String> name,
      Value<String?> channel,
      Value<String?> emailSubject,
      Value<String?> translationsJson,
      Value<String?> triggerContext,
      Value<int> orderIndex,
      Value<int> syncStatus,
      Value<DateTime?> lastSyncedAt,
    });

class $$MessageTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $MessageTemplatesTable> {
  $$MessageTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emailSubject => $composableBuilder(
    column: $table.emailSubject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationsJson => $composableBuilder(
    column: $table.translationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerContext => $composableBuilder(
    column: $table.triggerContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageTemplatesTable> {
  $$MessageTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emailSubject => $composableBuilder(
    column: $table.emailSubject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationsJson => $composableBuilder(
    column: $table.translationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerContext => $composableBuilder(
    column: $table.triggerContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageTemplatesTable> {
  $$MessageTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get emailSubject => $composableBuilder(
    column: $table.emailSubject,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translationsJson => $composableBuilder(
    column: $table.translationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerContext => $composableBuilder(
    column: $table.triggerContext,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$MessageTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageTemplatesTable,
          MessageTemplate,
          $$MessageTemplatesTableFilterComposer,
          $$MessageTemplatesTableOrderingComposer,
          $$MessageTemplatesTableAnnotationComposer,
          $$MessageTemplatesTableCreateCompanionBuilder,
          $$MessageTemplatesTableUpdateCompanionBuilder,
          (
            MessageTemplate,
            BaseReferences<
              _$AppDatabase,
              $MessageTemplatesTable,
              MessageTemplate
            >,
          ),
          MessageTemplate,
          PrefetchHooks Function()
        > {
  $$MessageTemplatesTableTableManager(
    _$AppDatabase db,
    $MessageTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<String?> emailSubject = const Value.absent(),
                Value<String?> translationsJson = const Value.absent(),
                Value<String?> triggerContext = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => MessageTemplatesCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                key: key,
                name: name,
                channel: channel,
                emailSubject: emailSubject,
                translationsJson: translationsJson,
                triggerContext: triggerContext,
                orderIndex: orderIndex,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                Value<String> key = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<String?> emailSubject = const Value.absent(),
                Value<String?> translationsJson = const Value.absent(),
                Value<String?> triggerContext = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
              }) => MessageTemplatesCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                key: key,
                name: name,
                channel: channel,
                emailSubject: emailSubject,
                translationsJson: translationsJson,
                triggerContext: triggerContext,
                orderIndex: orderIndex,
                syncStatus: syncStatus,
                lastSyncedAt: lastSyncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageTemplatesTable,
      MessageTemplate,
      $$MessageTemplatesTableFilterComposer,
      $$MessageTemplatesTableOrderingComposer,
      $$MessageTemplatesTableAnnotationComposer,
      $$MessageTemplatesTableCreateCompanionBuilder,
      $$MessageTemplatesTableUpdateCompanionBuilder,
      (
        MessageTemplate,
        BaseReferences<_$AppDatabase, $MessageTemplatesTable, MessageTemplate>,
      ),
      MessageTemplate,
      PrefetchHooks Function()
    >;
typedef $$PendingAuditActionsTableCreateCompanionBuilder =
    PendingAuditActionsCompanion Function({
      Value<int> id,
      required String actionType,
      required String targetTable,
      required String recordId,
      Value<String?> tenantId,
      required DateTime createdAtUtc,
      Value<int> syncStatus,
    });
typedef $$PendingAuditActionsTableUpdateCompanionBuilder =
    PendingAuditActionsCompanion Function({
      Value<int> id,
      Value<String> actionType,
      Value<String> targetTable,
      Value<String> recordId,
      Value<String?> tenantId,
      Value<DateTime> createdAtUtc,
      Value<int> syncStatus,
    });

class $$PendingAuditActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingAuditActionsTable> {
  $$PendingAuditActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingAuditActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingAuditActionsTable> {
  $$PendingAuditActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingAuditActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingAuditActionsTable> {
  $$PendingAuditActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$PendingAuditActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingAuditActionsTable,
          PendingAuditAction,
          $$PendingAuditActionsTableFilterComposer,
          $$PendingAuditActionsTableOrderingComposer,
          $$PendingAuditActionsTableAnnotationComposer,
          $$PendingAuditActionsTableCreateCompanionBuilder,
          $$PendingAuditActionsTableUpdateCompanionBuilder,
          (
            PendingAuditAction,
            BaseReferences<
              _$AppDatabase,
              $PendingAuditActionsTable,
              PendingAuditAction
            >,
          ),
          PendingAuditAction,
          PrefetchHooks Function()
        > {
  $$PendingAuditActionsTableTableManager(
    _$AppDatabase db,
    $PendingAuditActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingAuditActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingAuditActionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingAuditActionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String?> tenantId = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => PendingAuditActionsCompanion(
                id: id,
                actionType: actionType,
                targetTable: targetTable,
                recordId: recordId,
                tenantId: tenantId,
                createdAtUtc: createdAtUtc,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String actionType,
                required String targetTable,
                required String recordId,
                Value<String?> tenantId = const Value.absent(),
                required DateTime createdAtUtc,
                Value<int> syncStatus = const Value.absent(),
              }) => PendingAuditActionsCompanion.insert(
                id: id,
                actionType: actionType,
                targetTable: targetTable,
                recordId: recordId,
                tenantId: tenantId,
                createdAtUtc: createdAtUtc,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingAuditActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingAuditActionsTable,
      PendingAuditAction,
      $$PendingAuditActionsTableFilterComposer,
      $$PendingAuditActionsTableOrderingComposer,
      $$PendingAuditActionsTableAnnotationComposer,
      $$PendingAuditActionsTableCreateCompanionBuilder,
      $$PendingAuditActionsTableUpdateCompanionBuilder,
      (
        PendingAuditAction,
        BaseReferences<
          _$AppDatabase,
          $PendingAuditActionsTable,
          PendingAuditAction
        >,
      ),
      PendingAuditAction,
      PrefetchHooks Function()
    >;
typedef $$TaskChecklistsTableCreateCompanionBuilder =
    TaskChecklistsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      required String taskId,
      Value<String?> templateId,
      required DateTime localUpdatedAt,
      Value<int> syncStatus,
    });
typedef $$TaskChecklistsTableUpdateCompanionBuilder =
    TaskChecklistsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String> taskId,
      Value<String?> templateId,
      Value<DateTime> localUpdatedAt,
      Value<int> syncStatus,
    });

class $$TaskChecklistsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskChecklistsTable> {
  $$TaskChecklistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskChecklistsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskChecklistsTable> {
  $$TaskChecklistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskChecklistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskChecklistsTable> {
  $$TaskChecklistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$TaskChecklistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskChecklistsTable,
          TaskChecklist,
          $$TaskChecklistsTableFilterComposer,
          $$TaskChecklistsTableOrderingComposer,
          $$TaskChecklistsTableAnnotationComposer,
          $$TaskChecklistsTableCreateCompanionBuilder,
          $$TaskChecklistsTableUpdateCompanionBuilder,
          (
            TaskChecklist,
            BaseReferences<_$AppDatabase, $TaskChecklistsTable, TaskChecklist>,
          ),
          TaskChecklist,
          PrefetchHooks Function()
        > {
  $$TaskChecklistsTableTableManager(
    _$AppDatabase db,
    $TaskChecklistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskChecklistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskChecklistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskChecklistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => TaskChecklistsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskId: taskId,
                templateId: templateId,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                required String taskId,
                Value<String?> templateId = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<int> syncStatus = const Value.absent(),
              }) => TaskChecklistsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskId: taskId,
                templateId: templateId,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskChecklistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskChecklistsTable,
      TaskChecklist,
      $$TaskChecklistsTableFilterComposer,
      $$TaskChecklistsTableOrderingComposer,
      $$TaskChecklistsTableAnnotationComposer,
      $$TaskChecklistsTableCreateCompanionBuilder,
      $$TaskChecklistsTableUpdateCompanionBuilder,
      (
        TaskChecklist,
        BaseReferences<_$AppDatabase, $TaskChecklistsTable, TaskChecklist>,
      ),
      TaskChecklist,
      PrefetchHooks Function()
    >;
typedef $$TaskChecklistItemsTableCreateCompanionBuilder =
    TaskChecklistItemsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      required String tenantId,
      required String taskChecklistId,
      Value<String> title,
      Value<bool> isPhotoRequired,
      Value<int> sortOrder,
      Value<bool> isCompleted,
      Value<DateTime?> completedAt,
      Value<String?> completedBy,
      Value<String?> photoUrl,
      Value<String?> localPhotoPath,
      required DateTime localUpdatedAt,
      Value<int> syncStatus,
    });
typedef $$TaskChecklistItemsTableUpdateCompanionBuilder =
    TaskChecklistItemsCompanion Function({
      Value<int> id,
      Value<String?> supabaseId,
      Value<String> tenantId,
      Value<String> taskChecklistId,
      Value<String> title,
      Value<bool> isPhotoRequired,
      Value<int> sortOrder,
      Value<bool> isCompleted,
      Value<DateTime?> completedAt,
      Value<String?> completedBy,
      Value<String?> photoUrl,
      Value<String?> localPhotoPath,
      Value<DateTime> localUpdatedAt,
      Value<int> syncStatus,
    });

class $$TaskChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskChecklistItemsTable> {
  $$TaskChecklistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskChecklistId => $composableBuilder(
    column: $table.taskChecklistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPhotoRequired => $composableBuilder(
    column: $table.isPhotoRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskChecklistItemsTable> {
  $$TaskChecklistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskChecklistId => $composableBuilder(
    column: $table.taskChecklistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPhotoRequired => $composableBuilder(
    column: $table.isPhotoRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskChecklistItemsTable> {
  $$TaskChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get taskChecklistId => $composableBuilder(
    column: $table.taskChecklistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isPhotoRequired => $composableBuilder(
    column: $table.isPhotoRequired,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get localPhotoPath => $composableBuilder(
    column: $table.localPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$TaskChecklistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskChecklistItemsTable,
          TaskChecklistItem,
          $$TaskChecklistItemsTableFilterComposer,
          $$TaskChecklistItemsTableOrderingComposer,
          $$TaskChecklistItemsTableAnnotationComposer,
          $$TaskChecklistItemsTableCreateCompanionBuilder,
          $$TaskChecklistItemsTableUpdateCompanionBuilder,
          (
            TaskChecklistItem,
            BaseReferences<
              _$AppDatabase,
              $TaskChecklistItemsTable,
              TaskChecklistItem
            >,
          ),
          TaskChecklistItem,
          PrefetchHooks Function()
        > {
  $$TaskChecklistItemsTableTableManager(
    _$AppDatabase db,
    $TaskChecklistItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskChecklistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskChecklistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskChecklistItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> taskChecklistId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isPhotoRequired = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String?> localPhotoPath = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => TaskChecklistItemsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskChecklistId: taskChecklistId,
                title: title,
                isPhotoRequired: isPhotoRequired,
                sortOrder: sortOrder,
                isCompleted: isCompleted,
                completedAt: completedAt,
                completedBy: completedBy,
                photoUrl: photoUrl,
                localPhotoPath: localPhotoPath,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                required String tenantId,
                required String taskChecklistId,
                Value<String> title = const Value.absent(),
                Value<bool> isPhotoRequired = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String?> localPhotoPath = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<int> syncStatus = const Value.absent(),
              }) => TaskChecklistItemsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskChecklistId: taskChecklistId,
                title: title,
                isPhotoRequired: isPhotoRequired,
                sortOrder: sortOrder,
                isCompleted: isCompleted,
                completedAt: completedAt,
                completedBy: completedBy,
                photoUrl: photoUrl,
                localPhotoPath: localPhotoPath,
                localUpdatedAt: localUpdatedAt,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskChecklistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskChecklistItemsTable,
      TaskChecklistItem,
      $$TaskChecklistItemsTableFilterComposer,
      $$TaskChecklistItemsTableOrderingComposer,
      $$TaskChecklistItemsTableAnnotationComposer,
      $$TaskChecklistItemsTableCreateCompanionBuilder,
      $$TaskChecklistItemsTableUpdateCompanionBuilder,
      (
        TaskChecklistItem,
        BaseReferences<
          _$AppDatabase,
          $TaskChecklistItemsTable,
          TaskChecklistItem
        >,
      ),
      TaskChecklistItem,
      PrefetchHooks Function()
    >;
typedef $$TaskPayoutsTableCreateCompanionBuilder =
    TaskPayoutsCompanion Function({
      Value<int> id,
      required String supabaseId,
      required String tenantId,
      required String taskId,
      required String profileId,
      required double amount,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$TaskPayoutsTableUpdateCompanionBuilder =
    TaskPayoutsCompanion Function({
      Value<int> id,
      Value<String> supabaseId,
      Value<String> tenantId,
      Value<String> taskId,
      Value<String> profileId,
      Value<double> amount,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$TaskPayoutsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskPayoutsTable> {
  $$TaskPayoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskPayoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskPayoutsTable> {
  $$TaskPayoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskPayoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskPayoutsTable> {
  $$TaskPayoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TaskPayoutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskPayoutsTable,
          TaskPayout,
          $$TaskPayoutsTableFilterComposer,
          $$TaskPayoutsTableOrderingComposer,
          $$TaskPayoutsTableAnnotationComposer,
          $$TaskPayoutsTableCreateCompanionBuilder,
          $$TaskPayoutsTableUpdateCompanionBuilder,
          (
            TaskPayout,
            BaseReferences<_$AppDatabase, $TaskPayoutsTable, TaskPayout>,
          ),
          TaskPayout,
          PrefetchHooks Function()
        > {
  $$TaskPayoutsTableTableManager(_$AppDatabase db, $TaskPayoutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskPayoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskPayoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskPayoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TaskPayoutsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskId: taskId,
                profileId: profileId,
                amount: amount,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String supabaseId,
                required String tenantId,
                required String taskId,
                required String profileId,
                required double amount,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TaskPayoutsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskId: taskId,
                profileId: profileId,
                amount: amount,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskPayoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskPayoutsTable,
      TaskPayout,
      $$TaskPayoutsTableFilterComposer,
      $$TaskPayoutsTableOrderingComposer,
      $$TaskPayoutsTableAnnotationComposer,
      $$TaskPayoutsTableCreateCompanionBuilder,
      $$TaskPayoutsTableUpdateCompanionBuilder,
      (
        TaskPayout,
        BaseReferences<_$AppDatabase, $TaskPayoutsTable, TaskPayout>,
      ),
      TaskPayout,
      PrefetchHooks Function()
    >;
typedef $$TaskCommissionsTableCreateCompanionBuilder =
    TaskCommissionsCompanion Function({
      Value<int> id,
      required String supabaseId,
      required String tenantId,
      required String taskId,
      Value<String?> profileId,
      Value<String?> clientId,
      required double amount,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$TaskCommissionsTableUpdateCompanionBuilder =
    TaskCommissionsCompanion Function({
      Value<int> id,
      Value<String> supabaseId,
      Value<String> tenantId,
      Value<String> taskId,
      Value<String?> profileId,
      Value<String?> clientId,
      Value<double> amount,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$TaskCommissionsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskCommissionsTable> {
  $$TaskCommissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskCommissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskCommissionsTable> {
  $$TaskCommissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskCommissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskCommissionsTable> {
  $$TaskCommissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TaskCommissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskCommissionsTable,
          TaskCommission,
          $$TaskCommissionsTableFilterComposer,
          $$TaskCommissionsTableOrderingComposer,
          $$TaskCommissionsTableAnnotationComposer,
          $$TaskCommissionsTableCreateCompanionBuilder,
          $$TaskCommissionsTableUpdateCompanionBuilder,
          (
            TaskCommission,
            BaseReferences<
              _$AppDatabase,
              $TaskCommissionsTable,
              TaskCommission
            >,
          ),
          TaskCommission,
          PrefetchHooks Function()
        > {
  $$TaskCommissionsTableTableManager(
    _$AppDatabase db,
    $TaskCommissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskCommissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskCommissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskCommissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> clientId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TaskCommissionsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskId: taskId,
                profileId: profileId,
                clientId: clientId,
                amount: amount,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String supabaseId,
                required String tenantId,
                required String taskId,
                Value<String?> profileId = const Value.absent(),
                Value<String?> clientId = const Value.absent(),
                required double amount,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TaskCommissionsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                taskId: taskId,
                profileId: profileId,
                clientId: clientId,
                amount: amount,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskCommissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskCommissionsTable,
      TaskCommission,
      $$TaskCommissionsTableFilterComposer,
      $$TaskCommissionsTableOrderingComposer,
      $$TaskCommissionsTableAnnotationComposer,
      $$TaskCommissionsTableCreateCompanionBuilder,
      $$TaskCommissionsTableUpdateCompanionBuilder,
      (
        TaskCommission,
        BaseReferences<_$AppDatabase, $TaskCommissionsTable, TaskCommission>,
      ),
      TaskCommission,
      PrefetchHooks Function()
    >;
typedef $$StaffAbsencesTableCreateCompanionBuilder =
    StaffAbsencesCompanion Function({
      Value<int> id,
      required String supabaseId,
      required String tenantId,
      required String profileId,
      Value<String?> invitationId,
      required DateTime startDate,
      required DateTime endDate,
      Value<String> reason,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$StaffAbsencesTableUpdateCompanionBuilder =
    StaffAbsencesCompanion Function({
      Value<int> id,
      Value<String> supabaseId,
      Value<String> tenantId,
      Value<String> profileId,
      Value<String?> invitationId,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<String> reason,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$StaffAbsencesTableFilterComposer
    extends Composer<_$AppDatabase, $StaffAbsencesTable> {
  $$StaffAbsencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invitationId => $composableBuilder(
    column: $table.invitationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StaffAbsencesTableOrderingComposer
    extends Composer<_$AppDatabase, $StaffAbsencesTable> {
  $$StaffAbsencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invitationId => $composableBuilder(
    column: $table.invitationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StaffAbsencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StaffAbsencesTable> {
  $$StaffAbsencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get invitationId => $composableBuilder(
    column: $table.invitationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StaffAbsencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StaffAbsencesTable,
          DriftStaffAbsence,
          $$StaffAbsencesTableFilterComposer,
          $$StaffAbsencesTableOrderingComposer,
          $$StaffAbsencesTableAnnotationComposer,
          $$StaffAbsencesTableCreateCompanionBuilder,
          $$StaffAbsencesTableUpdateCompanionBuilder,
          (
            DriftStaffAbsence,
            BaseReferences<
              _$AppDatabase,
              $StaffAbsencesTable,
              DriftStaffAbsence
            >,
          ),
          DriftStaffAbsence,
          PrefetchHooks Function()
        > {
  $$StaffAbsencesTableTableManager(_$AppDatabase db, $StaffAbsencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StaffAbsencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StaffAbsencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StaffAbsencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String?> invitationId = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => StaffAbsencesCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                profileId: profileId,
                invitationId: invitationId,
                startDate: startDate,
                endDate: endDate,
                reason: reason,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String supabaseId,
                required String tenantId,
                required String profileId,
                Value<String?> invitationId = const Value.absent(),
                required DateTime startDate,
                required DateTime endDate,
                Value<String> reason = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => StaffAbsencesCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                profileId: profileId,
                invitationId: invitationId,
                startDate: startDate,
                endDate: endDate,
                reason: reason,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StaffAbsencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StaffAbsencesTable,
      DriftStaffAbsence,
      $$StaffAbsencesTableFilterComposer,
      $$StaffAbsencesTableOrderingComposer,
      $$StaffAbsencesTableAnnotationComposer,
      $$StaffAbsencesTableCreateCompanionBuilder,
      $$StaffAbsencesTableUpdateCompanionBuilder,
      (
        DriftStaffAbsence,
        BaseReferences<_$AppDatabase, $StaffAbsencesTable, DriftStaffAbsence>,
      ),
      DriftStaffAbsence,
      PrefetchHooks Function()
    >;
typedef $$EmployeeCashWalletsTableCreateCompanionBuilder =
    EmployeeCashWalletsCompanion Function({
      Value<int> id,
      required String supabaseId,
      required String tenantId,
      required String profileId,
      required double balance,
      Value<String?> currencyCode,
      required DateTime updatedAt,
    });
typedef $$EmployeeCashWalletsTableUpdateCompanionBuilder =
    EmployeeCashWalletsCompanion Function({
      Value<int> id,
      Value<String> supabaseId,
      Value<String> tenantId,
      Value<String> profileId,
      Value<double> balance,
      Value<String?> currencyCode,
      Value<DateTime> updatedAt,
    });

class $$EmployeeCashWalletsTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeeCashWalletsTable> {
  $$EmployeeCashWalletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmployeeCashWalletsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeeCashWalletsTable> {
  $$EmployeeCashWalletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeeCashWalletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeeCashWalletsTable> {
  $$EmployeeCashWalletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EmployeeCashWalletsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeeCashWalletsTable,
          DriftEmployeeCashWallet,
          $$EmployeeCashWalletsTableFilterComposer,
          $$EmployeeCashWalletsTableOrderingComposer,
          $$EmployeeCashWalletsTableAnnotationComposer,
          $$EmployeeCashWalletsTableCreateCompanionBuilder,
          $$EmployeeCashWalletsTableUpdateCompanionBuilder,
          (
            DriftEmployeeCashWallet,
            BaseReferences<
              _$AppDatabase,
              $EmployeeCashWalletsTable,
              DriftEmployeeCashWallet
            >,
          ),
          DriftEmployeeCashWallet,
          PrefetchHooks Function()
        > {
  $$EmployeeCashWalletsTableTableManager(
    _$AppDatabase db,
    $EmployeeCashWalletsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeeCashWalletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeeCashWalletsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EmployeeCashWalletsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<double> balance = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EmployeeCashWalletsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                profileId: profileId,
                balance: balance,
                currencyCode: currencyCode,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String supabaseId,
                required String tenantId,
                required String profileId,
                required double balance,
                Value<String?> currencyCode = const Value.absent(),
                required DateTime updatedAt,
              }) => EmployeeCashWalletsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                profileId: profileId,
                balance: balance,
                currencyCode: currencyCode,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmployeeCashWalletsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeeCashWalletsTable,
      DriftEmployeeCashWallet,
      $$EmployeeCashWalletsTableFilterComposer,
      $$EmployeeCashWalletsTableOrderingComposer,
      $$EmployeeCashWalletsTableAnnotationComposer,
      $$EmployeeCashWalletsTableCreateCompanionBuilder,
      $$EmployeeCashWalletsTableUpdateCompanionBuilder,
      (
        DriftEmployeeCashWallet,
        BaseReferences<
          _$AppDatabase,
          $EmployeeCashWalletsTable,
          DriftEmployeeCashWallet
        >,
      ),
      DriftEmployeeCashWallet,
      PrefetchHooks Function()
    >;
typedef $$EmployeeCashTransactionsTableCreateCompanionBuilder =
    EmployeeCashTransactionsCompanion Function({
      Value<int> id,
      required String supabaseId,
      required String tenantId,
      required String walletId,
      required String profileId,
      required double amount,
      required String transactionType,
      Value<String?> note,
      required DateTime createdAt,
      Value<String?> taskId,
      Value<String?> createdBy,
      Value<String?> receiptImageUrl,
      Value<double?> expectedAmount,
      Value<String?> apartmentId,
      Value<String?> clientId,
      Value<bool> isShortfallResolved,
      Value<String?> shortfallResolutionType,
      Value<String?> shortfallResolutionNote,
    });
typedef $$EmployeeCashTransactionsTableUpdateCompanionBuilder =
    EmployeeCashTransactionsCompanion Function({
      Value<int> id,
      Value<String> supabaseId,
      Value<String> tenantId,
      Value<String> walletId,
      Value<String> profileId,
      Value<double> amount,
      Value<String> transactionType,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<String?> taskId,
      Value<String?> createdBy,
      Value<String?> receiptImageUrl,
      Value<double?> expectedAmount,
      Value<String?> apartmentId,
      Value<String?> clientId,
      Value<bool> isShortfallResolved,
      Value<String?> shortfallResolutionType,
      Value<String?> shortfallResolutionNote,
    });

class $$EmployeeCashTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeeCashTransactionsTable> {
  $$EmployeeCashTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptImageUrl => $composableBuilder(
    column: $table.receiptImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get expectedAmount => $composableBuilder(
    column: $table.expectedAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apartmentId => $composableBuilder(
    column: $table.apartmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShortfallResolved => $composableBuilder(
    column: $table.isShortfallResolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortfallResolutionType => $composableBuilder(
    column: $table.shortfallResolutionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortfallResolutionNote => $composableBuilder(
    column: $table.shortfallResolutionNote,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmployeeCashTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeeCashTransactionsTable> {
  $$EmployeeCashTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletId => $composableBuilder(
    column: $table.walletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptImageUrl => $composableBuilder(
    column: $table.receiptImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get expectedAmount => $composableBuilder(
    column: $table.expectedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apartmentId => $composableBuilder(
    column: $table.apartmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShortfallResolved => $composableBuilder(
    column: $table.isShortfallResolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortfallResolutionType => $composableBuilder(
    column: $table.shortfallResolutionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortfallResolutionNote => $composableBuilder(
    column: $table.shortfallResolutionNote,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeeCashTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeeCashTransactionsTable> {
  $$EmployeeCashTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get walletId =>
      $composableBuilder(column: $table.walletId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get receiptImageUrl => $composableBuilder(
    column: $table.receiptImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get expectedAmount => $composableBuilder(
    column: $table.expectedAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get apartmentId => $composableBuilder(
    column: $table.apartmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<bool> get isShortfallResolved => $composableBuilder(
    column: $table.isShortfallResolved,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shortfallResolutionType => $composableBuilder(
    column: $table.shortfallResolutionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shortfallResolutionNote => $composableBuilder(
    column: $table.shortfallResolutionNote,
    builder: (column) => column,
  );
}

class $$EmployeeCashTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeeCashTransactionsTable,
          DriftEmployeeCashTransaction,
          $$EmployeeCashTransactionsTableFilterComposer,
          $$EmployeeCashTransactionsTableOrderingComposer,
          $$EmployeeCashTransactionsTableAnnotationComposer,
          $$EmployeeCashTransactionsTableCreateCompanionBuilder,
          $$EmployeeCashTransactionsTableUpdateCompanionBuilder,
          (
            DriftEmployeeCashTransaction,
            BaseReferences<
              _$AppDatabase,
              $EmployeeCashTransactionsTable,
              DriftEmployeeCashTransaction
            >,
          ),
          DriftEmployeeCashTransaction,
          PrefetchHooks Function()
        > {
  $$EmployeeCashTransactionsTableTableManager(
    _$AppDatabase db,
    $EmployeeCashTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeeCashTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EmployeeCashTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EmployeeCashTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> supabaseId = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> walletId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> transactionType = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> receiptImageUrl = const Value.absent(),
                Value<double?> expectedAmount = const Value.absent(),
                Value<String?> apartmentId = const Value.absent(),
                Value<String?> clientId = const Value.absent(),
                Value<bool> isShortfallResolved = const Value.absent(),
                Value<String?> shortfallResolutionType = const Value.absent(),
                Value<String?> shortfallResolutionNote = const Value.absent(),
              }) => EmployeeCashTransactionsCompanion(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                walletId: walletId,
                profileId: profileId,
                amount: amount,
                transactionType: transactionType,
                note: note,
                createdAt: createdAt,
                taskId: taskId,
                createdBy: createdBy,
                receiptImageUrl: receiptImageUrl,
                expectedAmount: expectedAmount,
                apartmentId: apartmentId,
                clientId: clientId,
                isShortfallResolved: isShortfallResolved,
                shortfallResolutionType: shortfallResolutionType,
                shortfallResolutionNote: shortfallResolutionNote,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String supabaseId,
                required String tenantId,
                required String walletId,
                required String profileId,
                required double amount,
                required String transactionType,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<String?> taskId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> receiptImageUrl = const Value.absent(),
                Value<double?> expectedAmount = const Value.absent(),
                Value<String?> apartmentId = const Value.absent(),
                Value<String?> clientId = const Value.absent(),
                Value<bool> isShortfallResolved = const Value.absent(),
                Value<String?> shortfallResolutionType = const Value.absent(),
                Value<String?> shortfallResolutionNote = const Value.absent(),
              }) => EmployeeCashTransactionsCompanion.insert(
                id: id,
                supabaseId: supabaseId,
                tenantId: tenantId,
                walletId: walletId,
                profileId: profileId,
                amount: amount,
                transactionType: transactionType,
                note: note,
                createdAt: createdAt,
                taskId: taskId,
                createdBy: createdBy,
                receiptImageUrl: receiptImageUrl,
                expectedAmount: expectedAmount,
                apartmentId: apartmentId,
                clientId: clientId,
                isShortfallResolved: isShortfallResolved,
                shortfallResolutionType: shortfallResolutionType,
                shortfallResolutionNote: shortfallResolutionNote,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmployeeCashTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeeCashTransactionsTable,
      DriftEmployeeCashTransaction,
      $$EmployeeCashTransactionsTableFilterComposer,
      $$EmployeeCashTransactionsTableOrderingComposer,
      $$EmployeeCashTransactionsTableAnnotationComposer,
      $$EmployeeCashTransactionsTableCreateCompanionBuilder,
      $$EmployeeCashTransactionsTableUpdateCompanionBuilder,
      (
        DriftEmployeeCashTransaction,
        BaseReferences<
          _$AppDatabase,
          $EmployeeCashTransactionsTable,
          DriftEmployeeCashTransaction
        >,
      ),
      DriftEmployeeCashTransaction,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesCacheTableCreateCompanionBuilder =
    UserProfilesCacheCompanion Function({
      required String id,
      required String tenantId,
      Value<String?> firstName,
      Value<String?> lastName,
      Value<String?> profileDisplayName,
      Value<String?> email,
      Value<String?> avatarUrl,
      Value<String> role,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserProfilesCacheTableUpdateCompanionBuilder =
    UserProfilesCacheCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String?> firstName,
      Value<String?> lastName,
      Value<String?> profileDisplayName,
      Value<String?> email,
      Value<String?> avatarUrl,
      Value<String> role,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserProfilesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesCacheTable> {
  $$UserProfilesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileDisplayName => $composableBuilder(
    column: $table.profileDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesCacheTable> {
  $$UserProfilesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileDisplayName => $composableBuilder(
    column: $table.profileDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesCacheTable> {
  $$UserProfilesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get profileDisplayName => $composableBuilder(
    column: $table.profileDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfilesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesCacheTable,
          DriftUserProfileCache,
          $$UserProfilesCacheTableFilterComposer,
          $$UserProfilesCacheTableOrderingComposer,
          $$UserProfilesCacheTableAnnotationComposer,
          $$UserProfilesCacheTableCreateCompanionBuilder,
          $$UserProfilesCacheTableUpdateCompanionBuilder,
          (
            DriftUserProfileCache,
            BaseReferences<
              _$AppDatabase,
              $UserProfilesCacheTable,
              DriftUserProfileCache
            >,
          ),
          DriftUserProfileCache,
          PrefetchHooks Function()
        > {
  $$UserProfilesCacheTableTableManager(
    _$AppDatabase db,
    $UserProfilesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String?> firstName = const Value.absent(),
                Value<String?> lastName = const Value.absent(),
                Value<String?> profileDisplayName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCacheCompanion(
                id: id,
                tenantId: tenantId,
                firstName: firstName,
                lastName: lastName,
                profileDisplayName: profileDisplayName,
                email: email,
                avatarUrl: avatarUrl,
                role: role,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<String?> firstName = const Value.absent(),
                Value<String?> lastName = const Value.absent(),
                Value<String?> profileDisplayName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> role = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCacheCompanion.insert(
                id: id,
                tenantId: tenantId,
                firstName: firstName,
                lastName: lastName,
                profileDisplayName: profileDisplayName,
                email: email,
                avatarUrl: avatarUrl,
                role: role,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesCacheTable,
      DriftUserProfileCache,
      $$UserProfilesCacheTableFilterComposer,
      $$UserProfilesCacheTableOrderingComposer,
      $$UserProfilesCacheTableAnnotationComposer,
      $$UserProfilesCacheTableCreateCompanionBuilder,
      $$UserProfilesCacheTableUpdateCompanionBuilder,
      (
        DriftUserProfileCache,
        BaseReferences<
          _$AppDatabase,
          $UserProfilesCacheTable,
          DriftUserProfileCache
        >,
      ),
      DriftUserProfileCache,
      PrefetchHooks Function()
    >;
typedef $$TenantUiPreferencesTableCreateCompanionBuilder =
    TenantUiPreferencesCompanion Function({
      required String id,
      required String tenantId,
      Value<String?> primaryColor,
      Value<String?> secondaryColor,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TenantUiPreferencesTableUpdateCompanionBuilder =
    TenantUiPreferencesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String?> primaryColor,
      Value<String?> secondaryColor,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TenantUiPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $TenantUiPreferencesTable> {
  $$TenantUiPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TenantUiPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $TenantUiPreferencesTable> {
  $$TenantUiPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TenantUiPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TenantUiPreferencesTable> {
  $$TenantUiPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TenantUiPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TenantUiPreferencesTable,
          TenantUiPreference,
          $$TenantUiPreferencesTableFilterComposer,
          $$TenantUiPreferencesTableOrderingComposer,
          $$TenantUiPreferencesTableAnnotationComposer,
          $$TenantUiPreferencesTableCreateCompanionBuilder,
          $$TenantUiPreferencesTableUpdateCompanionBuilder,
          (
            TenantUiPreference,
            BaseReferences<
              _$AppDatabase,
              $TenantUiPreferencesTable,
              TenantUiPreference
            >,
          ),
          TenantUiPreference,
          PrefetchHooks Function()
        > {
  $$TenantUiPreferencesTableTableManager(
    _$AppDatabase db,
    $TenantUiPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TenantUiPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TenantUiPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TenantUiPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String?> primaryColor = const Value.absent(),
                Value<String?> secondaryColor = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TenantUiPreferencesCompanion(
                id: id,
                tenantId: tenantId,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<String?> primaryColor = const Value.absent(),
                Value<String?> secondaryColor = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TenantUiPreferencesCompanion.insert(
                id: id,
                tenantId: tenantId,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TenantUiPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TenantUiPreferencesTable,
      TenantUiPreference,
      $$TenantUiPreferencesTableFilterComposer,
      $$TenantUiPreferencesTableOrderingComposer,
      $$TenantUiPreferencesTableAnnotationComposer,
      $$TenantUiPreferencesTableCreateCompanionBuilder,
      $$TenantUiPreferencesTableUpdateCompanionBuilder,
      (
        TenantUiPreference,
        BaseReferences<
          _$AppDatabase,
          $TenantUiPreferencesTable,
          TenantUiPreference
        >,
      ),
      TenantUiPreference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$ApartmentsTableTableManager get apartments =>
      $$ApartmentsTableTableManager(_db, _db.apartments);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
  $$ReservationsTableTableManager get reservations =>
      $$ReservationsTableTableManager(_db, _db.reservations);
  $$TenantsTableTableManager get tenants =>
      $$TenantsTableTableManager(_db, _db.tenants);
  $$MessageTemplatesTableTableManager get messageTemplates =>
      $$MessageTemplatesTableTableManager(_db, _db.messageTemplates);
  $$PendingAuditActionsTableTableManager get pendingAuditActions =>
      $$PendingAuditActionsTableTableManager(_db, _db.pendingAuditActions);
  $$TaskChecklistsTableTableManager get taskChecklists =>
      $$TaskChecklistsTableTableManager(_db, _db.taskChecklists);
  $$TaskChecklistItemsTableTableManager get taskChecklistItems =>
      $$TaskChecklistItemsTableTableManager(_db, _db.taskChecklistItems);
  $$TaskPayoutsTableTableManager get taskPayouts =>
      $$TaskPayoutsTableTableManager(_db, _db.taskPayouts);
  $$TaskCommissionsTableTableManager get taskCommissions =>
      $$TaskCommissionsTableTableManager(_db, _db.taskCommissions);
  $$StaffAbsencesTableTableManager get staffAbsences =>
      $$StaffAbsencesTableTableManager(_db, _db.staffAbsences);
  $$EmployeeCashWalletsTableTableManager get employeeCashWallets =>
      $$EmployeeCashWalletsTableTableManager(_db, _db.employeeCashWallets);
  $$EmployeeCashTransactionsTableTableManager get employeeCashTransactions =>
      $$EmployeeCashTransactionsTableTableManager(
        _db,
        _db.employeeCashTransactions,
      );
  $$UserProfilesCacheTableTableManager get userProfilesCache =>
      $$UserProfilesCacheTableTableManager(_db, _db.userProfilesCache);
  $$TenantUiPreferencesTableTableManager get tenantUiPreferences =>
      $$TenantUiPreferencesTableTableManager(_db, _db.tenantUiPreferences);
}
