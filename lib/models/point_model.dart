/// Model for segmentation point
class SegmentationPoint {
  final double x;
  final double y;
  final int label; // 1 = foreground, 0 = background

  SegmentationPoint({
    required this.x,
    required this.y,
    this.label = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'label': label,
    };
  }

  /// Convert normalized coordinates to pixel integer coordinates for backend
  Map<String, dynamic> toPixelJson(int imageWidth, int imageHeight) {
    return {
      'x': (x * imageWidth).round(),
      'y': (y * imageHeight).round(),
      'label': label,
    };
  }

  @override
  String toString() => 'Point(x: $x, y: $y, label: $label)';
}
