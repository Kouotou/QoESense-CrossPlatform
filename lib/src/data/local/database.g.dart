// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BufferedSamplesTable extends BufferedSamples
    with TableInfo<$BufferedSamplesTable, BufferedSampleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BufferedSamplesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, timestampMs, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buffered_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<BufferedSampleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BufferedSampleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BufferedSampleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $BufferedSamplesTable createAlias(String alias) {
    return $BufferedSamplesTable(attachedDatabase, alias);
  }
}

class BufferedSampleRow extends DataClass
    implements Insertable<BufferedSampleRow> {
  final int id;
  final int timestampMs;
  final String payload;
  const BufferedSampleRow({
    required this.id,
    required this.timestampMs,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  BufferedSamplesCompanion toCompanion(bool nullToAbsent) {
    return BufferedSamplesCompanion(
      id: Value(id),
      timestampMs: Value(timestampMs),
      payload: Value(payload),
    );
  }

  factory BufferedSampleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BufferedSampleRow(
      id: serializer.fromJson<int>(json['id']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'payload': serializer.toJson<String>(payload),
    };
  }

  BufferedSampleRow copyWith({int? id, int? timestampMs, String? payload}) =>
      BufferedSampleRow(
        id: id ?? this.id,
        timestampMs: timestampMs ?? this.timestampMs,
        payload: payload ?? this.payload,
      );
  BufferedSampleRow copyWithCompanion(BufferedSamplesCompanion data) {
    return BufferedSampleRow(
      id: data.id.present ? data.id.value : this.id,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BufferedSampleRow(')
          ..write('id: $id, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestampMs, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BufferedSampleRow &&
          other.id == this.id &&
          other.timestampMs == this.timestampMs &&
          other.payload == this.payload);
}

class BufferedSamplesCompanion extends UpdateCompanion<BufferedSampleRow> {
  final Value<int> id;
  final Value<int> timestampMs;
  final Value<String> payload;
  const BufferedSamplesCompanion({
    this.id = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.payload = const Value.absent(),
  });
  BufferedSamplesCompanion.insert({
    this.id = const Value.absent(),
    required int timestampMs,
    required String payload,
  }) : timestampMs = Value(timestampMs),
       payload = Value(payload);
  static Insertable<BufferedSampleRow> custom({
    Expression<int>? id,
    Expression<int>? timestampMs,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (payload != null) 'payload': payload,
    });
  }

  BufferedSamplesCompanion copyWith({
    Value<int>? id,
    Value<int>? timestampMs,
    Value<String>? payload,
  }) {
    return BufferedSamplesCompanion(
      id: id ?? this.id,
      timestampMs: timestampMs ?? this.timestampMs,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BufferedSamplesCompanion(')
          ..write('id: $id, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $PendingMosResponsesTable extends PendingMosResponses
    with TableInfo<$PendingMosResponsesTable, PendingMosResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMosResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _responseIdMeta = const VerificationMeta(
    'responseId',
  );
  @override
  late final GeneratedColumn<String> responseId = GeneratedColumn<String>(
    'response_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    responseId,
    payload,
    attempts,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mos_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMosResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('response_id')) {
      context.handle(
        _responseIdMeta,
        responseId.isAcceptableOrUnknown(data['response_id']!, _responseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_responseIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {responseId};
  @override
  PendingMosResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMosResponse(
      responseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $PendingMosResponsesTable createAlias(String alias) {
    return $PendingMosResponsesTable(attachedDatabase, alias);
  }
}

class PendingMosResponse extends DataClass
    implements Insertable<PendingMosResponse> {
  final String responseId;
  final String payload;
  final int attempts;
  final int createdAtMs;
  const PendingMosResponse({
    required this.responseId,
    required this.payload,
    required this.attempts,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['response_id'] = Variable<String>(responseId);
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  PendingMosResponsesCompanion toCompanion(bool nullToAbsent) {
    return PendingMosResponsesCompanion(
      responseId: Value(responseId),
      payload: Value(payload),
      attempts: Value(attempts),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory PendingMosResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMosResponse(
      responseId: serializer.fromJson<String>(json['responseId']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'responseId': serializer.toJson<String>(responseId),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  PendingMosResponse copyWith({
    String? responseId,
    String? payload,
    int? attempts,
    int? createdAtMs,
  }) => PendingMosResponse(
    responseId: responseId ?? this.responseId,
    payload: payload ?? this.payload,
    attempts: attempts ?? this.attempts,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  PendingMosResponse copyWithCompanion(PendingMosResponsesCompanion data) {
    return PendingMosResponse(
      responseId: data.responseId.present
          ? data.responseId.value
          : this.responseId,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMosResponse(')
          ..write('responseId: $responseId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(responseId, payload, attempts, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMosResponse &&
          other.responseId == this.responseId &&
          other.payload == this.payload &&
          other.attempts == this.attempts &&
          other.createdAtMs == this.createdAtMs);
}

class PendingMosResponsesCompanion extends UpdateCompanion<PendingMosResponse> {
  final Value<String> responseId;
  final Value<String> payload;
  final Value<int> attempts;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const PendingMosResponsesCompanion({
    this.responseId = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMosResponsesCompanion.insert({
    required String responseId,
    required String payload,
    this.attempts = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : responseId = Value(responseId),
       payload = Value(payload),
       createdAtMs = Value(createdAtMs);
  static Insertable<PendingMosResponse> custom({
    Expression<String>? responseId,
    Expression<String>? payload,
    Expression<int>? attempts,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (responseId != null) 'response_id': responseId,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMosResponsesCompanion copyWith({
    Value<String>? responseId,
    Value<String>? payload,
    Value<int>? attempts,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return PendingMosResponsesCompanion(
      responseId: responseId ?? this.responseId,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (responseId.present) {
      map['response_id'] = Variable<String>(responseId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMosResponsesCompanion(')
          ..write('responseId: $responseId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String key;
  final String value;
  const KeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValue copyWith({String? key, String? value}) =>
      KeyValue(key: key ?? this.key, value: value ?? this.value);
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValue && other.key == this.key && other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$QoESenseDatabase extends GeneratedDatabase {
  _$QoESenseDatabase(QueryExecutor e) : super(e);
  $QoESenseDatabaseManager get managers => $QoESenseDatabaseManager(this);
  late final $BufferedSamplesTable bufferedSamples = $BufferedSamplesTable(
    this,
  );
  late final $PendingMosResponsesTable pendingMosResponses =
      $PendingMosResponsesTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  late final Index bufferedSamplesTs = Index(
    'buffered_samples_ts',
    'CREATE INDEX buffered_samples_ts ON buffered_samples (timestamp_ms)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    bufferedSamples,
    pendingMosResponses,
    keyValues,
    bufferedSamplesTs,
  ];
}

typedef $$BufferedSamplesTableCreateCompanionBuilder =
    BufferedSamplesCompanion Function({
      Value<int> id,
      required int timestampMs,
      required String payload,
    });
typedef $$BufferedSamplesTableUpdateCompanionBuilder =
    BufferedSamplesCompanion Function({
      Value<int> id,
      Value<int> timestampMs,
      Value<String> payload,
    });

class $$BufferedSamplesTableFilterComposer
    extends Composer<_$QoESenseDatabase, $BufferedSamplesTable> {
  $$BufferedSamplesTableFilterComposer({
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

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BufferedSamplesTableOrderingComposer
    extends Composer<_$QoESenseDatabase, $BufferedSamplesTable> {
  $$BufferedSamplesTableOrderingComposer({
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

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BufferedSamplesTableAnnotationComposer
    extends Composer<_$QoESenseDatabase, $BufferedSamplesTable> {
  $$BufferedSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$BufferedSamplesTableTableManager
    extends
        RootTableManager<
          _$QoESenseDatabase,
          $BufferedSamplesTable,
          BufferedSampleRow,
          $$BufferedSamplesTableFilterComposer,
          $$BufferedSamplesTableOrderingComposer,
          $$BufferedSamplesTableAnnotationComposer,
          $$BufferedSamplesTableCreateCompanionBuilder,
          $$BufferedSamplesTableUpdateCompanionBuilder,
          (
            BufferedSampleRow,
            BaseReferences<
              _$QoESenseDatabase,
              $BufferedSamplesTable,
              BufferedSampleRow
            >,
          ),
          BufferedSampleRow,
          PrefetchHooks Function()
        > {
  $$BufferedSamplesTableTableManager(
    _$QoESenseDatabase db,
    $BufferedSamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BufferedSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BufferedSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BufferedSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => BufferedSamplesCompanion(
                id: id,
                timestampMs: timestampMs,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int timestampMs,
                required String payload,
              }) => BufferedSamplesCompanion.insert(
                id: id,
                timestampMs: timestampMs,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BufferedSamplesTable, BufferedSampleRow>(table),
                  BaseReferences<
                    _$QoESenseDatabase,
                    $BufferedSamplesTable,
                    BufferedSampleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BufferedSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$QoESenseDatabase,
      $BufferedSamplesTable,
      BufferedSampleRow,
      $$BufferedSamplesTableFilterComposer,
      $$BufferedSamplesTableOrderingComposer,
      $$BufferedSamplesTableAnnotationComposer,
      $$BufferedSamplesTableCreateCompanionBuilder,
      $$BufferedSamplesTableUpdateCompanionBuilder,
      (
        BufferedSampleRow,
        BaseReferences<
          _$QoESenseDatabase,
          $BufferedSamplesTable,
          BufferedSampleRow
        >,
      ),
      BufferedSampleRow,
      PrefetchHooks Function()
    >;
typedef $$PendingMosResponsesTableCreateCompanionBuilder =
    PendingMosResponsesCompanion Function({
      required String responseId,
      required String payload,
      Value<int> attempts,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$PendingMosResponsesTableUpdateCompanionBuilder =
    PendingMosResponsesCompanion Function({
      Value<String> responseId,
      Value<String> payload,
      Value<int> attempts,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$PendingMosResponsesTableFilterComposer
    extends Composer<_$QoESenseDatabase, $PendingMosResponsesTable> {
  $$PendingMosResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMosResponsesTableOrderingComposer
    extends Composer<_$QoESenseDatabase, $PendingMosResponsesTable> {
  $$PendingMosResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMosResponsesTableAnnotationComposer
    extends Composer<_$QoESenseDatabase, $PendingMosResponsesTable> {
  $$PendingMosResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$PendingMosResponsesTableTableManager
    extends
        RootTableManager<
          _$QoESenseDatabase,
          $PendingMosResponsesTable,
          PendingMosResponse,
          $$PendingMosResponsesTableFilterComposer,
          $$PendingMosResponsesTableOrderingComposer,
          $$PendingMosResponsesTableAnnotationComposer,
          $$PendingMosResponsesTableCreateCompanionBuilder,
          $$PendingMosResponsesTableUpdateCompanionBuilder,
          (
            PendingMosResponse,
            BaseReferences<
              _$QoESenseDatabase,
              $PendingMosResponsesTable,
              PendingMosResponse
            >,
          ),
          PendingMosResponse,
          PrefetchHooks Function()
        > {
  $$PendingMosResponsesTableTableManager(
    _$QoESenseDatabase db,
    $PendingMosResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMosResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMosResponsesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingMosResponsesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> responseId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMosResponsesCompanion(
                responseId: responseId,
                payload: payload,
                attempts: attempts,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String responseId,
                required String payload,
                Value<int> attempts = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => PendingMosResponsesCompanion.insert(
                responseId: responseId,
                payload: payload,
                attempts: attempts,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingMosResponsesTable, PendingMosResponse>(
                    table,
                  ),
                  BaseReferences<
                    _$QoESenseDatabase,
                    $PendingMosResponsesTable,
                    PendingMosResponse
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMosResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$QoESenseDatabase,
      $PendingMosResponsesTable,
      PendingMosResponse,
      $$PendingMosResponsesTableFilterComposer,
      $$PendingMosResponsesTableOrderingComposer,
      $$PendingMosResponsesTableAnnotationComposer,
      $$PendingMosResponsesTableCreateCompanionBuilder,
      $$PendingMosResponsesTableUpdateCompanionBuilder,
      (
        PendingMosResponse,
        BaseReferences<
          _$QoESenseDatabase,
          $PendingMosResponsesTable,
          PendingMosResponse
        >,
      ),
      PendingMosResponse,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder = KeyValuesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KeyValuesTableUpdateCompanionBuilder = KeyValuesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KeyValuesTableFilterComposer
    extends Composer<_$QoESenseDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$QoESenseDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$QoESenseDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$QoESenseDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (
            KeyValue,
            BaseReferences<_$QoESenseDatabase, $KeyValuesTable, KeyValue>,
          ),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$QoESenseDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValue>(table),
                  BaseReferences<_$QoESenseDatabase, $KeyValuesTable, KeyValue>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$QoESenseDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$QoESenseDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;

class $QoESenseDatabaseManager {
  final _$QoESenseDatabase _db;
  $QoESenseDatabaseManager(this._db);
  $$BufferedSamplesTableTableManager get bufferedSamples =>
      $$BufferedSamplesTableTableManager(_db, _db.bufferedSamples);
  $$PendingMosResponsesTableTableManager get pendingMosResponses =>
      $$PendingMosResponsesTableTableManager(_db, _db.pendingMosResponses);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
}
