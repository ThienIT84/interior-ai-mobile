import 'package:flutter/widgets.dart';

Rect containedImageRect({required Size viewport, required Size image}) {
  if (viewport.isEmpty || image.isEmpty) return Offset.zero & viewport;
  final scale = (viewport.width / image.width).clamp(
    0.0,
    viewport.height / image.height,
  );
  final displayed = Size(image.width * scale, image.height * scale);
  return Rect.fromLTWH(
    (viewport.width - displayed.width) / 2,
    (viewport.height - displayed.height) / 2,
    displayed.width,
    displayed.height,
  );
}

Rect normalizeRectToImage(Rect selection, Rect imageRect) {
  if (imageRect.isEmpty) return Rect.zero;
  return Rect.fromLTWH(
    ((selection.left - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
    ((selection.top - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
    (selection.width / imageRect.width).clamp(0.01, 1.0),
    (selection.height / imageRect.height).clamp(0.01, 1.0),
  );
}

Rect denormalizeRectFromImage(Rect normalized, Rect imageRect) {
  return Rect.fromLTWH(
    imageRect.left + normalized.left * imageRect.width,
    imageRect.top + normalized.top * imageRect.height,
    normalized.width * imageRect.width,
    normalized.height * imageRect.height,
  );
}
