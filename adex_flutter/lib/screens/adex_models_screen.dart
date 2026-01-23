import 'dart:convert';
import 'package:adex_client/adex_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

/// Screen to display all AdexModel records in a read-only format
class AdexModelsScreen extends StatefulWidget {
  const AdexModelsScreen({super.key});

  @override
  State<AdexModelsScreen> createState() => _AdexModelsScreenState();
}

class _AdexModelsScreenState extends State<AdexModelsScreen> {
  List<AdexModel>? _models;
  bool _isLoading = true;
  String? _errorMessage;
  AdexModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final models = await client.adexService.getAllAdexModels();
      setState(() {
        _models = models;
        _isLoading = false;
        if (models.isNotEmpty && _selectedModel == null) {
          _selectedModel = models.first;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load models: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Adex Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadModels,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(colors, isWide),
    );
  }

  Widget _buildBody(ColorScheme colors, bool isWide) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: colors.error)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadModels,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_models == null || _models!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No models found',
              style: TextStyle(
                fontSize: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Process a video to see results here',
              style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (isWide) {
      return Row(
        children: [
          SizedBox(
            width: 320,
            child: _buildModelsList(colors),
          ),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(
            child: _selectedModel != null
                ? _buildModelDetail(colors, _selectedModel!)
                : Center(
                    child: Text(
                      'Select a model to view details',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
          ),
        ],
      );
    }

    // Mobile layout - show list or detail
    if (_selectedModel != null) {
      return Column(
        children: [
          _buildMobileHeader(colors),
          Expanded(child: _buildModelDetail(colors, _selectedModel!)),
        ],
      );
    }

    return _buildModelsList(colors);
  }

  Widget _buildMobileHeader(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedModel = null),
          ),
          Expanded(
            child: Text(
              'Model Details',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelsList(ColorScheme colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _models!.length,
      itemBuilder: (context, index) {
        final model = _models![index];
        final isSelected = _selectedModel?.id == model.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected ? colors.primaryContainer : colors.surfaceContainerLow,
          child: InkWell(
            onTap: () => setState(() => _selectedModel = model),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatusBadge(model.status, colors),
                      const Spacer(),
                      Text(
                        _formatDate(model.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? colors.onPrimaryContainer.withValues(alpha: 0.7)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    model.userPrompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${model.processingId.substring(0, 12)}...',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isSelected
                          ? colors.onPrimaryContainer.withValues(alpha: 0.7)
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, ColorScheme colors) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelDetail(ColorScheme colors, AdexModel model) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          _buildHeaderCard(colors, model),
          const SizedBox(height: 16),

          // Main Info Card
          _buildInfoCard(colors, model),
          const SizedBox(height: 16),

          // Extracted Frames Card
          if (model.extractedFrames != null) ...[
            _buildExtractedFramesCard(colors, model),
            const SizedBox(height: 16),
          ],

          // Extracted Text Card
          if (model.extractedText != null) ...[
            _buildExtractedTextCard(colors, model),
            const SizedBox(height: 16),
          ],

          // Error Card
          if (model.errorMessage != null) ...[
            _buildErrorCard(colors, model),
            const SizedBox(height: 16),
          ],

          // Raw JSON Card
          _buildRawJsonCard(colors, model),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colors, AdexModel model) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusBadge(model.status, colors),
                const Spacer(),
                if (model.completedAt != null)
                  Text(
                    'Completed: ${_formatDate(model.completedAt!)}',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              model.userPrompt,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.fingerprint, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: SelectableText(
                    model.processingId,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: model.processingId));
                    _showSnackBar('Processing ID copied');
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy ID',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colors, AdexModel model) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Processing Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Video URL', model.videoUrl, colors),
            if (model.whatDoesThisVideoContain != null)
              _buildInfoRow('Video Description', model.whatDoesThisVideoContain!, colors),
            if (model.suggestFramesToExtract != null)
              _buildInfoRow('Suggested Frames', model.suggestFramesToExtract!, colors),
            _buildInfoRow('Extract Text', model.extractToText ? 'Yes' : 'No', colors),
            if (model.extractedDataInformationPrompt != null)
              _buildInfoRow('Text Extraction Prompt', model.extractedDataInformationPrompt!, colors),
            _buildInfoRow('Created', _formatDateTime(model.createdAt), colors),
            if (model.completedAt != null)
              _buildInfoRow('Completed', _formatDateTime(model.completedAt!), colors),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(fontSize: 13, color: colors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedFramesCard(ColorScheme colors, AdexModel model) {
    List<dynamic> frames;
    try {
      frames = jsonDecode(model.extractedFrames!) as List<dynamic>;
    } catch (e) {
      return const SizedBox.shrink();
    }

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Extracted Frames',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${frames.length} types',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...frames.map((frame) => _buildFrameTypeItem(frame as Map<String, dynamic>, colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameTypeItem(Map<String, dynamic> frame, ColorScheme colors) {
    final frameType = frame['frameType'] as String;
    final description = frame['description'] as String;
    final urls = (frame['extractedFrameUrls'] as List<dynamic>).cast<String>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  frameType.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${urls.length} frame${urls.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: urls.length,
                itemBuilder: (context, index) {
                  final url = urls[index];
                  final fullUrl = url.startsWith('http')
                      ? url
                      : 'http://13.53.188.175:8082$url';
                  return Container(
                    width: 80,
                    margin: EdgeInsets.only(right: index < urls.length - 1 ? 8 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(Icons.broken_image, size: 16, color: colors.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtractedTextCard(ColorScheme colors, AdexModel model) {
    Map<String, dynamic> textData;
    try {
      textData = jsonDecode(model.extractedText!) as Map<String, dynamic>;
    } catch (e) {
      return Card(
        color: colors.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.text_fields, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Extracted Text',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                model.extractedText!,
                style: TextStyle(fontSize: 12, color: colors.onSurface),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Extracted Text',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: model.extractedText!));
                    _showSnackBar('Extracted text copied');
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...textData.entries.map((entry) => _buildExtractedDataEntry(entry.key, entry.value, colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedDataEntry(String key, dynamic value, ColorScheme colors) {
    final displayValue = value is Map || value is List
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value.toString();

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        key.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
              fontSize: 11,
              fontFamily: 'monospace',
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(ColorScheme colors, AdexModel model) {
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: colors.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              model.errorMessage!,
              style: TextStyle(fontSize: 13, color: colors.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawJsonCard(ColorScheme colors, AdexModel model) {
    final jsonString = const JsonEncoder.withIndent('  ').convert(model.toJson());

    return Card(
      color: colors.surfaceContainerLow,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.code, size: 18, color: colors.primary),
          title: const Text(
            'Raw JSON Response',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonString));
                  _showSnackBar('JSON copied');
                },
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy JSON',
              ),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonString,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
}
