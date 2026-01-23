import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

/// Base URL for accessing uploaded files over the web.
/// Change this to your production URL when deploying.
const String _webServerBaseUrl = 'http://13.53.188.175:8082';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isUploading = false;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _resultMessage;
  String? _errorMessage;
  List<String> _uploadedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadUploadedFiles();
  }

  Future<void> _loadUploadedFiles() async {
    try {
      final files = await client.upload.listFiles();
      setState(() {
        _uploadedFiles = files;
      });
    } catch (e) {
      // Ignore errors on initial load
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFileName == null || _selectedFileBytes == null) {
      setState(() {
        _errorMessage = 'Please select a file first';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _resultMessage = null;
    });

    try {
      final byteData = ByteData.view(_selectedFileBytes!.buffer);
      final uploadedFileName = await client.upload.uploadFile(
        _selectedFileName!,
        byteData,
      );

      setState(() {
        _resultMessage = 'File uploaded: $uploadedFileName';
        _selectedFileName = null;
        _selectedFileBytes = null;
      });

      await _loadUploadedFiles();
    } catch (e) {
      setState(() {
        _errorMessage = 'Upload failed: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      await client.upload.deleteFile(fileName);
      await _loadUploadedFiles();
      setState(() {
        _resultMessage = 'File deleted: $fileName';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Delete failed: $e';
      });
    }
  }

  String _getPublicUrl(String fileName) {
    return '$_webServerBaseUrl/uploads/$fileName';
  }

  Future<void> _copyLink(String fileName) async {
    final url = _getPublicUrl(fileName);
    await Clipboard.setData(ClipboardData(text: url));
    setState(() {
      _resultMessage = 'Link copied: $url';
    });
  }

  Future<void> _openFile(String fileName) async {
    final url = Uri.parse(_getPublicUrl(fileName));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      setState(() {
        _errorMessage = 'Could not open link';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File selection section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload File',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Select File'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _selectedFileName ?? 'No file selected',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedFileBytes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${(_selectedFileBytes!.length / 1024).toStringAsFixed(2)} KB',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isUploading || _selectedFileBytes == null
                        ? null
                        : _uploadFile,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status messages
          if (_resultMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green[100],
              child: Text(_resultMessage!, style: TextStyle(color: Colors.green[800])),
            ),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red[100],
              child: Text(_errorMessage!, style: TextStyle(color: Colors.red[800])),
            ),

          const SizedBox(height: 16),

          // Uploaded files list
          const Text(
            'Uploaded Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _uploadedFiles.isEmpty
                ? const Center(child: Text('No files uploaded yet'))
                : ListView.builder(
                    itemCount: _uploadedFiles.length,
                    itemBuilder: (context, index) {
                      final fileName = _uploadedFiles[index];
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(fileName, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          _getPublicUrl(fileName),
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openFile(fileName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.link, color: Colors.green),
                              onPressed: () => _copyLink(fileName),
                              tooltip: 'Copy Link',
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_browser, color: Colors.blue),
                              onPressed: () => _openFile(fileName),
                              tooltip: 'Open in Browser',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteFile(fileName),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
