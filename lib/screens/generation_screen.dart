import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class GeneratedResult {
  final String style;
  final String styleName;
  final String resultUrl;
  final int processingTime;

  const GeneratedResult({
    required this.style,
    required this.styleName,
    required this.resultUrl,
    required this.processingTime,
  });
}

class _StyleMeta {
  final String name;
  final String displayName;
  final String description;
  final Color primaryColor;
  final Color accentColor;
  final IconData icon;

  const _StyleMeta({
    required this.name,
    required this.displayName,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _MainOption { chooseOption, targetedPlacement, globalStyle }

enum _JobState { idle, generating, result, error }

// ─────────────────────────────────────────────────────────────────────────────
// GenerationScreen
// ─────────────────────────────────────────────────────────────────────────────

class GenerationScreen extends StatefulWidget {
  final String inpaintedImageId;
  final String originalImageId;

  const GenerationScreen({
    super.key,
    required this.inpaintedImageId,
    required this.originalImageId,
  });

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  final ApiService _apiService = ApiService();

  // Navigation
  _MainOption _mainOption = _MainOption.chooseOption;
  bool _useInpainted = true;

  // Shared job state
  _JobState _jobState = _JobState.idle;
  String _status = '';
  double _progress = 0.0;
  String? _error;
  Timer? _pollTimer;
  Timer? _timeTimer;
  int _elapsedSeconds = 0;
  bool _isProcessing = false;

  // Option 1 – Placement
  final TextEditingController _furnitureCtrl = TextEditingController();
  Offset? _bboxStart;
  Offset? _bboxEnd;
  Size _containerSize = Size.zero;
  final GlobalKey _imageContainerKey = GlobalKey();
  String? _placementResultUrl;

  // Option 2 – Style
  String? _currentStyle;
  String? _currentStyleName;
  final List<GeneratedResult> _styleResults = [];
  int _galleryPage = 0;
  final PageController _galleryController = PageController();

  static const List<_StyleMeta> _styles = [
    _StyleMeta(
      name: 'modern',
      displayName: 'Modern',
      description: 'Đường nét sạch, tối giản, ánh sáng tự nhiên',
      primaryColor: Color(0xFFEEEEEE),
      accentColor: Color(0xFF546E7A),
      icon: Icons.architecture,
    ),
    _StyleMeta(
      name: 'minimalist',
      displayName: 'Minimalist',
      description: 'Không gian mở, vật liệu tự nhiên, zen & japandi',
      primaryColor: Color(0xFFF5F0E8),
      accentColor: Color(0xFF6D4C41),
      icon: Icons.spa_outlined,
    ),
    _StyleMeta(
      name: 'industrial',
      displayName: 'Industrial',
      description: 'Gạch trần, kim loại, sàn bê tông, loft style',
      primaryColor: Color(0xFF5D4037),
      accentColor: Color(0xFF212121),
      icon: Icons.factory_outlined,
    ),
    _StyleMeta(
      name: 'indochine',
      displayName: 'Indochine',
      description: 'Gỗ nhiệt đới, họa tiết hoa văn, ánh vàng ấm áp',
      primaryColor: Color(0xFF8D6E4F),
      accentColor: Color(0xFF4E2C0E),
      icon: Icons.temple_buddhist_outlined,
    ),
    _StyleMeta(
      name: 'scandinavian',
      displayName: 'Scandinavian',
      description: 'Sáng, ấm, hygge – vải len, gỗ sồi, cây xanh',
      primaryColor: Color(0xFFE8F0E8),
      accentColor: Color(0xFF2E7D32),
      icon: Icons.park_outlined,
    ),
  ];

  // ── Helpers ─────────────────────────────────────────────────────────────

  String get _activeImageId =>
      _useInpainted ? widget.inpaintedImageId : widget.originalImageId;

  String get _displayImageUrl => _useInpainted
      ? _apiService.getResultUrl(widget.inpaintedImageId)
      : _apiService.getImageUrl(widget.originalImageId);

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _startTimer() {
    _elapsedSeconds = 0;
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isProcessing) setState(() => _elapsedSeconds++);
    });
  }

  void _resetJobState() {
    _pollTimer?.cancel();
    _timeTimer?.cancel();
    setState(() {
      _jobState = _JobState.idle;
      _status = '';
      _progress = 0.0;
      _error = null;
      _isProcessing = false;
      _elapsedSeconds = 0;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeTimer?.cancel();
    _galleryController.dispose();
    _furnitureCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Option 1 – Furniture Placement
  // ─────────────────────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    final box =
        _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) _containerSize = box.size;
    setState(() {
      _bboxStart = d.localPosition;
      _bboxEnd = d.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) =>
      setState(() => _bboxEnd = d.localPosition);

  Rect? get _bboxRect {
    if (_bboxStart == null || _bboxEnd == null) return null;
    return Rect.fromPoints(_bboxStart!, _bboxEnd!);
  }

  Future<void> _submitPlacement() async {
    final description = _furnitureCtrl.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng mô tả đồ nội thất muốn đặt')),
      );
      return;
    }
    final rect = _bboxRect;
    if (rect == null || rect.width < 10 || rect.height < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng vẽ một vùng trên ảnh')),
      );
      return;
    }
    if (_containerSize == Size.zero) return;

    final bboxX = (rect.left / _containerSize.width).clamp(0.0, 1.0);
    final bboxY = (rect.top / _containerSize.height).clamp(0.0, 1.0);
    final bboxW = (rect.width / _containerSize.width).clamp(0.01, 1.0);
    final bboxH = (rect.height / _containerSize.height).clamp(0.01, 1.0);

    setState(() {
      _jobState = _JobState.generating;
      _status = 'Submitting job...';
      _progress = 0.05;
      _error = null;
      _isProcessing = true;
    });
    _startTimer();

    try {
      final data = await _apiService.placeFurniture(
        imageId: _activeImageId,
        bboxX: bboxX,
        bboxY: bboxY,
        bboxW: bboxW,
        bboxH: bboxH,
        furnitureDescription: description,
      );
      final jobId = data['job_id'] as String;
      setState(() {
        _status = 'AI đang tạo đồ nội thất...';
        _progress = 0.2;
      });
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          final s = await _apiService.checkPlacementJobStatus(jobId);
          _handlePlacementStatus(s);
        } catch (_) {}
      });
    } catch (e) {
      _timeTimer?.cancel();
      setState(() {
        _error = e.toString();
        _isProcessing = false;
        _jobState = _JobState.error;
      });
    }
  }

  void _handlePlacementStatus(Map<String, dynamic> data) {
    if (!mounted) return;
    switch (data['status'] as String? ?? '') {
      case 'pending':
        setState(() {
          _status = 'Đang chờ trong hàng...';
          _progress = 0.3;
        });
        break;
      case 'processing':
        setState(() {
          _status = 'Đang tạo đồ nội thất...';
          _progress = 0.65;
        });
        break;
      case 'completed':
        _pollTimer?.cancel();
        _timeTimer?.cancel();
        final resultId = data['result_id'] as String?;
        if (resultId != null) {
          setState(() {
            _placementResultUrl = _apiService.getPlacementResultUrl(resultId);
            _isProcessing = false;
            _jobState = _JobState.result;
          });
        }
        break;
      case 'failed':
        _pollTimer?.cancel();
        _timeTimer?.cancel();
        setState(() {
          _error = data['error'] as String? ?? 'Placement failed';
          _isProcessing = false;
          _jobState = _JobState.error;
        });
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Option 2 – Global Style
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateStyle(_StyleMeta style) async {
    setState(() {
      _currentStyle = style.name;
      _currentStyleName = style.displayName;
      _jobState = _JobState.generating;
      _status = 'Submitting job...';
      _progress = 0.05;
      _error = null;
      _isProcessing = true;
    });
    _startTimer();

    try {
      final data = await _apiService.generateDesign(
        imageId: _activeImageId,
        style: style.name,
      );
      final jobId = data['job_id'] as String;
      setState(() {
        _status = 'ControlNet đang xử lý...';
        _progress = 0.2;
      });

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          final s = await _apiService.checkGenerationJobStatus(jobId);
          _handleGenerationStatus(s, style);
        } catch (_) {}
      });
    } catch (e) {
      _timeTimer?.cancel();
      setState(() {
        _error = e.toString();
        _isProcessing = false;
        _jobState = _JobState.error;
      });
    }
  }

  void _handleGenerationStatus(Map<String, dynamic> data, _StyleMeta style) {
    if (!mounted) return;
    switch (data['status'] as String? ?? '') {
      case 'pending':
        setState(() {
          _status = 'Đang chờ trong hàng...';
          _progress = 0.3;
        });
        break;
      case 'processing':
        setState(() {
          _status = 'Đang tạo thiết kế ${style.displayName}...';
          _progress = 0.6;
        });
        break;
      case 'completed':
        _pollTimer?.cancel();
        _timeTimer?.cancel();
        final resultId = data['result_id'] as String?;
        final t = (data['processing_time'] as num?)?.toInt() ?? _elapsedSeconds;
        if (resultId != null) {
          final result = GeneratedResult(
            style: style.name,
            styleName: style.displayName,
            resultUrl: _apiService.getGenerationResultUrl(resultId),
            processingTime: t,
          );
          setState(() {
            _styleResults.add(result);
            _isProcessing = false;
            _jobState = _JobState.result;
            _galleryPage = _styleResults.length - 1;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_galleryController.hasClients) {
              _galleryController.animateToPage(
                _styleResults.length - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
        break;
      case 'failed':
        _pollTimer?.cancel();
        _timeTimer?.cancel();
        setState(() {
          _error = data['error'] as String? ?? 'Generation failed';
          _isProcessing = false;
          _jobState = _JobState.error;
        });
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: _mainOption != _MainOption.chooseOption
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _resetJobState();
                  setState(() => _mainOption = _MainOption.chooseOption);
                },
              )
            : null,
        actions: [
          if (_mainOption == _MainOption.globalStyle &&
              _jobState == _JobState.result &&
              _styleResults.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _jobState = _JobState.idle),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('More', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  String _appBarTitle() {
    switch (_mainOption) {
      case _MainOption.chooseOption:
        return 'Generate Design';
      case _MainOption.targetedPlacement:
        return 'Targeted Placement';
      case _MainOption.globalStyle:
        return 'Global Style';
    }
  }

  Widget _buildBody() {
    switch (_mainOption) {
      case _MainOption.chooseOption:
        return _buildChooseOption();
      case _MainOption.targetedPlacement:
        return _buildPlacementBody();
      case _MainOption.globalStyle:
        return _buildGlobalStyleBody();
    }
  }

  // ── Choose option ────────────────────────────────────────────────────────

  Widget _buildChooseOption() {
    return Column(
      children: [
        _buildImageSelector(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text('Chọn cách thiết kế',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _OptionCard(
                icon: Icons.touch_app,
                iconBgColor: const Color(0xFF1A73E8),
                title: 'Targeted Placement',
                subtitle: 'Đặt 1 món đồ vào vị trí bạn chọn',
                bullets: const [
                  'Vẽ vùng trên ảnh phòng trống',
                  'Mô tả đồ nội thất muốn đặt',
                  'AI điền vào đúng vị trí, ánh sáng hòa hợp',
                ],
                badgeColor: const Color(0xFF1A73E8),
                onTap: () =>
                    setState(() => _mainOption = _MainOption.targetedPlacement),
              ),
              const SizedBox(height: 16),
              _OptionCard(
                icon: Icons.auto_awesome,
                iconBgColor: Colors.deepPurple,
                title: 'Global Style',
                subtitle: 'Thiết kế lại toàn bộ phòng theo phong cách',
                bullets: const [
                  'Chọn 1 trong 5 phong cách (Modern, Indochine…)',
                  'ControlNet giữ nguyên cấu trúc phòng',
                  'AI tạo toàn bộ nội thất mới',
                ],
                badgeColor: Colors.deepPurple,
                onTap: () =>
                    setState(() => _mainOption = _MainOption.globalStyle),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Placement body ───────────────────────────────────────────────────────

  Widget _buildPlacementBody() {
    switch (_jobState) {
      case _JobState.idle:
        return _buildPlacementDraw();
      case _JobState.generating:
        return _buildGenerating(
          title: 'Targeted Placement',
          subtitle: 'AI đang vẽ đồ vào vị trí đã chọn',
        );
      case _JobState.result:
        return _buildPlacementResult();
      case _JobState.error:
        return _buildError();
    }
  }

  Widget _buildPlacementDraw() {
    return Column(children: [
      Expanded(
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            child: Container(
              key: _imageContainerKey,
              color: Colors.black,
              child: Image.network(
                _displayImageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        size: 64, color: Colors.grey)),
              ),
            ),
          ),
          if (_bboxRect != null)
            Positioned(
              left: _bboxRect!.left,
              top: _bboxRect!.top,
              width: _bboxRect!.width,
              height: _bboxRect!.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF1A73E8), width: 2.5),
                  color: const Color(0xFF1A73E8).withOpacity(0.15),
                ),
              ),
            ),
          if (_bboxRect == null)
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Kéo để vẽ vùng đặt đồ',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ]),
                ),
              ),
            ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _furnitureCtrl,
                decoration: InputDecoration(
                  hintText:
                      'Mô tả đồ gì muốn đặt (VD: a modern leather sofa)',
                  prefixIcon: const Icon(Icons.chair_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(
                        () => _bboxStart = _bboxEnd = null),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset vùng'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _submitPlacement,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Đặt nội thất'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ]),
            ]),
      ),
    ]);
  }

  Widget _buildPlacementResult() {
    final url = _placementResultUrl!;
    return Column(children: [
      Expanded(
        child: PageView(children: [
          _imgView(url: url, label: 'KẾT QUẢ', color: const Color(0xFF1A73E8)),
          _imgView(url: _displayImageUrl, label: 'GỐC', color: Colors.orange),
        ]),
      ),
      const _SwipeHint(),
      _actionButtons(
        resultUrl: url,
        onTryAgain: () => setState(() {
          _jobState = _JobState.idle;
          _bboxStart = null;
          _bboxEnd = null;
          _placementResultUrl = null;
        }),
      ),
    ]);
  }

  // ── Global style body ────────────────────────────────────────────────────

  Widget _buildGlobalStyleBody() {
    switch (_jobState) {
      case _JobState.idle:
        return _buildStyleSelection();
      case _JobState.generating:
        return _buildGenerating(
          title: _currentStyleName ?? 'Generating',
          subtitle: 'ControlNet đang tạo thiết kế...',
        );
      case _JobState.result:
        return _buildStyleResults();
      case _JobState.error:
        return _buildError();
    }
  }

  Widget _buildStyleSelection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text('Chọn Phong Cách',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: _styles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _buildStyleCard(_styles[i]),
        ),
      ),
      if (_styleResults.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _jobState = _JobState.result),
              icon: const Icon(Icons.photo_library,
                  color: Colors.deepPurple),
              label: Text('Xem ${_styleResults.length} kết quả',
                  style:
                      const TextStyle(color: Colors.deepPurple)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _buildStyleCard(_StyleMeta style) {
    final isDark = style.primaryColor.computeLuminance() < 0.3;
    final done = _styleResults.any((r) => r.style == style.name);
    return GestureDetector(
      onTap: done ? null : () => _generateStyle(style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 88,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              style.primaryColor,
              style.accentColor.withOpacity(isDark ? 0.85 : 0.3)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: done
              ? Border.all(color: Colors.green.shade400, width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: style.accentColor.withOpacity(0.18),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : style.accentColor)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon,
                  color: isDark ? Colors.white : style.accentColor,
                  size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(style.displayName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : style.accentColor)),
                    Text(style.description,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : style.accentColor.withOpacity(0.75))),
                  ]),
            ),
            if (done)
              const Icon(Icons.check_circle, color: Colors.green, size: 22)
            else
              Icon(Icons.arrow_forward_ios,
                  color: isDark ? Colors.white70 : style.accentColor,
                  size: 15),
          ]),
        ),
      ),
    );
  }

  Widget _buildStyleResults() {
    return Column(children: [
      Expanded(
        child: PageView.builder(
          controller: _galleryController,
          onPageChanged: (p) => setState(() => _galleryPage = p),
          itemCount: _styleResults.length,
          itemBuilder: (_, i) => _buildStyleResultPage(_styleResults[i]),
        ),
      ),
      if (_styleResults.length > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _styleResults.length,
                (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _galleryPage == i ? 20.0 : 8.0,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _galleryPage == i
                            ? Colors.deepPurple
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
          ),
        ),
      _actionButtons(
        resultUrl: _styleResults.isEmpty
            ? ''
            : _styleResults[_galleryPage].resultUrl,
      ),
    ]);
  }

  Widget _buildStyleResultPage(GeneratedResult result) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(result.styleName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(width: 6),
              Text('(${_fmt(result.processingTime)})',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: PageView(children: [
          _imgView(
              url: result.resultUrl,
              label: 'GENERATED',
              color: Colors.deepPurple),
          _imgView(
              url: _apiService.getImageUrl(widget.originalImageId),
              label: 'ORIGINAL',
              color: Colors.orange),
        ]),
      ),
      const _SwipeHint(),
    ]);
  }

  // ── Shared widgets ───────────────────────────────────────────────────────

  Widget _buildImageSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Source Image',
            style:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _toggleBtn(
                  label: 'Empty Room',
                  sub: 'After removal',
                  icon: Icons.auto_fix_high,
                  selected: _useInpainted,
                  onTap: () => setState(() => _useInpainted = true))),
          const SizedBox(width: 8),
          Expanded(
              child: _toggleBtn(
                  label: 'Original',
                  sub: 'Before removal',
                  icon: Icons.image_outlined,
                  selected: !_useInpainted,
                  onTap: () => setState(() => _useInpainted = false))),
        ]),
      ]),
    );
  }

  Widget _toggleBtn({
    required String label,
    required String sub,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Colors.deepPurple : Colors.grey[300]!),
        ),
        child: Row(children: [
          Icon(icon,
              color: selected ? Colors.white : Colors.grey, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : Colors.black87)),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? Colors.white70
                              : Colors.grey[600])),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildGenerating(
      {required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 44),
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    strokeWidth: 8,
                    valueColor: const AlwaysStoppedAnimation(
                        Colors.deepPurple),
                    backgroundColor:
                        Colors.deepPurple.withOpacity(0.1),
                  ),
                  Text(_fmt(_elapsedSeconds),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple)),
                ]),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_status,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.deepPurple),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 36),
              TextButton.icon(
                onPressed: () {
                  _pollTimer?.cancel();
                  _timeTimer?.cancel();
                  setState(() {
                    _isProcessing = false;
                    _jobState = _JobState.idle;
                    _error = null;
                  });
                },
                icon: const Icon(Icons.cancel_outlined,
                    color: Colors.grey),
                label: const Text('Cancel',
                    style: TextStyle(color: Colors.grey)),
              ),
            ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 72, color: Colors.red),
              const SizedBox(height: 20),
              const Text('Có lỗi xảy ra',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => setState(
                    () => _jobState = _JobState.idle),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Quay lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                ),
              ),
            ]),
      ),
    );
  }

  Widget _imgView(
      {required String url,
      required String label,
      required Color color}) {
    return Stack(fit: StackFit.expand, children: [
      Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : Center(
                child: CircularProgressIndicator(
                    value: p.expectedTotalBytes != null
                        ? p.cumulativeBytesLoaded /
                            p.expectedTotalBytes!
                        : null)),
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image,
                size: 64, color: Colors.grey)),
      ),
      Positioned(
        top: 12,
        left: 12,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
      ),
    ]);
  }

  Widget _actionButtons(
      {required String resultUrl, VoidCallback? onTryAgain}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: resultUrl.isNotEmpty
                  ? () => _saveToGallery(resultUrl)
                  : null,
              icon: const Icon(Icons.download),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: resultUrl.isNotEmpty
                  ? () => _shareImage(resultUrl)
                  : null,
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ]),
        if (onTryAgain != null) ...[
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử vị trí khác'))),
        ],
      ]),
    );
  }

  Future<void> _saveToGallery(String imageUrl) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving...')));
      final resp = await http.get(Uri.parse(imageUrl));
      if (resp.statusCode == 200) {
        await Gal.putImageBytes(resp.bodyBytes, album: 'Interior AI');
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Saved!')
            ]),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red));
    }
  }

  Future<void> _shareImage(String imageUrl) async {
    try {
      final resp = await http.get(Uri.parse(imageUrl));
      if (resp.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/design_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(resp.bodyBytes);
        if (!mounted) return;
        await Share.shareXFiles([XFile(file.path)],
            text: 'My AI interior design 🏠✨');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: Colors.red));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.swipe, color: Colors.grey, size: 14),
          SizedBox(width: 4),
          Text('Swipe to compare',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color badgeColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: badgeColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBgColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconBgColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: badgeColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  ...bullets.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                  style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                  child: Text(b,
                                      style: const TextStyle(
                                          fontSize: 12))),
                            ]),
                      )),
                ]),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, color: badgeColor, size: 15),
        ]),
      ),
    );
  }
}
