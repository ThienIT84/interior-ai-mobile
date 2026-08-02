import 'dart:typed_data';
import 'dart:js_interop';

import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

import 'image_export_contract.dart';

ImageExportService createImageExportService() => WebImageExportService();

class WebImageExportService implements ImageExportService {
  @override
  Future<void> save(Uint8List bytes, String fileName) async {
    final file = web.File(
      [bytes.buffer.toJS].toJS,
      fileName,
      web.FilePropertyBag()..type = 'image/png',
    );
    final url = web.URL.createObjectURL(file);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  @override
  Future<ImageShareOutcome> share(
    Uint8List bytes,
    String fileName,
    String text,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        text: text,
        downloadFallbackEnabled: true,
        mailToFallbackEnabled: false,
      ),
    );
    // share_plus uses the Web Share API and downloads the file automatically
    // when the browser cannot share files.
    return ImageShareOutcome.downloadedFallback;
  }
}
