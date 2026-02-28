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

abstract class VideoFrameEmbedding implements _i1.SerializableModel {
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

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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

  /// The embedding vector from Amazon Nova 2 Multimodal Embeddings (1024 dimensions)
  _i1.Vector embedding;

  /// Additional metadata as JSON string (optional)
  String? metadata;

  /// When this frame was processed
  DateTime createdAt;

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
