import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:interior_frontend/data/models/app_image.dart';

void main() {
  test('creates a platform-neutral image from XFile bytes', () async {
    final source = XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      path: 'room.PNG',
      name: 'room.PNG',
      mimeType: 'image/png',
    );

    final image = await AppImage.fromXFile(source);

    expect(image.fileName, 'room.PNG');
    expect(image.mimeType, 'image/png');
    expect(image.sizeInBytes, 3);
    expect(image.bytes, [1, 2, 3]);
  });

  test('rejects unsupported formats before reading them', () async {
    final source = XFile.fromData(
      Uint8List.fromList([1]),
      path: 'room.gif',
      name: 'room.gif',
      mimeType: 'image/gif',
    );

    expect(
      () => AppImage.fromXFile(source),
      throwsA(isA<AppImageValidationException>()),
    );
  });

  test('rejects images larger than 15 MB', () async {
    final source = XFile.fromData(
      Uint8List(AppImage.maxSizeInBytes + 1),
      path: 'large.jpg',
      name: 'large.jpg',
      mimeType: 'image/jpeg',
    );

    expect(
      () => AppImage.fromXFile(source),
      throwsA(isA<AppImageValidationException>()),
    );
  });
}
