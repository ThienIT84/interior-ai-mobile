import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:interior_frontend/core/constants/app_config.dart';
import 'package:interior_frontend/data/datasources/remote_datasource.dart';
import 'package:interior_frontend/data/exceptions/remote_data_source_exception.dart';
import 'package:interior_frontend/data/models/app_image.dart';

void main() {
  test('upload uses multipart file field, filename, and MIME type', () async {
    http.MultipartRequest? captured;
    final client = MockClient.streaming((request, body) async {
      captured = request as http.MultipartRequest;
      await body.drain<void>();
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'image_id': 'image-1',
              'image_shape': {'width': 1200, 'height': 800},
            }),
          ),
        ),
        200,
      );
    });
    final source = RemoteDataSource(client: client);

    final result = await source.uploadImage(
      AppImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'room.webp',
        mimeType: 'image/webp',
        sizeInBytes: 3,
      ),
    );

    expect(result['image_id'], 'image-1');
    expect(captured?.files.single.field, 'file');
    expect(captured?.files.single.filename, 'room.webp');
    expect(captured?.files.single.contentType.toString(), 'image/webp');
  });

  test('resolveUrl supports relative and absolute URLs', () {
    expect(
      AppConfig.resolveUrl('/api/v1/result/1'),
      '${AppConfig.baseUrl}/api/v1/result/1',
    );
    expect(
      AppConfig.resolveUrl('https://cdn.example.com/result.png'),
      'https://cdn.example.com/result.png',
    );
    expect(() => AppConfig.resolveUrl('  '), throwsFormatException);
  });

  test('submitInpainting parses Redis unavailable response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'detail': {
            'code': 'redis_unavailable',
            'message': 'Background job service is temporarily unavailable.',
          },
        }),
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    final source = RemoteDataSource(client: client);

    await expectLater(
      source.submitInpainting(imageId: 'image-1', maskId: 'mask-1'),
      throwsA(
        isA<RemoteDataSourceException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.code, 'code', 'redis_unavailable')
            .having(
              (error) => error.isRedisUnavailable,
              'isRedisUnavailable',
              isTrue,
            ),
      ),
    );
  });

  test('submitInpainting maps network failure safely', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('socket details'),
    );
    final source = RemoteDataSource(client: client);

    await expectLater(
      source.submitInpainting(imageId: 'image-1', maskId: 'mask-1'),
      throwsA(
        isA<RemoteDataSourceException>()
            .having((error) => error.code, 'code', 'backend_unreachable')
            .having(
              (error) => error.message,
              'message',
              isNot(contains('socket details')),
            ),
      ),
    );
  });
}
