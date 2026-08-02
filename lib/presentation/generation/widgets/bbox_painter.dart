import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_geometry.dart';

/// Overlay that lets users drag-draw a rectangular bounding box on top of an
/// image.  The [onBboxChanged] callback receives a normalised [Rect] (0..1)
/// relative to the widget size.
class BboxPainter extends StatefulWidget {
  final VoidCallback? onBboxCleared;
  final ValueChanged<Rect> onBboxChanged;
  final Rect? initialBox;
  final ImageProvider imageProvider;

  const BboxPainter({
    super.key,
    required this.onBboxChanged,
    required this.imageProvider,
    this.onBboxCleared,
    this.initialBox,
  });

  @override
  State<BboxPainter> createState() => _BboxPainterState();
}

class _BboxPainterState extends State<BboxPainter> {
  Offset? _start;
  Offset? _current;
  Rect? _normBox;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _normBox = widget.initialBox;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant BboxPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) _resolveImageSize();
  }

  void _resolveImageSize() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    _imageListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    });
    _imageStream!.addListener(_imageListener!);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    super.dispose();
  }

  Rect _toRect(Offset a, Offset b) {
    return Rect.fromPoints(a, b);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final imageRect = _imageSize == null
            ? Offset.zero & size
            : containedImageRect(viewport: size, image: _imageSize!);

        return GestureDetector(
          onPanStart: (d) {
            if (!imageRect.contains(d.localPosition)) return;
            setState(() {
              _start = d.localPosition;
              _current = d.localPosition;
              _normBox = null;
            });
          },
          onPanUpdate: (d) {
            if (_start == null) return;
            setState(() {
              _current = Offset(
                d.localPosition.dx.clamp(imageRect.left, imageRect.right),
                d.localPosition.dy.clamp(imageRect.top, imageRect.bottom),
              );
            });
          },
          onPanEnd: (_) {
            if (_start != null && _current != null) {
              final raw = _toRect(_start!, _current!);
              final norm = normalizeRectToImage(raw, imageRect);
              setState(() {
                _normBox = norm;
                _start = null;
                _current = null;
              });
              widget.onBboxChanged(norm);
            }
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _BoxPainter(
              drawingStart: _start,
              drawingCurrent: _current,
              normBox: _normBox,
              imageRect: imageRect,
            ),
            child: Container(color: Colors.transparent), // hit-test area
          ),
        );
      },
    );
  }
}

class _BoxPainter extends CustomPainter {
  final Offset? drawingStart;
  final Offset? drawingCurrent;
  final Rect? normBox;
  final Rect imageRect;

  _BoxPainter({
    this.drawingStart,
    this.drawingCurrent,
    this.normBox,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    Rect? rect;

    if (drawingStart != null && drawingCurrent != null) {
      rect = Rect.fromPoints(drawingStart!, drawingCurrent!);
    } else if (normBox != null) {
      rect = denormalizeRectFromImage(normBox!, imageRect);
    }

    if (rect != null) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, paint);

      // Draw corner handles
      _drawHandle(canvas, rect.topLeft);
      _drawHandle(canvas, rect.topRight);
      _drawHandle(canvas, rect.bottomLeft);
      _drawHandle(canvas, rect.bottomRight);

      // Draw dashed center cross for visual reference
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final crossPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(rect.left, cy),
        Offset(rect.right, cy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(cx, rect.top),
        Offset(cx, rect.bottom),
        crossPaint,
      );
    }
  }

  void _drawHandle(Canvas canvas, Offset position) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(position, 5, paint);
    canvas.drawCircle(position, 5, border);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => true;
}
