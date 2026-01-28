import 'dart:convert';
import 'package:adex_client/adex_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class ResultScreen extends StatefulWidget {
  final AdexModel model;
  final VideoPlayerController? videoController;
  final VoidCallback onNewCapture;
  final VoidCallback onBack;
  final bool isFromHistory;

  const ResultScreen({
    super.key,
    required this.model,
    this.videoController,
    required this.onNewCapture,
    required this.onBack,
    this.isFromHistory = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic>? _frames;
  Map<String, dynamic>? _extractedData;
  int _frameCount = 0;
  int _dataFieldCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _parseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _parseData() {
    // Parse frames
    if (widget.model.extractedFrames != null) {
      try {
        _frames = jsonDecode(widget.model.extractedFrames!) as List<dynamic>;
        _frameCount = _frames!.fold<int>(0, (sum, frame) {
          final urls = (frame as Map<String, dynamic>)['extractedFrameUrls'] as List?;
          return sum + (urls?.length ?? 0);
        });
      } catch (_) {}
    }

    // Parse extracted data
    if (widget.model.extractedText != null) {
      try {
        _extractedData = jsonDecode(widget.model.extractedText!) as Map<String, dynamic>;
        _dataFieldCount = _extractedData!.length;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: true,
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              title: const Text('Results'),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _shareResults,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: _copyToClipboard,
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: colors.primary,
                unselectedLabelColor: colors.onSurfaceVariant,
                indicatorColor: colors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Frames'),
                  Tab(text: 'Data'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(colors),
            _buildFramesTab(colors),
            _buildDataTab(colors),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: widget.onNewCapture,
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Capture New Video'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  // ============ OVERVIEW TAB ============
  Widget _buildOverviewTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Success card
        _buildSuccessCard(colors),
        const SizedBox(height: 16),

        // Video player
        if (widget.videoController?.value.isInitialized == true)
          _buildVideoPlayer(colors),

        // Quick stats
        const SizedBox(height: 16),
        _buildQuickStats(colors),

        // Prompt info
        const SizedBox(height: 16),
        _buildPromptCard(colors),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSuccessCard(ColorScheme colors) {
    final isCompleted = widget.model.status.toLowerCase() == 'completed';
    final statusColor = isCompleted
        ? const Color(0xFF10B981)
        : widget.model.status.toLowerCase() == 'failed'
            ? colors.error
            : colors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : Icons.sync,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted ? 'Processing Complete' : widget.model.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.tag,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.model.processingId.substring(0, 12),
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: widget.videoController!.value.aspectRatio,
          child: GestureDetector(
            onTap: () {
              setState(() {
                widget.videoController!.value.isPlaying
                    ? widget.videoController!.pause()
                    : widget.videoController!.play();
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(widget.videoController!),
                AnimatedOpacity(
                  opacity: widget.videoController!.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            colors,
            icon: Icons.photo_library_outlined,
            label: 'Frames',
            value: '$_frameCount',
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            colors,
            icon: Icons.data_object,
            label: 'Fields',
            value: '$_dataFieldCount',
            color: colors.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ColorScheme colors, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard(ColorScheme colors) {
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
              Icon(Icons.edit_note, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Extraction Prompt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.model.userPrompt,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============ FRAMES TAB ============
  Widget _buildFramesTab(ColorScheme colors) {
    if (_frames == null || _frames!.isEmpty) {
      return _buildEmptyState(
        colors,
        icon: Icons.photo_library_outlined,
        title: 'No frames extracted',
        subtitle: 'Frame extraction was not performed for this video',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _frames!.length,
      itemBuilder: (context, index) {
        final frame = _frames![index] as Map<String, dynamic>;
        return _buildFrameCategory(colors, frame);
      },
    );
  }

  Widget _buildFrameCategory(ColorScheme colors, Map<String, dynamic> frame) {
    final frameType = frame['frameType'] as String;
    final urls = (frame['extractedFrameUrls'] as List<dynamic>).cast<String>();
    final description = frame['description'] as String?;

    // Color palette for frame types
    final typeColors = <String, Color>{
      'nutrition_facts': const Color(0xFF10B981),
      'ingredients_list': const Color(0xFF3B82F6),
      'product_front': const Color(0xFFF59E0B),
      'product_back': const Color(0xFF8B5CF6),
      'barcode': const Color(0xFFEC4899),
    };
    final color = typeColors[frameType] ?? colors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      frameType.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${urls.length} frames',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),

          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Frame grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: urls.length,
            itemBuilder: (context, index) {
              return _buildFrameThumbnail(colors, urls[index], color);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrameThumbnail(ColorScheme colors, String url, Color accentColor) {
    return GestureDetector(
      onTap: () => _showImageViewer(url),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: colors.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, error, stackTrace) => Container(
                  color: colors.errorContainer,
                  child: Icon(Icons.broken_image, color: colors.error),
                ),
              ),
              // Expand icon overlay
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ DATA TAB ============
  Widget _buildDataTab(ColorScheme colors) {
    if (_extractedData == null || _extractedData!.isEmpty) {
      return _buildEmptyState(
        colors,
        icon: Icons.data_object,
        title: 'No data extracted',
        subtitle: 'Text extraction was not enabled for this video',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Copy all button
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(
              text: const JsonEncoder.withIndent('  ').convert(_extractedData),
            ));
            _showSnackBar('All data copied');
          },
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('Copy All Data'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Data sections
        ..._extractedData!.entries.map((entry) {
          return _buildDataSection(colors, entry.key, entry.value);
        }),

        // Raw JSON
        const SizedBox(height: 16),
        _buildRawJsonSection(colors),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDataSection(ColorScheme colors, String key, dynamic value) {
    final displayKey = key.replaceAll('_', ' ');
    final isComplex = value is Map || value is List;
    final displayValue = isComplex
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIconForKey(key),
              size: 20,
              color: colors.primary,
            ),
          ),
          title: Text(
            displayKey.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: !isComplex
              ? Text(
                  displayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: displayValue));
                  _showSnackBar('$displayKey copied');
                },
                visualDensity: VisualDensity.compact,
                color: colors.onSurfaceVariant,
              ),
              Icon(
                Icons.expand_more,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                displayValue,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: isComplex ? 'monospace' : null,
                  color: colors.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawJsonSection(ColorScheme colors) {
    final json = const JsonEncoder.withIndent('  ').convert(widget.model.toJson());

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.code,
              size: 20,
              color: colors.tertiary,
            ),
          ),
          title: Text(
            'RAW JSON',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            'Full response data',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colors.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ HELPER WIDGETS ============
  Widget _buildEmptyState(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForKey(String key) {
    final keyLower = key.toLowerCase();
    if (keyLower.contains('product') || keyLower.contains('brand')) {
      return Icons.inventory_2_outlined;
    }
    if (keyLower.contains('nutrition') || keyLower.contains('calorie')) {
      return Icons.restaurant_outlined;
    }
    if (keyLower.contains('ingredient')) {
      return Icons.list_alt_outlined;
    }
    if (keyLower.contains('allergen')) {
      return Icons.warning_amber_outlined;
    }
    if (keyLower.contains('claim') || keyLower.contains('certification')) {
      return Icons.verified_outlined;
    }
    if (keyLower.contains('manufactur') || keyLower.contains('address')) {
      return Icons.business_outlined;
    }
    return Icons.label_outlined;
  }

  void _showImageViewer(String url) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
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
        );
      },
    );
  }

  void _shareResults() {
    final json = const JsonEncoder.withIndent('  ').convert(widget.model.toJson());
    Clipboard.setData(ClipboardData(text: json));
    _showSnackBar('Results copied to clipboard');
  }

  void _copyToClipboard() {
    final json = const JsonEncoder.withIndent('  ').convert(widget.model.toJson());
    Clipboard.setData(ClipboardData(text: json));
    _showSnackBar('Copied to clipboard');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
