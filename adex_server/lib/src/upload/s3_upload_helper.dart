import 'dart:convert';
import 'dart:typed_data';

import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:path/path.dart' as p;

/// Patched S3 upload helper that fixes two issues in serverpod_cloud_storage_s3:
///
/// 1. **URL format**: The library uses `s3-region` (hyphen) but newer AWS regions
///    like `eu-north-1` require `s3.region` (dot).
/// 2. **ACL**: The library sets `acl: public-read` per object, but modern S3 buckets
///    have ACLs disabled by default. We omit ACLs and rely on bucket policy instead.
///
/// All other S3 operations (GET, HEAD, DELETE) use `AwsS3Client` which already has
/// the correct dot format, so they work via `session.storage.*`.
class S3UploadHelper {
  static S3UploadHelper? _instance;

  /// Returns the initialized singleton instance.
  /// Must call [initialize] first from `server.dart`.
  static S3UploadHelper get instance {
    if (_instance == null) {
      throw StateError('S3UploadHelper not initialized. Call initialize() in server.dart first.');
    }
    return _instance!;
  }

  /// Initialize the singleton with AWS credentials and bucket config.
  static void initialize({
    required String accessKey,
    required String secretKey,
    required String bucket,
    required String region,
  }) {
    _instance = S3UploadHelper._(
      accessKey: accessKey,
      secretKey: secretKey,
      bucket: bucket,
      region: region,
    );
  }

  final String accessKey;
  final String secretKey;
  final String bucket;
  final String region;

  S3UploadHelper._({
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    required this.region,
  });

  /// The corrected S3 endpoint using dot format (s3.region, not s3-region).
  String get endpoint => 'https://$bucket.s3.$region.amazonaws.com';

  /// Public host for constructing public URLs.
  String get publicHost => '$bucket.s3.$region.amazonaws.com';

  /// Upload byte data to S3. Throws on failure.
  ///
  /// Returns the public URL of the uploaded object.
  /// Does NOT set ACL — relies on bucket policy for public access.
  Future<String> uploadData({
    required ByteData data,
    required String uploadDst,
    String? contentType,
  }) async {
    // Auto-detect content type from file extension if not provided
    final resolvedContentType = contentType ?? _guessContentType(uploadDst);

    final stream = http.ByteStream.fromBytes(data.buffer.asUint8List());
    final length = data.lengthInBytes;

    final uri = Uri.parse(endpoint);
    final req = http.MultipartRequest('POST', uri);
    final multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: p.basename(uploadDst),
      contentType: _parseMediaType(resolvedContentType),
    );

    final policy = _S3Policy.fromPresignedPost(
      uploadDst,
      bucket,
      accessKey,
      15,
      length,
      region: region,
      contentType: resolvedContentType,
    );
    final key = SigV4.calculateSigningKey(
      secretKey,
      policy.datetime,
      region,
      's3',
    );
    final signature = SigV4.calculateSignature(key, policy.encode());

    req.files.add(multipartFile);
    req.fields['key'] = policy.key;
    req.fields['Content-Type'] = resolvedContentType;
    req.fields['X-Amz-Credential'] = policy.credential;
    req.fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    req.fields['X-Amz-Date'] = policy.datetime;
    req.fields['Policy'] = policy.encode();
    req.fields['X-Amz-Signature'] = signature;

    final res = await req.send();

    if (res.statusCode == 204) {
      return '$endpoint/$uploadDst';
    }

    final body = await res.stream.bytesToString();
    throw Exception(
      'S3 upload failed (${res.statusCode} ${res.reasonPhrase}): $body',
    );
  }

  static String _guessContentType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static MediaType _parseMediaType(String contentType) {
    final parts = contentType.split('/');
    return MediaType(parts[0], parts.length > 1 ? parts[1] : 'octet-stream');
  }

  /// Get a direct upload description JSON for client-side uploads.
  ///
  /// The returned JSON string is consumed by `FileUploader` on the client.
  /// Does NOT include ACL — relies on bucket policy for public access.
  String getDirectUploadDescription({
    required String uploadDst,
    Duration expires = const Duration(minutes: 10),
    int maxFileSize = 10 * 1024 * 1024,
  }) {
    final policy = _S3Policy.fromPresignedPost(
      uploadDst,
      bucket,
      accessKey,
      expires.inMinutes,
      maxFileSize,
      region: region,
    );
    final key = SigV4.calculateSigningKey(
      secretKey,
      policy.datetime,
      region,
      's3',
    );
    final signature = SigV4.calculateSignature(key, policy.encode());

    return jsonEncode({
      'url': endpoint,
      'type': 'multipart',
      'field': 'file',
      'file-name': p.basename(uploadDst),
      'request-fields': {
        'key': policy.key,
        'X-Amz-Credential': policy.credential,
        'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
        'X-Amz-Date': policy.datetime,
        'Policy': policy.encode(),
        'X-Amz-Signature': signature,
      },
    });
  }

  /// Construct the public URL for a given storage path.
  String getPublicUrl(String storagePath) {
    return 'https://$publicHost/$storagePath';
  }
}

/// S3 presigned POST policy for SigV4 signing.
///
/// Inlined from serverpod_cloud_storage_s3 to avoid depending on private API.
/// ACL condition removed to support buckets with ACLs disabled (modern default).
class _S3Policy {
  final String expiration;
  final String region;
  final String bucket;
  final String key;
  final String credential;
  final String datetime;
  final int maxFileSize;
  final String? contentType;

  _S3Policy(
    this.key,
    this.bucket,
    this.datetime,
    this.expiration,
    this.credential,
    this.maxFileSize, {
    this.region = 'us-east-1',
    this.contentType,
  });

  factory _S3Policy.fromPresignedPost(
    String key,
    String bucket,
    String accessKeyId,
    int expiryMinutes,
    int maxFileSize, {
    String region = 'us-east-1',
    String? contentType,
  }) {
    final datetime = SigV4.generateDatetime();
    final expiration = (DateTime.now())
        .add(Duration(minutes: expiryMinutes))
        .toUtc()
        .toString()
        .split(' ')
        .join('T');
    final cred =
        '$accessKeyId/${SigV4.buildCredentialScope(datetime, region, 's3')}';

    return _S3Policy(
      key,
      bucket,
      datetime,
      expiration,
      cred,
      maxFileSize,
      region: region,
      contentType: contentType,
    );
  }

  String encode() {
    final bytes = utf8.encode(toString());
    return base64.encode(bytes);
  }

  @override
  String toString() {
    final contentTypeCondition = contentType != null
        ? '\n    {"Content-Type": "$contentType"},'
        : '';
    return '''
{ "expiration": "$expiration",
  "conditions": [
    {"bucket": "$bucket"},
    ["starts-with", "\$key", "$key"],$contentTypeCondition
    ["content-length-range", 1, $maxFileSize],
    {"x-amz-credential": "$credential"},
    {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
    {"x-amz-date": "$datetime" }
  ]
}
''';
  }
}
