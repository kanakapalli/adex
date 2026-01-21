import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

/// Endpoint for handling file uploads.
class UploadEndpoint extends Endpoint {
  /// Uploads a file and returns the file path where it was saved.
  ///
  /// [fileName] is the original name of the file.
  /// [fileData] is the binary content of the file.
  Future<String> uploadFile(
    Session session,
    String fileName,
    ByteData fileData,
  ) async {
    // Create uploads directory if it doesn't exist
    final uploadsDir = Directory('uploads');
    if (!await uploadsDir.exists()) {
      await uploadsDir.create(recursive: true);
    }

    // Generate unique filename to avoid collisions
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final uniqueFileName = '${timestamp}_$sanitizedFileName';
    final filePath = '${uploadsDir.path}/$uniqueFileName';

    // Write file to disk
    final file = File(filePath);
    await file.writeAsBytes(fileData.buffer.asUint8List());

    session.log('File uploaded: $uniqueFileName (${fileData.lengthInBytes} bytes)');

    return uniqueFileName;
  }

  /// Lists all uploaded files.
  Future<List<String>> listFiles(Session session) async {
    final uploadsDir = Directory('uploads');
    if (!await uploadsDir.exists()) {
      return [];
    }

    final files = await uploadsDir.list().toList();
    return files
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .toList();
  }

  /// Deletes an uploaded file.
  Future<bool> deleteFile(Session session, String fileName) async {
    final file = File('uploads/$fileName');
    if (await file.exists()) {
      await file.delete();
      session.log('File deleted: $fileName');
      return true;
    }
    return false;
  }

  /// Downloads a file and returns its content as ByteData.
  Future<ByteData?> downloadFile(Session session, String fileName) async {
    final file = File('uploads/$fileName');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      session.log('File downloaded: $fileName (${bytes.length} bytes)');
      return ByteData.view(bytes.buffer);
    }
    return null;
  }
}
