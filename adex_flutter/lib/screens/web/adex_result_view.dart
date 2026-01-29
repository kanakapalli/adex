import 'dart:convert';
import 'package:adex_client/adex_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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

class AdexResultView extends StatefulWidget {
  final AdexModel result;
  final VoidCallback onNewPressed;

  const AdexResultView({
    super.key,
    required this.result,
    required this.onNewPressed,
  });

  @override
  State<AdexResultView> createState() => _AdexResultViewState();
}

class _AdexResultViewState extends State<AdexResultView>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  List<VideoTimestamp> _videoTimestamps = [];
  int? _selectedTimestampIndex;
  String? _selectedFrameUrl;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _initializeVideoPlayer(widget.result.videoUrl);
    _fadeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    _videoPlayerController?.dispose();
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(videoUrl));

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
    final timestamps = <VideoTimestamp>[];
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF8B5CF6), // Violet
    ];

    if (widget.result.extractedFrames != null) {
      try {
        final extractedFrames =
            jsonDecode(widget.result.extractedFrames!) as List<dynamic>;

        for (int i = 0; i < extractedFrames.length; i++) {
          final frame = extractedFrames[i] as Map<String, dynamic>;
          final frameType = frame['frameType'] as String;
          final description = frame['description'] as String;
          final urls =
              (frame['extractedFrameUrls'] as List<dynamic>).cast<String>();
          final frameTimestamps =
              frame['extractedFrameTimestamps'] as List<dynamic>?;

          double timestampSeconds = 0.0;
          if (frameTimestamps != null && frameTimestamps.isNotEmpty) {
            timestampSeconds = (frameTimestamps.first as num).toDouble();
          }

          String? thumbnailUrl;
          if (urls.isNotEmpty) {
            thumbnailUrl = urls.first;
          }

          timestamps.add(VideoTimestamp(
            timestamp:
                Duration(milliseconds: (timestampSeconds * 1000).round()),
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
    if (_videoPlayerController == null || index >= _videoTimestamps.length) {
      return;
    }
    final timestamp = _videoTimestamps[index];
    _videoPlayerController!.seekTo(timestamp.timestamp);
    _videoPlayerController!.pause();
    setState(() => _selectedTimestampIndex = index);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        // Compact header with New button
        _buildCompactHeader(colors),
        // Results content with fade animation
        _buildResultsSection(colors),
      ],
    );
  }

  Widget _buildCompactHeader(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo/adex_logo.png',
              width: 28,
              height: 28,
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
            onPressed: widget.onNewPressed,
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
            if (context.useWideLayout &&
                widget.result.extractedFrames != null)
              _buildVideoFramesSideBySide(colors)
            else
              _buildVideoSection(colors),

            // Data and JSON sections
            if (widget.result.extractedText != null || true) ...[
              const SizedBox(height: 20),
              _buildDataJsonTabs(colors),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
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
                'ID: ${widget.result.processingId.substring(0, 8)}...',
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

  Widget _buildVideoFramesSideBySide(ColorScheme colors) {
    final gap = context.isLarge || context.isExtraLarge ? 32.0 : 20.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildVideoCard(colors),
        ),
        SizedBox(width: gap),
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
        if (widget.result.extractedFrames != null) ...[
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
                  aspectRatio:
                      _videoPlayerController?.value.isInitialized == true
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
                                opacity: _videoPlayerController!.value.isPlaying
                                    ? 0
                                    : 1,
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
                            child: CircularProgressIndicator(
                                color: colors.primary),
                          ),
                        ),
                ),

                // Progress bar
                if (_videoPlayerController?.value.isInitialized == true)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _videoPlayerController!,
                      builder: (context, value, _) =>
                          _buildVideoProgress(value, colors),
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
    final frames =
        jsonDecode(widget.result.extractedFrames!) as List<dynamic>;

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
                Icon(Icons.photo_library_outlined,
                    size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Extracted Frames',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Click to seek',
                  style:
                      TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
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
            final urls = (frame['extractedFrameUrls'] as List<dynamic>)
                .cast<String>();
            final timestamps =
                frame['extractedFrameTimestamps'] as List<dynamic>?;

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
    final matchingTimestamp =
        _videoTimestamps.isNotEmpty && frameIndex < _videoTimestamps.length
            ? _videoTimestamps[frameIndex]
            : null;
    final isTypeSelected = _selectedTimestampIndex == frameIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTypeSelected
            ? colors.primaryContainer.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: isTypeSelected
            ? Border.all(color: colors.primary, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            InkWell(
              onTap: () => _selectFrameType(frameIndex),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTypeSelected
                            ? colors.primary
                            : colors.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        frameType.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isTypeSelected
                              ? colors.onPrimary
                              : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (matchingTimestamp != null) ...[
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: isTypeSelected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(matchingTimestamp.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isTypeSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isTypeSelected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '${urls.length} frame${urls.length > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    if (isTypeSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.play_circle_filled,
                          size: 16, color: colors.primary),
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
                  final thumbHeight = context.isCompact
                      ? 80.0
                      : (context.isMedium ? 90.0 : 100.0);
                  final thumbWidth = context.isCompact
                      ? 110.0
                      : (context.isMedium ? 130.0 : 150.0);

                  return SizedBox(
                    height: thumbHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final imageUrl = urls[index];
                        final isSelected = _selectedFrameUrl == imageUrl;

                        Duration? frameTimestamp;
                        if (timestamps != null && index < timestamps.length) {
                          frameTimestamp = Duration(
                            milliseconds:
                                ((timestamps[index] as num).toDouble() * 1000)
                                    .round(),
                          );
                        }

                        return GestureDetector(
                          onTap: () => _selectFrame(
                              imageUrl, frameIndex, frameTimestamp),
                          onLongPress: () => _showImageViewer(imageUrl),
                          child: Container(
                            width: thumbWidth,
                            margin: EdgeInsets.only(
                                right: index < urls.length - 1 ? 8 : 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : colors.outlineVariant,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: colors.primary
                                            .withValues(alpha: 0.3),
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
                                          value:
                                              progress.expectedTotalBytes !=
                                                      null
                                                  ? progress
                                                          .cumulativeBytesLoaded /
                                                      progress
                                                          .expectedTotalBytes!
                                                  : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(Icons.broken_image,
                                          size: 20, color: colors.error),
                                    ),
                                  ),
                                  // Selected overlay
                                  if (isSelected)
                                    Container(
                                      color: colors.primary
                                          .withValues(alpha: 0.2),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(4),
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

  Widget _buildVideoProgress(VideoPlayerValue value, ColorScheme colors) {
    final duration = value.duration.inMilliseconds.toDouble();
    if (duration == 0) return const SizedBox.shrink();

    return Column(
      children: [
        // Slider with frame markers
        LayoutBuilder(
          builder: (context, constraints) {
            const sliderHeight = 32.0;
            const sliderPadding = 14.0;
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
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: colors.primary,
                      inactiveTrackColor: colors.surfaceContainerHighest,
                      thumbColor: colors.primary,
                    ),
                    child: Slider(
                      value: value.position.inMilliseconds
                          .toDouble()
                          .clamp(0, duration),
                      min: 0,
                      max: duration,
                      onChanged: (v) => _videoPlayerController!
                          .seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),

                  // Frame markers on the track
                  ..._videoTimestamps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final timestamp = entry.value;
                    final isSelected = _selectedTimestampIndex == index;
                    final position =
                        timestamp.timestamp.inMilliseconds / duration;
                    final markerLeft =
                        sliderPadding + (trackWidth * position);
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
                            color: isSelected
                                ? timestamp.color
                                : timestamp.color.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 2.5 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? timestamp.color
                                        .withValues(alpha: 0.6)
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
                style:
                    TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              Text(
                _formatDuration(value.duration),
                style:
                    TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
            backgroundColor:
                selected ? ts.color.withValues(alpha: 0.15) : null,
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

  Widget _buildDataJsonTabs(ColorScheme colors) {
    final hasData = widget.result.extractedText != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (hasData) _buildDataSection(colors),
          _buildJsonSection(colors),
        ],
      ),
    );
  }

  Widget _buildDataSection(ColorScheme colors) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(widget.result.extractedText!) as Map<String, dynamic>;
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
                  Clipboard.setData(
                      ClipboardData(text: widget.result.extractedText!));
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
        ...data.entries
            .map((entry) => _buildDataEntry(entry.key, entry.value, colors)),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildJsonSection(ColorScheme colors) {
    final json = const JsonEncoder.withIndent('  ')
        .convert(widget.result.toJson());

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
