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
import 'package:serverpod_client/serverpod_client.dart' as _i1;

/// Main model for storing Adex video processing jobs and results
abstract class AdexModel implements _i1.SerializableModel {
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

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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
