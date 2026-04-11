import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../providers/home_provider.dart';
import '../../segmentation/views/segmentation_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Hero Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1618221195710-dd6b41faeaa6?q=80&w=2000&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: AppColors.background);
              },
            ),
          ),
          // Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    AppColors.background.withOpacity(0.8),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
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
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Transform your room with the power of AI. Just snap a photo and let the magic happen.',
                          style: GoogleFonts.montserrat(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    child: Consumer<HomeProvider>(
                      builder: (context, provider, child) {
                        return GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildSourceOption(
                                context,
                                icon: Icons.camera_alt_outlined,
                                title: 'Take a Photo',
                                subtitle: 'Use your camera to capture room',
                                onTap: () => provider.pickImage(ImageSource.camera),
                              ),
                              const Divider(color: Colors.white10, height: 32),
                              _buildSourceOption(
                                context,
                                icon: Icons.photo_library_outlined,
                                title: 'From Gallery',
                                subtitle: 'Choose an existing photo',
                                onTap: () => provider.pickImage(ImageSource.gallery),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: Consumer<HomeProvider>(
                      builder: (context, provider, child) {
                        return SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: provider.selectedImage == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SegmentationView(
                                          imageFile: provider.selectedImage!,
                                        ),
                                      ),
                                    );
                                  },
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
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // Loading Overlay
          Consumer<HomeProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return Container(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
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
    );
  }
}
