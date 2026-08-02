import 'package:flutter/material.dart';
import '../../../core/providers/base_provider.dart';
import '../../../data/datasources/remote_datasource.dart';
import '../../../data/models/app_image.dart';
import '../../../data/models/point_model.dart';

class SegmentationProvider extends BaseProvider {
  SegmentationProvider({RemoteDataSource? dataSource})
    : _dataSource = dataSource ?? RemoteDataSource();

  final RemoteDataSource _dataSource;

  // ─── Image state ──────────────────────────────
  AppImage? _image;
  String? _imageId;
  int? _imageWidth;
  int? _imageHeight;

  // ─── Segmentation state ───────────────────────
  final List<SegmentationPoint> _points = [];
  String? _maskId;
  bool _showMask = true;
  double _maskOpacity = 0.45;

  // ─── Backend config ───────────────────────────
  static const String backendLocal = 'local';
  static const String backendSam3 = 'sam3_replicate';
  String _selectedBackend = backendSam3;
  String? _defaultBackend;
  String? _selectedModelName;
  String? _backendDebugError;
  final TextEditingController textPromptController = TextEditingController();

  // ─── Status message ───────────────────────────
  String _status = 'Tap on an object to select it';
  bool _isSegmenting = false;

  // ─── Getters ──────────────────────────────────
  AppImage? get image => _image;
  String? get imageId => _imageId;
  int? get imageWidth => _imageWidth;
  int? get imageHeight => _imageHeight;
  List<SegmentationPoint> get points => List.unmodifiable(_points);
  String? get maskId => _maskId;
  bool get showMask => _showMask;
  double get maskOpacity => _maskOpacity;
  String get selectedBackend => _selectedBackend;
  String? get defaultBackend => _defaultBackend;
  String? get selectedModelName => _selectedModelName;
  String? get backendDebugError => _backendDebugError;
  String get status => _status;
  bool get isSegmenting => _isSegmenting;
  bool get hasImage => _imageId != null;
  bool get hasMask => _maskId != null;
  bool get isSam3 => _selectedBackend == backendSam3;

  String get maskUrl => _dataSource.getMaskUrl(_maskId!);
  String get imageUrl => _dataSource.getImageUrl(_imageId!);

  String backendLabel(String backend) =>
      backend == backendSam3 ? 'SAM 3' : 'SAM Local';

  // ─── Initialization ───────────────────────────

  Future<void> initialize(AppImage image) async {
    _image = image;
    notifyListeners();
    await Future.wait([_uploadImage(), _loadBackendDebugInfo()]);
  }

  Future<void> _uploadImage() async {
    setLoading(true);
    _status = 'Uploading image to AI server...';
    notifyListeners();

    try {
      final result = await _dataSource.uploadImage(_image!);
      _imageId = result['image_id'] as String;
      _imageWidth = result['image_width'] as int;
      _imageHeight = result['image_height'] as int;
      _status = 'AI is ready! Tap on the object you want to select.';
    } catch (e) {
      _status = 'Upload failed. Please try again.';
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<void> _loadBackendDebugInfo() async {
    try {
      final result = await _dataSource.getSegmentationBackendDebug();
      final segmentation = result['segmentation'] as Map<String, dynamic>;
      _defaultBackend =
          segmentation['default_backend'] as String? ?? backendLocal;
      _selectedBackend = _defaultBackend!;
      _selectedModelName = segmentation['default_model'] as String?;
      _backendDebugError = null;
    } catch (e) {
      _backendDebugError = e.toString();
    }
    notifyListeners();
  }

  // ─── Backend switching ────────────────────────

  void changeBackend(String backend) {
    _selectedBackend = backend;
    _selectedModelName = backend == backendSam3
        ? 'mattsays/sam3-image'
        : 'local_sam:vit_b';
    _maskId = null;
    _points.clear();
    _status = isSam3
        ? 'Tap on an object or enter a description'
        : 'Tap on the object you want to select';
    notifyListeners();
  }

  // ─── Point interactions ───────────────────────

  void addPoint(double normalizedX, double normalizedY) {
    if (!hasImage || isLoading || _isSegmenting) return;

    _points.add(SegmentationPoint(x: normalizedX, y: normalizedY, label: 1));
    notifyListeners();
    _performSegmentation();
  }

  void undoLastPoint() {
    if (_points.isEmpty) return;
    _points.removeLast();

    if (_points.isEmpty) {
      _maskId = null;
      _status = isSam3
          ? 'Tap on an object or enter a description'
          : 'Tap on the object you want to select';
      notifyListeners();
    } else {
      notifyListeners();
      _performSegmentation();
    }
  }

  void clearAll() {
    _points.clear();
    _maskId = null;
    textPromptController.clear();
    _status = isSam3
        ? 'Tap on an object or enter a description'
        : 'Tap on the object you want to select';
    notifyListeners();
  }

  // ─── Mask controls ────────────────────────────

  void toggleMask() {
    _showMask = !_showMask;
    notifyListeners();
  }

  void setMaskOpacity(double value) {
    _maskOpacity = value;
    notifyListeners();
  }

  // ─── Segmentation API ─────────────────────────

  Future<void> segmentWithTextOnly() async {
    final prompt = textPromptController.text.trim();
    if (prompt.isEmpty || !hasImage) return;
    await _performSegmentation();
  }

  Future<void> _performSegmentation() async {
    final textPrompt = isSam3 ? textPromptController.text.trim() : null;
    final hasPoints = _points.isNotEmpty;
    final hasText = textPrompt != null && textPrompt.isNotEmpty;

    if (!hasImage || (!hasPoints && !hasText)) return;

    _isSegmenting = true;
    _status = 'AI is analyzing the region...';
    notifyListeners();

    try {
      final result = await _dataSource.segmentWithPoints(
        imageId: _imageId!,
        points: _points
            .map((p) => p.toPixelJson(_imageWidth!, _imageHeight!))
            .toList(),
        backend: _selectedBackend,
        textPrompt: textPrompt,
      );

      _maskId = result['mask_id'] as String;
      _selectedModelName =
          result['segmentation_model'] as String? ?? _selectedModelName;
      final backendUsed =
          result['segmentation_backend'] as String? ?? _selectedBackend;

      String actionInfo = hasPoints
          ? '${_points.length} point(s)'
          : 'text prompt';
      _status =
          'Selection complete · ${backendLabel(backendUsed)} · $actionInfo';
    } catch (e) {
      _status = 'Segmentation failed. Try again.';
      setError(e.toString());
    } finally {
      _isSegmenting = false;
      notifyListeners();
    }
  }

  // ─── Cleanup ──────────────────────────────────

  @override
  void dispose() {
    textPromptController.dispose();
    super.dispose();
  }
}
