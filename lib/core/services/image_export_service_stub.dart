import 'dart:typed_data';

import 'image_export_contract.dart';

ImageExportService createImageExportService() =>
    const UnsupportedImageExportService();

class UnsupportedImageExportService implements ImageExportService {
  const UnsupportedImageExportService();

  @override
  Future<void> save(Uint8List bytes, String fileName) {
    throw UnsupportedError('Saving images is not supported on this platform.');
  }

  @override
  Future<ImageShareOutcome> share(
    Uint8List bytes,
    String fileName,
    String text,
  ) {
    throw UnsupportedError('Sharing images is not supported on this platform.');
  }
}
