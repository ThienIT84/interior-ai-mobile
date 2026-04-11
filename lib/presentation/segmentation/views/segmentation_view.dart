import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/segmentation_provider.dart';
import '../widgets/pulsing_point_marker.dart';
import '../../generation/views/generation_view.dart';

class SegmentationView extends StatefulWidget {
  final File imageFile;

  const SegmentationView({
    super.key,
    required this.imageFile,
  });

  @override
  State<SegmentationView> createState() => _SegmentationViewState();
}

class _SegmentationViewState extends State<SegmentationView> {
  final GlobalKey _imageContainerKey = GlobalKey();
  late SegmentationProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SegmentationProvider();
    _provider.initialize(widget.imageFile);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Rect _getDisplayedImageRect(Size viewportSize) {
    final iw = _provider.imageWidth?.toDouble();
    final ih = _provider.imageHeight?.toDouble();
    if (iw == null || ih == null || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height);
    }

    final imageAspect = iw / ih;
    final viewportAspect = viewportSize.width / viewportSize.height;
    double dw, dh, left, top;

    if (imageAspect > viewportAspect) {
      dw = viewportSize.width;
      dh = dw / imageAspect;
      left = 0;
      top = (viewportSize.height - dh) / 2;
    } else {
      dh = viewportSize.height;
      dw = dh * imageAspect;
      top = 0;
      left = (viewportSize.width - dw) / 2;
    }

    return Rect.fromLTWH(left, top, dw, dh);
  }

  void _handleTap(TapDownDetails details) {
    if (!_provider.hasImage) return;

    final RenderBox? renderBox =
        _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    final localPos = details.localPosition;
    final imageRect = _getDisplayedImageRect(viewportSize);

    if (!imageRect.contains(localPos)) return;

    final nx = (localPos.dx - imageRect.left) / imageRect.width;
    final ny = (localPos.dy - imageRect.top) / imageRect.height;
    _provider.addPoint(nx, ny);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildStatusBar(),
              _buildBackendSelector(),
              Expanded(child: _buildImageCanvas()),
              _buildBottomToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar ─────────────────────────────────────

  Widget _buildAppBar() {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SELECT OBJECT',
                style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            Consumer<SegmentationProvider>(
              builder: (context, provider, _) {
                return IconButton(
                  onPressed: provider.hasMask ? provider.toggleMask : null,
                  icon: Icon(
                    provider.showMask ? Icons.visibility : Icons.visibility_off,
                    color: provider.hasMask ? AppColors.accent : Colors.white24,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status bar ─────────────────────────────────

  Widget _buildStatusBar() {
    return Consumer<SegmentationProvider>(
      builder: (context, provider, _) {
        final bool busy = provider.isLoading || provider.isSegmenting;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: busy
                ? AppColors.accent.withOpacity(0.15)
                : (provider.hasMask
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: busy
                  ? AppColors.accent.withOpacity(0.3)
                  : (provider.hasMask
                      ? AppColors.success.withOpacity(0.2)
                      : Colors.white10),
            ),
          ),
          child: Row(
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              if (provider.hasMask && !busy)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.check_circle, color: AppColors.success, size: 18),
                ),
              Expanded(
                child: Text(
                  provider.status,
                  style: GoogleFonts.montserrat(
                    color: busy ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: busy ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (provider.points.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${provider.points.length} pts',
                    style: GoogleFonts.montserrat(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Backend selector ───────────────────────────

  Widget _buildBackendSelector() {
    return Consumer<SegmentationProvider>(
      builder: (context, provider, _) {
        return FadeInDown(
          delay: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Backend toggle row
                Row(
                  children: [
                    _buildBackendChip(
                      label: 'SAM Local',
                      icon: Icons.memory,
                      isSelected: provider.selectedBackend == SegmentationProvider.backendLocal,
                      onTap: () =>
                          provider.changeBackend(SegmentationProvider.backendLocal),
                    ),
                    const SizedBox(width: 8),
                    _buildBackendChip(
                      label: 'SAM 3',
                      icon: Icons.cloud_outlined,
                      isSelected: provider.selectedBackend == SegmentationProvider.backendSam3,
                      onTap: () =>
                          provider.changeBackend(SegmentationProvider.backendSam3),
                    ),
                    const SizedBox(width: 8),
                    if (provider.selectedModelName != null)
                      Expanded(
                        child: Text(
                          provider.selectedModelName!.split('/').last,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: AppColors.textDim,
                            fontSize: 10,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
                // Text prompt input (SAM3 only)
                if (provider.isSam3) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.search, color: AppColors.textDim, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: provider.textPromptController,
                            style: GoogleFonts.montserrat(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Describe the object (e.g. sofa, chair...)',
                              hintStyle: GoogleFonts.montserrat(
                                color: AppColors.textDim,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) => provider.segmentWithTextOnly(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => provider.segmentWithTextOnly(),
                          icon: const Icon(Icons.send_rounded,
                              color: AppColors.accent, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackendChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? AppColors.accent : AppColors.textDim),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Image canvas with mask & markers ───────────

  Widget _buildImageCanvas() {
    return Consumer<SegmentationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.hasImage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitPulsingGrid(
                  color: AppColors.accent,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  'Uploading to AI server...',
                  style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return FadeIn(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final imageRect = _getDisplayedImageRect(viewportSize);

                return GestureDetector(
                  onTapDown: _handleTap,
                  child: Container(
                    key: _imageContainerKey,
                    color: AppColors.surface,
                    width: viewportSize.width,
                    height: viewportSize.height,
                    child: Stack(
                      children: [
                        // Original image
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
                        // Mask overlay
                        if (provider.hasMask && provider.showMask)
                          Positioned(
                            left: imageRect.left,
                            top: imageRect.top,
                            width: imageRect.width,
                            height: imageRect.height,
                            child: Image.network(
                              '${provider.maskUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
                              fit: BoxFit.fill,
                              color: AppColors.accent
                                  .withOpacity(provider.maskOpacity),
                              colorBlendMode: BlendMode.srcATop,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        // Pulsing point markers
                        ...provider.points.asMap().entries.map((entry) {
                          return PulsingPointMarker(
                            point: entry.value,
                            index: entry.key,
                            imageRect: imageRect,
                          );
                        }),
                        // Segmenting spinner overlay
                        if (provider.isSegmenting)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black38,
                              child: Center(
                                child: SpinKitRipple(
                                  color: AppColors.accent,
                                  size: 80,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ─── Bottom toolbar ─────────────────────────────

  Widget _buildBottomToolbar() {
    return Consumer<SegmentationProvider>(
      builder: (context, provider, _) {
        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Opacity slider (only when mask is active)
                if (provider.hasMask) _buildOpacitySlider(provider),
                const SizedBox(height: 8),
                // Action buttons row
                Row(
                  children: [
                    _buildToolButton(
                      icon: Icons.undo_rounded,
                      label: 'Undo',
                      onTap: provider.points.isNotEmpty
                          ? provider.undoLastPoint
                          : null,
                    ),
                    const SizedBox(width: 10),
                    _buildToolButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Clear',
                      onTap: (provider.points.isNotEmpty || provider.hasMask)
                          ? provider.clearAll
                          : null,
                      isDestructive: true,
                    ),
                    const SizedBox(width: 10),
                    _buildToolButton(
                      icon: Icons.auto_awesome,
                      label: 'Design',
                      onTap: provider.imageId != null
                          ? () => _navigateToGeneration(provider)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildPrimaryAction(provider),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpacitySlider(SegmentationProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.opacity, size: 18, color: AppColors.textDim),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: Colors.white10,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withOpacity(0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: provider.maskOpacity,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: provider.setMaskOpacity,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${(provider.maskOpacity * 100).toInt()}%',
              style: GoogleFonts.montserrat(
                color: AppColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final bool enabled = onTap != null;
    final Color color = isDestructive
        ? (enabled ? AppColors.error : AppColors.textDim)
        : (enabled ? AppColors.textPrimary : AppColors.textDim);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToGeneration(SegmentationProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenerationView(
          imageId: provider.imageId!,
          imageUrl: provider.imageUrl,
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(SegmentationProvider provider) {
    final bool canProceed = provider.hasMask;

    return GestureDetector(
      onTap: canProceed
          ? () => _navigateToGeneration(provider)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: canProceed
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.secondary],
                )
              : null,
          color: canProceed ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: canProceed
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canProceed ? Icons.auto_fix_high : Icons.touch_app_outlined,
              color: canProceed ? Colors.white : AppColors.textDim,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                canProceed ? 'GENERATE' : 'SELECT FIRST',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.montserrat(
                  color: canProceed ? Colors.white : AppColors.textDim,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

