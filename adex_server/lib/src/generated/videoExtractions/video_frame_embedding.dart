/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class VideoFrameEmbedding
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  VideoFrameEmbedding._({
    this.id,
    this.adexModelId,
    required this.videoUrl,
    required this.processingId,
    required this.frameNumber,
    required this.timestamp,
    required this.framePath,
    required this.embedding,
    this.metadata,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory VideoFrameEmbedding({
    int? id,
    int? adexModelId,
    required String videoUrl,
    required String processingId,
    required int frameNumber,
    required double timestamp,
    required String framePath,
    required _i1.Vector embedding,
    String? metadata,
    DateTime? createdAt,
  }) = _VideoFrameEmbeddingImpl;

  factory VideoFrameEmbedding.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoFrameEmbedding(
      id: jsonSerialization['id'] as int?,
      adexModelId: jsonSerialization['adexModelId'] as int?,
      videoUrl: jsonSerialization['videoUrl'] as String,
      processingId: jsonSerialization['processingId'] as String,
      frameNumber: jsonSerialization['frameNumber'] as int,
      timestamp: (jsonSerialization['timestamp'] as num).toDouble(),
      framePath: jsonSerialization['framePath'] as String,
      embedding: _i1.VectorJsonExtension.fromJson(
        jsonSerialization['embedding'],
      ),
      metadata: jsonSerialization['metadata'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = VideoFrameEmbeddingTable();

  static const db = VideoFrameEmbeddingRepository._();

  @override
  int? id;

  /// Foreign key to AdexModel (for linking temp embeddings to a job)
  int? adexModelId;

  /// The source video URL
  String videoUrl;

  /// Unique identifier for this processing run (prevents conflicts if same video processed concurrently)
  String processingId;

  /// Frame number in the video
  int frameNumber;

  /// Timestamp in seconds (with decimals for precision)
  double timestamp;

  /// Path to the frame image file (temporary storage)
  String framePath;

  /// The embedding vector from Vertex AI multimodalembedding@002 (1408 dimensions)
  _i1.Vector embedding;

  /// Additional metadata as JSON string (optional)
  String? metadata;

  /// When this frame was processed
  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [VideoFrameEmbedding]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoFrameEmbedding copyWith({
    int? id,
    int? adexModelId,
    String? videoUrl,
    String? processingId,
    int? frameNumber,
    double? timestamp,
    String? framePath,
    _i1.Vector? embedding,
    String? metadata,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoFrameEmbedding',
      if (id != null) 'id': id,
      if (adexModelId != null) 'adexModelId': adexModelId,
      'videoUrl': videoUrl,
      'processingId': processingId,
      'frameNumber': frameNumber,
      'timestamp': timestamp,
      'framePath': framePath,
      'embedding': embedding.toJson(),
      if (metadata != null) 'metadata': metadata,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VideoFrameEmbedding',
      if (id != null) 'id': id,
      if (adexModelId != null) 'adexModelId': adexModelId,
      'videoUrl': videoUrl,
      'processingId': processingId,
      'frameNumber': frameNumber,
      'timestamp': timestamp,
      'framePath': framePath,
      'embedding': embedding.toJson(),
      if (metadata != null) 'metadata': metadata,
      'createdAt': createdAt.toJson(),
    };
  }

  static VideoFrameEmbeddingInclude include() {
    return VideoFrameEmbeddingInclude._();
  }

  static VideoFrameEmbeddingIncludeList includeList({
    _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoFrameEmbeddingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoFrameEmbeddingTable>? orderByList,
    VideoFrameEmbeddingInclude? include,
  }) {
    return VideoFrameEmbeddingIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VideoFrameEmbedding.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(VideoFrameEmbedding.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VideoFrameEmbeddingImpl extends VideoFrameEmbedding {
  _VideoFrameEmbeddingImpl({
    int? id,
    int? adexModelId,
    required String videoUrl,
    required String processingId,
    required int frameNumber,
    required double timestamp,
    required String framePath,
    required _i1.Vector embedding,
    String? metadata,
    DateTime? createdAt,
  }) : super._(
         id: id,
         adexModelId: adexModelId,
         videoUrl: videoUrl,
         processingId: processingId,
         frameNumber: frameNumber,
         timestamp: timestamp,
         framePath: framePath,
         embedding: embedding,
         metadata: metadata,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [VideoFrameEmbedding]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoFrameEmbedding copyWith({
    Object? id = _Undefined,
    Object? adexModelId = _Undefined,
    String? videoUrl,
    String? processingId,
    int? frameNumber,
    double? timestamp,
    String? framePath,
    _i1.Vector? embedding,
    Object? metadata = _Undefined,
    DateTime? createdAt,
  }) {
    return VideoFrameEmbedding(
      id: id is int? ? id : this.id,
      adexModelId: adexModelId is int? ? adexModelId : this.adexModelId,
      videoUrl: videoUrl ?? this.videoUrl,
      processingId: processingId ?? this.processingId,
      frameNumber: frameNumber ?? this.frameNumber,
      timestamp: timestamp ?? this.timestamp,
      framePath: framePath ?? this.framePath,
      embedding: embedding ?? this.embedding.clone(),
      metadata: metadata is String? ? metadata : this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VideoFrameEmbeddingUpdateTable
    extends _i1.UpdateTable<VideoFrameEmbeddingTable> {
  VideoFrameEmbeddingUpdateTable(super.table);

  _i1.ColumnValue<int, int> adexModelId(int? value) => _i1.ColumnValue(
    table.adexModelId,
    value,
  );

  _i1.ColumnValue<String, String> videoUrl(String value) => _i1.ColumnValue(
    table.videoUrl,
    value,
  );

  _i1.ColumnValue<String, String> processingId(String value) => _i1.ColumnValue(
    table.processingId,
    value,
  );

  _i1.ColumnValue<int, int> frameNumber(int value) => _i1.ColumnValue(
    table.frameNumber,
    value,
  );

  _i1.ColumnValue<double, double> timestamp(double value) => _i1.ColumnValue(
    table.timestamp,
    value,
  );

  _i1.ColumnValue<String, String> framePath(String value) => _i1.ColumnValue(
    table.framePath,
    value,
  );

  _i1.ColumnValue<_i1.Vector, _i1.Vector> embedding(_i1.Vector value) =>
      _i1.ColumnValue(
        table.embedding,
        value,
      );

  _i1.ColumnValue<String, String> metadata(String? value) => _i1.ColumnValue(
    table.metadata,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class VideoFrameEmbeddingTable extends _i1.Table<int?> {
  VideoFrameEmbeddingTable({super.tableRelation})
    : super(tableName: 'video_frame_embeddings') {
    updateTable = VideoFrameEmbeddingUpdateTable(this);
    adexModelId = _i1.ColumnInt(
      'adexModelId',
      this,
    );
    videoUrl = _i1.ColumnString(
      'videoUrl',
      this,
    );
    processingId = _i1.ColumnString(
      'processingId',
      this,
    );
    frameNumber = _i1.ColumnInt(
      'frameNumber',
      this,
    );
    timestamp = _i1.ColumnDouble(
      'timestamp',
      this,
    );
    framePath = _i1.ColumnString(
      'framePath',
      this,
    );
    embedding = _i1.ColumnVector(
      'embedding',
      this,
      dimension: 1408,
    );
    metadata = _i1.ColumnString(
      'metadata',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final VideoFrameEmbeddingUpdateTable updateTable;

  /// Foreign key to AdexModel (for linking temp embeddings to a job)
  late final _i1.ColumnInt adexModelId;

  /// The source video URL
  late final _i1.ColumnString videoUrl;

  /// Unique identifier for this processing run (prevents conflicts if same video processed concurrently)
  late final _i1.ColumnString processingId;

  /// Frame number in the video
  late final _i1.ColumnInt frameNumber;

  /// Timestamp in seconds (with decimals for precision)
  late final _i1.ColumnDouble timestamp;

  /// Path to the frame image file (temporary storage)
  late final _i1.ColumnString framePath;

  /// The embedding vector from Vertex AI multimodalembedding@002 (1408 dimensions)
  late final _i1.ColumnVector embedding;

  /// Additional metadata as JSON string (optional)
  late final _i1.ColumnString metadata;

  /// When this frame was processed
  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    adexModelId,
    videoUrl,
    processingId,
    frameNumber,
    timestamp,
    framePath,
    embedding,
    metadata,
    createdAt,
  ];
}

class VideoFrameEmbeddingInclude extends _i1.IncludeObject {
  VideoFrameEmbeddingInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => VideoFrameEmbedding.t;
}

class VideoFrameEmbeddingIncludeList extends _i1.IncludeList {
  VideoFrameEmbeddingIncludeList._({
    _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(VideoFrameEmbedding.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => VideoFrameEmbedding.t;
}

class VideoFrameEmbeddingRepository {
  const VideoFrameEmbeddingRepository._();

  /// Returns a list of [VideoFrameEmbedding]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<VideoFrameEmbedding>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoFrameEmbeddingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoFrameEmbeddingTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<VideoFrameEmbedding>(
      where: where?.call(VideoFrameEmbedding.t),
      orderBy: orderBy?.call(VideoFrameEmbedding.t),
      orderByList: orderByList?.call(VideoFrameEmbedding.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [VideoFrameEmbedding] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<VideoFrameEmbedding?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable>? where,
    int? offset,
    _i1.OrderByBuilder<VideoFrameEmbeddingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<VideoFrameEmbeddingTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<VideoFrameEmbedding>(
      where: where?.call(VideoFrameEmbedding.t),
      orderBy: orderBy?.call(VideoFrameEmbedding.t),
      orderByList: orderByList?.call(VideoFrameEmbedding.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [VideoFrameEmbedding] by its [id] or null if no such row exists.
  Future<VideoFrameEmbedding?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<VideoFrameEmbedding>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [VideoFrameEmbedding]s in the list and returns the inserted rows.
  ///
  /// The returned [VideoFrameEmbedding]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<VideoFrameEmbedding>> insert(
    _i1.Session session,
    List<VideoFrameEmbedding> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<VideoFrameEmbedding>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [VideoFrameEmbedding] and returns the inserted row.
  ///
  /// The returned [VideoFrameEmbedding] will have its `id` field set.
  Future<VideoFrameEmbedding> insertRow(
    _i1.Session session,
    VideoFrameEmbedding row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<VideoFrameEmbedding>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [VideoFrameEmbedding]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<VideoFrameEmbedding>> update(
    _i1.Session session,
    List<VideoFrameEmbedding> rows, {
    _i1.ColumnSelections<VideoFrameEmbeddingTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<VideoFrameEmbedding>(
      rows,
      columns: columns?.call(VideoFrameEmbedding.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VideoFrameEmbedding]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<VideoFrameEmbedding> updateRow(
    _i1.Session session,
    VideoFrameEmbedding row, {
    _i1.ColumnSelections<VideoFrameEmbeddingTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<VideoFrameEmbedding>(
      row,
      columns: columns?.call(VideoFrameEmbedding.t),
      transaction: transaction,
    );
  }

  /// Updates a single [VideoFrameEmbedding] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<VideoFrameEmbedding?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<VideoFrameEmbeddingUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<VideoFrameEmbedding>(
      id,
      columnValues: columnValues(VideoFrameEmbedding.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [VideoFrameEmbedding]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<VideoFrameEmbedding>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<VideoFrameEmbeddingUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<VideoFrameEmbeddingTable>? orderBy,
    _i1.OrderByListBuilder<VideoFrameEmbeddingTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<VideoFrameEmbedding>(
      columnValues: columnValues(VideoFrameEmbedding.t.updateTable),
      where: where(VideoFrameEmbedding.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(VideoFrameEmbedding.t),
      orderByList: orderByList?.call(VideoFrameEmbedding.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [VideoFrameEmbedding]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<VideoFrameEmbedding>> delete(
    _i1.Session session,
    List<VideoFrameEmbedding> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<VideoFrameEmbedding>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [VideoFrameEmbedding].
  Future<VideoFrameEmbedding> deleteRow(
    _i1.Session session,
    VideoFrameEmbedding row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<VideoFrameEmbedding>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<VideoFrameEmbedding>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<VideoFrameEmbedding>(
      where: where(VideoFrameEmbedding.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<VideoFrameEmbeddingTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<VideoFrameEmbedding>(
      where: where?.call(VideoFrameEmbedding.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
