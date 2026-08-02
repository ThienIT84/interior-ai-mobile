import 'dart:typed_data';

enum ImageShareOutcome { shared, downloadedFallback }

abstract interface class ImageExportService {
  Future<void> save(Uint8List bytes, String fileName);

  Future<ImageShareOutcome> share(
    Uint8List bytes,
    String fileName,
    String text,
  );
}
