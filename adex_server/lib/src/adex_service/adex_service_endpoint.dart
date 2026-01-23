import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis_auth/auth_io.dart';
import 'package:serverpod/serverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../generated/protocol.dart';

/// AdexService Endpoint for processing videos and extracting frames using RAG
///
/// This endpoint provides:
/// 1. Video upload and AdexModel creation
/// 2. Frame extraction at 2 FPS using FFmpeg
/// 3. Embedding generation using Vertex AI multimodalembedding@001 (1408 dimensions)
/// 4. RAG-based frame type detection and extraction using Gemini
/// 5. Text extraction from frames when extractToText is true
class AdexServiceEndpoint extends Endpoint {
  // ============================================================================
  // CONFIGURATION
  // ============================================================================

  static const int _concurrency = 10; // Process 10 frames concurrently (optimized for speed)
  static const String _projectId = 'weedit-india';
  static const String _location = 'us-central1';

  // Frame extraction configuration
  static const double _framesPerSecond = 2.0; // Extract 2 frames per second

  // Rate limiting configuration (reduced delays since rate limits are handled)
  static const int _maxRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 1);
  static const Duration _delayBetweenBatches = Duration(milliseconds: 100); // Reduced from 500ms

  // Token caching
  static String? _cachedAccessToken;
  static DateTime? _tokenExpiresAt;

  // ============================================================================
  // DEBUG HELPER
  // ============================================================================

  void _debug(String message, {String emoji = '🔵'}) {
    final timestamp = DateTime.now().toIso8601String();
    print('$emoji [$timestamp] $message');
  }

  // ============================================================================
  // RETRY HELPER WITH EXPONENTIAL BACKOFF
  // ============================================================================

  /// Execute an async operation with retry logic and exponential backoff
  /// Handles 429 (rate limit) and 503 (service unavailable) errors
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    String operationName = 'API call',
    int maxRetries = _maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = _initialRetryDelay;

    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        final isRetryable = e.toString().contains('429') ||
            e.toString().contains('RESOURCE_EXHAUSTED') ||
            e.toString().contains('503') ||
            e.toString().contains('overloaded');

        if (!isRetryable || attempt >= maxRetries) {
          _debug('❌ $operationName failed after $attempt attempts: $e', emoji: '❌');
          rethrow;
        }

        _debug('⚠️  $operationName attempt $attempt failed (rate limited), retrying in ${delay.inSeconds}s...', emoji: '🔄');
        await Future.delayed(delay);

        // Exponential backoff with jitter
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2) + (DateTime.now().millisecond % 500),
        );

        // Cap at 60 seconds
        if (delay.inSeconds > 60) {
          delay = const Duration(seconds: 60);
        }
      }
    }
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// Process a video from URL and extract relevant frames based on user prompts
  Future<AdexModel> processVideoFromUrl(
    Session session,
    String videoUrl,
    String userPrompt, {
    String? whatDoesThisVideoContain,
    List<String>? suggestFramesToExtract,
    bool extractToText = false,
    String? extractedDataInformationPrompt,
    int? concurrency,
    int? delayBetweenBatchesMs,
  }) async {
    _debug('🚀 processVideoFromUrl called', emoji: '📥');
    _debug('   📹 videoUrl: $videoUrl', emoji: '📥');
    _debug('   💬 userPrompt: $userPrompt', emoji: '📥');
    _debug('   📝 whatDoesThisVideoContain: $whatDoesThisVideoContain', emoji: '📥');
    _debug('   🎯 suggestFramesToExtract: $suggestFramesToExtract', emoji: '📥');
    _debug('   📄 extractToText: $extractToText', emoji: '📥');
    _debug('   ⚡ concurrency: ${concurrency ?? _concurrency}', emoji: '📥');
    _debug('   ⏱️  delayBetweenBatchesMs: ${delayBetweenBatchesMs ?? _delayBetweenBatches.inMilliseconds}', emoji: '📥');

    return _processVideoInternal(
      session,
      videoUrl,
      userPrompt,
      whatDoesThisVideoContain: whatDoesThisVideoContain,
      suggestFramesToExtract: suggestFramesToExtract,
      extractToText: extractToText,
      extractedDataInformationPrompt: extractedDataInformationPrompt,
      concurrency: concurrency,
      delayBetweenBatchesMs: delayBetweenBatchesMs,
    );
  }

  /// Process a video and extract relevant frames based on user prompts
  Future<AdexModel> processVideo(
    Session session,
    ByteData video,
    String userPrompt, {
    String? whatDoesThisVideoContain,
    List<String>? suggestFramesToExtract,
    bool extractToText = false,
    String? extractedDataInformationPrompt,
  }) async {
    _debug('🚀 processVideo called (with ByteData)', emoji: '📥');
    _debug('   📦 video size: ${video.lengthInBytes} bytes (${(video.lengthInBytes / 1024 / 1024).toStringAsFixed(2)} MB)', emoji: '📥');

    // Generate unique processing ID
    final processingId = '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomId()}';
    _debug('   🆔 Generated processingId: $processingId', emoji: '📥');

    // Upload video first
    _debug('📤 Uploading video...', emoji: '⬆️');
    final videoUrl = await _uploadVideo(session, video, processingId);
    _debug('✅ Video uploaded to: $videoUrl', emoji: '⬆️');

    return _processVideoInternal(
      session,
      videoUrl,
      userPrompt,
      whatDoesThisVideoContain: whatDoesThisVideoContain,
      suggestFramesToExtract: suggestFramesToExtract,
      extractToText: extractToText,
      extractedDataInformationPrompt: extractedDataInformationPrompt,
    );
  }

  /// Internal method to process video from URL
  Future<AdexModel> _processVideoInternal(
    Session session,
    String videoUrl,
    String userPrompt, {
    String? whatDoesThisVideoContain,
    List<String>? suggestFramesToExtract,
    bool extractToText = false,
    String? extractedDataInformationPrompt,
    int? concurrency,
    int? delayBetweenBatchesMs,
  }) async {
    // Use provided values or defaults
    final effectiveConcurrency = concurrency ?? _concurrency;
    final effectiveDelay = delayBetweenBatchesMs != null
        ? Duration(milliseconds: delayBetweenBatchesMs)
        : _delayBetweenBatches;

    final overallTimer = Stopwatch()..start();

    _debug('', emoji: '');
    _debug('╔══════════════════════════════════════════════════════════════╗', emoji: '🎬');
    _debug('║           ADEX VIDEO PROCESSING STARTED                      ║', emoji: '🎬');
    _debug('╚══════════════════════════════════════════════════════════════╝', emoji: '🎬');
    _debug('', emoji: '');

    // Validate inputs
    if (extractToText && (extractedDataInformationPrompt == null || extractedDataInformationPrompt.isEmpty)) {
      _debug('❌ VALIDATION ERROR: extractedDataInformationPrompt is required when extractToText is true', emoji: '🚫');
      throw ArgumentError('extractedDataInformationPrompt is required when extractToText is true');
    }
    _debug('✅ Input validation passed', emoji: '✓');

    // Generate unique processing ID
    final processingId = '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomId()}';

    _debug('📋 Processing Configuration:', emoji: '⚙️');
    _debug('   🆔 Processing ID: $processingId', emoji: '⚙️');
    _debug('   📹 Video URL: $videoUrl', emoji: '⚙️');
    _debug('   💬 User Prompt: ${userPrompt.substring(0, userPrompt.length > 50 ? 50 : userPrompt.length)}...', emoji: '⚙️');
    _debug('   📄 Extract to Text: $extractToText', emoji: '⚙️');
    _debug('   🔢 Concurrency: $effectiveConcurrency frames', emoji: '⚙️');
    _debug('   ⏱️  Delay between batches: ${effectiveDelay.inMilliseconds}ms', emoji: '⚙️');

    session.log('========================================');
    session.log('Starting AdexService video processing...');
    session.log('Processing ID: $processingId');
    session.log('========================================');

    AdexModel? adexModel;
    Directory? tempDir;

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // STEP 1: Create AdexModel entry
      // ═══════════════════════════════════════════════════════════════════════
      _debug('', emoji: '');
      _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '📝');
      _debug('│  STEP 1: Creating AdexModel Database Entry                  │', emoji: '📝');
      _debug('└─────────────────────────────────────────────────────────────┘', emoji: '📝');

      final createTimer = Stopwatch()..start();

      _debug('💾 Inserting AdexModel into database...', emoji: '🗄️');
      adexModel = await AdexModel.db.insertRow(
        session,
        AdexModel(
          videoUrl: videoUrl,
          processingId: processingId,
          userPrompt: userPrompt,
          whatDoesThisVideoContain: whatDoesThisVideoContain,
          suggestFramesToExtract: suggestFramesToExtract != null
              ? jsonEncode(suggestFramesToExtract)
              : null,
          extractToText: extractToText,
          extractedDataInformationPrompt: extractedDataInformationPrompt,
          status: 'processing',
        ),
      );

      createTimer.stop();
      _debug('✅ AdexModel created successfully!', emoji: '✓');
      _debug('   🆔 AdexModel ID: ${adexModel.id}', emoji: '✓');
      _debug('   ⏱️  Time: ${createTimer.elapsedMilliseconds}ms', emoji: '✓');

      // ═══════════════════════════════════════════════════════════════════════
      // STEP 2: Get Access Token
      // ═══════════════════════════════════════════════════════════════════════
      _debug('', emoji: '');
      _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '🔐');
      _debug('│  STEP 2: Fetching Vertex AI Access Token                    │', emoji: '🔐');
      _debug('└─────────────────────────────────────────────────────────────┘', emoji: '🔐');

      final tokenTimer = Stopwatch()..start();
      _debug('🔑 Authenticating with Google Cloud...', emoji: '🔐');
      final accessToken = await _getAccessToken(session);
      tokenTimer.stop();
      _debug('✅ Access token obtained!', emoji: '✓');
      _debug('   🔑 Token: ${accessToken.substring(0, 20)}...', emoji: '✓');
      _debug('   ⏱️  Time: ${tokenTimer.elapsedMilliseconds}ms', emoji: '✓');

      // ═══════════════════════════════════════════════════════════════════════
      // STEP 3: Extract Frames & Generate Embeddings
      // ═══════════════════════════════════════════════════════════════════════
      _debug('', emoji: '');
      _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '🎞️');
      _debug('│  STEP 3: Extracting Frames & Generating Embeddings          │', emoji: '🎞️');
      _debug('└─────────────────────────────────────────────────────────────┘', emoji: '🎞️');

      final embeddingTimer = Stopwatch()..start();

      _debug('📁 Creating temporary directory...', emoji: '📂');
      tempDir = await Directory.systemTemp.createTemp('adex_processing_');
      _debug('   📂 Temp dir: ${tempDir.path}', emoji: '📂');

      final result = await _extractFramesAndGenerateEmbeddings(
        session,
        videoUrl,
        processingId,
        adexModel.id!,
        accessToken,
        tempDir,
        effectiveConcurrency,
        effectiveDelay,
      );

      embeddingTimer.stop();
      _debug('✅ Frame extraction & embedding complete!', emoji: '✓');
      _debug('   🎞️  Total frames: ${result['totalFrames']}', emoji: '✓');
      _debug('   ⏱️  Duration: ${result['duration']}s', emoji: '✓');
      _debug('   ⏱️  Processing time: ${embeddingTimer.elapsed.inSeconds}s', emoji: '✓');

      // ═══════════════════════════════════════════════════════════════════════
      // STEP 4: RAG - Generate Frame Types
      // ═══════════════════════════════════════════════════════════════════════
      _debug('', emoji: '');
      _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '🤖');
      _debug('│  STEP 4: RAG - Generating Frame Types with Gemini           │', emoji: '🤖');
      _debug('└─────────────────────────────────────────────────────────────┘', emoji: '🤖');

      final ragTimer = Stopwatch()..start();

      _debug('🧠 Calling Gemini to analyze frame requirements...', emoji: '🤖');
      final frameTypesJson = await _generateFrameTypes(
        session,
        userPrompt,
        whatDoesThisVideoContain,
        suggestFramesToExtract,
        accessToken,
      );

      _debug('✅ Frame types generated!', emoji: '✓');
      _debug('   📋 Frame Types JSON:', emoji: '✓');
      // Pretty print the JSON
      try {
        final parsed = jsonDecode(frameTypesJson);
        final prettyJson = const JsonEncoder.withIndent('   ').convert(parsed);
        for (final line in prettyJson.split('\n')) {
          _debug('      $line', emoji: '');
        }
      } catch (e) {
        _debug('      $frameTypesJson', emoji: '');
      }

      // Update AdexModel with frame types
      _debug('💾 Updating AdexModel with frame types...', emoji: '🗄️');
      adexModel = await AdexModel.db.updateRow(
        session,
        adexModel.copyWith(frameTypesJson: frameTypesJson),
      );
      _debug('✅ AdexModel updated!', emoji: '✓');

      // ═══════════════════════════════════════════════════════════════════════
      // STEP 5: RAG - Extract Frames
      // ═══════════════════════════════════════════════════════════════════════
      _debug('', emoji: '');
      _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '🔍');
      _debug('│  STEP 5: RAG - Extracting Matching Frames                   │', emoji: '🔍');
      _debug('└─────────────────────────────────────────────────────────────┘', emoji: '🔍');

      _debug('🔍 Searching for matching frames using embeddings...', emoji: '🔍');
      final extractedFramesData = await _extractFramesUsingRag(
        session,
        adexModel.id!,
        processingId,
        frameTypesJson,
        accessToken,
        tempDir,
      );

      ragTimer.stop();
      _debug('✅ RAG frame extraction complete!', emoji: '✓');
      _debug('   📊 Extracted ${extractedFramesData.length} frame types', emoji: '✓');
      _debug('   ⏱️  Time: ${ragTimer.elapsed.inSeconds}s', emoji: '✓');

      // Log extracted frames summary
      for (final frameData in extractedFramesData) {
        _debug('   🖼️  ${frameData['frameType']}: ${(frameData['extractedFrameUrls'] as List).length} frames', emoji: '');
      }

      // Update AdexModel with extracted frames
      _debug('💾 Updating AdexModel with extracted frames...', emoji: '🗄️');
      adexModel = await AdexModel.db.updateRow(
        session,
        adexModel.copyWith(extractedFrames: jsonEncode(extractedFramesData)),
      );
      _debug('✅ AdexModel updated!', emoji: '✓');

      // ═══════════════════════════════════════════════════════════════════════
      // STEP 6: Text Extraction (Optional)
      // ═══════════════════════════════════════════════════════════════════════
      String? extractedText;
      if (extractToText && extractedDataInformationPrompt != null) {
        _debug('', emoji: '');
        _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '📝');
        _debug('│  STEP 6: Extracting Text from Frames with Gemini            │', emoji: '📝');
        _debug('└─────────────────────────────────────────────────────────────┘', emoji: '📝');

        final textTimer = Stopwatch()..start();

        _debug('📖 Extracting text from ${extractedFramesData.length} frame types...', emoji: '📝');
        extractedText = await _extractTextFromFrames(
          session,
          extractedFramesData,
          extractedDataInformationPrompt,
          accessToken,
        );

        textTimer.stop();
        _debug('✅ Text extraction complete!', emoji: '✓');
        _debug('   ⏱️  Time: ${textTimer.elapsed.inSeconds}s', emoji: '✓');

        // Log extracted text preview
        try {
          final parsed = jsonDecode(extractedText);
          _debug('   📋 Extracted data keys: ${(parsed as Map).keys.toList()}', emoji: '✓');
        } catch (e) {
          _debug('   📋 Extracted text length: ${extractedText.length} chars', emoji: '✓');
        }

        _debug('💾 Updating AdexModel with extracted text...', emoji: '🗄️');
        adexModel = await AdexModel.db.updateRow(
          session,
          adexModel.copyWith(extractedText: extractedText),
        );
        _debug('✅ AdexModel updated!', emoji: '✓');
      } else {
        _debug('', emoji: '');
        _debug('⏭️  STEP 6: Skipping text extraction (extractToText=$extractToText)', emoji: '⏭️');
      }

      // ═══════════════════════════════════════════════════════════════════════
      // STEP 7: Cleanup
      // ═══════════════════════════════════════════════════════════════════════
      _debug('', emoji: '');
      _debug('┌─────────────────────────────────────────────────────────────┐', emoji: '🧹');
      _debug('│  STEP 7: Cleaning Up Temporary Data                         │', emoji: '🧹');
      _debug('└─────────────────────────────────────────────────────────────┘', emoji: '🧹');

      _debug('🗑️  Deleting temporary embeddings from database...', emoji: '🧹');
      await _cleanupTemporaryData(session, adexModel.id!, processingId);
      _debug('✅ Cleanup complete!', emoji: '✓');

      // ═══════════════════════════════════════════════════════════════════════
      // COMPLETE
      // ═══════════════════════════════════════════════════════════════════════
      _debug('💾 Marking job as completed...', emoji: '🗄️');
      adexModel = await AdexModel.db.updateRow(
        session,
        adexModel.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
        ),
      );

      overallTimer.stop();

      _debug('', emoji: '');
      _debug('╔══════════════════════════════════════════════════════════════╗', emoji: '🎉');
      _debug('║           🎉 VIDEO PROCESSING COMPLETE! 🎉                   ║', emoji: '🎉');
      _debug('╠══════════════════════════════════════════════════════════════╣', emoji: '🎉');
      _debug('║  📊 Summary:                                                 ║', emoji: '🎉');
      _debug('║     🆔 AdexModel ID: ${adexModel.id.toString().padRight(36)}║', emoji: '🎉');
      _debug('║     ⏱️  Total Time: ${overallTimer.elapsed.inMinutes}m ${overallTimer.elapsed.inSeconds % 60}s'.padRight(63) + '║', emoji: '🎉');
      _debug('║     📹 Status: ${adexModel.status.padRight(42)}║', emoji: '🎉');
      _debug('╚══════════════════════════════════════════════════════════════╝', emoji: '🎉');
      _debug('', emoji: '');

      session.log('========================================');
      session.log('⏱️  TOTAL PROCESSING TIME: ${overallTimer.elapsed.inMinutes}m ${overallTimer.elapsed.inSeconds % 60}s');
      session.log('Video processing complete!');
      session.log('========================================');

      return adexModel;
    } catch (e, stackTrace) {
      _debug('', emoji: '');
      _debug('╔══════════════════════════════════════════════════════════════╗', emoji: '❌');
      _debug('║           ❌ ERROR DURING PROCESSING ❌                       ║', emoji: '❌');
      _debug('╚══════════════════════════════════════════════════════════════╝', emoji: '❌');
      _debug('🚫 Error: $e', emoji: '❌');
      _debug('📚 Stack trace:', emoji: '❌');
      for (final line in stackTrace.toString().split('\n').take(10)) {
        _debug('   $line', emoji: '');
      }

      session.log('Error processing video: $e', level: LogLevel.error);
      session.log('Stack trace: $stackTrace', level: LogLevel.error);

      // Update status to failed
      if (adexModel != null) {
        _debug('💾 Marking job as failed...', emoji: '🗄️');
        adexModel = await AdexModel.db.updateRow(
          session,
          adexModel.copyWith(
            status: 'failed',
            errorMessage: e.toString(),
          ),
        );
      }

      rethrow;
    } finally {
      // Cleanup temp directory
      if (tempDir != null && await tempDir.exists()) {
        try {
          _debug('🗑️  Deleting temp directory: ${tempDir.path}', emoji: '🧹');
          await tempDir.delete(recursive: true);
          _debug('✅ Temp directory deleted', emoji: '✓');
        } catch (e) {
          _debug('⚠️  Warning: Failed to cleanup temp directory: $e', emoji: '⚠️');
          session.log('Warning: Failed to cleanup temp directory: $e', level: LogLevel.warning);
        }
      }
    }
  }

  /// Get the status of a processing job
  Future<AdexModel?> getProcessingStatus(Session session, int adexModelId) async {
    _debug('📊 getProcessingStatus called for ID: $adexModelId', emoji: '📊');
    return await AdexModel.db.findById(session, adexModelId);
  }

  /// Get the status of a processing job by processingId
  Future<AdexModel?> getProcessingStatusByProcessingId(Session session, String processingId) async {
    _debug('📊 getProcessingStatusByProcessingId called for: $processingId', emoji: '📊');
    return await AdexModel.db.findFirstRow(
      session,
      where: (t) => t.processingId.equals(processingId),
    );
  }

  /// Get all AdexModels, ordered by createdAt descending
  Future<List<AdexModel>> getAllAdexModels(Session session) async {
    _debug('📊 getAllAdexModels called', emoji: '📊');
    return await AdexModel.db.find(
      session,
      orderBy: (t) => t.createdAt,
      orderDescending: true,
    );
  }

  // ============================================================================
  // PRIVATE METHODS - Video Upload
  // ============================================================================

  /// Upload video to storage and return URL
  Future<String> _uploadVideo(Session session, ByteData videoData, String processingId) async {
    _debug('📤 _uploadVideo: Starting upload...', emoji: '⬆️');
    _debug('   📦 Size: ${videoData.lengthInBytes} bytes', emoji: '⬆️');

    final uploadsDir = Directory('uploads/videos/$processingId');
    if (!await uploadsDir.exists()) {
      _debug('   📁 Creating directory: ${uploadsDir.path}', emoji: '⬆️');
      await uploadsDir.create(recursive: true);
    }

    final videoFileName = 'video_$processingId.mp4';
    final videoFile = File(path.join(uploadsDir.path, videoFileName));

    _debug('   💾 Writing to: ${videoFile.path}', emoji: '⬆️');
    await videoFile.writeAsBytes(videoData.buffer.asUint8List());

    final resultUrl = '/uploads/videos/$processingId/$videoFileName';
    _debug('   ✅ Upload complete: $resultUrl', emoji: '⬆️');

    return resultUrl;
  }

  // ============================================================================
  // PRIVATE METHODS - Frame Extraction & Embedding
  // ============================================================================

  /// Extract frames at 2 FPS and generate embeddings
  Future<Map<String, dynamic>> _extractFramesAndGenerateEmbeddings(
    Session session,
    String videoUrl,
    String processingId,
    int adexModelId,
    String accessToken,
    Directory tempDir,
    int concurrency,
    Duration delayBetweenBatches,
  ) async {
    _debug('🎞️  _extractFramesAndGenerateEmbeddings: Starting...', emoji: '🎬');

    final framesDir = Directory(path.join(tempDir.path, 'frames'));
    await framesDir.create();
    _debug('   📁 Frames directory: ${framesDir.path}', emoji: '🎬');

    // Get video file path from URL
    final videoPath = videoUrl.startsWith('/')
        ? videoUrl.substring(1)
        : videoUrl;
    _debug('   📹 Video path: $videoPath', emoji: '🎬');

    // Check if video file exists locally
    File videoFile;
    if (await File(videoPath).exists()) {
      _debug('   ✅ Video file found locally', emoji: '🎬');
      videoFile = File(videoPath);
    } else {
      _debug('   ⬇️  Video not local, downloading from: $videoUrl', emoji: '🎬');
      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) {
        _debug('   ❌ Download failed: ${response.statusCode}', emoji: '❌');
        throw Exception('Failed to download video: ${response.statusCode}');
      }
      videoFile = File(path.join(tempDir.path, 'video.mp4'));
      await videoFile.writeAsBytes(response.bodyBytes);
      _debug('   ✅ Video downloaded: ${videoFile.path}', emoji: '🎬');
    }

    // Get video duration
    _debug('   ⏱️  Getting video duration with ffprobe...', emoji: '🎬');
    final durationResult = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      videoFile.path,
    ]);

    final duration = double.parse(durationResult.stdout.toString().trim());
    _debug('   📊 Video duration: ${duration.toStringAsFixed(2)} seconds', emoji: '🎬');

    // Extract frames at configured FPS
    _debug('   🎞️  Extracting frames at $_framesPerSecond FPS with FFmpeg...', emoji: '🎬');
    final extractTimer = Stopwatch()..start();

    final result = await Process.run('ffmpeg', [
      '-i', videoFile.path,
      '-vf', 'fps=$_framesPerSecond',
      '-q:v', '2',
      path.join(framesDir.path, 'frame_%04d.png'),
    ]);

    if (result.exitCode != 0) {
      _debug('   ❌ FFmpeg failed: ${result.stderr}', emoji: '❌');
      throw Exception('FFmpeg extraction failed: ${result.stderr}');
    }

    // Get all extracted frame files
    final frameFiles = framesDir
        .listSync()
        .where((f) => f.path.endsWith('.png'))
        .map((f) => f as File)
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    extractTimer.stop();
    _debug('   ✅ Extracted ${frameFiles.length} frames in ${extractTimer.elapsedMilliseconds}ms', emoji: '🎬');

    // Generate embeddings in parallel batches
    _debug('   🧠 Generating embeddings for ${frameFiles.length} frames...', emoji: '🧠');
    _debug('   ⚡ Concurrency: $concurrency parallel requests', emoji: '🧠');
    final embeddingTimer = Stopwatch()..start();

    final allFrameObjects = <VideoFrameEmbedding>[];
    int batchNumber = 0;

    // Process frames in parallel batches (API only supports 1 image per request)
    for (int i = 0; i < frameFiles.length; i += concurrency) {
      batchNumber++;
      final batchEnd = (i + concurrency < frameFiles.length)
          ? i + concurrency
          : frameFiles.length;

      final batchFiles = frameFiles.sublist(i, batchEnd);
      _debug('   📦 Batch $batchNumber: frames ${i + 1}-$batchEnd (${batchFiles.length} parallel calls)', emoji: '🧠');

      // Generate embeddings in parallel (concurrent API calls)
      final embeddingFutures = batchFiles.map((file) =>
          _generateImageEmbedding(session, file.path, accessToken));
      final embeddings = await Future.wait(embeddingFutures);

      // Create frame objects
      for (int j = 0; j < embeddings.length; j++) {
        final frameIndex = i + j;
        final timestamp = frameIndex / _framesPerSecond;

        allFrameObjects.add(VideoFrameEmbedding(
          adexModelId: adexModelId,
          videoUrl: videoUrl,
          processingId: processingId,
          frameNumber: frameIndex,
          timestamp: timestamp,
          framePath: batchFiles[j].path,
          embedding: Vector(embeddings[j]),
        ));
      }

      _debug('   ✅ Batch $batchNumber complete (${i + embeddings.length}/${frameFiles.length} total)', emoji: '🧠');
      session.log('Generated ${i + embeddings.length}/${frameFiles.length} embeddings');

      // Small delay between batches to avoid rate limiting
      if (i + concurrency < frameFiles.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }

    embeddingTimer.stop();
    _debug('   ✅ All embeddings generated in ${embeddingTimer.elapsed.inSeconds}s', emoji: '🧠');

    // Batch insert all frames to database
    _debug('   💾 Inserting ${allFrameObjects.length} frames to database...', emoji: '🗄️');
    final dbTimer = Stopwatch()..start();
    await VideoFrameEmbedding.db.insert(session, allFrameObjects);
    dbTimer.stop();
    _debug('   ✅ Database insert complete in ${dbTimer.elapsedMilliseconds}ms', emoji: '🗄️');

    return {
      'totalFrames': frameFiles.length,
      'duration': duration,
      'framesDir': framesDir.path,
    };
  }

  /// Generate embedding for a single image using Vertex AI multimodalembedding@001
  Future<List<double>> _generateImageEmbedding(
    Session session,
    String imagePath,
    String accessToken,
  ) async {
    return _withRetry(
      operationName: 'Image embedding',
      () async {
        final imageBytes = await File(imagePath).readAsBytes();
        final base64Image = base64Encode(imageBytes);

        final url = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/multimodalembedding@001:predict';

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'instances': [
              {
                'image': {'bytesBase64Encoded': base64Image},
              },
            ],
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to generate embedding: ${response.statusCode} - ${response.body}');
        }

        final result = jsonDecode(response.body);
        final embedding = (result['predictions'][0]['imageEmbedding'] as List)
            .map((e) => (e as num).toDouble())
            .toList();

        return embedding;
      },
    );
  }


  /// Generate text embedding using Vertex AI
  Future<List<double>> _generateTextEmbedding(
    Session session,
    String text,
    String accessToken,
  ) async {
    _debug('   📝 Generating text embedding for: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."', emoji: '🧠');

    return _withRetry(
      operationName: 'Text embedding',
      () async {
        final url = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/multimodalembedding@001:predict';

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'instances': [
              {
                'text': text,
              },
            ],
          }),
        );

        if (response.statusCode != 200) {
          _debug('   ❌ Text embedding API error: ${response.statusCode}', emoji: '❌');
          throw Exception('Failed to generate text embedding: ${response.statusCode} - ${response.body}');
        }

        final result = jsonDecode(response.body);
        final embedding = (result['predictions'][0]['textEmbedding'] as List)
            .map((e) => (e as num).toDouble())
            .toList();

        _debug('   ✅ Text embedding generated (${embedding.length} dimensions)', emoji: '🧠');
        return embedding;
      },
    );
  }

  // ============================================================================
  // PRIVATE METHODS - RAG Frame Type Detection
  // ============================================================================

  /// Generate frame types JSON using Gemini based on user prompts
  Future<String> _generateFrameTypes(
    Session session,
    String userPrompt,
    String? whatDoesThisVideoContain,
    List<String>? suggestFramesToExtract,
    String accessToken,
  ) async {
    _debug('🤖 _generateFrameTypes: Calling Gemini API...', emoji: '🤖');

    final prompt = '''
You are an expert at analyzing video content and determining what types of frames need to be extracted.

Given the following information:
- User Prompt: $userPrompt
- Video Content Description: ${whatDoesThisVideoContain ?? 'Not provided'}
- Suggested Frame Types: ${suggestFramesToExtract?.join(', ') ?? 'Not provided'}

Generate a JSON object that describes the types of frames that need to be extracted from this video.
Each frame type should have:
- A key that is a descriptive name (e.g., "nutrition_facts", "ingredients_list", "product_front")
- A "description" field that describes what this frame should contain (be specific about visual elements)
- An "extractFrameCount" field (minimum 1, maximum 5) indicating how many frames of this type to extract

The description should be detailed enough to be converted into an embedding for semantic search.

Important guidelines:
- If extracting important data (nutrition facts, ingredients, barcodes), use extractFrameCount of 2-3
- For general product shots, use extractFrameCount of 1-2
- Be specific in descriptions to help with embedding-based search

Return ONLY valid JSON with no markdown formatting or explanation.

Example output:
{
  "nutrition_facts": {
    "description": "Image showing nutrition facts label or nutrition information panel with calorie counts, macronutrients, vitamins and minerals values clearly visible",
    "extractFrameCount": 2
  },
  "ingredients_list": {
    "description": "Image showing product ingredients list text, typically on back or side of packaging with all ingredient names visible",
    "extractFrameCount": 2
  },
  "product_front": {
    "description": "Clear front view of product packaging showing brand name, product name and main imagery",
    "extractFrameCount": 1
  }
}
''';

    return _withRetry(
      operationName: 'Generate frame types',
      () async {
        final url = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/gemini-2.0-flash-exp:generateContent';

        _debug('   🌐 Sending request to Gemini...', emoji: '🤖');
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [{'text': prompt}],
              },
            ],
            'generationConfig': {
              'temperature': 0.2,
              'topK': 32,
              'topP': 1,
              'maxOutputTokens': 2048,
            },
          }),
        );

        if (response.statusCode != 200) {
          _debug('   ❌ Gemini API error: ${response.statusCode}', emoji: '❌');
          _debug('   📄 Response: ${response.body}', emoji: '❌');
          throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
        }

        _debug('   ✅ Gemini response received', emoji: '🤖');

        final result = jsonDecode(response.body);
        final textResponse = result['candidates'][0]['content']['parts'][0]['text'] as String;

        // Clean up the response
        String jsonString = textResponse.trim();
        if (jsonString.startsWith('```json')) {
          jsonString = jsonString.substring(7);
        }
        if (jsonString.startsWith('```')) {
          jsonString = jsonString.substring(3);
        }
        if (jsonString.endsWith('```')) {
          jsonString = jsonString.substring(0, jsonString.length - 3);
        }
        jsonString = jsonString.trim();

        // Validate JSON
        jsonDecode(jsonString);
        _debug('   ✅ Valid JSON response received', emoji: '🤖');

        return jsonString;
      },
    );
  }

  // ============================================================================
  // PRIVATE METHODS - RAG Frame Extraction
  // ============================================================================

  /// Extract frames using RAG based on frame types (PARALLEL processing)
  Future<List<Map<String, dynamic>>> _extractFramesUsingRag(
    Session session,
    int adexModelId,
    String processingId,
    String frameTypesJson,
    String accessToken,
    Directory tempDir,
  ) async {
    _debug('🔍 _extractFramesUsingRag: Starting RAG extraction...', emoji: '🔍');

    final frameTypes = jsonDecode(frameTypesJson) as Map<String, dynamic>;

    _debug('   📋 Frame types to extract: ${frameTypes.keys.toList()}', emoji: '🔍');

    // Create output directory for extracted frames
    final outputDir = Directory('uploads/extracted_frames/$adexModelId');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
      _debug('   📁 Created output dir: ${outputDir.path}', emoji: '🔍');
    }

    // Step 1: Generate ALL text embeddings in PARALLEL
    _debug('   🧠 Generating embeddings for all ${frameTypes.length} frame types in parallel...', emoji: '🔍');
    final descriptions = <String, String>{};
    final extractCounts = <String, int>{};

    for (final entry in frameTypes.entries) {
      final frameInfo = entry.value as Map<String, dynamic>;
      descriptions[entry.key] = frameInfo['description'] as String;
      extractCounts[entry.key] = (frameInfo['extractFrameCount'] as num).toInt();
    }

    // Generate all embeddings in parallel
    final embeddingFutures = descriptions.entries.map((entry) async {
      final embedding = await _generateTextEmbedding(session, entry.value, accessToken);
      return MapEntry(entry.key, embedding);
    });

    final embeddingResults = await Future.wait(embeddingFutures);
    final embeddings = Map.fromEntries(embeddingResults);
    _debug('   ✅ All ${embeddings.length} embeddings generated in parallel!', emoji: '🔍');

    // Step 2: Query database and extract frames for each type in PARALLEL
    _debug('   🔎 Querying database for all frame types in parallel...', emoji: '🔍');

    final extractionFutures = frameTypes.keys.map((frameType) async {
      final description = descriptions[frameType]!;
      final extractFrameCount = extractCounts[frameType]!;
      final descriptionEmbedding = embeddings[frameType]!;

      // Query similar frames using cosine distance
      final frames = await VideoFrameEmbedding.db.find(
        session,
        where: (t) => t.adexModelId.equals(adexModelId),
        orderBy: (t) => t.embedding.distanceCosine(Vector(descriptionEmbedding)),
        limit: extractFrameCount,
      );

      if (frames.isEmpty) {
        _debug('   ⚠️  No frames found for $frameType', emoji: '⚠️');
        return null;
      }

      // Copy extracted frames to output directory
      final extractedFrameUrls = <String>[];
      final extractedFrameTimestamps = <double>[];

      for (int i = 0; i < frames.length; i++) {
        final frame = frames[i];
        final sourceFile = File(frame.framePath);

        if (await sourceFile.exists()) {
          final outputFileName = '${frameType}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}_$i.png';
          final outputPath = path.join(outputDir.path, outputFileName);
          await sourceFile.copy(outputPath);
          extractedFrameUrls.add('/uploads/extracted_frames/$adexModelId/$outputFileName');
          extractedFrameTimestamps.add(frame.timestamp);
        }
      }

      _debug('   ✅ $frameType: ${extractedFrameUrls.length} frames extracted', emoji: '🔍');

      return {
        'frameType': frameType,
        'description': description,
        'extractFrameCount': extractFrameCount,
        'extractedFrameUrls': extractedFrameUrls,
        'extractedFrameTimestamps': extractedFrameTimestamps,
      };
    });

    final results = await Future.wait(extractionFutures);
    final extractedFramesData = results.whereType<Map<String, dynamic>>().toList();

    _debug('', emoji: '');
    _debug('   🏁 RAG extraction complete: ${extractedFramesData.length} frame types processed in parallel!', emoji: '🔍');

    return extractedFramesData;
  }

  // ============================================================================
  // PRIVATE METHODS - Text Extraction
  // ============================================================================

  /// Extract text from ALL frames using a single Gemini API call
  /// This is more efficient and avoids rate limiting issues
  Future<String> _extractTextFromFrames(
    Session session,
    List<Map<String, dynamic>> extractedFramesData,
    String extractedDataInformationPrompt,
    String accessToken,
  ) async {
    _debug('📝 _extractTextFromFrames: Starting text extraction...', emoji: '📝');
    _debug('   📋 Processing ${extractedFramesData.length} frame types in a SINGLE API call', emoji: '📝');

    // Collect all image URLs first
    final allImageUrls = <String>[];
    final frameTypeDescriptions = <String>[];

    for (final frameData in extractedFramesData) {
      final frameType = frameData['frameType'] as String;
      final description = frameData['description'] as String;
      final extractedFrameUrls = frameData['extractedFrameUrls'] as List<dynamic>;

      if (extractedFrameUrls.isEmpty) {
        _debug('   ⏭️  Skipping $frameType (no frames)', emoji: '📝');
        continue;
      }

      final startIndex = allImageUrls.length;
      for (final url in extractedFrameUrls) {
        allImageUrls.add((url as String).startsWith('/') ? url.substring(1) : url);
      }
      final endIndex = allImageUrls.length - 1;

      frameTypeDescriptions.add('''
## $frameType (Images ${startIndex + 1} to ${endIndex + 1})
Description: $description
''');
      _debug('   📎 Added ${extractedFrameUrls.length} images for: $frameType', emoji: '📝');
    }

    if (allImageUrls.isEmpty) {
      _debug('   ⚠️  No images to process', emoji: '⚠️');
      return jsonEncode({});
    }

    // Read ALL image files in PARALLEL
    _debug('   ⚡ Reading ${allImageUrls.length} images in parallel...', emoji: '📝');
    final imageReadFutures = allImageUrls.map((filePath) async {
      final file = File(filePath);
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();
        return base64Encode(imageBytes);
      }
      return null;
    });

    final base64Images = await Future.wait(imageReadFutures);

    // Build image parts from parallel results
    final allImageParts = <Map<String, dynamic>>[];
    for (final base64Image in base64Images) {
      if (base64Image != null) {
        allImageParts.add({
          'inlineData': {
            'mimeType': 'image/png',
            'data': base64Image,
          },
        });
      }
    }

    if (allImageParts.isEmpty) {
      _debug('   ⚠️  No valid images found across all frame types', emoji: '⚠️');
      return jsonEncode({});
    }

    _debug('   ✅ Loaded ${allImageParts.length} images in parallel', emoji: '📝');
    _debug('   📊 Frame types: ${frameTypeDescriptions.length}', emoji: '📝');

    // Build a comprehensive prompt for all frame types
    final prompt = '''
$extractedDataInformationPrompt

You are analyzing ${allImageParts.length} images from a video. These images are categorized into the following frame types:

${frameTypeDescriptions.join('\n')}

IMPORTANT: Analyze ALL the provided images and extract relevant information for EACH frame type.

Return a JSON object where:
- Each key is the frame type name (exactly as listed above: ${extractedFramesData.where((f) => (f['extractedFrameUrls'] as List).isNotEmpty).map((f) => f['frameType']).join(', ')})
- Each value contains the extracted data for that frame type

Example structure:
{
  "nutrition_facts": {
    "calories": "...",
    "protein": "...",
    ...
  },
  "ingredients_list": {
    "ingredients": ["...", "..."],
    ...
  },
  ...
}

Return ONLY valid JSON with no markdown formatting or explanation.
''';

    try {
      final textResponse = await _withRetry(
        operationName: 'Text extraction (all frames)',
        () async {
          final url = 'https://$_location-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_location/publishers/google/models/gemini-2.0-flash-exp:generateContent';

          _debug('   🤖 Calling Gemini with ${allImageParts.length} images...', emoji: '📝');
          final response = await http.post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                    ...allImageParts,
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.1,
                'topK': 32,
                'topP': 1,
                'maxOutputTokens': 8192, // Increased for comprehensive response
              },
            }),
          );

          if (response.statusCode != 200) {
            _debug('   ❌ Gemini API error: ${response.statusCode}', emoji: '❌');
            _debug('   📄 Response: ${response.body}', emoji: '❌');
            throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
          }

          final result = jsonDecode(response.body);
          return result['candidates'][0]['content']['parts'][0]['text'] as String;
        },
      );

      _debug('   ✅ Gemini response received', emoji: '✓');

      // Parse the response as JSON
      String jsonString = textResponse.trim();
      if (jsonString.startsWith('```json')) {
        jsonString = jsonString.substring(7);
      }
      if (jsonString.startsWith('```')) {
        jsonString = jsonString.substring(3);
      }
      if (jsonString.endsWith('```')) {
        jsonString = jsonString.substring(0, jsonString.length - 3);
      }
      jsonString = jsonString.trim();

      // Validate JSON
      final parsed = jsonDecode(jsonString);
      _debug('   ✅ Parsed JSON successfully with ${(parsed as Map).keys.length} frame types', emoji: '✓');

      // Log extracted keys
      for (final key in parsed.keys) {
        _debug('      📋 $key: extracted', emoji: '✓');
      }

      _debug('', emoji: '');
      _debug('   🏁 Text extraction complete in a single API call!', emoji: '📝');

      return jsonString;
    } catch (e) {
      _debug('   ❌ Error extracting text: $e', emoji: '❌');
      session.log('Error extracting text: $e', level: LogLevel.error);

      // Return empty JSON on error
      return jsonEncode({});
    }
  }

  // ============================================================================
  // PRIVATE METHODS - Cleanup
  // ============================================================================

  /// Cleanup temporary data from database
  Future<void> _cleanupTemporaryData(
    Session session,
    int adexModelId,
    String processingId,
  ) async {
    _debug('🧹 _cleanupTemporaryData: Starting cleanup...', emoji: '🧹');

    try {
      // Get frames for this processing run
      _debug('   🔍 Finding frames to delete...', emoji: '🧹');
      final frames = await VideoFrameEmbedding.db.find(
        session,
        where: (t) => t.adexModelId.equals(adexModelId) & t.processingId.equals(processingId),
      );

      _debug('   📊 Found ${frames.length} frames to clean up', emoji: '🧹');

      // Delete frame files from disk (temp files only)
      int deletedFiles = 0;
      for (final frame in frames) {
        final file = File(frame.framePath);
        if (await file.exists() && (frame.framePath.contains('/tmp/') || frame.framePath.contains('\\Temp\\'))) {
          await file.delete();
          deletedFiles++;
        }
      }
      _debug('   🗑️  Deleted $deletedFiles temp files from disk', emoji: '🧹');

      // Delete database entries
      _debug('   💾 Deleting ${frames.length} database entries...', emoji: '🧹');
      await VideoFrameEmbedding.db.deleteWhere(
        session,
        where: (t) => t.adexModelId.equals(adexModelId) & t.processingId.equals(processingId),
      );

      _debug('   ✅ Cleanup complete: ${frames.length} embeddings removed', emoji: '✓');
      session.log('Cleaned up ${frames.length} temporary frame embeddings');
    } catch (e) {
      _debug('   ⚠️  Cleanup error: $e', emoji: '⚠️');
      session.log('Warning: Cleanup error: $e', level: LogLevel.warning);
    }
  }

  // ============================================================================
  // PRIVATE METHODS - Authentication
  // ============================================================================

  /// Get access token for Vertex AI using service account (with caching)
  Future<String> _getAccessToken(Session session) async {
    // Check if we have a valid cached token (with 5-minute buffer)
    if (_cachedAccessToken != null && _tokenExpiresAt != null) {
      final now = DateTime.now();
      if (_tokenExpiresAt!.isAfter(now.add(const Duration(minutes: 5)))) {
        _debug('🔐 _getAccessToken: Using cached token (expires: $_tokenExpiresAt)', emoji: '🔐');
        return _cachedAccessToken!;
      }
    }

    _debug('🔐 _getAccessToken: Fetching new token...', emoji: '🔐');

    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "weedit-india",
      "private_key_id": "ddab251d446cb7a52023fd94e039af5ae2e091a0",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDLigIUwTLYajK+\nOMVt1oHL6C3MGxUdhbwhWN4QWFiPrrzstj9NcDp74hifyeUwpDjODIFp5VitqQou\nHiUDrExBvhVuLEzXMjgmRslnBK4DgFreo3CQYvicCorh5r8RYYfHbIkiDDya3nSE\nZ6rB/4jPIK5neHDGLx8CwN76F6SOK9pTxYDOQfdCmsz1CxWWcCslj6Oj0EesT1Tu\nDBjeqfC3uctq54aUAW2joWQ7XDNSAlHVAXkLuARzxW3iP1FmAlYQmC8Q70NqwykJ\n4e8qLxWw+LH6jIQsjklrDq38hNHjdGCJsb/LUVdIasDFuHiJ70a4tA27AFOQRyiC\nbzi5lY/tAgMBAAECggEADBhe6EnU0ix5aHlqLg1FuE7LTeo8Fn2IgPjNdW4ykRNC\nsdRgraLiLtNwQCqYvou7vm7az+arnuJBMx1ieLXn8C4yCtKCHHWlBY1GUaNjDd02\nSS2wNjxTZr5vo135c7h2f6DRA19zyIY4qVeZu56KTDi2dHqhRP2u25SHi5gVFMem\nN5X/yofNdNCdhR6PDgAOwReJvKYTQmF1/mV0emhg0JxRtJ8QygVVxKz3snlVktnB\nApmE52Y4EHiaGYf2oaF21KAcEK3jwRg2Y02SWiP7ohrwTLTJPaAI4GDf8kd/LC0T\nWKjkkOOo+O2JXlg6Ci0l3pZooapAKdcpduyCQptXcQKBgQDm2Sn950Z9yh5UDk7+\n0hNu6mmXEy/VKdHigl9ZzxJfu9xn29P2C8oOdPom3Lb559DKbOHenyrM805jvd3d\nwjuKeNyQD6bA6pO83KomOdif/OfNbfeMx/G1Y2jrqUPsAJf3bitHcHDjm2dU/4Z9\ni1uJOMNxiSji74IbG4gLYI0jOQKBgQDhtyJOcd8ce4nC5u0/DtTH/NBX8wJ2W6jn\nu1jxr1We643Ujx/UbeomBqvyszW0MXoCb+DLXj8YO6F/uyMG4IqFHslppKJwGKgk\nye4Ff51//CNnL3bljVkzeQWLbWtVEDvavuQG+od1Hb8BbMIb913vJWgARPpSrih0\nXkLD1mnOVQKBgDvISYOjfTHeQfRqsDJ1nOrAcg/ZvC1r4xrRwHe1lICOWgnbeAzk\nCLOtv4qI5inZysxhXi0U8zSYXdietvJS9rBplFUKeJjFJvVl//peSKdGC5G7xLwE\nm6fp0qYU864OiUxej360s8d920i708x3ZoEm3hZs+tWqSPtUKesoWeShAoGAMSIm\nS6EqCg8yS8Ts+/8Efowf5iU18gG94MO9ds7N+owYEZ8eNKXAhIqLP4eXNyRWBNXJ\nvztCzMmePCnGVCbowFWVTnPSEEitwWRbdcLzy/pc0odYgFumgTfk5xboeFnSTamk\nBYjfl7Tj8TF1h5TvU7F21CgvvXO/xqUGL48q9QkCgYBmXzDotdb6bx5NDgWj7/0w\nmJqqunMYyPukOuUz/7QBIDUhQ3DwDklZ4kTVGqS7PHaZLzgHXYMxIDC63t2UOgzy\nBBvfg77dAigMZgCLVOFwUsu4EvoVC74LxZapTKLlCTcw3tvYupmifnypkUOpc2Z/\nS580xE8PTXaQAWtCcsMIFQ==\n-----END PRIVATE KEY-----\n",
      "client_email": "vetex-ai-user-serverpod@weedit-india.iam.gserviceaccount.com",
      "client_id": "104443392683761524427",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/vetex-ai-user-serverpod%40weedit-india.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    _debug('   📧 Service account: ${serviceAccountJson['client_email']}', emoji: '🔐');
    _debug('   🌐 Token URI: ${serviceAccountJson['token_uri']}', emoji: '🔐');

    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

    _debug('   🔄 Requesting token from Google...', emoji: '🔐');
    final client = await clientViaServiceAccount(credentials, scopes);

    final token = client.credentials.accessToken.data;
    final expiry = client.credentials.accessToken.expiry;

    // Cache the token
    _cachedAccessToken = token;
    _tokenExpiresAt = expiry;

    _debug('   ✅ Token obtained: ${token.substring(0, 20)}...', emoji: '✓');
    _debug('   📅 Token expires: $expiry', emoji: '✓');

    return token;
  }

  // ============================================================================
  // PRIVATE METHODS - Utilities
  // ============================================================================

  /// Generate a random ID for uniqueness
  String _generateRandomId() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return random.toRadixString(36);
  }
}
