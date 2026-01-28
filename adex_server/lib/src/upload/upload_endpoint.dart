import 'dart:typed_data';
import 'package:serverpod/serverpod.dart';

import 's3_upload_helper.dart';

/// Endpoint for handling file uploads to S3.
///
/// Primary flow (direct upload — best for large files like videos):
///   1. Client calls [getUploadDescription] to get a presigned S3 URL
///   2. Client uploads directly to S3 using FileUploader
///   3. Client calls [verifyUpload] to confirm
///
/// Fallback flow (server-side upload — no CORS needed):
///   1. Client calls [storeFile] with bytes — server stores to S3
class UploadEndpoint extends Endpoint {
  static const String _storageId = 'public';

  static const bool _enableDebugLogs = true;

  void _log(String message) {
    if (!_enableDebugLogs) return;
    final timestamp = DateTime.now().toIso8601String();
    print('[UPLOAD] [$timestamp] $message');
  }

  // ===========================================================================
  // PRIMARY: Direct upload (client -> S3)
  // ===========================================================================

  /// Step 1: Get a presigned upload description for direct client-to-S3 upload.
  ///
  /// Uses patched S3UploadHelper with correct URL format (s3.region, not s3-region).
  Future<String?> getUploadDescription(
    Session session,
    String storagePath,
  ) async {
    _log('=== getUploadDescription (patched) ===');
    _log('  storagePath: $storagePath');

    try {
      final description = S3UploadHelper.instance.getDirectUploadDescription(
        uploadDst: storagePath,
      );

      _log('  OK: ${description.length} chars');
      _log('  endpoint: ${S3UploadHelper.instance.endpoint}');
      return description;
    } catch (e, st) {
      _log('  EXCEPTION: $e');
      _log('  ${st.toString().split('\n').take(3).join('\n')}');
      rethrow;
    }
  }

  /// Step 3: Verify the direct upload completed.
  /// Uses session.storage which correctly uses AwsS3Client (dot format).
  Future<bool> verifyUpload(
    Session session,
    String storagePath,
  ) async {
    _log('=== verifyUpload ===');
    _log('  storagePath: $storagePath');

    try {
      final result = await session.storage.verifyDirectFileUpload(
        storageId: _storageId,
        path: storagePath,
      );

      _log('  result: $result');
      return result;
    } catch (e, st) {
      _log('  EXCEPTION: $e');
      _log('  ${st.toString().split('\n').take(3).join('\n')}');
      rethrow;
    }
  }

  // ===========================================================================
  // FALLBACK: Server-side upload (client -> server -> S3)
  // ===========================================================================

  /// Uploads file bytes through the server to S3. No CORS needed.
  /// Uses patched S3UploadHelper to avoid the URL format bug.
  /// Returns the public URL on success.
  Future<String?> storeFile(
    Session session,
    String storagePath,
    ByteData fileData,
  ) async {
    _log('=== storeFile (patched) ===');
    _log('  storagePath: $storagePath');
    _log('  size: ${fileData.lengthInBytes} bytes (${(fileData.lengthInBytes / 1024 / 1024).toStringAsFixed(2)} MB)');
    _log('  endpoint: ${S3UploadHelper.instance.endpoint}');

    try {
      final uploadUrl = await S3UploadHelper.instance.uploadData(
        data: fileData,
        uploadDst: storagePath,
      );
      _log('  uploaded to S3: $uploadUrl');

      final publicUrl = S3UploadHelper.instance.getPublicUrl(storagePath);
      _log('  publicUrl: $publicUrl');
      return publicUrl;
    } catch (e, st) {
      _log('  EXCEPTION: $e');
      _log('  ${st.toString().split('\n').take(3).join('\n')}');
      rethrow;
    }
  }

  // ===========================================================================
  // UTILITY
  // ===========================================================================

  /// Gets the public URL for a stored file.
  Future<String?> getPublicUrl(
    Session session,
    String storagePath,
  ) async {
    return S3UploadHelper.instance.getPublicUrl(storagePath);
  }

  /// Lists uploaded files. S3 doesn't support listing via Serverpod.
  Future<List<String>> listFiles(Session session) async {
    return [];
  }

  /// Deletes a file from S3.
  Future<bool> deleteFile(Session session, String storagePath) async {
    _log('=== deleteFile === path: $storagePath');
    try {
      await session.storage.deleteFile(
        storageId: _storageId,
        path: storagePath,
      );
      _log('  deleted');
      return true;
    } catch (e) {
      _log('  FAILED: $e');
      return false;
    }
  }
}
