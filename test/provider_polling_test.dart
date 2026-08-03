import 'package:flutter_test/flutter_test.dart';
import 'package:interior_frontend/data/datasources/remote_datasource.dart';
import 'package:interior_frontend/data/exceptions/remote_data_source_exception.dart';
import 'package:interior_frontend/presentation/generation/providers/generation_provider.dart';
import 'package:interior_frontend/presentation/inpainting/providers/inpainting_provider.dart';

class _PollingDataSource extends RemoteDataSource {
  _PollingDataSource({this.status = 'completed'});

  final String status;

  @override
  Future<String> submitInpainting({
    required String imageId,
    required String maskId,
  }) async => 'job-1';

  @override
  Future<Map<String, dynamic>> checkJobStatus(
    String jobId, {
    required String type,
  }) async {
    return {
      'status': status,
      'progress': status == 'completed' ? 1.0 : 0.5,
      if (status == 'completed' && type == 'inpainting')
        'result_url': '/api/v1/inpainting/result/1',
      if (status == 'completed' && type == 'generation')
        'result_id': 'result-1',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getStyles() async => [
    {'name': 'modern', 'display_name': 'Modern', 'description': 'Modern room'},
  ];

  @override
  Future<Map<String, dynamic>> generateDesign({
    required String imageId,
    required String style,
    String? modelId,
    double? guidanceScale,
    int? steps,
    int? seed,
  }) async => {'job_id': 'generation-1', 'status': 'pending'};
}

class _UnavailableInpaintingDataSource extends RemoteDataSource {
  @override
  Future<String> submitInpainting({
    required String imageId,
    required String maskId,
  }) {
    throw const RemoteDataSourceException(
      message: 'Internal service message',
      code: 'redis_unavailable',
      statusCode: 503,
    );
  }
}

void main() {
  test('inpainting polling reaches completed state', () async {
    final provider = InpaintingProvider(
      dataSource: _PollingDataSource(),
      pollInterval: const Duration(milliseconds: 1),
      maxPolls: 5,
    );

    provider.initialize('image-1', 'mask-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.status, InpaintingStatus.completed);
    expect(provider.progress, 1.0);
    expect(provider.resultUrl, '/api/v1/inpainting/result/1');
    provider.dispose();
  });

  test(
    'inpainting polling reports timeout and retry does not stack timers',
    () async {
      final provider = InpaintingProvider(
        dataSource: _PollingDataSource(status: 'processing'),
        pollInterval: const Duration(milliseconds: 1),
        maxPolls: 1,
      );

      provider.initialize('image-1', 'mask-1');
      provider.retry();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.status, InpaintingStatus.failed);
      expect(provider.errorMessage, contains('timeout'));
      provider.dispose();
    },
  );

  test('inpainting shows a friendly Redis unavailable error', () async {
    final provider = InpaintingProvider(
      dataSource: _UnavailableInpaintingDataSource(),
    );

    provider.initialize('image-1', 'mask-1');
    await Future<void>.delayed(Duration.zero);

    expect(provider.status, InpaintingStatus.failed);
    expect(provider.errorMessage, contains('Please start Redis'));
    expect(provider.errorMessage, isNot(contains('Internal service message')));
    provider.dispose();
  });

  test('generation polling resolves a local result URL', () async {
    final provider = GenerationProvider(
      dataSource: _PollingDataSource(),
      pollInterval: const Duration(milliseconds: 1),
      maxPolls: 5,
    );
    provider.setImageContext(imageId: 'image-1');
    await provider.loadStyles();

    await provider.generateDesign();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.isGenerating, isFalse);
    expect(provider.jobProgress, 1.0);
    expect(provider.resultImageUrl, contains('/api/v1/generation/result/'));
    provider.dispose();
  });
}
