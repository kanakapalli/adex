import 'dart:async';
import 'dart:convert';
import 'package:adex_client/adex_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';

const String _webServerBaseUrl = 'http://13.53.188.175:8082';

/// Responsive breakpoints
class _Breakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;
  static const double large = 1600;
}

extension _ResponsiveExt on BuildContext {
  double get width => MediaQuery.of(this).size.width;
  bool get isCompact => width < _Breakpoints.compact;
  bool get isMedium => width >= _Breakpoints.compact && width < _Breakpoints.medium;
  bool get isExpanded => width >= _Breakpoints.medium && width < _Breakpoints.expanded;
  bool get isLarge => width >= _Breakpoints.expanded && width < _Breakpoints.large;
  bool get isExtraLarge => width >= _Breakpoints.large;

  double get contentPadding {
    if (isCompact) return 16;
    if (isMedium) return 24;
    if (isExpanded) return 32;
    if (isLarge) return 48;
    return 64; // extraLarge
  }

  double get maxResultWidth {
    if (isCompact || isMedium) return double.infinity;
    if (isExpanded) return 1100;
    if (isLarge) return 1400;
    return 1600; // extraLarge
  }

  bool get useWideLayout => width >= _Breakpoints.medium;
}

class VideoTimestamp {
  final Duration timestamp;
  final String label;
  final String? description;
  final Color color;
  final String? thumbnailUrl;

  const VideoTimestamp({
    required this.timestamp,
    required this.label,
    this.description,
    this.color = Colors.blue,
    this.thumbnailUrl,
  });
}

class AdexServiceScreen extends StatefulWidget {
  const AdexServiceScreen({super.key});

  @override
  State<AdexServiceScreen> createState() => _AdexServiceScreenState();
}

class _AdexServiceScreenState extends State<AdexServiceScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _userPromptController = TextEditingController(
    text: 'Extract nutrition facts, ingredients list, product details, and any health claims from this packed food product video',
  );
  final _videoDescriptionController = TextEditingController(
    text: 'Video of a packed food product showing all sides including front label, back label with nutrition facts and ingredients, and any barcodes or certifications',
  );
  final _suggestedFramesController = TextEditingController(
    text: 'nutrition_facts, ingredients_list, product_front, product_back, barcode',
  );
  final _textExtractionPromptController = TextEditingController(
    text: '''Extract the following information from the images:

1. **Product Information**: Brand name, product name, variant/flavor, net weight/volume
2. **Nutrition Facts**: Serving size, calories, total fat, saturated fat, trans fat, cholesterol, sodium, total carbohydrates, dietary fiber, sugars, protein, vitamins and minerals with their %DV
3. **Ingredients**: Complete ingredients list in order
4. **Allergens**: Any allergen warnings (contains wheat, milk, soy, nuts, etc.)
5. **Claims & Certifications**: Health claims, organic, non-GMO, vegan, gluten-free, etc.
6. **Manufacturing Info**: Manufacturer name, address, FSSAI license number, batch number, manufacturing/expiry dates

Return the data in a structured JSON format.''',
  );
  final _scrollController = ScrollController();

  // Rate limiting configuration
  final _concurrencyController = TextEditingController(text: '5');
  final _delayBetweenBatchesController = TextEditingController(text: '200');

  // State
  bool _isProcessing = false;
  bool _extractToText = true;
  bool _showAdvancedOptions = true; // Show advanced options by default to display pre-filled values
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _errorMessage;
  AdexModel? _result;
  double _processingProgress = 0.0;
  String _processingStatus = '';
  VideoPlayerController? _videoPlayerController;
  List<VideoTimestamp> _videoTimestamps = [];
  int? _selectedTimestampIndex;
  String? _selectedFrameUrl; // Track selected frame by URL

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _userPromptController.dispose();
    _videoDescriptionController.dispose();
    _suggestedFramesController.dispose();
    _textExtractionPromptController.dispose();
    _concurrencyController.dispose();
    _delayBetweenBatchesController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
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
        _errorMessage = 'Error picking video: $e';
      });
    }
  }

  Future<void> _processVideo() async {
    if (_selectedFileBytes == null) {
      setState(() => _errorMessage = 'Please select a video first');
      return;
    }

    if (_userPromptController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a user prompt');
      return;
    }

    if (_extractToText && _textExtractionPromptController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a text extraction prompt');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _result = null;
      _processingProgress = 0.0;
      _processingStatus = 'Uploading video...';
    });

    try {
      List<String>? suggestedFrames;
      if (_suggestedFramesController.text.trim().isNotEmpty) {
        suggestedFrames = _suggestedFramesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      _updateProgress(0.05, 'Preparing upload...');
      await Future.delayed(const Duration(milliseconds: 200));

      _updateProgress(0.1, 'Uploading video...');

      final byteData = ByteData.view(_selectedFileBytes!.buffer);
      final uploadedFileName = await client.upload.uploadFile(
        _selectedFileName ?? 'video.mp4',
        byteData,
      );

      _updateProgress(0.2, 'Upload complete!');
      await Future.delayed(const Duration(milliseconds: 300));

      final videoUrl = '/uploads/$uploadedFileName';
      _updateProgress(0.25, 'Processing with AI...');

      final progressTimer = _startProgressSimulation();

      try {
        // Parse rate limiting config
        final concurrency = int.tryParse(_concurrencyController.text.trim()) ?? 5;
        final delayBetweenBatches = int.tryParse(_delayBetweenBatchesController.text.trim()) ?? 200;

        final result = await client.adexService.processVideoFromUrl(
          videoUrl,
          _userPromptController.text.trim(),
          whatDoesThisVideoContain:
              _videoDescriptionController.text.trim().isNotEmpty
                  ? _videoDescriptionController.text.trim()
                  : null,
          suggestFramesToExtract: suggestedFrames,
          extractToText: _extractToText,
          extractedDataInformationPrompt:
              _extractToText ? _textExtractionPromptController.text.trim() : null,
          concurrency: concurrency,
          delayBetweenBatchesMs: delayBetweenBatches,
        );

        progressTimer.cancel();
        _updateProgress(1.0, 'Complete!');

        setState(() {
          _result = result;
          _isProcessing = false;
        });

        _initializeVideoPlayer(result.videoUrl);
        _fadeController.forward(from: 0.0);

        await Future.delayed(const Duration(milliseconds: 200));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      } catch (e) {
        progressTimer.cancel();
        rethrow;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Processing failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    _videoPlayerController?.dispose();
    final fullUrl = videoUrl.startsWith('http') ? videoUrl : '$_webServerBaseUrl$videoUrl';
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.setLooping(true);
      _extractTimestampsFromResult();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video player error: $e');
    }
  }

  void _extractTimestampsFromResult() {
    if (_result == null) return;

    final timestamps = <VideoTimestamp>[];
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF8B5CF6), // Violet
    ];

    if (_result!.extractedFrames != null) {
      try {
        final extractedFrames = jsonDecode(_result!.extractedFrames!) as List<dynamic>;

        for (int i = 0; i < extractedFrames.length; i++) {
          final frame = extractedFrames[i] as Map<String, dynamic>;
          final frameType = frame['frameType'] as String;
          final description = frame['description'] as String;
          final urls = (frame['extractedFrameUrls'] as List<dynamic>).cast<String>();
          final frameTimestamps = frame['extractedFrameTimestamps'] as List<dynamic>?;

          double timestampSeconds = 0.0;
          if (frameTimestamps != null && frameTimestamps.isNotEmpty) {
            timestampSeconds = (frameTimestamps.first as num).toDouble();
          }

          String? thumbnailUrl;
          if (urls.isNotEmpty) {
            final rawUrl = urls.first;
            thumbnailUrl = rawUrl.startsWith('http') ? rawUrl : '$_webServerBaseUrl$rawUrl';
          }

          timestamps.add(VideoTimestamp(
            timestamp: Duration(milliseconds: (timestampSeconds * 1000).round()),
            label: frameType.replaceAll('_', ' '),
            description: description,
            color: colors[i % colors.length],
            thumbnailUrl: thumbnailUrl,
          ));
        }

        timestamps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      } catch (e) {
        debugPrint('Error extracting timestamps: $e');
      }
    }

    _videoTimestamps = timestamps;
  }

  void _seekToTimestamp(int index) {
    if (_videoPlayerController == null || index >= _videoTimestamps.length) return;
    final timestamp = _videoTimestamps[index];
    _videoPlayerController!.seekTo(timestamp.timestamp);
    _videoPlayerController!.pause();
    setState(() => _selectedTimestampIndex = index);
  }

  Timer _startProgressSimulation() {
    final stages = [
      (0.30, 'Extracting frames...'),
      (0.45, 'Generating embeddings...'),
      (0.60, 'Analyzing content...'),
      (0.75, 'Identifying frames...'),
      (0.85, 'Extracting data...'),
      (0.95, 'Finalizing...'),
    ];

    int stageIndex = 0;
    return Timer.periodic(const Duration(seconds: 6), (timer) {
      if (stageIndex < stages.length && mounted) {
        final (progress, status) = stages[stageIndex];
        _updateProgress(progress, status);
        stageIndex++;
      }
    });
  }

  void _updateProgress(double progress, String status) {
    if (mounted) {
      setState(() {
        _processingProgress = progress;
        _processingStatus = status;
      });
    }
  }

  void _resetForm() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _videoTimestamps = [];
    _selectedTimestampIndex = null;
    _selectedFrameUrl = null;
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
      _result = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(context.contentPadding),
          child: Center(
            child: Column(
              children: [
                // Compact header with New button when results exist
                if (_result != null) _buildCompactHeader(colors),

                // Input Section
                if (_result == null) _buildInputSection(colors),

                // Processing Indicator
                if (_isProcessing) _buildProcessingSection(colors),

                // Results Section
                if (_result != null) _buildResultsSection(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 16,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Adex',
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: _resetForm,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(ColorScheme colors) {
    // Use horizontal layout for desktop (840px+)
    if (context.useWideLayout) {
      return _buildDesktopInputSection(colors);
    }
    return _buildMobileInputSection(colors);
  }

  Widget _buildMobileInputSection(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Video Upload
        _buildUploadArea(colors),
        const SizedBox(height: 20),

        // Main Prompt
        _buildPromptField(colors),
        const SizedBox(height: 16),

        // Advanced Options Toggle
        _buildAdvancedToggle(colors),

        // Advanced Options
        if (_showAdvancedOptions) ...[
          const SizedBox(height: 16),
          _buildAdvancedOptions(colors),
        ],

        const SizedBox(height: 24),

        // Process Button
        _buildProcessButton(colors),

        // Error Message
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(colors),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDesktopInputSection(ColorScheme colors) {
    final gap = context.isLarge || context.isExtraLarge ? 40.0 : 32.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.maxResultWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Desktop header
          _buildDesktopHeader(colors),
          const SizedBox(height: 32),

          // Two-column layout: Upload on left, Form on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Video Upload (sticky preview area)
              Expanded(
                flex: 4,
                child: _buildDesktopUploadArea(colors),
              ),
              SizedBox(width: gap),
              // Right column: Form fields
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Prompt
                    _buildPromptField(colors),
                    const SizedBox(height: 20),

                    // Advanced Options Toggle
                    _buildAdvancedToggle(colors),

                    // Advanced Options
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 16),
                      _buildAdvancedOptions(colors),
                    ],

                    const SizedBox(height: 28),

                    // Process Button
                    _buildProcessButton(colors),

                    // Error Message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(colors),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(ColorScheme colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 24,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adex Video Processor',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            Text(
              'Extract data from product videos using AI',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopUploadArea(ColorScheme colors) {
    final hasFile = _selectedFileBytes != null;

    return Container(
      decoration: BoxDecoration(
        color: hasFile ? colors.primaryContainer.withValues(alpha: 0.2) : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFile ? colors.primary.withValues(alpha: 0.4) : colors.outlineVariant,
          width: hasFile ? 2 : 1,
        ),
      ),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: InkWell(
          onTap: _isProcessing ? null : _pickVideo,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: hasFile ? colors.primary : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasFile ? Icons.check_rounded : Icons.videocam_rounded,
                  size: 40,
                  color: hasFile ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                hasFile ? _selectedFileName! : 'Drop video here or click to browse',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: hasFile ? colors.onSurface : colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (hasFile) ...[
                Text(
                  '${(_selectedFileBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isProcessing ? null : _pickVideo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Change video'),
                ),
              ] else ...[
                Text(
                  'MP4, MOV, AVI supported',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea(ColorScheme colors) {
    final hasFile = _selectedFileBytes != null;
    final uploadPadding = context.isCompact ? 24.0 : (context.isMedium ? 32.0 : 40.0);

    return Material(
      color: hasFile ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _isProcessing ? null : _pickVideo,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(uploadPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFile ? colors.primary.withValues(alpha: 0.5) : colors.outlineVariant,
              width: hasFile ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: hasFile ? colors.primary : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasFile ? Icons.check_rounded : Icons.videocam_rounded,
                  size: 28,
                  color: hasFile ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasFile ? _selectedFileName! : 'Select video file',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: hasFile ? colors.onSurface : colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasFile) ...[
                const SizedBox(height: 4),
                Text(
                  '${(_selectedFileBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  'MP4, MOV, AVI supported',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptField(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you want to extract?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _userPromptController,
          enabled: !_isProcessing,
          maxLines: 3,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'e.g., Extract nutrition facts and ingredients from this product...',
            hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle(ColorScheme colors) {
    return InkWell(
      onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Advanced options',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _extractToText ? colors.primaryContainer : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _extractToText ? 'Text extraction ON' : 'Text extraction OFF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _extractToText ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Description
          _buildCompactField(
            colors,
            label: 'Video description',
            controller: _videoDescriptionController,
            hint: 'Describe what the video contains...',
          ),
          const SizedBox(height: 12),

          // Suggested Frames
          _buildCompactField(
            colors,
            label: 'Frame types to extract',
            controller: _suggestedFramesController,
            hint: 'nutrition_facts, ingredients, barcode',
          ),
          const SizedBox(height: 16),

          // Text Extraction Toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extract text from frames',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      'Use AI to read text content',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _extractToText,
                onChanged: _isProcessing ? null : (v) => setState(() => _extractToText = v),
              ),
            ],
          ),

          if (_extractToText) ...[
            const SizedBox(height: 12),
            _buildCompactField(
              colors,
              label: 'Text extraction prompt',
              controller: _textExtractionPromptController,
              hint: 'What text information to extract...',
              maxLines: 3,
            ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Rate Limiting Configuration
          Text(
            'Performance Settings',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust these if you experience rate limiting errors',
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactField(
                  colors,
                  label: 'Concurrency (parallel calls)',
                  controller: _concurrencyController,
                  hint: '5',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactField(
                  colors,
                  label: 'Delay between batches (ms)',
                  controller: _delayBetweenBatchesController,
                  hint: '200',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactField(
    ColorScheme colors, {
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: !_isProcessing,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessButton(ColorScheme colors) {
    final canProcess = !_isProcessing && _selectedFileBytes != null;

    return FilledButton(
      onPressed: canProcess ? _processVideo : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Processing...'),
          ] else ...[
            const Icon(Icons.auto_awesome, size: 20),
            const SizedBox(width: 8),
            const Text('Process Video'),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(fontSize: 13, color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingSection(ColorScheme colors) {
    final processingMaxWidth = context.useWideLayout ? 500.0 : double.infinity;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: processingMaxWidth),
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: EdgeInsets.all(context.useWideLayout ? 48 : 32),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _processingProgress,
                    strokeWidth: 6,
                    backgroundColor: colors.surfaceContainerHighest,
                    color: colors.primary,
                  ),
                  Text(
                    '${(_processingProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _processingStatus,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This may take a few minutes',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(ColorScheme colors) {
    return FadeTransition(
      opacity: _fadeController,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.maxResultWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Header
            _buildSuccessHeader(colors),
            const SizedBox(height: 20),

            // Video + Frames side by side on large screens
            if (context.useWideLayout && _result!.extractedFrames != null)
              _buildVideoFramesSideBySide(colors)
            else
              _buildVideoSection(colors),

            // Other tabs for Data and JSON
            if (_result!.extractedText != null || true) ...[
              const SizedBox(height: 20),
              _buildDataJsonTabs(colors),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFramesSideBySide(ColorScheme colors) {
    // Use larger gap on wider screens
    final gap = context.isLarge || context.isExtraLarge ? 32.0 : 20.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video on the left - slightly smaller
        Expanded(
          flex: 5,
          child: _buildVideoCard(colors),
        ),
        SizedBox(width: gap),
        // Frames on the right - slightly larger for content
        Expanded(
          flex: 6,
          child: _buildFramesCard(colors),
        ),
      ],
    );
  }

  Widget _buildVideoSection(ColorScheme colors) {
    return Column(
      children: [
        _buildVideoCard(colors),
        if (_result!.extractedFrames != null) ...[
          const SizedBox(height: 16),
          _buildFramesCard(colors),
        ],
      ],
    );
  }

  Widget _buildVideoCard(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Video',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Video Player
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: _videoPlayerController?.value.isInitialized == true
                      ? _videoPlayerController!.value.aspectRatio
                      : 16 / 9,
                  child: _videoPlayerController?.value.isInitialized == true
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _videoPlayerController!.value.isPlaying
                                  ? _videoPlayerController!.pause()
                                  : _videoPlayerController!.play();
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoPlayerController!),
                              AnimatedOpacity(
                                opacity: _videoPlayerController!.value.isPlaying ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  color: Colors.black26,
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          color: colors.surfaceContainerHighest,
                          child: Center(
                            child: CircularProgressIndicator(color: colors.primary),
                          ),
                        ),
                ),

                // Progress bar
                if (_videoPlayerController?.value.isInitialized == true)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _videoPlayerController!,
                      builder: (context, value, _) => _buildVideoProgress(value, colors),
                    ),
                  ),

                // Timestamp chips
                if (_videoTimestamps.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildTimestampChips(colors),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFramesCard(ColorScheme colors) {
    final frames = jsonDecode(_result!.extractedFrames!) as List<dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Extracted Frames',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Click to seek',
                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Frame list
          ...frames.asMap().entries.map((entry) {
            final frameIndex = entry.key;
            final frame = entry.value as Map<String, dynamic>;
            final frameType = frame['frameType'] as String;
            final description = frame['description'] as String;
            final urls = (frame['extractedFrameUrls'] as List<dynamic>).cast<String>();
            final timestamps = frame['extractedFrameTimestamps'] as List<dynamic>?;

            return _buildFrameItem(
              frameIndex: frameIndex,
              frameType: frameType,
              description: description,
              urls: urls,
              timestamps: timestamps,
              colors: colors,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFrameItem({
    required int frameIndex,
    required String frameType,
    required String description,
    required List<String> urls,
    required List<dynamic>? timestamps,
    required ColorScheme colors,
  }) {
    // Find the matching timestamp for this frame type
    final matchingTimestamp = _videoTimestamps.isNotEmpty && frameIndex < _videoTimestamps.length
        ? _videoTimestamps[frameIndex]
        : null;
    final isTypeSelected = _selectedTimestampIndex == frameIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTypeSelected ? colors.primaryContainer.withValues(alpha: 0.3) : null,
        borderRadius: BorderRadius.circular(8),
        border: isTypeSelected ? Border.all(color: colors.primary, width: 1.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row - clickable to select this frame type
            InkWell(
              onTap: () => _selectFrameType(frameIndex),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTypeSelected ? colors.primary : colors.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        frameType.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isTypeSelected ? colors.onPrimary : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (matchingTimestamp != null) ...[
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: isTypeSelected ? colors.primary : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(matchingTimestamp.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isTypeSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isTypeSelected ? colors.primary : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${urls.length} frame${urls.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    if (isTypeSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.play_circle_filled, size: 16, color: colors.primary),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (urls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  // Scale thumbnail sizes based on screen width
                  final thumbHeight = context.isCompact ? 80.0 : (context.isMedium ? 90.0 : 100.0);
                  final thumbWidth = context.isCompact ? 110.0 : (context.isMedium ? 130.0 : 150.0);

                  return SizedBox(
                    height: thumbHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final rawUrl = urls[index];
                        final imageUrl = rawUrl.startsWith('http') ? rawUrl : '$_webServerBaseUrl$rawUrl';
                        final isSelected = _selectedFrameUrl == imageUrl;

                        // Get timestamp for this specific frame
                        Duration? frameTimestamp;
                        if (timestamps != null && index < timestamps.length) {
                          frameTimestamp = Duration(
                            milliseconds: ((timestamps[index] as num).toDouble() * 1000).round(),
                          );
                        }

                        return GestureDetector(
                          onTap: () => _selectFrame(imageUrl, frameIndex, frameTimestamp),
                          onLongPress: () => _showImageViewer(imageUrl),
                          child: Container(
                            width: thumbWidth,
                        margin: EdgeInsets.only(right: index < urls.length - 1 ? 8 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? colors.primary : colors.outlineVariant,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.broken_image, size: 20, color: colors.error),
                                ),
                              ),
                              // Selected overlay
                              if (isSelected)
                                Container(
                                  color: colors.primary.withValues(alpha: 0.2),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 16,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              // Timestamp badge
                              if (frameTimestamp != null)
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatDuration(frameTimestamp),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectFrameType(int frameIndex) {
    if (frameIndex < _videoTimestamps.length) {
      _seekToTimestamp(frameIndex);
    }
  }

  void _selectFrame(String imageUrl, int frameIndex, Duration? timestamp) {
    setState(() {
      _selectedFrameUrl = imageUrl;
      _selectedTimestampIndex = frameIndex;
    });

    if (timestamp != null && _videoPlayerController != null) {
      _videoPlayerController!.seekTo(timestamp);
      _videoPlayerController!.pause();
    } else if (frameIndex < _videoTimestamps.length) {
      _seekToTimestamp(frameIndex);
    }
  }

  Widget _buildDataJsonTabs(ColorScheme colors) {
    final hasData = _result!.extractedText != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Data Section
          if (hasData) _buildDataSection(colors),

          // JSON Section
          _buildJsonSection(colors),
        ],
      ),
    );
  }

  Widget _buildDataSection(ColorScheme colors) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(_result!.extractedText!) as Map<String, dynamic>;
    } catch (e) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.data_object, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Extracted Data',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _result!.extractedText!));
                  _showSnackBar('Data copied');
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ...data.entries.map((entry) => _buildDataEntry(entry.key, entry.value, colors)),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildJsonSection(ColorScheme colors) {
    final json = const JsonEncoder.withIndent('  ').convert(_result!.toJson());

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(Icons.code, size: 18, color: colors.primary),
      title: const Text(
        'Raw JSON',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              _showSnackBar('JSON copied');
            },
            icon: const Icon(Icons.copy, size: 16),
            visualDensity: VisualDensity.compact,
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colors.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessHeader(ColorScheme colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF10B981),
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Processing Complete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'ID: ${_result!.processingId.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoProgress(VideoPlayerValue value, ColorScheme colors) {
    final duration = value.duration.inMilliseconds.toDouble();
    if (duration == 0) return const SizedBox.shrink();

    return Column(
      children: [
        // Slider with frame markers
        LayoutBuilder(
          builder: (context, constraints) {
            const sliderHeight = 32.0;
            const sliderPadding = 14.0; // Horizontal padding for slider thumb
            final trackWidth = constraints.maxWidth - (sliderPadding * 2);

            return SizedBox(
              height: sliderHeight,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // The slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: colors.surfaceContainerHighest,
                      thumbColor: colors.primary,
                    ),
                    child: Slider(
                      value: value.position.inMilliseconds.toDouble().clamp(0, duration),
                      min: 0,
                      max: duration,
                      onChanged: (v) => _videoPlayerController!.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),

                  // Frame markers on the track
                  ..._videoTimestamps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final timestamp = entry.value;
                    final isSelected = _selectedTimestampIndex == index;
                    final position = timestamp.timestamp.inMilliseconds / duration;
                    final markerLeft = sliderPadding + (trackWidth * position);
                    final markerSize = isSelected ? 18.0 : 14.0;

                    return Positioned(
                      left: markerLeft - (markerSize / 2),
                      top: (sliderHeight - markerSize) / 2,
                      child: GestureDetector(
                        onTap: () => _seekToTimestamp(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: markerSize,
                          height: markerSize,
                          decoration: BoxDecoration(
                            color: isSelected ? timestamp.color : timestamp.color.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 2.5 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? timestamp.color.withValues(alpha: 0.6)
                                    : Colors.black26,
                                blurRadius: isSelected ? 8 : 3,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(value.position),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              Text(
                _formatDuration(value.duration),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimestampChips(ColorScheme colors) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _videoTimestamps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ts = _videoTimestamps[index];
          final selected = _selectedTimestampIndex == index;

          return ActionChip(
            avatar: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: ts.color,
                shape: BoxShape.circle,
              ),
            ),
            label: Text(
              '${ts.label} ${_formatDuration(ts.timestamp)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            backgroundColor: selected ? ts.color.withValues(alpha: 0.15) : null,
            side: BorderSide(
              color: selected ? ts.color : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
            onPressed: () => _seekToTimestamp(index),
          );
        },
      ),
    );
  }

  Widget _buildDataEntry(String key, dynamic value, ColorScheme colors) {
    final displayValue = value is Map || value is List
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value.toString();

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      title: Text(
        key.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            displayValue,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  void _showImageViewer(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 200,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
