import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'image_export_contract.dart';

ImageExportService createImageExportService() => MobileImageExportService();

class MobileImageExportService implements ImageExportService {
  @override
  Future<void> save(Uint8List bytes, String fileName) {
    final name = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return Gal.putImageBytes(bytes, name: name);
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
      ),
    );
    return ImageShareOutcome.shared;
  }
}
