import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Overlay that lets users drag-draw a rectangular bounding box on top of an
/// image.  The [onBboxChanged] callback receives a normalised [Rect] (0..1)
/// relative to the widget size.
class BboxPainter extends StatefulWidget {
  final VoidCallback? onBboxCleared;
  final ValueChanged<Rect> onBboxChanged;
  final Rect? initialBox;

  const BboxPainter({
    super.key,
    required this.onBboxChanged,
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

  @override
  void initState() {
    super.initState();
    _normBox = widget.initialBox;
  }

  Rect _toRect(Offset a, Offset b) {
    return Rect.fromPoints(a, b);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;

      return GestureDetector(
        onPanStart: (d) {
          setState(() {
            _start = d.localPosition;
            _current = d.localPosition;
            _normBox = null;
          });
        },
        onPanUpdate: (d) {
          setState(() {
            _current = Offset(
              d.localPosition.dx.clamp(0, size.width),
              d.localPosition.dy.clamp(0, size.height),
            );
          });
        },
        onPanEnd: (_) {
          if (_start != null && _current != null) {
            final raw = _toRect(_start!, _current!);
            final norm = Rect.fromLTWH(
              (raw.left / size.width).clamp(0.0, 1.0),
              (raw.top / size.height).clamp(0.0, 1.0),
              (raw.width / size.width).clamp(0.01, 1.0),
              (raw.height / size.height).clamp(0.01, 1.0),
            );
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
            widgetSize: size,
          ),
          child: Container(color: Colors.transparent), // hit-test area
        ),
      );
    });
  }
}

class _BoxPainter extends CustomPainter {
  final Offset? drawingStart;
  final Offset? drawingCurrent;
  final Rect? normBox;
  final Size widgetSize;

  _BoxPainter({
    this.drawingStart,
    this.drawingCurrent,
    this.normBox,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    Rect? rect;

    if (drawingStart != null && drawingCurrent != null) {
      rect = Rect.fromPoints(drawingStart!, drawingCurrent!);
    } else if (normBox != null) {
      rect = Rect.fromLTWH(
        normBox!.left * widgetSize.width,
        normBox!.top * widgetSize.height,
        normBox!.width * widgetSize.width,
        normBox!.height * widgetSize.height,
      );
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
        ..color = AppColors.primary.withOpacity(0.3)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(rect.left, cy), Offset(rect.right, cy), crossPaint);
      canvas.drawLine(Offset(cx, rect.top), Offset(cx, rect.bottom), crossPaint);
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
