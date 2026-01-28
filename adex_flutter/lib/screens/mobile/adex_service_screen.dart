import 'dart:async';
import 'dart:io';
import 'package:adex_client/adex_client.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../main.dart';
import 'history_screen.dart';
import 'processing_screen.dart';
import 'result_screen.dart';

enum MobileViewState { camera, preview, processing, results, history }

class MobileAdexServiceScreen extends StatefulWidget {
  const MobileAdexServiceScreen({super.key});

  @override
  State<MobileAdexServiceScreen> createState() =>
      _MobileAdexServiceScreenState();
}

class _MobileAdexServiceScreenState extends State<MobileAdexServiceScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // View state
  MobileViewState _viewState = MobileViewState.camera;

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _recordedVideoPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Processing
  double _processingProgress = 0.0;
  String _processingStatus = '';
  AdexModel? _result;
  String? _errorMessage;

  // Video playback
  VideoPlayerController? _videoPlayerController;

  // History
  List<AdexModel>? _models;
  bool _isLoadingHistory = false;
  AdexModel? _selectedHistoryModel;

  // Form controllers - same as desktop
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

  // Rate limiting configuration
  final _concurrencyController = TextEditingController(text: '5');
  final _delayBetweenBatchesController = TextEditingController(text: '200');
  final _maxRetriesController = TextEditingController(text: '5');

  bool _extractToText = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    _recordingTimer?.cancel();
    _userPromptController.dispose();
    _videoDescriptionController.dispose();
    _suggestedFramesController.dispose();
    _textExtractionPromptController.dispose();
    _concurrencyController.dispose();
    _delayBetweenBatchesController.dispose();
    _maxRetriesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      if (_viewState == MobileViewState.camera) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _errorMessage = 'No cameras available');
        return;
      }

      final backCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || _isRecording) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;

    try {
      _recordingTimer?.cancel();
      final file = await _cameraController!.stopVideoRecording();

      setState(() {
        _isRecording = false;
        _recordedVideoPath = file.path;
        _viewState = MobileViewState.preview;
      });

      _initializeVideoPlayer(file.path);
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = 'Failed to stop recording: $e';
      });
    }
  }

  Future<void> _initializeVideoPlayer(String path) async {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(File(path));

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.setLooping(true);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video player error: $e');
    }
  }

  Future<void> _initializeNetworkVideoPlayer(String url) async {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.setLooping(true);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video player error: $e');
    }
  }

  Future<void> _processVideo() async {
    if (_recordedVideoPath == null) return;

    setState(() {
      _viewState = MobileViewState.processing;
      _errorMessage = null;
      _result = null;
      _processingProgress = 0.0;
      _processingStatus = 'Preparing video...';
    });

    try {
      final file = File(_recordedVideoPath!);
      final bytes = await file.readAsBytes();

      _updateProgress(0.1, 'Uploading video...');

      final progressTimer = _startProgressSimulation();

      try {
        final byteData = ByteData.view(bytes.buffer);

        List<String>? suggestedFrames;
        if (_suggestedFramesController.text.trim().isNotEmpty) {
          suggestedFrames = _suggestedFramesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        final concurrency = int.tryParse(_concurrencyController.text.trim()) ?? 5;
        final delayBetweenBatches = int.tryParse(_delayBetweenBatchesController.text.trim()) ?? 200;
        final maxRetries = int.tryParse(_maxRetriesController.text.trim()) ?? 5;

        final result = await client.adexService.processVideo(
          byteData,
          _userPromptController.text.trim(),
          whatDoesThisVideoContain: _videoDescriptionController.text.trim().isNotEmpty
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
        _updateProgress(1.0, 'Complete!');

        setState(() {
          _result = result;
          _viewState = MobileViewState.results;
        });

        _initializeNetworkVideoPlayer(result.videoUrl);
      } catch (e) {
        progressTimer.cancel();
        rethrow;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Processing failed: $e';
        _viewState = MobileViewState.preview;
      });
    }
  }

  Timer _startProgressSimulation() {
    final stages = [
      (0.25, 'Extracting frames...'),
      (0.40, 'Generating embeddings...'),
      (0.55, 'Analyzing content...'),
      (0.70, 'Identifying products...'),
      (0.85, 'Extracting text...'),
      (0.95, 'Finalizing...'),
    ];

    int stageIndex = 0;
    return Timer.periodic(const Duration(seconds: 5), (timer) {
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

  void _resetToCamera() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;

    if (_recordedVideoPath != null) {
      File(_recordedVideoPath!).delete().ignore();
    }

    setState(() {
      _recordedVideoPath = null;
      _result = null;
      _errorMessage = null;
      _recordingDuration = Duration.zero;
      _selectedHistoryModel = null;
      _viewState = MobileViewState.camera;
    });

    _initializeCamera();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _viewState = MobileViewState.history;
    });

    try {
      final models = await client.adexService.getAllAdexModels();
      setState(() {
        _models = models;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load history: $e';
        _isLoadingHistory = false;
      });
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSettingsSheet(),
    );
  }

  void _handleResultBack() {
    if (_selectedHistoryModel != null) {
      setState(() {
        _selectedHistoryModel = null;
        _viewState = MobileViewState.history;
      });
    } else {
      _resetToCamera();
    }
  }

  void _handleHistoryItemTap(AdexModel model) {
    setState(() {
      _selectedHistoryModel = model;
      _viewState = MobileViewState.results;
    });
    _initializeNetworkVideoPlayer(model.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_viewState) {
      MobileViewState.camera => _buildCameraView(),
      MobileViewState.preview => _buildPreviewView(),
      MobileViewState.processing => ProcessingScreen(
        progress: _processingProgress,
        status: _processingStatus,
        onCancel: _resetToCamera,
      ),
      MobileViewState.results => ResultScreen(
        model: _selectedHistoryModel ?? _result!,
        videoController: _videoPlayerController,
        onNewCapture: _resetToCamera,
        onBack: _handleResultBack,
        isFromHistory: _selectedHistoryModel != null,
      ),
      MobileViewState.history => HistoryScreen(
        models: _models,
        isLoading: _isLoadingHistory,
        onBack: _resetToCamera,
        onRefresh: _loadHistory,
        onItemTap: _handleHistoryItemTap,
        onCaptureVideo: _resetToCamera,
      ),
    };
  }

  // ============ CAMERA VIEW ============
  Widget _buildCameraView() {
    final colors = Theme.of(context).colorScheme;

    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Initializing camera...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview
            CameraPreview(_cameraController!),

            // Top overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: colors.primary),
                          const SizedBox(width: 6),
                          const Text(
                            'Adex',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Recording indicator
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // History button
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.white),
                        onPressed: _loadHistory,
                      ),
                  ],
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _isRecording
                          ? 'Recording... Tap to stop'
                          : 'Tap to record product video',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    // Record button with settings beside it
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Settings button (left side)
                        if (!_isRecording)
                          GestureDetector(
                            onTap: _showSettings,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 50),

                        const SizedBox(width: 32),

                        // Record button (center)
                        GestureDetector(
                          onTap: _isRecording ? _stopRecording : _startRecording,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isRecording ? 80 : 72,
                            height: _isRecording ? 80 : 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _isRecording ? 32 : 56,
                                height: _isRecording ? 32 : 56,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(_isRecording ? 8 : 28),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 32),

                        // Placeholder for symmetry (right side)
                        const SizedBox(width: 50),
                      ],
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

  // ============ PREVIEW VIEW ============
  Widget _buildPreviewView() {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video preview
            if (_videoPlayerController?.value.isInitialized == true)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _videoPlayerController!.value.isPlaying
                        ? _videoPlayerController!.pause()
                        : _videoPlayerController!.play();
                  });
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoPlayerController!),
                        if (!_videoPlayerController!.value.isPlaying)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _resetToCamera,
                    ),
                    const Expanded(
                      child: Text(
                        'Preview',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: _showSettings,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prompt preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userPromptController.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                            onPressed: _showSettings,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: colors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: colors.onErrorContainer, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetToCamera,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _processVideo,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Process'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
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

  // ============ SETTINGS SHEET ============
  Widget _buildSettingsSheet() {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Main Prompt
                    _buildSettingsField(
                      colors,
                      label: 'What to extract',
                      controller: _userPromptController,
                      hint: 'Describe what you want to extract...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Video Description
                    _buildSettingsField(
                      colors,
                      label: 'Video description',
                      controller: _videoDescriptionController,
                      hint: 'Describe what the video contains...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Suggested Frames
                    _buildSettingsField(
                      colors,
                      label: 'Frame types to extract',
                      controller: _suggestedFramesController,
                      hint: 'nutrition_facts, ingredients, barcode',
                    ),
                    const SizedBox(height: 20),

                    // Text Extraction Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Extract text from frames',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Use AI to read text content',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _extractToText,
                            onChanged: (v) => setState(() => _extractToText = v),
                          ),
                        ],
                      ),
                    ),

                    if (_extractToText) ...[
                      const SizedBox(height: 20),
                      _buildSettingsField(
                        colors,
                        label: 'Text extraction prompt',
                        controller: _textExtractionPromptController,
                        hint: 'What text information to extract...',
                        maxLines: 6,
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text(
                      'Performance Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust if you experience rate limiting errors',
                      style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingsField(
                            colors,
                            label: 'Concurrency',
                            controller: _concurrencyController,
                            hint: '5',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSettingsField(
                            colors,
                            label: 'Delay (ms)',
                            controller: _delayBetweenBatchesController,
                            hint: '200',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSettingsField(
                            colors,
                            label: 'Max retries',
                            controller: _maxRetriesController,
                            hint: '5',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsField(
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
