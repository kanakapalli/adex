import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:adex_client/adex_client.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../main.dart';

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
  bool _isProcessing = false;
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
      _isProcessing = true;
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
          _isProcessing = false;
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
        _isProcessing = false;
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
      File(_recordedVideoPath!).delete().catchError((_) {});
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

  @override
  Widget build(BuildContext context) {
    return switch (_viewState) {
      MobileViewState.camera => _buildCameraView(),
      MobileViewState.preview => _buildPreviewView(),
      MobileViewState.processing => _buildProcessingView(),
      MobileViewState.results => _buildResultsView(),
      MobileViewState.history => _buildHistoryView(),
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

  // ============ PROCESSING VIEW ============
  Widget _buildProcessingView() {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _processingProgress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white24,
                        color: colors.primary,
                      ),
                      Text(
                        '${(_processingProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _processingStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This may take a moment',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ RESULTS VIEW ============
  Widget _buildResultsView() {
    final colors = Theme.of(context).colorScheme;
    final model = _selectedHistoryModel ?? _result;

    if (model == null) {
      return Scaffold(
        body: Center(child: Text('No results', style: TextStyle(color: colors.onSurface))),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedHistoryModel != null) {
              setState(() {
                _selectedHistoryModel = null;
                _viewState = MobileViewState.history;
              });
            } else {
              _resetToCamera();
            }
          },
        ),
        title: const Text('Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final json = const JsonEncoder.withIndent('  ').convert(model.toJson());
              Clipboard.setData(ClipboardData(text: json));
              _showSnackBar('Copied to clipboard');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success badge
            _buildSuccessCard(colors, model),
            const SizedBox(height: 16),

            // Video player (for results from current session)
            if (_videoPlayerController?.value.isInitialized == true && _selectedHistoryModel == null)
              _buildVideoCard(colors),

            // Extracted frames
            if (model.extractedFrames != null) ...[
              const SizedBox(height: 16),
              _buildFramesCard(colors, model),
            ],

            // Extracted data
            if (model.extractedText != null) ...[
              const SizedBox(height: 16),
              _buildDataCard(colors, model),
            ],

            // Raw JSON
            const SizedBox(height: 16),
            _buildJsonCard(colors, model),

            const SizedBox(height: 24),

            // New capture button
            FilledButton.icon(
              onPressed: _resetToCamera,
              icon: const Icon(Icons.videocam),
              label: const Text('Capture New Video'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ============ HISTORY VIEW ============
  Widget _buildHistoryView() {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _resetToCamera,
        ),
        title: const Text('History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : _models == null || _models!.isEmpty
              ? _buildEmptyHistory(colors)
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _models!.length,
                    itemBuilder: (context, index) {
                      final model = _models![index];
                      return _buildHistoryCard(model, colors);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyHistory(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_open_outlined, size: 48, color: colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No results yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a video to see\nextracted data here',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _resetToCamera,
              icon: const Icon(Icons.videocam),
              label: const Text('Capture Video'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(AdexModel model, ColorScheme colors) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedHistoryModel = model;
            _viewState = MobileViewState.results;
          });
          _initializeNetworkVideoPlayer(model.videoUrl);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusChip(model.status, colors),
                  const Spacer(),
                  Text(
                    _formatDate(model.createdAt),
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                model.userPrompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.tag, size: 14, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      model.processingId.substring(0, 12),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: colors.onSurfaceVariant),
                ],
              ),
            ],
          ),
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

  // ============ RESULT CARDS ============
  Widget _buildSuccessCard(ColorScheme colors, AdexModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.status == 'completed' ? 'Processing Complete' : model.status.toUpperCase(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'ID: ${model.processingId.substring(0, 12)}...',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: GestureDetector(
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
                if (!_videoPlayerController!.value.isPlaying)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFramesCard(ColorScheme colors, AdexModel model) {
    List<dynamic> frames;
    try {
      frames = jsonDecode(model.extractedFrames!) as List<dynamic>;
    } catch (e) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              const Text('Extracted Frames', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ...frames.map((frame) {
            final f = frame as Map<String, dynamic>;
            final frameType = f['frameType'] as String;
            final urls = (f['extractedFrameUrls'] as List<dynamic>).cast<String>();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      frameType.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showImageViewer(urls[index]),
                          child: Container(
                            width: 100,
                            margin: EdgeInsets.only(right: index < urls.length - 1 ? 8 : 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(
                                urls[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.broken_image, color: colors.error),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataCard(ColorScheme colors, AdexModel model) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(model.extractedText!) as Map<String, dynamic>;
    } catch (e) {
      data = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Extracted Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: model.extractedText!));
                  _showSnackBar('Data copied');
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data != null)
            ...data.entries.map((entry) {
              final value = entry.value is Map || entry.value is List
                  ? const JsonEncoder.withIndent('  ').convert(entry.value)
                  : entry.value.toString();

              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  entry.key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      value,
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: colors.onSurface),
                    ),
                  ),
                ],
              );
            })
          else
            Text(model.extractedText!, style: TextStyle(fontSize: 13, color: colors.onSurface)),
        ],
      ),
    );
  }

  Widget _buildJsonCard(ColorScheme colors, AdexModel model) {
    final json = const JsonEncoder.withIndent('  ').convert(model.toJson());

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(Icons.code, size: 20, color: colors.primary),
        title: const Text('Raw JSON', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 250),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colors.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, ColorScheme colors) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
        textColor = const Color(0xFF10B981);
        icon = Icons.check_circle;
        break;
      case 'processing':
        bgColor = colors.primaryContainer;
        textColor = colors.primary;
        icon = Icons.sync;
        break;
      case 'failed':
        bgColor = colors.errorContainer;
        textColor = colors.error;
        icon = Icons.error;
        break;
      default:
        bgColor = colors.surfaceContainerHighest;
        textColor = colors.onSurfaceVariant;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showImageViewer(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
