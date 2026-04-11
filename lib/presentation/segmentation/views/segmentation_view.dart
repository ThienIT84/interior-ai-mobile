import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SegmentationView extends StatelessWidget {
  const SegmentationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Design Selection'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Segmentation View Placeholder\n(Coming in Task 3)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}
