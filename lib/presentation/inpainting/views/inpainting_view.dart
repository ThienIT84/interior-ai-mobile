import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../core/constants/app_breakpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/image_export_service.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/datasources/remote_datasource.dart';
import '../../generation/views/generation_view.dart';
import '../providers/inpainting_provider.dart';

class InpaintingView extends StatefulWidget {
  final String imageId;
  final String maskId;

  const InpaintingView({
    super.key,
    required this.imageId,
    required this.maskId,
    this.dataSource,
    this.imageExportService,
  });

  final RemoteDataSource? dataSource;
  final ImageExportService? imageExportService;

  @override
  State<InpaintingView> createState() => _InpaintingViewState();
}

class _InpaintingViewState extends State<InpaintingView> {
  late InpaintingProvider _provider;
  late final RemoteDataSource _dataSource;
  late final ImageExportService _imageExportService;

  // Slider position for before/after comparison
  double _sliderPosition = 0.5;

  // Tips rotation
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  final List<String> _loadingTips = [
    "Removing objects helps AI understand the room structure better.",
    "Select the area close to the object for the most natural removal result.",
    "Flat surfaces (floors, walls) are where AI works best.",
    "Tip: Remove old furniture before designing to give AI more creative freedom.",
    "Analyzing surrounding pixels to fill the gap seamlessly.",
    "AI is recreating wood grains and wall patterns perfectly.",
    "An empty room is the perfect canvas for a breakthrough design.",
  ];

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? RemoteDataSource();
    _imageExportService =
        widget.imageExportService ?? createImageExportService();
    _provider = InpaintingProvider(dataSource: _dataSource);
    _provider.initialize(widget.imageId, widget.maskId);
    _startTipTimer();
  }

  @override
  void dispose() {
    _provider.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipTimer() {
    _tipTimer?.cancel();
    _currentTipIndex = Random().nextInt(_loadingTips.length);
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _provider.isProcessing) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _loadingTips.length;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(),
          body: SafeArea(child: _buildBody()),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'CLEANING ROOM',
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    if (_provider.status == InpaintingStatus.failed) {
      return _buildErrorState();
    }

    if (_provider.status == InpaintingStatus.completed) {
      return _buildResultState();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.maxContentWidth,
        ),
        child: _buildProcessingState(),
      ),
    );
  }

  // ── Processing State ──────────────────────────────────────────────────

  Widget _buildProcessingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          FadeInDown(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SpinKitRipple(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  size: 200,
                ),
                SpinKitDoubleBounce(color: AppColors.accent, size: 140),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(_provider.elapsedSeconds),
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'sec',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
          FadeInUp(
            child: Text(
              _provider.statusText,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'This usually takes 15-45 seconds',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _provider.progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const Spacer(),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: GlassContainer(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _loadingTips[_currentTipIndex],
                        key: ValueKey<int>(_currentTipIndex),
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassContainer(
          borderRadius: 32,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 64),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _provider.errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _provider.retry(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Result State ──────────────────────────────────────────────────────

  Widget _buildResultState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: desktop
                ? Row(
                    children: [
                      Expanded(child: _buildResultCanvas()),
                      SizedBox(width: 400, child: _buildResultControls()),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 6, child: _buildResultCanvas()),
                      _buildResultControls(),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResultCanvas() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder),
          color: AppColors.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildBeforeAfterSlider(),
      ),
    );
  }

  Widget _buildResultControls() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transformation Complete!',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Items removed in ${_formatTime(_provider.elapsedSeconds)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildIconButton(
                  icon: Icons.file_download_outlined,
                  label: 'Save',
                  onTap: _saveToGallery,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildIconButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: _shareImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _navigateToGeneration,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                'GENERATE DESIGN',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfterSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        final resultUrl = _dataSource.getInpaintingResultUrl(
          _provider.resultUrl!.split('/').last,
        );
        final originalUrl = _dataSource.getImageUrl(_provider.imageId!);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition = (_sliderPosition + details.primaryDelta! / w)
                  .clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // After Image (Base)
              Image.network(resultUrl, fit: BoxFit.contain),

              // Before Image (Clipped)
              ClipRect(
                clipper: SliderClipper(_sliderPosition),
                child: Image.network(originalUrl, fit: BoxFit.contain),
              ),

              // Divider line
              Positioned(
                left: w * _sliderPosition - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),

              // Handle
              Positioned(
                left: w * _sliderPosition - 18,
                top: h / 2 - 18,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.unfold_more_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),

              // Labels
              Positioned(left: 12, top: 12, child: _sliderLabel('BEFORE')),
              Positioned(right: 12, top: 12, child: _sliderLabel('AFTER')),
            ],
          ),
        );
      },
    );
  }

  Widget _sliderLabel(String text) {
    return GlassContainer(
      borderRadius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────

  Future<void> _saveToGallery() async {
    try {
      final bytes = await _dataSource.fetchImageBytes(_resultImageUrl());
      final fileName =
          'clean_room_${DateTime.now().millisecondsSinceEpoch}.png';
      await _imageExportService.save(bytes, fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image saved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _shareImage() async {
    try {
      final bytes = await _dataSource.fetchImageBytes(_resultImageUrl());
      final outcome = await _imageExportService.share(
        bytes,
        'clean_room_${DateTime.now().millisecondsSinceEpoch}.png',
        'Check out my clean room! 🏠',
      );
      if (!mounted) return;
      if (outcome == ImageShareOutcome.downloadedFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Share opened. If file sharing is unavailable, the image was downloaded.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _resultImageUrl() {
    final resultUrl = _provider.resultUrl;
    if (resultUrl == null || resultUrl.trim().isEmpty) {
      throw const FormatException('The result image URL is missing.');
    }
    return resultUrl;
  }

  void _navigateToGeneration() {
    final resultId = _provider.resultUrl!.split('/').last;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenerationView(
          imageId: resultId,
          imageUrl: _dataSource.getInpaintingResultUrl(resultId),
          dataSource: _dataSource,
          imageExportService: _imageExportService,
        ),
      ),
    );
  }
}

class SliderClipper extends CustomClipper<Rect> {
  final double position;
  SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(SliderClipper oldClipper) =>
      oldClipper.position != position;
}
