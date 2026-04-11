import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../providers/generation_provider.dart';
import '../widgets/style_selector.dart';
import '../widgets/bbox_painter.dart';

/// Main Generation screen – premium dark-mode UI.
///
/// Layout (top → bottom):
///   • AppBar with title
///   • Before/After image area (with slider when result available)
///   • Mode tabs: Design | Furniture
///   • Tab-specific controls
///   • Action button row (Generate / Save / Share)
class GenerationView extends StatefulWidget {
  final String imageId;
  final String? imageUrl;

  const GenerationView({
    super.key,
    required this.imageId,
    this.imageUrl,
  });

  @override
  State<GenerationView> createState() => _GenerationViewState();
}

class _GenerationViewState extends State<GenerationView>
    with SingleTickerProviderStateMixin {
  late GenerationProvider _provider;
  late TabController _tabController;
  final TextEditingController _furnitureTextCtrl = TextEditingController();

  // Before/After slider
  double _sliderPosition = 0.5;

  @override
  void initState() {
    super.initState();
    _provider = GenerationProvider();
    _provider.setImageContext(imageId: widget.imageId);
    _provider.loadStyles();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _provider.setMode(
          _tabController.index == 0
              ? GenerationMode.design
              : GenerationMode.placement,
        );
      }
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    _tabController.dispose();
    _furnitureTextCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ─ Image area ──────────────────────────────────────
              Expanded(
                flex: 5,
                child: _buildImageArea(),
              ),
              // ─ Progress bar (visible during generation) ────────
              if (_provider.isGenerating) _buildProgressSection(),
              // ─ Error banner ────────────────────────────────────
              if (_provider.errorMessage != null) _buildErrorBanner(),
              // ─ Tabs ────────────────────────────────────────────
              _buildTabBar(),
              // ─ Tab content ─────────────────────────────────────
              Expanded(
                flex: 4,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDesignTab(),
                    _buildPlacementTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'AI Generation',
        style: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      actions: [
        if (_provider.resultImageUrl != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Tạo lại',
            onPressed: () {
              _provider.resetGeneration();
            },
          ),
      ],
    );
  }

  // ── Image Area (Before/After) ─────────────────────────────────
  Widget _buildImageArea() {
    return FadeIn(
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 1),
          color: AppColors.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: _provider.resultImageUrl != null
            ? _buildBeforeAfterSlider()
            : _buildOriginalImage(),
      ),
    );
  }

  Widget _buildOriginalImage() {
    final url = widget.imageUrl ?? _provider.originalImageUrl;
    if (url == null) {
      return const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: AppColors.textDim, size: 48),
      );
    }

    // For placement mode show bbox overlay
    if (_provider.mode == GenerationMode.placement && !_provider.isGenerating) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image, color: AppColors.textDim, size: 48))),
          BboxPainter(
            initialBox: _provider.boundingBox,
            onBboxChanged: (box) => _provider.setBoundingBox(box),
          ),
          // Instruction overlay when no box drawn
          if (_provider.boundingBox == null)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: GlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(
                    '👆  Kéo để vẽ vùng đặt nội thất',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
        const Center(child: Icon(Icons.broken_image, color: AppColors.textDim, size: 48)));
  }

  Widget _buildBeforeAfterSlider() {
    final beforeUrl = widget.imageUrl ?? _provider.originalImageUrl;
    final afterUrl = _provider.resultImageUrl;
    if (beforeUrl == null || afterUrl == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _sliderPosition = (d.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            children: [
              // After image (background)
              Positioned.fill(
                child: Image.network(afterUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                    Container(color: AppColors.surface)),
              ),
              // Before image (clipped)
              Positioned.fill(
                child: ClipRect(
                  clipper: _BeforeClipper(_sliderPosition),
                  child: Image.network(beforeUrl, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.surface)),
                ),
              ),
              // Slider line
              Positioned(
                left: w * _sliderPosition - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                ),
              ),
              // Slider handle
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
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
                ),
              ),
              // Labels
              Positioned(
                left: 12,
                top: 12,
                child: _sliderLabel('BEFORE'),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _sliderLabel('AFTER'),
              ),
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

  // ── Progress section ──────────────────────────────────────────
  Widget _buildProgressSection() {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                const SpinKitPulse(color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _provider.jobStatus,
                    style: GoogleFonts.montserrat(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  '${(_provider.jobProgress * 100).toInt()}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _provider.jobProgress,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _provider.errorMessage!,
              style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: () {
              _provider.resetGeneration();
            },
            child: const Icon(Icons.close, color: AppColors.textDim, size: 16),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500),
        dividerHeight: 0,
        tabs: const [
          Tab(
            icon: Icon(Icons.auto_awesome, size: 18),
            text: 'Thiết kế',
          ),
          Tab(
            icon: Icon(Icons.chair_outlined, size: 18),
            text: 'Nội thất',
          ),
        ],
      ),
    );
  }

  // ── Design Tab ────────────────────────────────────────────────
  Widget _buildDesignTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Chọn phong cách thiết kế',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          StyleSelector(
            styles: _provider.styles,
            selectedIndex: _provider.selectedStyleIndex,
            onSelected: (i) => _provider.selectStyle(i),
          ),
          if (_provider.selectedStyle != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _provider.selectedStyle!.description,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  // ── Placement Tab ─────────────────────────────────────────────
  Widget _buildPlacementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mô tả đồ nội thất',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Text input
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              controller: _furnitureTextCtrl,
              onChanged: _provider.setFurnitureDescription,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'VD: Sofa da nâu phong cách hiện đại',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: AppColors.textDim,
                ),
                prefixIcon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickSuggestion('Sofa da nâu'),
              _quickSuggestion('Bàn gỗ sồi'),
              _quickSuggestion('Kệ tivi mdf'),
              _quickSuggestion('Giường ngủ'),
              _quickSuggestion('Tủ quần áo'),
            ],
          ),
          const SizedBox(height: 16),
          _buildPlaceButton(),
        ],
      ),
    );
  }

  Widget _quickSuggestion(String text) {
    return GestureDetector(
      onTap: () {
        _furnitureTextCtrl.text = text;
        _provider.setFurnitureDescription(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────
  Widget _buildGenerateButton() {
    final canPress = !_provider.isGenerating && _provider.selectedStyle != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: canPress ? () => _provider.generateDesign() : null,
          icon: _provider.isGenerating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.auto_awesome, size: 20),
          label: Text(
            _provider.isGenerating ? 'Đang tạo...' : 'Generate Design',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.surfaceLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: canPress ? 6 : 0,
            shadowColor: AppColors.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceButton() {
    final canPress = !_provider.isGenerating &&
        _provider.boundingBox != null &&
        _furnitureTextCtrl.text.trim().isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: canPress ? () => _provider.placeFurniture() : null,
        icon: _provider.isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.add_home_work_outlined, size: 20),
        label: Text(
          _provider.isGenerating ? 'Đang tạo...' : 'Place Furniture',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: canPress ? 6 : 0,
          shadowColor: AppColors.primary.withOpacity(0.5),
        ),
      ),
    );
  }
}

// ── Before/After clip helper ────────────────────────────────────
class _BeforeClipper extends CustomClipper<Rect> {
  final double position;

  _BeforeClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(covariant _BeforeClipper oldClipper) {
    return oldClipper.position != position;
  }
}
