class SegmentationPoint {
  final double x;
  final double y;
  final int label;

  SegmentationPoint({required this.x, required this.y, this.label = 1});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'label': label};

  Map<String, dynamic> toPixelJson(int width, int height) => {
    'x': (x * width).toInt(),
    'y': (y * height).toInt(),
    'label': label,
  };
}
