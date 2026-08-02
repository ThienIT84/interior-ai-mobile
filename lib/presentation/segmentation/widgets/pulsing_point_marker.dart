import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/point_model.dart';

/// A widget that renders an animated pulsing marker at a segmentation point.
class PulsingPointMarker extends StatefulWidget {
  final SegmentationPoint point;
  final int index;
  final Rect imageRect;

  const PulsingPointMarker({
    super.key,
    required this.point,
    required this.index,
    required this.imageRect,
  });

  @override
  State<PulsingPointMarker> createState() => _PulsingPointMarkerState();
}

class _PulsingPointMarkerState extends State<PulsingPointMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 2.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double cx =
        widget.imageRect.left + widget.point.x * widget.imageRect.width;
    final double cy =
        widget.imageRect.top + widget.point.y * widget.imageRect.height;

    const double markerSize = 28;
    const double pulseSize = 40;

    return Stack(
      children: [
        // Pulse ring (animated)
        Positioned(
          left: cx - pulseSize / 2,
          top: cy - pulseSize / 2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: pulseSize,
                    height: pulseSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Core marker (static)
        Positioned(
          left: cx - markerSize / 2,
          top: cy - markerSize / 2,
          child: Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.85),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${widget.index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the mask overlays with a premium glow effect.
class MaskOverlayPainter extends CustomPainter {
  final ImageProvider maskImage;

  MaskOverlayPainter({required this.maskImage});

  @override
  void paint(Canvas canvas, Size size) {
    // Mask is rendered via Image.network in the widget tree
    // This painter is reserved for future custom mask effects
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
