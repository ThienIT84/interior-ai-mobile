import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/generation_provider.dart';

/// Horizontal scrollable style gallery for the Generate Design tab.
class StyleSelector extends StatelessWidget {
  final List<StyleOption> styles;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const StyleSelector({
    super.key,
    required this.styles,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (styles.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SizedBox(
      height: 88, // Reduced from 95
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: styles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8), // Reduced from 10
        itemBuilder: (context, index) {
          final style = styles[index];
          final isSelected = index == selectedIndex;
          return _StyleCard(
            style: style,
            isSelected: isSelected,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final StyleOption style;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 75, // Reduced from 80
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14), // Slightly smaller radius
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? style.gradient
                : [AppColors.surfaceLight, AppColors.surface],
          ),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.6)
                : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: style.gradient.first.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              style.icon,
              size: 24, // Reduced from 30
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(height: 6), // Reduced spacing
            Text(
              style.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 10, // Reduced from 11
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
