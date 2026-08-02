import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_breakpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/image_export_service.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/datasources/remote_datasource.dart';
import '../../segmentation/views/segmentation_view.dart';
import '../providers/home_provider.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    this.backgroundImage,
    this.dataSource,
    this.imageExportService,
  });

  final ImageProvider? backgroundImage;
  final RemoteDataSource? dataSource;
  final ImageExportService? imageExportService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image:
                  backgroundImage ??
                  const NetworkImage(
                    'https://images.unsplash.com/photo-1618221195710-dd6b41faeaa6?q=80&w=2000&auto=format&fit=crop',
                  ),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.background),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    AppColors.background.withValues(alpha: 0.88),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: desktop ? 56 : 24,
                        vertical: desktop ? 56 : 32,
                      ),
                      child: desktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(child: _HeroCopy()),
                                const SizedBox(width: 64),
                                Expanded(
                                  child: _ActionPanel(
                                    dataSource: dataSource,
                                    imageExportService: imageExportService,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _HeroCopy(),
                                const SizedBox(height: 40),
                                _ActionPanel(
                                  dataSource: dataSource,
                                  imageExportService: imageExportService,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          Consumer<HomeProvider>(
            builder: (_, provider, _) => provider.isLoading
                ? Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    return FadeInDown(
      duration: const Duration(milliseconds: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI INTERIOR',
            style: GoogleFonts.montserrat(
              color: AppColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Redesign Your\nLiving Space.',
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: desktop ? 58 : 42,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Transform your room with the power of AI. Choose a photo and let the design workflow guide you.',
              style: GoogleFonts.montserrat(
                color: AppColors.textSecondary,
                fontSize: desktop ? 18 : 16,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({this.dataSource, this.imageExportService});

  final RemoteDataSource? dataSource;
  final ImageExportService? imageExportService;

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: Consumer<HomeProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (provider.selectedImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.memory(
                            provider.selectedImage!.bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (kIsWeb)
                      _SourceOption(
                        icon: Icons.upload_file_rounded,
                        title: 'Choose an image',
                        subtitle: 'JPG, PNG, or WebP · up to 15 MB',
                        onTap: () => provider.pickImage(ImageSource.gallery),
                      )
                    else ...[
                      _SourceOption(
                        icon: Icons.camera_alt_outlined,
                        title: 'Take a Photo',
                        subtitle: 'Use your camera to capture the room',
                        onTap: () => provider.pickImage(ImageSource.camera),
                      ),
                      const Divider(color: Colors.white10, height: 32),
                      _SourceOption(
                        icon: Icons.photo_library_outlined,
                        title: 'From Gallery',
                        subtitle: 'Choose an existing photo',
                        onTap: () => provider.pickImage(ImageSource.gallery),
                      ),
                    ],
                  ],
                ),
              ),
              if (provider.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: provider.error!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: provider.selectedImage == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SegmentationView(
                              image: provider.selectedImage!,
                              dataSource: dataSource,
                              imageExportService: imageExportService,
                            ),
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    provider.selectedImage == null
                        ? 'SELECT A PHOTO'
                        : 'START AI DESIGN',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
