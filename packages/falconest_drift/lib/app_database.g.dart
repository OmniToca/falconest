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
    status,
    photoUrl,
    localUpdatedAt,
    lastSyncedAt,
    syncStatus,
    lastUpdated,
    metadataJson,
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
  final String status;
  final String? photoUrl;
  final DateTime localUpdatedAt;
  final DateTime? lastSyncedAt;
  final int syncStatus;
  final DateTime lastUpdated;
  final String? metadataJson;
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
    required this.status,
    this.photoUrl,
    required this.localUpdatedAt,
    this.lastSyncedAt,
    required this.syncStatus,
    required this.lastUpdated,
    this.metadataJson,
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
      status: serializer.fromJson<String>(json['status']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
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
      'status': serializer.toJson<String>(status),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'metadataJson': serializer.toJson<String?>(metadataJson),
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
    String? status,
    Value<String?> photoUrl = const Value.absent(),
    DateTime? localUpdatedAt,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    int? syncStatus,
    DateTime? lastUpdated,
    Value<String?> metadataJson = const Value.absent(),
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
    status: status ?? this.status,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
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
          ..write('status: $status, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('metadataJson: $metadataJson, ')
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
    status,
    photoUrl,
    localUpdatedAt,
    lastSyncedAt,
    syncStatus,
    lastUpdated,
    metadataJson,
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
          other.status == this.status &&
          other.photoUrl == this.photoUrl &&
          other.localUpdatedAt == this.localUpdatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.syncStatus == this.syncStatus &&
          other.lastUpdated == this.lastUpdated &&
          other.metadataJson == this.metadataJson &&
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
  final Value<String> status;
  final Value<String?> photoUrl;
  final Value<DateTime> localUpdatedAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> syncStatus;
  final Value<DateTime> lastUpdated;
  final Value<String?> metadataJson;
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
    this.status = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.metadataJson = const Value.absent(),
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
    required String status,
    this.photoUrl = const Value.absent(),
    required DateTime localUpdatedAt,
    this.lastSyncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    required DateTime lastUpdated,
    this.metadataJson = const Value.absent(),
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
    Expression<String>? status,
    Expression<String>? photoUrl,
    Expression<DateTime>? localUpdatedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? syncStatus,
    Expression<DateTime>? lastUpdated,
    Expression<String>? metadataJson,
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
      if (status != null) 'status': status,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (metadataJson != null) 'metadata_json': metadataJson,
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
    Value<String>? status,
    Value<String?>? photoUrl,
    Value<DateTime>? localUpdatedAt,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? syncStatus,
    Value<DateTime>? lastUpdated,
    Value<String?>? metadataJson,
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
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadataJson: metadataJson ?? this.metadataJson,
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
          ..write('status: $status, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('metadataJson: $metadataJson, ')
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
          ..write('syncStatus: $syncStatus, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    supabaseId,
    tenantId,
    name,
    address,
    keybox,
    code,
    ownerNotes,
    syncStatus,
    localUpdatedAt,
    lastSyncedAt,
    lastUpdated,
  );
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
    localUpdatedAt,
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
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
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
  final DateTime localUpdatedAt;
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
    required this.localUpdatedAt,
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
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
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
      localUpdatedAt: Value(localUpdatedAt),
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
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
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
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
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
    DateTime? localUpdatedAt,
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
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
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
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
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
          ..write('localUpdatedAt: $localUpdatedAt, ')
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
    localUpdatedAt,
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
          other.localUpdatedAt == this.localUpdatedAt &&
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
  final Value<DateTime> localUpdatedAt;
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
    this.localUpdatedAt = const Value.absent(),
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
    required DateTime localUpdatedAt,
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
    Expression<DateTime>? localUpdatedAt,
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
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
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
    Value<DateTime>? localUpdatedAt,
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
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
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
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
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
          ..write('localUpdatedAt: $localUpdatedAt, ')
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
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
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
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
    body,
    channel,
    languageCode,
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
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
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
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      ),
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
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
  final String body;
  final String? channel;
  final String? languageCode;
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
    required this.body,
    this.channel,
    this.languageCode,
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
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || channel != null) {
      map['channel'] = Variable<String>(channel);
    }
    if (!nullToAbsent || languageCode != null) {
      map['language_code'] = Variable<String>(languageCode);
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
      body: Value(body),
      channel: channel == null && nullToAbsent
          ? const Value.absent()
          : Value(channel),
      languageCode: languageCode == null && nullToAbsent
          ? const Value.absent()
          : Value(languageCode),
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
      body: serializer.fromJson<String>(json['body']),
      channel: serializer.fromJson<String?>(json['channel']),
      languageCode: serializer.fromJson<String?>(json['languageCode']),
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
      'body': serializer.toJson<String>(body),
      'channel': serializer.toJson<String?>(channel),
      'languageCode': serializer.toJson<String?>(languageCode),
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
    String? body,
    Value<String?> channel = const Value.absent(),
    Value<String?> languageCode = const Value.absent(),
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
    body: body ?? this.body,
    channel: channel.present ? channel.value : this.channel,
    languageCode: languageCode.present ? languageCode.value : this.languageCode,
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
      body: data.body.present ? data.body.value : this.body,
      channel: data.channel.present ? data.channel.value : this.channel,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
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
          ..write('body: $body, ')
          ..write('channel: $channel, ')
          ..write('languageCode: $languageCode, ')
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
    body,
    channel,
    languageCode,
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
          other.body == this.body &&
          other.channel == this.channel &&
          other.languageCode == this.languageCode &&
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
  final Value<String> body;
  final Value<String?> channel;
  final Value<String?> languageCode;
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
    this.body = const Value.absent(),
    this.channel = const Value.absent(),
    this.languageCode = const Value.absent(),
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
    this.body = const Value.absent(),
    this.channel = const Value.absent(),
    this.languageCode = const Value.absent(),
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
    Expression<String>? body,
    Expression<String>? channel,
    Expression<String>? languageCode,
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
      if (body != null) 'body': body,
      if (channel != null) 'channel': channel,
      if (languageCode != null) 'language_code': languageCode,
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
    Value<String>? body,
    Value<String?>? channel,
    Value<String?>? languageCode,
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
      body: body ?? this.body,
      channel: channel ?? this.channel,
      languageCode: languageCode ?? this.languageCode,
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
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
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
          ..write('body: $body, ')
          ..write('channel: $channel, ')
          ..write('languageCode: $languageCode, ')
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
      required String status,
      Value<String?> photoUrl,
      required DateTime localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> syncStatus,
      required DateTime lastUpdated,
      Value<String?> metadataJson,
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
      Value<String> status,
      Value<String?> photoUrl,
      Value<DateTime> localUpdatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<int> syncStatus,
      Value<DateTime> lastUpdated,
      Value<String?> metadataJson,
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
                Value<String> status = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
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
                status: status,
                photoUrl: photoUrl,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncStatus: syncStatus,
                lastUpdated: lastUpdated,
                metadataJson: metadataJson,
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
                required String status,
                Value<String?> photoUrl = const Value.absent(),
                required DateTime localUpdatedAt,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                required DateTime lastUpdated,
                Value<String?> metadataJson = const Value.absent(),
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
                status: status,
                photoUrl: photoUrl,
                localUpdatedAt: localUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncStatus: syncStatus,
                lastUpdated: lastUpdated,
                metadataJson: metadataJson,
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
      required DateTime localUpdatedAt,
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
      Value<DateTime> localUpdatedAt,
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

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
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

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
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

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
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
                Value<DateTime> localUpdatedAt = const Value.absent(),
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
                localUpdatedAt: localUpdatedAt,
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
                required DateTime localUpdatedAt,
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
                localUpdatedAt: localUpdatedAt,
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
      Value<String> body,
      Value<String?> channel,
      Value<String?> languageCode,
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
      Value<String> body,
      Value<String?> channel,
      Value<String?> languageCode,
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
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

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
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
                Value<String> body = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<String?> languageCode = const Value.absent(),
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
                body: body,
                channel: channel,
                languageCode: languageCode,
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
                Value<String> body = const Value.absent(),
                Value<String?> channel = const Value.absent(),
                Value<String?> languageCode = const Value.absent(),
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
                body: body,
                channel: channel,
                languageCode: languageCode,
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
}
