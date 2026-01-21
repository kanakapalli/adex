import 'package:adex_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class VideoExtractionScreen extends StatefulWidget {
  const VideoExtractionScreen({super.key});

  @override
  State<VideoExtractionScreen> createState() => _VideoExtractionScreenState();
}

class _VideoExtractionScreenState extends State<VideoExtractionScreen> {
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _outputDirController = TextEditingController();
  bool _textExtraction = false;
  bool _isLoading = false;
  String? _result;
  String? _error;

  String _prettyPrintJson(Map<String, dynamic> json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (e) {
      return jsonEncode(json);
    }
  }

  void _startVideoExtraction() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      // Call the backend API
      // This returns Map<String, dynamic> directly
      final response = await client.videoExtraction.processVideoComplete(
        _videoUrlController.text,
        _outputDirController.text,
        textExtraction: _textExtraction,
      );

      // Convert the Map to JSON with proper formatting
      final jsonResponse = jsonEncode(response);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonResponse));

      setState(() {
        _result = prettyJson;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error Details: $e');
      print('Stack Trace: $stackTrace');
      
      setState(() {
        _error = '''Error: $e

Stack Trace:
$stackTrace''';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Extraction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                labelText: 'Video URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _outputDirController,
              decoration: const InputDecoration(
                labelText: 'Output Directory',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Enable Text Extraction'),
                Switch(
                  value: _textExtraction,
                  onChanged: (value) {
                    setState(() {
                      _textExtraction = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _startVideoExtraction,
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text('Start Extraction'),
            ),
            const SizedBox(height: 16),
            if (_result != null || _error != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Raw Response:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _error!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[800],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _error!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Error copied to clipboard!'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_result != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _result!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _result!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Response copied to clipboard!'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}