import 'dart:io';
import 'package:flutter/material.dart';
import '../models/point_model.dart';
import '../services/api_service.dart';
import 'inpainting_screen.dart';

/// Screen for interactive segmentation with SAM
class SegmentationScreen extends StatefulWidget {
  final File imageFile;

  const SegmentationScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<SegmentationScreen> createState() => _SegmentationScreenState();
}

class _SegmentationScreenState extends State<SegmentationScreen> {
  final ApiService _apiService = ApiService();
  static const String _backendLocal = 'local';
  static const String _backendSam3 = 'sam3_replicate';

  String? _imageId;
  int? _imageWidth;
  int? _imageHeight;
  String? _maskId;
  final List<SegmentationPoint> _points = [];
  bool _isLoading = false;
  bool _showMask = true;
  double _maskOpacity = 0.4;
  String _status = 'Chạm vào vật thể hoặc nhập mô tả';
  String _selectedSegmentationBackend = _backendSam3;
  String? _defaultBackend;
  String? _selectedModelName;
  String? _backendDebugError;
  final TextEditingController _textPromptController = TextEditingController(); // Bỏ chữ mặc định 'object' để giao diện sạch hơn

  final GlobalKey _imageContainerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadBackendDebugInfo();
    _uploadImage();
  }

  @override
  void dispose() {
    _textPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadBackendDebugInfo() async {
    try {
      final result = await _apiService.getSegmentationBackendDebug();
      final segmentation = result['segmentation'] as Map<String, dynamic>;
      final defaultBackend = segmentation['default_backend'] as String? ?? _backendLocal;
      final defaultModel = segmentation['default_model'] as String?;

      if (!mounted) return;

      setState(() {
        _defaultBackend = defaultBackend;
        _selectedSegmentationBackend = defaultBackend;
        _selectedModelName = defaultModel;
        _backendDebugError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _backendDebugError = e.toString();
      });
    }
  }

  void _changeSegmentationBackend(String backend) {
    setState(() {
      _selectedSegmentationBackend = backend;
      _selectedModelName = backend == _backendSam3
          ? 'mattsays/sam3-image'
          : 'local_sam:vit_b';
      _maskId = null;
      _points.clear(); 
      _status = backend == _backendSam3
          ? 'Chạm vào vật thể hoặc nhập mô tả'
          : 'Chạm vào vật thể bạn muốn chọn';
    });
  }

  String _backendLabel(String backend) {
    return backend == _backendSam3 ? 'SAM3' : 'SAM';
  }

  Future<void> _uploadImage() async {
    setState(() {
      _isLoading = true;
      _status = 'Uploading image...';
    });

    try {
      final result = await _apiService.uploadImage(widget.imageFile);
      setState(() {
        _imageId = result['image_id'] as String;
        _imageWidth = result['image_width'] as int;
        _imageHeight = result['image_height'] as int;
        _status = _selectedSegmentationBackend == _backendSam3 
            ? 'Chạm vào vật thể hoặc nhập mô tả' 
            : 'Chạm vào vật thể bạn muốn chọn';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Upload failed: $e';
        _isLoading = false;
      });
    }
  }

  void _handleImageTap(TapDownDetails details) {
    if (_imageId == null || _isLoading) return;

    final RenderBox? renderBox =
        _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    final localPosition = details.localPosition;
    final imageRect = _getDisplayedImageRect(viewportSize);

    if (!imageRect.contains(localPosition)) {
      setState(() {
        _status = 'Tap inside the image area';
      });
      return;
    }

    final normalizedX = (localPosition.dx - imageRect.left) / imageRect.width;
    final normalizedY = (localPosition.dy - imageRect.top) / imageRect.height;

    setState(() {
      _points.add(SegmentationPoint(
        x: normalizedX,
        y: normalizedY,
        label: 1,
      ));
    });

    _performSegmentation();
  }

  Future<void> _performSegmentation() async {
    final textPrompt = _selectedSegmentationBackend == _backendSam3
        ? _textPromptController.text.trim()
        : null;

    final bool hasPoints = _points.isNotEmpty;
    final bool hasText = textPrompt != null && textPrompt.isNotEmpty;

    // [Cập nhật] Cho phép chạy API nếu có điểm chạm HOẶC có text mô tả
    if (_imageId == null || (!hasPoints && !hasText)) {
      if (!hasPoints && !hasText) {
        setState(() {
          _status = 'Vui lòng chạm vào ảnh hoặc nhập mô tả!';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Segmenting...';
    });

    try {
      final result = await _apiService.segmentWithPoints(
        imageId: _imageId!,
        points: _points.map((p) => p.toPixelJson(_imageWidth!, _imageHeight!)).toList(),
        segmentationBackend: _selectedSegmentationBackend,
        textPrompt: textPrompt,
      );

      setState(() {
        _maskId = result['mask_id'] as String;
        _selectedModelName = result['segmentation_model'] as String? ?? _selectedModelName;
        final backendUsed = result['segmentation_backend'] as String? ?? _selectedSegmentationBackend;
        
        String actionInfo = hasPoints ? '${_points.length} point(s)' : 'text prompt';
        _status = 'Segmentation complete with ${_backendLabel(backendUsed)} ($actionInfo)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Segmentation failed: $e';
        _isLoading = false;
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
      _maskId = null;
      _textPromptController.clear(); // Xóa luôn chữ khi bấm clear
      _status = _selectedSegmentationBackend == _backendSam3 
            ? 'Chạm vào vật thể hoặc nhập mô tả' 
            : 'Chạm vào vật thể bạn muốn chọn';
    });
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;

    setState(() {
      _points.removeLast();
      if (_points.isEmpty) {
        _maskId = null;
        _status = _selectedSegmentationBackend == _backendSam3 
            ? 'Chạm vào vật thể hoặc nhập mô tả' 
            : 'Chạm vào vật thể bạn muốn chọn';
      }
    });

    // Nếu vẫn còn điểm HOẶC có text, thì chạy lại segmentation
    if (_points.isNotEmpty || (_selectedSegmentationBackend == _backendSam3 && _textPromptController.text.isNotEmpty)) {
      _performSegmentation();
    }
  }

  void _toggleMask() {
    setState(() {
      _showMask = !_showMask;
    });
  }

  Rect _getDisplayedImageRect(Size viewportSize) {
    final imageWidth = _imageWidth?.toDouble();
    final imageHeight = _imageHeight?.toDouble();

    if (imageWidth == null || imageHeight == null ||
        viewportSize.width <= 0 || viewportSize.height <= 0) {
      return Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height);
    }

    final imageAspect = imageWidth / imageHeight;
    final viewportAspect = viewportSize.width / viewportSize.height;

    double displayWidth;
    double displayHeight;
    double left;
    double top;

    if (imageAspect > viewportAspect) {
      displayWidth = viewportSize.width;
      displayHeight = displayWidth / imageAspect;
      left = 0;
      top = (viewportSize.height - displayHeight) / 2;
    } else {
      displayHeight = viewportSize.height;
      displayWidth = displayHeight * imageAspect;
      top = 0;
      left = (viewportSize.width - displayWidth) / 2;
    }

    return Rect.fromLTWH(left, top, displayWidth, displayHeight);
  }

  Widget _buildImageWithOverlay() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          final imageRect = _getDisplayedImageRect(viewportSize);

          return GestureDetector(
            onTapDown: _handleImageTap,
            child: SizedBox(
              key: _imageContainerKey,
              width: viewportSize.width,
              height: viewportSize.height,
              child: Stack(
                children: [
                  Positioned(
                    left: imageRect.left,
                    top: imageRect.top,
                    width: imageRect.width,
                    height: imageRect.height,
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.fill,
                    ),
                  ),
                  if (_maskId != null && _showMask)
                    Positioned(
                      left: imageRect.left,
                      top: imageRect.top,
                      width: imageRect.width,
                      height: imageRect.height,
                      child: Image.network(
                        '${_apiService.getMaskUrl(_maskId!)}?t=${DateTime.now().millisecondsSinceEpoch}',
                        fit: BoxFit.fill,
                        color: Colors.red.withOpacity(_maskOpacity),
                        colorBlendMode: BlendMode.srcATop,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ..._buildPointMarkers(viewportSize),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPointMarkers(Size viewportSize) {
    final imageRect = _getDisplayedImageRect(viewportSize);

    return _points.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return Positioned(
        left: imageRect.left + point.x * imageRect.width - 12,
        top: imageRect.top + point.y * imageRect.height - 12,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Object'),
        actions: [
          IconButton(
            icon: Icon(_showMask ? Icons.visibility : Icons.visibility_off),
            onPressed: _maskId != null ? _toggleMask : null,
            tooltip: 'Toggle mask visibility',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildBackendSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildImageWithOverlay(),
          ),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_maskId != null) _buildOpacitySlider(),
          Text(
            '${_points.length} point(s) selected',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _points.isNotEmpty ? _undoLastPoint : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_points.isNotEmpty || _textPromptController.text.isNotEmpty || _maskId != null) 
                      ? _clearPoints 
                      : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _maskId != null ? _goToInpainting : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Remove Object'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSelector() {
    final defaultText = _defaultBackend == null
        ? 'Loading backend config...'
        : 'Default backend: ${_backendLabel(_defaultBackend!)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              const Text(
                'Segmentation Backend',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: _backendLocal,
                label: Text('SAM'),
                icon: Icon(Icons.memory),
              ),
              ButtonSegment<String>(
                value: _backendSam3,
                label: Text('SAM3'),
                icon: Icon(Icons.cloud),
              ),
            ],
            selected: {_selectedSegmentationBackend},
            onSelectionChanged: (selection) {
              _changeSegmentationBackend(selection.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            defaultText,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (_selectedSegmentationBackend == _backendSam3) ..._buildTextPromptInput(),
          if (_selectedModelName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Model: $_selectedModelName',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_backendDebugError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Debug endpoint unavailable: $_backendDebugError',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTextPromptInput() {
    return [
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(Icons.text_fields, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          const Text(
            'Mô tả vật thể',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            '(Tùy chọn: Nhập để SAM3 tự tìm)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _textPromptController,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          // [Cập nhật] Bấm Enter trên bàn phím là chạy tìm kiếm luôn
          _performSegmentation();
        },
        decoration: InputDecoration(
          hintText: 'VD: sofa, chair, dog, person...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _textPromptController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _textPromptController.clear();
                    setState(() {});
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }

  Widget _buildOpacitySlider() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.opacity, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: _maskOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _maskOpacity.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _maskOpacity = value;
                });
              },
            ),
          ),
          Text(
            '${(_maskOpacity * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _goToInpainting() {
    if (_imageId == null || _maskId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InpaintingScreen(
          imageId: _imageId!,
          maskId: _maskId!,
        ),
      ),
    );
  }
}