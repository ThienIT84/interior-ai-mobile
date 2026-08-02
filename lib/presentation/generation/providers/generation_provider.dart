import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/datasources/remote_datasource.dart';

/// Enum for the two operating modes of the Generation screen
enum GenerationMode { design, placement }

/// Represents a design style option
class StyleOption {
  final String name;
  final String displayName;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const StyleOption({
    required this.name,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

/// Represents an AI model option
class ModelOption {
  final String id;
  final String displayName;
  final String subtitle;
  final IconData icon;

  const ModelOption({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.icon,
  });
}

/// Provider managing state for the Generation screen.
///
/// Handles two workflows:
///   1. Generate Design – applies a style to the whole room
///   2. Place Furniture – inpaints an object inside a user-drawn bbox
class GenerationProvider with ChangeNotifier {
  GenerationProvider({
    RemoteDataSource? dataSource,
    Duration pollInterval = const Duration(seconds: 3),
    int maxPolls = 300,
  }) : _dataSource = dataSource ?? RemoteDataSource(),
       _pollInterval = pollInterval,
       _maxPolls = maxPolls;

  final RemoteDataSource _dataSource;
  final Duration _pollInterval;
  final int _maxPolls;

  // ── Available AI models ───────────────────────────────────────────
  static const List<ModelOption> modelOptions = [
    ModelOption(
      id: 'controlnet',
      displayName: 'Standard',
      subtitle: 'Fast & Efficient',
      icon: Icons.flash_on_rounded,
    ),
    ModelOption(
      id: 'flux-pro',
      displayName: 'Professional',
      subtitle: 'Ultra High Quality',
      icon: Icons.auto_awesome,
    ),
  ];

  // ── Selected model ────────────────────────────────────────────────
  String _selectedModelId = 'controlnet';
  String get selectedModelId => _selectedModelId;
  ModelOption get selectedModel =>
      modelOptions.firstWhere((m) => m.id == _selectedModelId);

  void selectModel(String modelId) {
    _selectedModelId = modelId;
    notifyListeners();
  }

  // ── Current mode ──────────────────────────────────────────────────
  GenerationMode _mode = GenerationMode.design;
  GenerationMode get mode => _mode;

  void setMode(GenerationMode m) {
    _mode = m;
    notifyListeners();
  }

  // ── Image / context passed from previous screen ───────────────────
  String? _imageId;
  String? get imageId => _imageId;

  String? _originalImageUrl;
  String? get originalImageUrl => _originalImageUrl;

  void setImageContext({required String imageId}) {
    _imageId = imageId;
    _originalImageUrl = _dataSource.getImageUrl(imageId);
    notifyListeners();
  }

  // ── Styles ────────────────────────────────────────────────────────
  List<StyleOption> _styles = [];
  List<StyleOption> get styles => _styles;
  bool _stylesLoading = false;
  bool get stylesLoading => _stylesLoading;

  int _selectedStyleIndex = 0;
  int get selectedStyleIndex => _selectedStyleIndex;
  StyleOption? get selectedStyle =>
      _styles.isNotEmpty ? _styles[_selectedStyleIndex] : null;

  void selectStyle(int index) {
    _selectedStyleIndex = index;
    notifyListeners();
  }

  /// Default icon + gradient mapping for known style names
  static const Map<String, ({IconData icon, List<Color> gradient})>
  _styleVisuals = {
    'modern': (
      icon: Icons.weekend_outlined,
      gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    'minimalist': (
      icon: Icons.crop_square_rounded,
      gradient: [Color(0xFF89F7FE), Color(0xFF66A6FF)],
    ),
    'industrial': (
      icon: Icons.factory_outlined,
      gradient: [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
    ),
    'indochine': (
      icon: Icons.temple_buddhist_outlined,
      gradient: [Color(0xFFF5AF19), Color(0xFFF12711)],
    ),
    'scandinavian': (
      icon: Icons.forest_outlined,
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
  };

  /// Localization overrides for backend styles
  static const Map<String, ({String displayName, String description})>
  _styleLocalization = {
    'modern': (
      displayName: 'Modern',
      description: 'Clean lines and a polished look for a contemporary space.',
    ),
    'modern_vn': (
      displayName: 'Modern',
      description: 'Clean lines and a polished look for a contemporary space.',
    ),
    'minimalist': (
      displayName: 'Minimalist',
      description:
          'Focus on simplicity and functionality with minimal clutter.',
    ),
    'industrial': (
      displayName: 'Industrial',
      description: 'Raw materials and an edgy, warehouse-inspired aesthetic.',
    ),
    'indochine': (
      displayName: 'Indochine',
      description: 'A fusion of French colonial charm and Oriental traditions.',
    ),
    'scandinavian': (
      displayName: 'Scandinavian',
      description:
          'Bright, airy, and warm with natural wood and soft textures.',
    ),
    // Vietnamese aliases to catch backend strings
    'hiện đại': (
      displayName: 'Modern',
      description: 'Clean lines and a polished look for a contemporary space.',
    ),
    'phong cách hiện đại': (
      displayName: 'Modern',
      description: 'Clean lines and a polished look for a contemporary space.',
    ),
    'tối giản': (
      displayName: 'Minimalist',
      description:
          'Focus on simplicity and functionality with minimal clutter.',
    ),
    'phong cách tối giản': (
      displayName: 'Minimalist',
      description:
          'Focus on simplicity and functionality with minimal clutter.',
    ),
    'công nghiệp': (
      displayName: 'Industrial',
      description: 'Raw materials and an edgy, warehouse-inspired aesthetic.',
    ),
    'đông dương': (
      displayName: 'Indochine',
      description: 'A fusion of French colonial charm and Oriental traditions.',
    ),
    'bắc âu': (
      displayName: 'Scandinavian',
      description:
          'Bright, airy, and warm with natural wood and soft textures.',
    ),
  };

  Future<void> loadStyles() async {
    _stylesLoading = true;
    notifyListeners();

    try {
      final rawStyles = await _dataSource.getStyles();
      _styles = rawStyles.map((s) {
        String name = (s['name'] as String?)?.toLowerCase() ?? 'unknown';

        // Match visualization (using English key if possible)
        String visualKey = name;
        if (name.contains('modern') || name.contains('hiện đại')) {
          visualKey = 'modern';
        }
        if (name.contains('minimalist') || name.contains('tối giản')) {
          visualKey = 'minimalist';
        }
        if (name.contains('industrial') || name.contains('công nghiệp')) {
          visualKey = 'industrial';
        }
        if (name.contains('indochine') || name.contains('đông dương')) {
          visualKey = 'indochine';
        }
        if (name.contains('scandinavian') || name.contains('bắc âu')) {
          visualKey = 'scandinavian';
        }

        final vis = _styleVisuals[visualKey];
        final loc = _styleLocalization[name] ?? _styleLocalization[visualKey];

        return StyleOption(
          name: name,
          displayName:
              loc?.displayName ?? (s['display_name'] as String?) ?? name,
          description: loc?.description ?? (s['description'] as String?) ?? '',
          icon: vis?.icon ?? Icons.auto_awesome,
          gradient:
              vis?.gradient ?? const [Color(0xFF9D50BB), Color(0xFF6E48AA)],
        );
      }).toList();
    } catch (e) {
      // Fallback to hardcoded list so UI is never empty
      _styles = _styleVisuals.entries.map((e) {
        final loc = _styleLocalization[e.key];
        return StyleOption(
          name: e.key,
          displayName:
              loc?.displayName ?? (e.key[0].toUpperCase() + e.key.substring(1)),
          description: loc?.description ?? '',
          icon: e.value.icon,
          gradient: e.value.gradient,
        );
      }).toList();
    } finally {
      _stylesLoading = false;
      notifyListeners();
    }
  }

  // ── Generation job ────────────────────────────────────────────────
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _jobId;
  String? get jobId => _jobId;

  String _jobStatus = '';
  String get jobStatus => _jobStatus;

  double _jobProgress = 0;
  double get jobProgress => _jobProgress;

  String? _resultImageUrl;
  String? get resultImageUrl => _resultImageUrl;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _pollingTimer;
  bool _disposed = false;

  /// Start a Generate Design job
  Future<void> generateDesign() async {
    if (_imageId == null || selectedStyle == null) return;

    _isGenerating = true;
    _jobStatus = 'Sending request...';
    _jobProgress = 0.05;
    _resultImageUrl = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _dataSource.generateDesign(
        imageId: _imageId!,
        style: selectedStyle!.name,
        modelId: _selectedModelId,
      );
      if (_disposed) return;
      _jobId = result['job_id'] as String?;
      _jobStatus = 'Processing on Cloud...';
      _jobProgress = 0.15;
      notifyListeners();

      // Start polling
      _startPolling(type: 'generation');
    } catch (e) {
      _isGenerating = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // ── Place furniture job ───────────────────────────────────────────
  Rect? _boundingBox; // normalised 0..1
  Rect? get boundingBox => _boundingBox;

  String _furnitureDescription = '';
  String get furnitureDescription => _furnitureDescription;

  void setBoundingBox(Rect? box) {
    _boundingBox = box;
    notifyListeners();
  }

  void setFurnitureDescription(String desc) {
    _furnitureDescription = desc;
  }

  Future<void> placeFurniture() async {
    if (_imageId == null ||
        _boundingBox == null ||
        _furnitureDescription.trim().isEmpty) {
      _errorMessage = 'Please draw a selection and input object description';
      notifyListeners();
      return;
    }

    _isGenerating = true;
    _jobStatus = 'Sending request...';
    _jobProgress = 0.05;
    _resultImageUrl = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _dataSource.placeFurniture(
        imageId: _imageId!,
        x: _boundingBox!.left,
        y: _boundingBox!.top,
        w: _boundingBox!.width,
        h: _boundingBox!.height,
        description: _furnitureDescription.trim(),
      );
      if (_disposed) return;
      _jobId = result['job_id'] as String?;
      _jobStatus = 'Creating furniture...';
      _jobProgress = 0.15;
      notifyListeners();

      _startPolling(type: 'placement');
    } catch (e) {
      _isGenerating = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // ── Polling ───────────────────────────────────────────────────────
  void _startPolling({required String type}) {
    _pollingTimer?.cancel();
    var pollCount = 0;
    _pollingTimer = Timer.periodic(_pollInterval, (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_jobId == null) return;
      pollCount++;
      if (pollCount > _maxPolls) {
        timer.cancel();
        _isGenerating = false;
        _jobStatus = 'Timed out';
        _errorMessage = 'Processing timeout. Please try again.';
        if (!_disposed) notifyListeners();
        return;
      }
      try {
        final status = await _dataSource.checkJobStatus(_jobId!, type: type);
        final st = status['status'] as String?;
        final remoteProgress = (status['progress'] as num?)?.toDouble();

        if (st == 'processing') {
          _jobStatus = 'AI Processing...';
          _jobProgress = remoteProgress ?? 0.5;
          if (!_disposed) notifyListeners();
        } else if (st == 'completed') {
          _stopPolling();
          _jobStatus = 'Complete!';
          _jobProgress = 1.0;

          if (type == 'generation') {
            final resultId = status['result_id'] as String?;
            if (resultId != null) {
              _resultImageUrl = _dataSource.getGenerationResultUrl(resultId);
            } else {
              _resultImageUrl = status['result_url'] as String?;
            }
          } else {
            final meta = status['metadata'] as Map<String, dynamic>?;
            final resultId =
                (meta?['result_id'] ?? status['result_id']) as String?;
            if (resultId != null) {
              _resultImageUrl = _dataSource.getPlacementResultUrl(resultId);
            } else {
              _resultImageUrl = status['result_url'] as String?;
            }
          }

          _isGenerating = false;
          if (!_disposed) notifyListeners();
        } else if (st == 'failed') {
          _stopPolling();
          _isGenerating = false;
          _errorMessage = status['error'] as String? ?? 'Unknown error';
          _jobStatus = 'Failed';
          if (!_disposed) notifyListeners();
        }
      } catch (e) {
        // Don't stop polling on transient errors
        debugPrint('Polling error: $e');
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Reset the whole generation state for a new run
  void resetGeneration() {
    _stopPolling();
    _isGenerating = false;
    _jobId = null;
    _jobStatus = '';
    _jobProgress = 0;
    _resultImageUrl = null;
    _errorMessage = null;
    _boundingBox = null;
    _furnitureDescription = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    super.dispose();
  }
}
