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

/// Main model for storing Adex video processing jobs and results
abstract class AdexModel
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AdexModel._({
    this.id,
    required this.videoUrl,
    required this.processingId,
    required this.userPrompt,
    this.whatDoesThisVideoContain,
    this.suggestFramesToExtract,
    bool? extractToText,
    this.extractedDataInformationPrompt,
    String? status,
    this.frameTypesJson,
    this.extractedFrames,
    this.extractedText,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : extractToText = extractToText ?? false,
       status = status ?? 'pending',
       createdAt = createdAt ?? DateTime.now();

  factory AdexModel({
    int? id,
    required String videoUrl,
    required String processingId,
    required String userPrompt,
    String? whatDoesThisVideoContain,
    String? suggestFramesToExtract,
    bool? extractToText,
    String? extractedDataInformationPrompt,
    String? status,
    String? frameTypesJson,
    String? extractedFrames,
    String? extractedText,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) = _AdexModelImpl;

  factory AdexModel.fromJson(Map<String, dynamic> jsonSerialization) {
    return AdexModel(
      id: jsonSerialization['id'] as int?,
      videoUrl: jsonSerialization['videoUrl'] as String,
      processingId: jsonSerialization['processingId'] as String,
      userPrompt: jsonSerialization['userPrompt'] as String,
      whatDoesThisVideoContain:
          jsonSerialization['whatDoesThisVideoContain'] as String?,
      suggestFramesToExtract:
          jsonSerialization['suggestFramesToExtract'] as String?,
      extractToText: jsonSerialization['extractToText'] as bool?,
      extractedDataInformationPrompt:
          jsonSerialization['extractedDataInformationPrompt'] as String?,
      status: jsonSerialization['status'] as String?,
      frameTypesJson: jsonSerialization['frameTypesJson'] as String?,
      extractedFrames: jsonSerialization['extractedFrames'] as String?,
      extractedText: jsonSerialization['extractedText'] as String?,
      errorMessage: jsonSerialization['errorMessage'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
    );
  }

  static final t = AdexModelTable();

  static const db = AdexModelRepository._();

  @override
  int? id;

  /// URL to the uploaded video file
  String videoUrl;

  /// Unique processing ID for this job
  String processingId;

  /// User's prompt describing what to extract from the video
  String userPrompt;

  /// Optional context about what the video contains
  String? whatDoesThisVideoContain;

  /// Optional hints for frame extraction (stored as JSON array)
  String? suggestFramesToExtract;

  /// Whether to extract text from the identified frames
  bool extractToText;

  /// Prompt for text extraction (required if extractToText is true)
  String? extractedDataInformationPrompt;

  /// Processing status: pending, processing, completed, failed
  String status;

  /// Nova 2 Lite-generated frame types JSON
  String? frameTypesJson;

  /// Extracted frames data as JSON with frame type, description, count, and URLs
  String? extractedFrames;

  /// Extracted text from frames (if extractToText was true)
  String? extractedText;

  /// Error message if processing failed
  String? errorMessage;

  /// When this job was created
  DateTime createdAt;

  /// When processing was completed
  DateTime? completedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AdexModel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AdexModel copyWith({
    int? id,
    String? videoUrl,
    String? processingId,
    String? userPrompt,
    String? whatDoesThisVideoContain,
    String? suggestFramesToExtract,
    bool? extractToText,
    String? extractedDataInformationPrompt,
    String? status,
    String? frameTypesJson,
    String? extractedFrames,
    String? extractedText,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AdexModel',
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'processingId': processingId,
      'userPrompt': userPrompt,
      if (whatDoesThisVideoContain != null)
        'whatDoesThisVideoContain': whatDoesThisVideoContain,
      if (suggestFramesToExtract != null)
        'suggestFramesToExtract': suggestFramesToExtract,
      'extractToText': extractToText,
      if (extractedDataInformationPrompt != null)
        'extractedDataInformationPrompt': extractedDataInformationPrompt,
      'status': status,
      if (frameTypesJson != null) 'frameTypesJson': frameTypesJson,
      if (extractedFrames != null) 'extractedFrames': extractedFrames,
      if (extractedText != null) 'extractedText': extractedText,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'createdAt': createdAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AdexModel',
      if (id != null) 'id': id,
      'videoUrl': videoUrl,
      'processingId': processingId,
      'userPrompt': userPrompt,
      if (whatDoesThisVideoContain != null)
        'whatDoesThisVideoContain': whatDoesThisVideoContain,
      if (suggestFramesToExtract != null)
        'suggestFramesToExtract': suggestFramesToExtract,
      'extractToText': extractToText,
      if (extractedDataInformationPrompt != null)
        'extractedDataInformationPrompt': extractedDataInformationPrompt,
      'status': status,
      if (frameTypesJson != null) 'frameTypesJson': frameTypesJson,
      if (extractedFrames != null) 'extractedFrames': extractedFrames,
      if (extractedText != null) 'extractedText': extractedText,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'createdAt': createdAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
    };
  }

  static AdexModelInclude include() {
    return AdexModelInclude._();
  }

  static AdexModelIncludeList includeList({
    _i1.WhereExpressionBuilder<AdexModelTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AdexModelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AdexModelTable>? orderByList,
    AdexModelInclude? include,
  }) {
    return AdexModelIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AdexModel.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AdexModel.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AdexModelImpl extends AdexModel {
  _AdexModelImpl({
    int? id,
    required String videoUrl,
    required String processingId,
    required String userPrompt,
    String? whatDoesThisVideoContain,
    String? suggestFramesToExtract,
    bool? extractToText,
    String? extractedDataInformationPrompt,
    String? status,
    String? frameTypesJson,
    String? extractedFrames,
    String? extractedText,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
  }) : super._(
         id: id,
         videoUrl: videoUrl,
         processingId: processingId,
         userPrompt: userPrompt,
         whatDoesThisVideoContain: whatDoesThisVideoContain,
         suggestFramesToExtract: suggestFramesToExtract,
         extractToText: extractToText,
         extractedDataInformationPrompt: extractedDataInformationPrompt,
         status: status,
         frameTypesJson: frameTypesJson,
         extractedFrames: extractedFrames,
         extractedText: extractedText,
         errorMessage: errorMessage,
         createdAt: createdAt,
         completedAt: completedAt,
       );

  /// Returns a shallow copy of this [AdexModel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AdexModel copyWith({
    Object? id = _Undefined,
    String? videoUrl,
    String? processingId,
    String? userPrompt,
    Object? whatDoesThisVideoContain = _Undefined,
    Object? suggestFramesToExtract = _Undefined,
    bool? extractToText,
    Object? extractedDataInformationPrompt = _Undefined,
    String? status,
    Object? frameTypesJson = _Undefined,
    Object? extractedFrames = _Undefined,
    Object? extractedText = _Undefined,
    Object? errorMessage = _Undefined,
    DateTime? createdAt,
    Object? completedAt = _Undefined,
  }) {
    return AdexModel(
      id: id is int? ? id : this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      processingId: processingId ?? this.processingId,
      userPrompt: userPrompt ?? this.userPrompt,
      whatDoesThisVideoContain: whatDoesThisVideoContain is String?
          ? whatDoesThisVideoContain
          : this.whatDoesThisVideoContain,
      suggestFramesToExtract: suggestFramesToExtract is String?
          ? suggestFramesToExtract
          : this.suggestFramesToExtract,
      extractToText: extractToText ?? this.extractToText,
      extractedDataInformationPrompt: extractedDataInformationPrompt is String?
          ? extractedDataInformationPrompt
          : this.extractedDataInformationPrompt,
      status: status ?? this.status,
      frameTypesJson: frameTypesJson is String?
          ? frameTypesJson
          : this.frameTypesJson,
      extractedFrames: extractedFrames is String?
          ? extractedFrames
          : this.extractedFrames,
      extractedText: extractedText is String?
          ? extractedText
          : this.extractedText,
      errorMessage: errorMessage is String? ? errorMessage : this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
    );
  }
}

class AdexModelUpdateTable extends _i1.UpdateTable<AdexModelTable> {
  AdexModelUpdateTable(super.table);

  _i1.ColumnValue<String, String> videoUrl(String value) => _i1.ColumnValue(
    table.videoUrl,
    value,
  );

  _i1.ColumnValue<String, String> processingId(String value) => _i1.ColumnValue(
    table.processingId,
    value,
  );

  _i1.ColumnValue<String, String> userPrompt(String value) => _i1.ColumnValue(
    table.userPrompt,
    value,
  );

  _i1.ColumnValue<String, String> whatDoesThisVideoContain(String? value) =>
      _i1.ColumnValue(
        table.whatDoesThisVideoContain,
        value,
      );

  _i1.ColumnValue<String, String> suggestFramesToExtract(String? value) =>
      _i1.ColumnValue(
        table.suggestFramesToExtract,
        value,
      );

  _i1.ColumnValue<bool, bool> extractToText(bool value) => _i1.ColumnValue(
    table.extractToText,
    value,
  );

  _i1.ColumnValue<String, String> extractedDataInformationPrompt(
    String? value,
  ) => _i1.ColumnValue(
    table.extractedDataInformationPrompt,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> frameTypesJson(String? value) =>
      _i1.ColumnValue(
        table.frameTypesJson,
        value,
      );

  _i1.ColumnValue<String, String> extractedFrames(String? value) =>
      _i1.ColumnValue(
        table.extractedFrames,
        value,
      );

  _i1.ColumnValue<String, String> extractedText(String? value) =>
      _i1.ColumnValue(
        table.extractedText,
        value,
      );

  _i1.ColumnValue<String, String> errorMessage(String? value) =>
      _i1.ColumnValue(
        table.errorMessage,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );
}

class AdexModelTable extends _i1.Table<int?> {
  AdexModelTable({super.tableRelation}) : super(tableName: 'adex_models') {
    updateTable = AdexModelUpdateTable(this);
    videoUrl = _i1.ColumnString(
      'videoUrl',
      this,
    );
    processingId = _i1.ColumnString(
      'processingId',
      this,
    );
    userPrompt = _i1.ColumnString(
      'userPrompt',
      this,
    );
    whatDoesThisVideoContain = _i1.ColumnString(
      'whatDoesThisVideoContain',
      this,
    );
    suggestFramesToExtract = _i1.ColumnString(
      'suggestFramesToExtract',
      this,
    );
    extractToText = _i1.ColumnBool(
      'extractToText',
      this,
      hasDefault: true,
    );
    extractedDataInformationPrompt = _i1.ColumnString(
      'extractedDataInformationPrompt',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
      hasDefault: true,
    );
    frameTypesJson = _i1.ColumnString(
      'frameTypesJson',
      this,
    );
    extractedFrames = _i1.ColumnString(
      'extractedFrames',
      this,
    );
    extractedText = _i1.ColumnString(
      'extractedText',
      this,
    );
    errorMessage = _i1.ColumnString(
      'errorMessage',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
  }

  late final AdexModelUpdateTable updateTable;

  /// URL to the uploaded video file
  late final _i1.ColumnString videoUrl;

  /// Unique processing ID for this job
  late final _i1.ColumnString processingId;

  /// User's prompt describing what to extract from the video
  late final _i1.ColumnString userPrompt;

  /// Optional context about what the video contains
  late final _i1.ColumnString whatDoesThisVideoContain;

  /// Optional hints for frame extraction (stored as JSON array)
  late final _i1.ColumnString suggestFramesToExtract;

  /// Whether to extract text from the identified frames
  late final _i1.ColumnBool extractToText;

  /// Prompt for text extraction (required if extractToText is true)
  late final _i1.ColumnString extractedDataInformationPrompt;

  /// Processing status: pending, processing, completed, failed
  late final _i1.ColumnString status;

  /// Nova 2 Lite-generated frame types JSON
  late final _i1.ColumnString frameTypesJson;

  /// Extracted frames data as JSON with frame type, description, count, and URLs
  late final _i1.ColumnString extractedFrames;

  /// Extracted text from frames (if extractToText was true)
  late final _i1.ColumnString extractedText;

  /// Error message if processing failed
  late final _i1.ColumnString errorMessage;

  /// When this job was created
  late final _i1.ColumnDateTime createdAt;

  /// When processing was completed
  late final _i1.ColumnDateTime completedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    videoUrl,
    processingId,
    userPrompt,
    whatDoesThisVideoContain,
    suggestFramesToExtract,
    extractToText,
    extractedDataInformationPrompt,
    status,
    frameTypesJson,
    extractedFrames,
    extractedText,
    errorMessage,
    createdAt,
    completedAt,
  ];
}

class AdexModelInclude extends _i1.IncludeObject {
  AdexModelInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AdexModel.t;
}

class AdexModelIncludeList extends _i1.IncludeList {
  AdexModelIncludeList._({
    _i1.WhereExpressionBuilder<AdexModelTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AdexModel.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AdexModel.t;
}

class AdexModelRepository {
  const AdexModelRepository._();

  /// Returns a list of [AdexModel]s matching the given query parameters.
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
  Future<List<AdexModel>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AdexModelTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AdexModelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AdexModelTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<AdexModel>(
      where: where?.call(AdexModel.t),
      orderBy: orderBy?.call(AdexModel.t),
      orderByList: orderByList?.call(AdexModel.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [AdexModel] matching the given query parameters.
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
  Future<AdexModel?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AdexModelTable>? where,
    int? offset,
    _i1.OrderByBuilder<AdexModelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AdexModelTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<AdexModel>(
      where: where?.call(AdexModel.t),
      orderBy: orderBy?.call(AdexModel.t),
      orderByList: orderByList?.call(AdexModel.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [AdexModel] by its [id] or null if no such row exists.
  Future<AdexModel?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<AdexModel>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [AdexModel]s in the list and returns the inserted rows.
  ///
  /// The returned [AdexModel]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<AdexModel>> insert(
    _i1.Session session,
    List<AdexModel> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<AdexModel>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [AdexModel] and returns the inserted row.
  ///
  /// The returned [AdexModel] will have its `id` field set.
  Future<AdexModel> insertRow(
    _i1.Session session,
    AdexModel row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AdexModel>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AdexModel]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AdexModel>> update(
    _i1.Session session,
    List<AdexModel> rows, {
    _i1.ColumnSelections<AdexModelTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AdexModel>(
      rows,
      columns: columns?.call(AdexModel.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AdexModel]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AdexModel> updateRow(
    _i1.Session session,
    AdexModel row, {
    _i1.ColumnSelections<AdexModelTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AdexModel>(
      row,
      columns: columns?.call(AdexModel.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AdexModel] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AdexModel?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<AdexModelUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AdexModel>(
      id,
      columnValues: columnValues(AdexModel.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AdexModel]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AdexModel>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<AdexModelUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<AdexModelTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AdexModelTable>? orderBy,
    _i1.OrderByListBuilder<AdexModelTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AdexModel>(
      columnValues: columnValues(AdexModel.t.updateTable),
      where: where(AdexModel.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AdexModel.t),
      orderByList: orderByList?.call(AdexModel.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AdexModel]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AdexModel>> delete(
    _i1.Session session,
    List<AdexModel> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AdexModel>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AdexModel].
  Future<AdexModel> deleteRow(
    _i1.Session session,
    AdexModel row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AdexModel>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AdexModel>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<AdexModelTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AdexModel>(
      where: where(AdexModel.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AdexModelTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AdexModel>(
      where: where?.call(AdexModel.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
