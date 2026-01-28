import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProcessingScreen extends StatefulWidget {
  final double progress;
  final String status;
  final VoidCallback? onCancel;

  const ProcessingScreen({
    super.key,
    required this.progress,
    required this.status,
    this.onCancel,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  List<_ProcessingStage> get _stages => [
        _ProcessingStage(
          icon: Icons.cloud_upload_outlined,
          label: 'Uploading video',
          threshold: 0.1,
        ),
        _ProcessingStage(
          icon: Icons.burst_mode_outlined,
          label: 'Extracting frames',
          threshold: 0.25,
        ),
        _ProcessingStage(
          icon: Icons.auto_awesome_outlined,
          label: 'Generating embeddings',
          threshold: 0.40,
        ),
        _ProcessingStage(
          icon: Icons.analytics_outlined,
          label: 'Analyzing content',
          threshold: 0.55,
        ),
        _ProcessingStage(
          icon: Icons.text_fields_outlined,
          label: 'Extracting text',
          threshold: 0.85,
        ),
        _ProcessingStage(
          icon: Icons.check_circle_outline,
          label: 'Finalizing',
          threshold: 0.95,
        ),
      ];

  int get _currentStageIndex {
    for (int i = _stages.length - 1; i >= 0; i--) {
      if (widget.progress >= _stages[i].threshold) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with cancel option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  if (widget.onCancel != null)
                    TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated progress ring
                    _buildProgressRing(colors),
                    const SizedBox(height: 40),

                    // Status text with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        widget.status,
                        key: ValueKey(widget.status),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This may take a moment',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Stage indicators
                    _buildStageIndicators(colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(ColorScheme colors) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ring
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 12,
                backgroundColor: colors.surfaceContainerHighest,
                color: colors.surfaceContainerHighest,
              ),
            ),

            // Animated gradient ring
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: CustomPaint(
                      painter: _GradientProgressPainter(
                        progress: widget.progress,
                        primaryColor: colors.primary,
                        secondaryColor: colors.tertiary,
                        strokeWidth: 12,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Percentage text
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.progress * 100),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Text(
                      '${value.toInt()}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
                Text(
                  'Complete',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageIndicators(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(_stages.length, (index) {
          final stage = _stages[index];
          final isCompleted = widget.progress >= stage.threshold;
          final isCurrent = index == _currentStageIndex;

          return Padding(
            padding: EdgeInsets.only(bottom: index < _stages.length - 1 ? 12 : 0),
            child: Row(
              children: [
                // Stage indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? colors.primary
                        : isCurrent
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          )
                        : isCurrent
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              )
                            : Icon(
                                stage.icon,
                                size: 16,
                                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                  ),
                ),
                const SizedBox(width: 14),

                // Stage label
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCompleted || isCurrent
                          ? colors.onSurface
                          : colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    child: Text(stage.label),
                  ),
                ),

                // Progress indicator for current stage
                if (isCurrent)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: colors.primary,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ProcessingStage {
  final IconData icon;
  final String label;
  final double threshold;

  const _ProcessingStage({
    required this.icon,
    required this.label,
    required this.threshold,
  });
}

class _GradientProgressPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final double strokeWidth;

  _GradientProgressPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [primaryColor, secondaryColor, primaryColor],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
