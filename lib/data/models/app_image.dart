import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class AppImageValidationException implements Exception {
  const AppImageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppImage {
  const AppImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.sizeInBytes,
  });

  static const int maxSizeInBytes = 15 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int sizeInBytes;

  static Future<AppImage> fromXFile(XFile file) async {
    final rawName = file.name.trim();
    final fileName = rawName.isEmpty
        ? 'room-image.jpg'
        : rawName.split(RegExp(r'[\\/]')).last;
    final extension = _extensionOf(fileName);
    if (!allowedExtensions.contains(extension)) {
      throw const AppImageValidationException(
        'Unsupported image format. Please choose a JPG, PNG, or WebP image.',
      );
    }

    final size = await file.length();
    if (size > maxSizeInBytes) {
      throw const AppImageValidationException(
        'Image is larger than 15 MB. Please choose a smaller image.',
      );
    }
    if (size == 0) {
      throw const AppImageValidationException('The selected image is empty.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const AppImageValidationException('The selected image is empty.');
    }

    return AppImage(
      bytes: bytes,
      fileName: fileName,
      mimeType: _resolveMimeType(file.mimeType, extension),
      sizeInBytes: bytes.length,
    );
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static String _resolveMimeType(String? provided, String extension) {
    final normalized = provided?.trim().toLowerCase();
    if (normalized != null && normalized.startsWith('image/')) {
      return normalized;
    }
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }
}
