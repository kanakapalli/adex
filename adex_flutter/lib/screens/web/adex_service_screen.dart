import 'dart:async';
import 'package:adex_client/adex_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../main.dart';
import '_blob_url_stub.dart' if (dart.library.html) '_blob_url_web.dart';
import 'adex_result_view.dart';

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
  bool get isMedium =>
      width >= _Breakpoints.compact && width < _Breakpoints.medium;
  bool get isExpanded =>
      width >= _Breakpoints.medium && width < _Breakpoints.expanded;
  bool get isLarge =>
      width >= _Breakpoints.expanded && width < _Breakpoints.large;
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

class AdexServiceScreen extends StatefulWidget {
  const AdexServiceScreen({super.key});

  @override
  State<AdexServiceScreen> createState() => _AdexServiceScreenState();
}

class _AdexServiceScreenState extends State<AdexServiceScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _userPromptController = TextEditingController(
    text:
        'Extract nutrition facts, ingredients list, product details, and any health claims from this packed food product video',
  );
  final _videoDescriptionController = TextEditingController(
    text:
        'Video of a packed food product showing all sides including front label, back label with nutrition facts and ingredients, and any barcodes or certifications',
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
  final _maxRetriesController = TextEditingController(text: '5');

  // State
  bool _isProcessing = false;
  bool _isPicking = false;
  bool _extractToText = true;
  bool _showAdvancedOptions = false;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _errorMessage;
  AdexModel? _result;
  double _processingProgress = 0.0;
  String _processingStatus = '';
  int _currentStageIndex = -1;

  // Video preview
  VideoPlayerController? _previewController;
  String? _previewBlobUrl;

  // Pulse animation for uploading
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _userPromptController.dispose();
    _videoDescriptionController.dispose();
    _suggestedFramesController.dispose();
    _textExtractionPromptController.dispose();
    _concurrencyController.dispose();
    _delayBetweenBatchesController.dispose();
    _maxRetriesController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _disposePreview();
    super.dispose();
  }

  void _disposePreview() {
    _previewController?.dispose();
    _previewController = null;
    if (_previewBlobUrl != null) {
      revokeBlobUrl(_previewBlobUrl);
      _previewBlobUrl = null;
    }
  }

  Future<void> _initPreview() async {
    _disposePreview();
    if (_selectedFileBytes == null) return;

    final url = createBlobUrl(_selectedFileBytes!, 'video/mp4');
    if (url == null) return;

    _previewBlobUrl = url;
    _previewController = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await _previewController!.initialize();
      await _previewController!.pause();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Preview init error: $e');
    }
  }

  Future<void> _pickVideo() async {
    setState(() => _isPicking = true);
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
        await _initPreview();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: $e';
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
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
      _currentStageIndex = -1;
      _showAdvancedOptions = false;
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

      _updateProgress(0.05, 'Uploading video...', -1);
      await Future.delayed(const Duration(milliseconds: 200));

      _updateProgress(0.1, 'Uploading video to server...', 0);

      debugPrint(
          '[PROCESS] Sending ${_selectedFileBytes!.length} bytes directly to server');

      final progressTimer = _startProgressSimulation();

      try {
        final byteData = ByteData.view(_selectedFileBytes!.buffer);
        final concurrency =
            int.tryParse(_concurrencyController.text.trim()) ?? 5;
        final delayBetweenBatches =
            int.tryParse(_delayBetweenBatchesController.text.trim()) ?? 200;
        final maxRetries =
            int.tryParse(_maxRetriesController.text.trim()) ?? 5;

        final result = await client.adexService.processVideo(
          byteData,
          _userPromptController.text.trim(),
          whatDoesThisVideoContain:
              _videoDescriptionController.text.trim().isNotEmpty
                  ? _videoDescriptionController.text.trim()
                  : null,
          suggestFramesToExtract: suggestedFrames,
          extractToText: _extractToText,
          extractedDataInformationPrompt: _extractToText
              ? _textExtractionPromptController.text.trim()
              : null,
          concurrency: concurrency,
          delayBetweenBatchesMs: delayBetweenBatches,
          maxRetries: maxRetries,
        );

        progressTimer.cancel();
        _updateProgress(1.0, 'Complete!', _stages.length);

        setState(() {
          _result = result;
          _isProcessing = false;
        });

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
    } catch (e, stackTrace) {
      debugPrint('[PROCESS] EXCEPTION: $e');
      debugPrint(
          '[PROCESS] Stack trace: ${stackTrace.toString().split('\n').take(10).join('\n')}');
      setState(() {
        _errorMessage = 'Processing failed: $e';
        _isProcessing = false;
      });
    }
  }

  static const _stages = [
    (0.15, 'Uploading video...', Icons.cloud_upload_outlined),
    (0.30, 'Extracting frames...', Icons.burst_mode_outlined),
    (0.45, 'Generating embeddings...', Icons.hub_outlined),
    (0.60, 'Analyzing content...', Icons.psychology_outlined),
    (0.75, 'Identifying frames...', Icons.image_search_outlined),
    (0.85, 'Extracting data...', Icons.text_snippet_outlined),
    (0.95, 'Finalizing...', Icons.check_circle_outline),
  ];

  Timer _startProgressSimulation() {
    int stageIndex = 1; // start from 1 since 0 (uploading) is already shown
    return Timer.periodic(const Duration(seconds: 6), (timer) {
      if (stageIndex < _stages.length && mounted) {
        final (progress, status, _) = _stages[stageIndex];
        _updateProgress(progress, status, stageIndex);
        stageIndex++;
      }
    });
  }

  void _updateProgress(double progress, String status, int stageIndex) {
    if (mounted) {
      setState(() {
        _processingProgress = progress;
        _processingStatus = status;
        _currentStageIndex = stageIndex;
      });
    }
  }

  void _resetForm() {
    _disposePreview();
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
                // Input Section
                if (_result == null) _buildInputSection(colors),

                // Results Section
                if (_result != null)
                  AdexResultView(
                    result: _result!,
                    onNewPressed: _resetForm,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(ColorScheme colors) {
    if (context.useWideLayout) {
      return _buildDesktopInputSection(colors);
    }
    return _buildMobileInputSection(colors);
  }

  Widget _buildMobileInputSection(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUploadArea(colors),
        const SizedBox(height: 20),
        _buildPromptField(colors),
        const SizedBox(height: 16),
        _buildAdvancedToggle(colors),
        if (_showAdvancedOptions) ...[
          const SizedBox(height: 16),
          _buildAdvancedOptions(colors),
        ],
        const SizedBox(height: 24),
        _buildProcessButton(colors),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(colors),
        ],
        if (_isProcessing) _buildProcessingSection(colors),
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
          _buildDesktopHeader(colors),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildDesktopUploadArea(colors),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPromptField(colors),
                    const SizedBox(height: 20),
                    _buildAdvancedToggle(colors),
                    if (_showAdvancedOptions) ...[
                      const SizedBox(height: 16),
                      _buildAdvancedOptions(colors),
                    ],
                    const SizedBox(height: 28),
                    _buildProcessButton(colors),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(colors),
                    ],
                    if (_isProcessing) _buildProcessingSection(colors),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/logo/banner_bg.png',
        height: 100,
        fit: BoxFit.contain,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Upload Area — with preview, picking animation
  // ---------------------------------------------------------------------------
  Widget _buildDesktopUploadArea(ColorScheme colors) {
    final hasFile = _selectedFileBytes != null;
    final previewReady =
        hasFile && _previewController?.value.isInitialized == true;

    return Container(
      decoration: BoxDecoration(
        color: previewReady
            ? Colors.black
            : hasFile
                ? colors.primaryContainer.withValues(alpha: 0.2)
                : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: previewReady
              ? colors.primary.withValues(alpha: 0.6)
              : hasFile
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.outlineVariant,
          width: previewReady || hasFile ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: previewReady
              ? _previewController!.value.aspectRatio
              : 4 / 3,
          child: _isPicking
              ? _buildPickingOverlay(colors)
              : previewReady
                  ? _buildVideoPreview(colors, isDesktop: true)
                  : hasFile
                      ? _buildPreviewLoading(colors)
                      : _buildEmptyUpload(colors, isDesktop: true),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Upload Area — with preview, picking animation
  // ---------------------------------------------------------------------------
  Widget _buildUploadArea(ColorScheme colors) {
    final hasFile = _selectedFileBytes != null;
    final previewReady =
        hasFile && _previewController?.value.isInitialized == true;

    if (previewReady) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: _previewController!.value.aspectRatio,
            child: _buildVideoPreview(colors, isDesktop: false),
          ),
        ),
      );
    }

    final uploadPadding =
        context.isCompact ? 24.0 : (context.isMedium ? 32.0 : 40.0);

    return Material(
      color: hasFile
          ? colors.primaryContainer.withValues(alpha: 0.3)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _isProcessing ? null : _pickVideo,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(uploadPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFile
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.outlineVariant,
              width: hasFile ? 2 : 1,
            ),
          ),
          child: _isPicking
              ? _buildPickingOverlayCompact(colors)
              : hasFile
                  ? _buildPreviewLoadingCompact(colors)
                  : _buildEmptyUploadCompact(colors),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Upload area states
  // ---------------------------------------------------------------------------

  Widget _buildPickingOverlay(ColorScheme colors) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.3 + (_pulseController.value * 0.4);
        return Container(
          color: colors.primaryContainer.withValues(alpha: opacity),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading video...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickingOverlayCompact(ColorScheme colors) {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading video...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview(ColorScheme colors, {required bool isDesktop}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _previewController!.value.isPlaying
              ? _previewController!.pause()
              : _previewController!.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          VideoPlayer(_previewController!),

          // Play/pause overlay
          AnimatedOpacity(
            opacity: _previewController!.value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Bottom info bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFileName ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_selectedFileBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ChangeVideoChip(
                    onTap: _isProcessing ? null : _pickVideo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewLoading(ColorScheme colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _selectedFileName ?? 'Loading preview...',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${(_selectedFileBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildPreviewLoadingCompact(ColorScheme colors) {
    return Column(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedFileName ?? 'Loading preview...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${(_selectedFileBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEmptyUpload(ColorScheme colors, {required bool isDesktop}) {
    return InkWell(
      onTap: _isProcessing ? null : _pickVideo,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.videocam_rounded,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Drop video here or click to browse',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'MP4, MOV, AVI supported',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUploadCompact(ColorScheme colors) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.videocam_rounded,
            size: 28,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Select video file',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'MP4, MOV, AVI supported',
          style: TextStyle(
            fontSize: 13,
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Form fields
  // ---------------------------------------------------------------------------

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
            hintText:
                'e.g., Extract nutrition facts and ingredients from this product...',
            hintStyle: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5)),
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
      onTap: () =>
          setState(() => _showAdvancedOptions = !_showAdvancedOptions),
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
                color: _extractToText
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _extractToText ? 'Text extraction ON' : 'Text extraction OFF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _extractToText
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
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
        border:
            Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactField(
            colors,
            label: 'Video description',
            controller: _videoDescriptionController,
            hint: 'Describe what the video contains...',
          ),
          const SizedBox(height: 12),
          _buildCompactField(
            colors,
            label: 'Frame types to extract',
            controller: _suggestedFramesController,
            hint: 'nutrition_facts, ingredients, barcode',
          ),
          const SizedBox(height: 16),
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
                onChanged: _isProcessing
                    ? null
                    : (v) => setState(() => _extractToText = v),
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactField(
                  colors,
                  label: 'Max retries (per API call)',
                  controller: _maxRetriesController,
                  hint: '5',
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              style:
                  TextStyle(fontSize: 13, color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Processing Section — with step-by-step progress
  // ---------------------------------------------------------------------------
  Widget _buildProcessingSection(ColorScheme colors) {
    final processingMaxWidth = context.useWideLayout ? 560.0 : double.infinity;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: processingMaxWidth),
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: EdgeInsets.all(context.useWideLayout ? 40 : 28),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // Animated progress ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glowOpacity = 0.1 + (_pulseController.value * 0.2);
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: glowOpacity),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: SizedBox(
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
                );
              },
            ),
            const SizedBox(height: 24),

            // Current status
            Text(
              _processingStatus,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Step indicators
            ..._stages.asMap().entries.map((entry) {
              final index = entry.key;
              final (_, label, icon) = entry.value;
              final isComplete = _currentStageIndex > index;
              final isCurrent = _currentStageIndex == index;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isComplete
                            ? const Color(0xFF10B981)
                            : isCurrent
                                ? colors.primary
                                : colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: isComplete
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : isCurrent
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : Icon(icon, size: 12, color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w400,
                          color: isComplete || isCurrent
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isComplete)
                      const Icon(Icons.check_circle,
                          size: 16, color: Color(0xFF10B981)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helper widget for the "Change" chip on the video preview
// ---------------------------------------------------------------------------
class _ChangeVideoChip extends StatelessWidget {
  final VoidCallback? onTap;
  const _ChangeVideoChip({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Change',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
