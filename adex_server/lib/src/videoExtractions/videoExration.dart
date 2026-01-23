import 'dart:io';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:serverpod/serverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../generated/protocol.dart';

class VideoExtractionEndpoint extends Endpoint {
  // ============================================================================
  // PUBLIC API - Main Function
  // ============================================================================

  /// Complete workflow: Extract frames, generate embeddings, classify, and save product images
  ///
  /// This is the main entry point for video processing. It performs:
  /// 1. Extract 2 frames per second from video
  /// 2. Generate embeddings using Vertex AI multimodalembedding@002
  /// 3. Save embeddings to database with vector indexing
  /// 4. Use RAG to find product, nutrition facts, ingredients, and back images
  /// 5. Save classified images to organized output directory
  /// 6. Optionally extract text using Gemini 2.0 Flash (if textExtraction is true)
  /// 7. Cleanup temporary frames and database entries
  ///
  /// Parameters:
  /// - videoUrl: URL of the video to process
  /// - outputDir: Directory to save classified images
  /// - textExtraction: If true, extract text from images using Gemini 2.0 (default: false)
  ///
  /// Note: Vertex AI credentials are automatically loaded from config/passwords.yaml
  ///
  /// Returns: Map with paths to saved images and extracted text (if enabled):
  ///   {
  ///     'images': {
  ///       'product': 'path',
  ///       'nutrifact': ['path1', 'path2'],
  ///       'ingredients': ['path1', 'path2'],
  ///       'back': 'path'
  ///     },
  ///     'extractedText': {  // Only if textExtraction=true
  ///       'nutritionFacts': { ... },
  ///       'ingredients': { ... },
  ///       'productInfo': { ... },
  ///       'claimsAndAllergens': { ... }
  ///     }
  ///   }
  Future<Map<String, dynamic>> processVideoComplete(
    Session session,
    String videoUrl,
    String outputDir, {
    bool textExtraction = false,
  }) async {
    final overallTimer = Stopwatch()..start();

    try {
      session.log('========================================');
      session.log('Starting complete video processing workflow...');
      session.log('Video URL: $videoUrl');
      session.log('========================================');

      // Step 0: Get access token
      final tokenTimer = Stopwatch()..start();
      final accessToken = await _getAccessToken(session);
      tokenTimer.stop();
      session.log('⏱️  Access token fetch: ${tokenTimer.elapsedMilliseconds}ms');

      if (accessToken.isEmpty) {
        throw Exception(
          'Incomplete Vertex AI credentials in passwords.yaml. '
          'Required: projectId, location, accessToken',
        );
      }

      // Step 1: Extract frames and generate embeddings
      final embeddingTimer = Stopwatch()..start();
      final result = await _processVideoWithEmbeddings(
        session,
        videoUrl,
        accessToken,
      );
      embeddingTimer.stop();

      final processingId = result['processingId'] as String;
      session.log('Frames processed: ${result['totalFrames']}');
      session.log('⏱️  Total frame extraction + embedding: ${embeddingTimer.elapsed.inSeconds}s (${embeddingTimer.elapsedMilliseconds}ms)');

      // Step 2: Extract and classify product images using RAG
      final ragTimer = Stopwatch()..start();
      final productImages = await _extractProductImages(
        session,
        videoUrl,
        processingId,
        outputDir,
      );
      ragTimer.stop();
      session.log('⏱️  RAG classification + cleanup: ${ragTimer.elapsed.inSeconds}s (${ragTimer.elapsedMilliseconds}ms)');

      // Step 3: Extract text from images using Gemini 2.0 (if enabled)
      Map<String, dynamic>? extractedText;
      if (textExtraction) {
        session.log('========================================');
        session.log('Starting text extraction with Gemini 2.0...');
        final textTimer = Stopwatch()..start();
        extractedText = await _extractTextFromImages(
          session,
          productImages,
          accessToken,
        );
        textTimer.stop();
        session.log('⏱️  Text extraction: ${textTimer.elapsed.inSeconds}s (${textTimer.elapsedMilliseconds}ms)');
      }

      overallTimer.stop();
      session.log('========================================');
      session.log('⏱️  TOTAL PROCESSING TIME: ${overallTimer.elapsed.inMinutes}m ${overallTimer.elapsed.inSeconds % 60}s (${overallTimer.elapsed.inSeconds}s total)');
      session.log('========================================');
      session.log('Video processing complete! Images saved to: $outputDir');

      // Return structured response
      final response = <String, dynamic>{
        'images': productImages,
      };

      if (textExtraction && extractedText != null) {
        response['extractedText'] = extractedText;
      }

      return response;
    } catch (e) {
      session.log('Error in complete workflow: $e', level: LogLevel.error);
      rethrow;
    }
  }

  // ============================================================================
  // LEGACY API - Kept for backward compatibility
  // ============================================================================

  /// Legacy method: Extract 1 frame per second (deprecated)
  ///
  /// Use processVideoComplete() instead for the full workflow.
  @Deprecated('Use processVideoComplete() for the complete workflow')
  Future<int> extractVideoFrames(Session session, String videoUrl) async {
    Directory? tempDir;

    try {
      tempDir = await Directory.systemTemp.createTemp('video_frames_legacy_');
      final framesDir = Directory(path.join(tempDir.path, 'frames'));
      await framesDir.create();

      session.log('Downloading video from: $videoUrl');
      final response = await http.get(Uri.parse(videoUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download video: ${response.statusCode}');
      }

      final videoFile = File(path.join(tempDir.path, 'video.mp4'));
      await videoFile.writeAsBytes(response.bodyBytes);
      session.log('Video downloaded: ${videoFile.path}');

      final result = await Process.run(
        'ffmpeg',
        [
          '-i',
          videoFile.path,
          '-vf',
          'fps=1',
          path.join(framesDir.path, 'frame_%04d.png'),
        ],
      );

      if (result.exitCode != 0) {
        session.log('FFmpeg error: ${result.stderr}', level: LogLevel.error);
        throw Exception('FFmpeg failed: ${result.stderr}');
      }

      final frames = framesDir
          .listSync()
          .where((file) => file.path.endsWith('.png'))
          .toList();
      final frameCount = frames.length;

      session.log('Extracted $frameCount frames from video');
      return frameCount;
    } catch (e) {
      session.log('Error extracting video frames: $e', level: LogLevel.error);
      rethrow;
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        session.log('Cleaned up temporary files');
      }
    }
  }

  // ============================================================================
  // PRIVATE METHODS - Internal Implementation
  // ============================================================================

  /// Extract 2 frames per second, generate embeddings, and store in database
  Future<Map<String, dynamic>> _processVideoWithEmbeddings(
    Session session,
    String videoUrl,
    String accessToken,
  ) async {
    Directory? tempDir;
    Directory? framesDir;

    try {
      // Create temporary directories
      tempDir = await Directory.systemTemp.createTemp('video_processing_');
      framesDir = Directory(path.join(tempDir.path, 'frames'));
      await framesDir.create();

      // Download video
      session.log('Downloading video from: $videoUrl');
      final downloadTimer = Stopwatch()..start();
      final videoResponse = await http.get(Uri.parse(videoUrl));
      if (videoResponse.statusCode != 200) {
        throw Exception(
          'Failed to download video: ${videoResponse.statusCode}',
        );
      }

      final videoFile = File(path.join(tempDir.path, 'video.mp4'));
      await videoFile.writeAsBytes(videoResponse.bodyBytes);
      downloadTimer.stop();
      session.log('⏱️  Video download: ${downloadTimer.elapsedMilliseconds}ms (${(videoResponse.bodyBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');

      // Get video duration
      final ffprobeTimer = Stopwatch()..start();
      final durationResult = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        videoFile.path,
      ]);

      final duration = double.parse(durationResult.stdout.toString().trim());
      final totalSeconds = duration.floor();
      ffprobeTimer.stop();
      session.log('Video duration: $totalSeconds seconds');
      session.log('⏱️  FFprobe duration check: ${ffprobeTimer.elapsedMilliseconds}ms');

      // Generate unique processing ID for this run
      final processingId = DateTime.now().millisecondsSinceEpoch.toString();
      session.log('Processing ID: $processingId');

      // PHASE 1: Extract all frames with single FFmpeg command
      session.log('Extracting frames from video...');
      final extractionTimer = Stopwatch()..start();

      final result = await Process.run('ffmpeg', [
        '-i',
        videoFile.path,
        '-vf',
        'fps=2', // 2 frames per second
        '-q:v',
        '2', // High quality
        path.join(framesDir.path, 'frame_%04d.png'),
      ]);

      if (result.exitCode != 0) {
        throw Exception('FFmpeg extraction failed: ${result.stderr}');
      }

      // Get all extracted frame files
      final frameFiles = framesDir
          .listSync()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f as File)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final framePaths = <String>[];
      final frameMetadata = <Map<String, dynamic>>[];

      for (int i = 0; i < frameFiles.length; i++) {
        final timestamp = i * 0.5; // 2 fps = 0.5s intervals
        framePaths.add(frameFiles[i].path);
        frameMetadata.add({
          'timestamp': timestamp,
          'frameNumber': i,
        });
      }

      extractionTimer.stop();
      session.log(
          '⏱️  Frame extraction: ${extractionTimer.elapsed.inSeconds}s (${extractionTimer.elapsedMilliseconds}ms) - ${framePaths.length} frames extracted');

      // PHASE 2: Generate embeddings in parallel (8 concurrent requests)
      session.log('Generating embeddings for ${framePaths.length} frames...');
      final embeddingTimer = Stopwatch()..start();

      const concurrency = 8; // Process 8 frames concurrently
      final allFrameObjects = <VideoFrameEmbedding>[];

      // Process frames in batches of `concurrency`
      for (int i = 0; i < framePaths.length; i += concurrency) {
        final batchEnd = (i + concurrency < framePaths.length)
            ? i + concurrency
            : framePaths.length;

        final batchPaths = framePaths.sublist(i, batchEnd);
        final batchMetadata = frameMetadata.sublist(i, batchEnd);

        // Generate embeddings in parallel using Future.wait
        final embeddingFutures = batchPaths
            .map((framePath) =>
                _generateVertexAIEmbedding(session, framePath, accessToken))
            .toList();

        final embeddings = await Future.wait(embeddingFutures);

        // Create frame objects
        for (int j = 0; j < embeddings.length; j++) {
          final meta = batchMetadata[j];
          allFrameObjects.add(VideoFrameEmbedding(
            videoUrl: videoUrl,
            processingId: processingId,
            frameNumber: meta['frameNumber'] as int,
            timestamp: meta['timestamp'] as double,
            framePath: batchPaths[j],
            embedding: Vector(embeddings[j]),
          ));
        }

        session.log(
            'Generated ${i + embeddings.length}/${framePaths.length} embeddings (batch ${(i ~/ concurrency) + 1})');
      }

      embeddingTimer.stop();
      session.log(
          '⏱️  Embedding generation: ${embeddingTimer.elapsed.inSeconds}s (${embeddingTimer.elapsedMilliseconds}ms) - Average: ${(embeddingTimer.elapsedMilliseconds / framePaths.length).toStringAsFixed(0)}ms per frame');

      // PHASE 3: Batch insert all frames to database
      session.log('Saving ${allFrameObjects.length} frames to database...');
      final dbInsertTimer = Stopwatch()..start();
      await VideoFrameEmbedding.db.insert(session, allFrameObjects);
      dbInsertTimer.stop();
      session.log('⏱️  Database batch insert: ${dbInsertTimer.elapsedMilliseconds}ms');
      session.log('Total frames extracted, embedded, and saved: ${framePaths.length}');

      return {
        'success': true,
        'videoUrl': videoUrl,
        'processingId': processingId,
        'totalFrames': framePaths.length,
        'duration': duration,
        'framesDir': framesDir.path,
      };
    } catch (e) {
      session.log('Error processing video: $e', level: LogLevel.error);
      rethrow;
    }
  }

  /// Extract a single frame at specific timestamp using FFmpeg
  Future<void> _extractFrameAtTimestamp(
    String videoPath,
    double timestamp,
    String outputPath,
  ) async {
    final result = await Process.run('ffmpeg', [
      '-ss',
      timestamp.toString(),
      '-i',
      videoPath,
      '-frames:v',
      '1',
      '-q:v',
      '2', // High quality
      outputPath,
      '-y', // Overwrite output file
    ]);

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to extract frame at $timestamp: ${result.stderr}',
      );
    }
  }

  /// Calculate image quality score using file size as proxy
  ///
  /// Returns a score where HIGHER = BETTER quality (less blurry)
  /// Good quality frames typically have score > 30 (KB)
  /// Blurry/shaky frames have score < 20 (KB)
  ///
  /// Note: Blurry images compress more, resulting in smaller file sizes
  Future<double> _calculateImageQuality(String imagePath) async {
    try {
      // Use file size as proxy for quality
      // Blurry images tend to compress more (smaller file size)
      final file = File(imagePath);
      final bytes = await file.length();

      // Normalize: typical clear product image is 50KB-500KB
      // Blurry images are often < 30KB
      final qualityScore = bytes / 1000.0; // Convert to KB

      return qualityScore;
    } catch (e) {
      // If quality check fails, return neutral score
      return 50.0;
    }
  }

  /// Generate embedding using Vertex AI multimodalembedding@002
  ///
  /// Uses Google Cloud Vertex AI to generate 1408-dimensional embeddings
  /// Reference: https://cloud.google.com/vertex-ai/docs/generative-ai/embeddings/get-multimodal-embeddings
  Future<List<double>> _generateVertexAIEmbedding(
    Session session,
    String imagePath,

    String accessToken,
  ) async {
    try {
      // Read image and convert to base64
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Vertex AI multimodalembedding@002 endpoint
      final url =
          'https://us-central1-aiplatform.googleapis.com/v1/projects/weedit-india/locations/us-central1/publishers/google/models/multimodalembedding@001:predict';

      // Make API request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'instances': [
            {
              'image': {
                'bytesBase64Encoded': base64Image,
              },
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        session.log('Vertex AI error: ${response.body}', level: LogLevel.error);
        throw Exception(
          'Failed to generate embedding: ${response.statusCode} - ${response.body}',
        );
      }

      final result = jsonDecode(response.body);
      final embedding = (result['predictions'][0]['imageEmbedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      session.log(
        'Generated Vertex AI embedding with ${embedding.length} dimensions',
        level: LogLevel.debug,
      );

      return embedding;
    } catch (e) {
      session.log(
        'Error generating Vertex AI embedding: $e',
        level: LogLevel.error,
      );
      rethrow;
    }
  }

  /// Use RAG to find and classify product-related images
  ///
  /// Retrieves frames from database, classifies them using timeline heuristics,
  /// filters by quality (non-blurry, clear), and saves to organized output directory
  ///
  /// Returns TWO images for nutrifact and ingredients (multiple angles/views)
  Future<Map<String, dynamic>> _extractProductImages(
    Session session,
    String videoUrl,
    String processingId,
    String outputDir,
  ) async {
    try {
      session.log('Starting RAG-based product image extraction for: $videoUrl');

      // Create output directories
      final productDir = Directory(path.join(outputDir, 'product'));
      final nutrifactDir = Directory(path.join(outputDir, 'nutrifact'));
      final ingredientsDir = Directory(path.join(outputDir, 'ingredients'));
      final backDir = Directory(path.join(outputDir, 'back'));

      await productDir.create(recursive: true);
      await nutrifactDir.create(recursive: true);
      await ingredientsDir.create(recursive: true);
      await backDir.create(recursive: true);

      final results = <String, dynamic>{};

      // Get all frames for THIS specific processing run
      final dbQueryTimer = Stopwatch()..start();
      final frames = await VideoFrameEmbedding.db.find(
        session,
        where: (t) =>
            t.videoUrl.equals(videoUrl) & t.processingId.equals(processingId),
      );
      dbQueryTimer.stop();
      session.log('⏱️  Database query for frames: ${dbQueryTimer.elapsedMilliseconds}ms');

      if (frames.isEmpty) {
        session.log(
          'No frames found for video: $videoUrl',
          level: LogLevel.warning,
        );
        return results;
      }

      session.log('Analyzing ${frames.length} frames for quality...');

      // Calculate quality scores for all frames
      final qualityTimer = Stopwatch()..start();
      final frameQuality = <VideoFrameEmbedding, double>{};
      for (final frame in frames) {
        final quality = await _calculateImageQuality(frame.framePath);
        frameQuality[frame] = quality;
      }
      qualityTimer.stop();
      session.log('⏱️  Quality analysis: ${qualityTimer.elapsedMilliseconds}ms (${(qualityTimer.elapsedMilliseconds / frames.length).toStringAsFixed(0)}ms per frame)');

      // Helper function to select best quality frames from a list
      Future<List<VideoFrameEmbedding>> selectBestFrames(
        List<VideoFrameEmbedding> candidates,
        int count,
      ) async {
        if (candidates.isEmpty) return [];

        // Sort by quality score (descending - higher is better)
        final sorted = candidates.toList()
          ..sort((a, b) {
            final qualityA = frameQuality[a] ?? 0;
            final qualityB = frameQuality[b] ?? 0;
            return qualityB.compareTo(qualityA);
          });

        // Filter: only accept frames with quality > 30 (clear, not blurry)
        final goodQuality = sorted.where((f) {
          final quality = frameQuality[f] ?? 0;
          return quality > 30;
        }).toList();

        if (goodQuality.isEmpty) {
          session.log(
            'Warning: No high-quality frames found, using best available',
            level: LogLevel.warning,
          );
          return sorted.take(count).toList();
        }

        // Select frames that are spaced apart (different views)
        final selected = <VideoFrameEmbedding>[];
        for (final frame in goodQuality) {
          if (selected.isEmpty) {
            selected.add(frame);
          } else {
            // Only add if timestamp is at least 1 second apart from all selected
            final tooClose = selected.any((s) {
              return (frame.timestamp - s.timestamp).abs() < 1.0;
            });
            if (!tooClose) {
              selected.add(frame);
            }
          }
          if (selected.length >= count) break;
        }

        return selected;
      }

      // ======== CLASSIFICATION AND FILE COPYING ========
      final classificationTimer = Stopwatch()..start();

      // ======== PRODUCT: 1 image from first 20% ========
      final productFrames = frames
          .where((f) => f.timestamp < (frames.last.timestamp * 0.2))
          .toList();
      final selectedProduct = await selectBestFrames(productFrames, 1);

      if (selectedProduct.isNotEmpty) {
        final frame = selectedProduct[0];
        final sourceFile = File(frame.framePath);
        if (await sourceFile.exists()) {
          final outputPath = path.join(
            productDir.path,
            'product_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await sourceFile.copy(outputPath);
          results['product'] = outputPath;
          final quality = frameQuality[frame] ?? 0;
          session.log('✓ Product image saved (quality: ${quality.toStringAsFixed(1)}): $outputPath');
        }
      }

      // ======== NUTRITION FACTS: 2 images from 40-70% ========
      final nutrifactFrames = frames
          .where(
            (f) =>
                f.timestamp >= (frames.last.timestamp * 0.4) &&
                f.timestamp <= (frames.last.timestamp * 0.7),
          )
          .toList();
      final selectedNutrifact = await selectBestFrames(nutrifactFrames, 2);

      final nutrifactPaths = <String>[];
      for (int i = 0; i < selectedNutrifact.length; i++) {
        final frame = selectedNutrifact[i];
        final sourceFile = File(frame.framePath);
        if (await sourceFile.exists()) {
          final outputPath = path.join(
            nutrifactDir.path,
            'nutrifact_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await sourceFile.copy(outputPath);
          nutrifactPaths.add(outputPath);
          final quality = frameQuality[frame] ?? 0;
          session.log('✓ Nutrition facts image ${i + 1}/2 saved (quality: ${quality.toStringAsFixed(1)}): $outputPath');
        }
      }
      results['nutrifact'] = nutrifactPaths;

      // ======== INGREDIENTS: 2 images from 25-55% ========
      final ingredientsFrames = frames
          .where(
            (f) =>
                f.timestamp >= (frames.last.timestamp * 0.25) &&
                f.timestamp <= (frames.last.timestamp * 0.55),
          )
          .toList();
      final selectedIngredients = await selectBestFrames(ingredientsFrames, 2);

      final ingredientsPaths = <String>[];
      for (int i = 0; i < selectedIngredients.length; i++) {
        final frame = selectedIngredients[i];
        final sourceFile = File(frame.framePath);
        if (await sourceFile.exists()) {
          final outputPath = path.join(
            ingredientsDir.path,
            'ingredients_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await sourceFile.copy(outputPath);
          ingredientsPaths.add(outputPath);
          final quality = frameQuality[frame] ?? 0;
          session.log('✓ Ingredients image ${i + 1}/2 saved (quality: ${quality.toStringAsFixed(1)}): $outputPath');
        }
      }
      results['ingredients'] = ingredientsPaths;

      // ======== BACK: 1 image from 60-80% ========
      final backFrames = frames
          .where(
            (f) =>
                f.timestamp >= (frames.last.timestamp * 0.6) &&
                f.timestamp <= (frames.last.timestamp * 0.8),
          )
          .toList();
      final selectedBack = await selectBestFrames(backFrames, 1);

      if (selectedBack.isNotEmpty) {
        final frame = selectedBack[0];
        final sourceFile = File(frame.framePath);
        if (await sourceFile.exists()) {
          final outputPath = path.join(
            backDir.path,
            'back_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await sourceFile.copy(outputPath);
          results['back'] = outputPath;
          final quality = frameQuality[frame] ?? 0;
          session.log('✓ Back image saved (quality: ${quality.toStringAsFixed(1)}): $outputPath');
        }
      }

      classificationTimer.stop();
      session.log('⏱️  Classification + file copying: ${classificationTimer.elapsedMilliseconds}ms');

      // Cleanup: Delete frames and database entries
      session.log('Cleaning up temporary data...');
      final cleanupTimer = Stopwatch()..start();
      await _cleanup(session, videoUrl, processingId);
      cleanupTimer.stop();
      session.log('⏱️  Cleanup: ${cleanupTimer.elapsedMilliseconds}ms');

      session.log('Product image extraction complete!');
      return results;
    } catch (e) {
      session.log('Error extracting product images: $e', level: LogLevel.error);
      rethrow;
    }
  }

  /// Cleanup temporary frames and database entries
  ///
  /// Deletes frame files from disk and removes database entries for a specific processing run
  Future<void> _cleanup(
      Session session, String videoUrl, String processingId) async {
    try {
      // Get frames for THIS specific processing run only
      final frames = await VideoFrameEmbedding.db.find(
        session,
        where: (t) =>
            t.videoUrl.equals(videoUrl) & t.processingId.equals(processingId),
      );

      // Delete frame files from disk
      for (final frame in frames) {
        final file = File(frame.framePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Delete database entries for THIS processing run
      await VideoFrameEmbedding.db.deleteWhere(
        session,
        where: (t) =>
            t.videoUrl.equals(videoUrl) & t.processingId.equals(processingId),
      );

      session.log(
          'Cleaned up ${frames.length} frames for processing ID: $processingId');
    } catch (e) {
      session.log('Error during cleanup: $e', level: LogLevel.warning);
    }
  }

  Future<String> _getAccessToken(Session session) async {
    session.log('Fetching access token...');

    // Service account credentials
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "weedit-india",
      "private_key_id": "ddab251d446cb7a52023fd94e039af5ae2e091a0",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDLigIUwTLYajK+\nOMVt1oHL6C3MGxUdhbwhWN4QWFiPrrzstj9NcDp74hifyeUwpDjODIFp5VitqQou\nHiUDrExBvhVuLEzXMjgmRslnBK4DgFreo3CQYvicCorh5r8RYYfHbIkiDDya3nSE\nZ6rB/4jPIK5neHDGLx8CwN76F6SOK9pTxYDOQfdCmsz1CxWWcCslj6Oj0EesT1Tu\nDBjeqfC3uctq54aUAW2joWQ7XDNSAlHVAXkLuARzxW3iP1FmAlYQmC8Q70NqwykJ\n4e8qLxWw+LH6jIQsjklrDq38hNHjdGCJsb/LUVdIasDFuHiJ70a4tA27AFOQRyiC\nbzi5lY/tAgMBAAECggEADBhe6EnU0ix5aHlqLg1FuE7LTeo8Fn2IgPjNdW4ykRNC\nsdRgraLiLtNwQCqYvou7vm7az+arnuJBMx1ieLXn8C4yCtKCHHWlBY1GUaNjDd02\nSS2wNjxTZr5vo135c7h2f6DRA19zyIY4qVeZu56KTDi2dHqhRP2u25SHi5gVFMem\nN5X/yofNdNCdhR6PDgAOwReJvKYTQmF1/mV0emhg0JxRtJ8QygVVxKz3snlVktnB\nApmE52Y4EHiaGYf2oaF21KAcEK3jwRg2Y02SWiP7ohrwTLTJPaAI4GDf8kd/LC0T\nWKjkkOOo+O2JXlg6Ci0l3pZooapAKdcpduyCQptXcQKBgQDm2Sn950Z9yh5UDk7+\n0hNu6mmXEy/VKdHigl9ZzxJfu9xn29P2C8oOdPom3Lb559DKbOHenyrM805jvd3d\nwjuKeNyQD6bA6pO83KomOdif/OfNbfeMx/G1Y2jrqUPsAJf3bitHcHDjm2dU/4Z9\ni1uJOMNxiSji74IbG4gLYI0jOQKBgQDhtyJOcd8ce4nC5u0/DtTH/NBX8wJ2W6jn\nu1jxr1We643Ujx/UbeomBqvyszW0MXoCb+DLXj8YO6F/uyMG4IqFHslppKJwGKgk\nye4Ff51//CNnL3bljVkzeQWLbWtVEDvavuQG+od1Hb8BbMIb913vJWgARPpSrih0\nXkLD1mnOVQKBgDvISYOjfTHeQfRqsDJ1nOrAcg/ZvC1r4xrRwHe1lICOWgnbeAzk\nCLOtv4qI5inZysxhXi0U8zSYXdietvJS9rBplFUKeJjFJvVl//peSKdGC5G7xLwE\nm6fp0qYU864OiUxej360s8d920i708x3ZoEm3hZs+tWqSPtUKesoWeShAoGAMSIm\nS6EqCg8yS8Ts+/8Efowf5iU18gG94MO9ds7N+owYEZ8eNKXAhIqLP4eXNyRWBNXJ\nvztCzMmePCnGVCbowFWVTnPSEEitwWRbdcLzy/pc0odYgFumgTfk5xboeFnSTamk\nBYjfl7Tj8TF1h5TvU7F21CgvvXO/xqUGL48q9QkCgYBmXzDotdb6bx5NDgWj7/0w\nmJqqunMYyPukOuUz/7QBIDUhQ3DwDklZ4kTVGqS7PHaZLzgHXYMxIDC63t2UOgzy\nBBvfg77dAigMZgCLVOFwUsu4EvoVC74LxZapTKLlCTcw3tvYupmifnypkUOpc2Z/\nS580xE8PTXaQAWtCcsMIFQ==\n-----END PRIVATE KEY-----\n",
      "client_email":
          "vetex-ai-user-serverpod@weedit-india.iam.gserviceaccount.com",
      "client_id": "104443392683761524427",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/vetex-ai-user-serverpod%40weedit-india.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
    final client = await clientViaServiceAccount(credentials, scopes);

    return client.credentials.accessToken.data;
  }

  /// Extract text from classified product images using Gemini 2.0 Flash
  ///
  /// Sends images to Gemini 2.0 Flash API for text extraction and analysis
  Future<Map<String, dynamic>> _extractTextFromImages(
    Session session,
    Map<String, dynamic> productImages,
    String accessToken,
  ) async {
    try {
      final extractedText = <String, dynamic>{};

      // Get back image path to include in nutrition and ingredients extraction
      final backPath = productImages.containsKey('back')
          ? productImages['back'] as String?
          : null;

      // Extract nutrition facts from both nutrifact images + back image
      if (productImages.containsKey('nutrifact')) {
        final nutrifactPaths = (productImages['nutrifact'] as List<dynamic>).cast<String>();
        if (nutrifactPaths.isNotEmpty) {
          // Include back image if available
          final allNutritionImages = [...nutrifactPaths];
          if (backPath != null) {
            allNutritionImages.add(backPath);
          }

          session.log('Extracting nutrition facts from ${allNutritionImages.length} images...');
          final nutritionFacts = await _extractTextWithGemini(
            session,
            allNutritionImages,
            'Extract all nutrition facts information from these images. Return a JSON object with: servingSize, calories, totalFat, saturatedFat, transFat, cholesterol, sodium, totalCarbohydrates, dietaryFiber, sugars, protein, vitamins, and any other nutrition information.',
            accessToken,
          );
          extractedText['nutritionFacts'] = nutritionFacts;
          session.log('✓ Nutrition facts extracted');
        }
      }

      // Extract ingredients from both ingredient images + back image
      if (productImages.containsKey('ingredients')) {
        final ingredientsPaths = (productImages['ingredients'] as List<dynamic>).cast<String>();
        if (ingredientsPaths.isNotEmpty) {
          // Include back image if available
          final allIngredientImages = [...ingredientsPaths];
          if (backPath != null) {
            allIngredientImages.add(backPath);
          }

          session.log('Extracting ingredients from ${allIngredientImages.length} images...');
          final ingredients = await _extractTextWithGemini(
            session,
            allIngredientImages,
            'Extract all ingredients listed in these images. Return a JSON object with: ingredientsList (array of ingredients in order), and allergenWarnings (if any).',
            accessToken,
          );
          extractedText['ingredients'] = ingredients;
          session.log('✓ Ingredients extracted');
        }
      }

      // Extract product information from product image
      if (productImages.containsKey('product')) {
        final productPath = productImages['product'] as String;
        session.log('Extracting product information...');
        final productInfo = await _extractTextWithGemini(
          session,
          [productPath],
          'Extract product information from this image. Return a JSON object with: productName, brandName, netWeight, flavor, and any other visible product details. Include the image in your response.',
          accessToken,
        );
        extractedText['productInfo'] = productInfo;
        session.log('✓ Product information extracted');
      }

      // Extract claims and allergen information from back image
      if (productImages.containsKey('back')) {
        final backPath = productImages['back'] as String;
        session.log('Extracting claims and allergen information...');
        final claimsAndAllergens = await _extractTextWithGemini(
          session,
          [backPath],
          'Extract any health claims, marketing claims, allergen warnings, or certifications from this back-of-package image. Return a JSON object with: healthClaims (array), allergenWarnings (array), certifications (array like organic, non-GMO, etc.), and warningStatements (array). Include the image in your response.',
          accessToken,
        );
        extractedText['claimsAndAllergens'] = claimsAndAllergens;
        session.log('✓ Claims and allergen information extracted');
      }

      return extractedText;
    } catch (e) {
      session.log('Error extracting text from images: $e', level: LogLevel.error);
      rethrow;
    }
  }

  /// Call Gemini 2.0 Flash API to extract text from images
  ///
  /// Uses Vertex AI Gemini 2.0 Flash model for multimodal text extraction
  Future<Map<String, dynamic>> _extractTextWithGemini(
    Session session,
    List<String> imagePaths,
    String prompt,
    String accessToken,
  ) async {
    try {
      // Prepare image content parts
      final imageParts = <Map<String, dynamic>>[];
      final returnImages = <String>[];

      for (final imagePath in imagePaths) {
        final imageBytes = await File(imagePath).readAsBytes();
        final base64Image = base64Encode(imageBytes);
        imageParts.add({
          'inlineData': {
            'mimeType': 'image/png',
            'data': base64Image,
          },
        });
        returnImages.add(imagePath);
      }

      // Build the request content
      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            ...imageParts,
          ],
        },
      ];

      // Gemini 3 Pro endpoint
      final url =
          'https://us-central1-aiplatform.googleapis.com/v1/projects/weedit-india/locations/us-central1/publishers/google/models/gemini-3-pro-preview:generateContent';

      // Make API request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.1,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 2048,
          },
        }),
      );

      if (response.statusCode != 200) {
        session.log('Gemini API error: ${response.body}', level: LogLevel.error);
        throw Exception(
          'Failed to extract text with Gemini: ${response.statusCode} - ${response.body}',
        );
      }

      final result = jsonDecode(response.body);
      final textResponse =
          result['candidates'][0]['content']['parts'][0]['text'] as String;

      session.log('Gemini response received', level: LogLevel.debug);

      // Try to parse JSON from response
      Map<String, dynamic> parsedData;
      try {
        // Look for JSON in the response (might be wrapped in markdown code blocks)
        final jsonMatch = RegExp(r'```json\s*(.*?)\s*```', dotAll: true)
            .firstMatch(textResponse);
        final jsonString = jsonMatch?.group(1) ?? textResponse;
        parsedData = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        // If JSON parsing fails, return raw text
        session.log('Warning: Could not parse JSON from Gemini response',
            level: LogLevel.warning);
        parsedData = {'rawText': textResponse};
      }

      // Add the images to the response
      parsedData['images'] = returnImages;

      return parsedData;
    } catch (e) {
      session.log(
        'Error calling Gemini API: $e',
        level: LogLevel.error,
      );
      rethrow;
    }
  }
}
