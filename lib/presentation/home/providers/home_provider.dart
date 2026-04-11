import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/base_provider.dart';

class HomeProvider extends BaseProvider {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  File? get selectedImage => _selectedImage;

  Future<void> pickImage(ImageSource source) async {
    try {
      setLoading(true);
      clearError();
      
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        _selectedImage = File(pickedFile.path);
        notifyListeners();
      }
    } catch (e) {
      setError("Không thể chọn ảnh: ${e.toString()}");
    } finally {
      setLoading(false);
    }
  }

  void clearImage() {
    _selectedImage = null;
    notifyListeners();
  }
}
