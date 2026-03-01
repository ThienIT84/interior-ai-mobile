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
  
  // State variables
  String? _imageId;
  int? _imageWidth;
  int? _imageHeight;
  String? _maskId;
  List<SegmentationPoint> _points = [];
  bool _isLoading = false;
  bool _showMask = true;
  double _maskOpacity = 0.4; // Default opacity for mask overlay
  String _status = 'Tap on the object you want to remove';
  
  // Image dimensions for coordinate conversion
  Size? _imageSize;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _uploadImage();
  }

  /// Upload image to backend
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
        _status = 'Tap on the object you want to remove';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Upload failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle tap on image
  void _handleImageTap(TapDownDetails details) {
    if (_imageId == null || _isLoading) return;

    // Get image widget size
    final RenderBox? renderBox = 
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final localPosition = details.localPosition;

    // Convert to normalized coordinates (0-1) for display
    final normalizedX = localPosition.dx / size.width;
    final normalizedY = localPosition.dy / size.height;

    // Add point (stored as normalized for UI display)
    setState(() {
      _points.add(SegmentationPoint(
        x: normalizedX,
        y: normalizedY,
        label: 1, // Foreground
      ));
    });

    // Trigger segmentation
    _performSegmentation();
  }

  /// Perform segmentation with current points
  Future<void> _performSegmentation() async {
    if (_imageId == null || _points.isEmpty) return;

    setState(() {
      _isLoading = true;
      _status = 'Segmenting...';
    });

    try {
      final result = await _apiService.segmentWithPoints(
        imageId: _imageId!,
        points: _points.map((p) => p.toPixelJson(_imageWidth!, _imageHeight!)).toList(),
      );

      setState(() {
        _maskId = result['mask_id'] as String;
        _status = 'Segmentation complete! ${_points.length} point(s)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Segmentation failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Clear all points and mask
  void _clearPoints() {
    setState(() {
      _points.clear();
      _maskId = null;
      _status = 'Tap on the object you want to remove';
    });
  }

  /// Undo last point
  void _undoLastPoint() {
    if (_points.isEmpty) return;
    
    setState(() {
      _points.removeLast();
      if (_points.isEmpty) {
        _maskId = null;
        _status = 'Tap on the object you want to remove';
      }
    });

    // Re-segment if points remain
    if (_points.isNotEmpty) {
      _performSegmentation();
    }
  }

  /// Toggle mask visibility
  void _toggleMask() {
    setState(() {
      _showMask = !_showMask;
    });
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
          // Status bar
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

          // Image with overlay
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildImageWithOverlay(),
          ),

          // Control buttons
          _buildControlButtons(),
        ],
      ),
    );
  }

  /// Build image with point markers and mask overlay
  Widget _buildImageWithOverlay() {
    return Center(
      child: GestureDetector(
        onTapDown: _handleImageTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Original image
            Image.file(
              widget.imageFile,
              key: _imageKey,
              fit: BoxFit.contain,
            ),

            // Mask overlay with adjustable opacity
            if (_maskId != null && _showMask)
              Positioned.fill(
                child: Image.network(
                  _apiService.getMaskUrl(_maskId!),
                  fit: BoxFit.contain,
                  color: Colors.red.withOpacity(_maskOpacity),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),

            // Point markers
            ..._buildPointMarkers(),
          ],
        ),
      ),
    );
  }

  /// Build point markers overlay
  List<Widget> _buildPointMarkers() {
    final RenderBox? renderBox = 
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return [];

    final size = renderBox.size;

    return _points.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return Positioned(
        left: point.x * size.width - 12,
        top: point.y * size.height - 12,
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

  /// Build control buttons
  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mask opacity slider (only show when mask exists)
          if (_maskId != null) _buildOpacitySlider(),
          
          // Point count
          Text(
            '${_points.length} point(s) selected',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              // Undo button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _points.isNotEmpty ? _undoLastPoint : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
              ),
              const SizedBox(width: 12),

              // Clear button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _points.isNotEmpty ? _clearPoints : null,
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

          // Next button
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

  /// Navigate to inpainting screen
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
