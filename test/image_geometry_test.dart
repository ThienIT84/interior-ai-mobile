import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interior_frontend/core/utils/image_geometry.dart';

void main() {
  test('landscape image is letterboxed vertically', () {
    final rect = containedImageRect(
      viewport: const Size(400, 400),
      image: const Size(1600, 900),
    );

    expect(rect.left, 0);
    expect(rect.width, 400);
    expect(rect.height, closeTo(225, 0.001));
    expect(rect.top, closeTo(87.5, 0.001));
  });

  test('portrait image is letterboxed horizontally', () {
    final rect = containedImageRect(
      viewport: const Size(600, 300),
      image: const Size(600, 1200),
    );

    expect(rect.top, 0);
    expect(rect.height, 300);
    expect(rect.width, 150);
    expect(rect.left, 225);
  });

  test('bounding box coordinates ignore the letterbox area', () {
    const imageRect = Rect.fromLTWH(0, 87.5, 400, 225);
    const selection = Rect.fromLTWH(100, 143.75, 200, 112.5);

    final normalized = normalizeRectToImage(selection, imageRect);

    expect(normalized, const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5));
    expect(denormalizeRectFromImage(normalized, imageRect), selection);
  });
}
