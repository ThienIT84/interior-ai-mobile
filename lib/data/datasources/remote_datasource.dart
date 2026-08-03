import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/constants/app_config.dart';
import '../exceptions/remote_data_source_exception.dart';
import '../models/app_image.dart';

class RemoteDataSource {
  RemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl = AppConfig.baseUrl;

  Future<Map<String, dynamic>> uploadImage(AppImage image) async {
    final uri = Uri.parse('$_baseUrl/api/v1/segmentation/segment');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        image.bytes,
        filename: image.fileName,
        contentType: MediaType.parse(image.mimeType),
      ),
    );

    final streamedResponse = await _client
        .send(request)
        .timeout(AppConfig.uploadTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'image_id': data['image_id'],
        'image_width': data['image_shape']['width'],
        'image_height': data['image_shape']['height'],
      };
    }
    throw Exception('Upload failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> segmentWithPoints({
    required String imageId,
    required List<Map<String, dynamic>> points,
    String? backend,
    String? textPrompt,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/segmentation/segment-points');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'image_id': imageId,
            'points': points,
            'segmentation_backend': ?backend,
            'text_prompt': ?textPrompt,
          }),
        )
        .timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Segmentation failed');
  }

  Future<String> submitInpainting({
    required String imageId,
    required String maskId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/inpainting/remove-object-async');
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'image_id': imageId, 'mask_id': maskId}),
          )
          .timeout(AppConfig.receiveTimeout);
    } on TimeoutException {
      throw const RemoteDataSourceException(
        message: 'The backend request timed out. Please try again.',
        code: 'backend_timeout',
      );
    } on http.ClientException {
      throw const RemoteDataSourceException(
        message: 'The backend is unreachable. Check that it is running.',
        code: 'backend_unreachable',
      );
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final jobId = data['job_id'] as String?;
      if (jobId == null || jobId.trim().isEmpty) {
        throw const RemoteDataSourceException(
          message: 'The backend returned an invalid job response.',
          code: 'invalid_job_response',
        );
      }
      return jobId;
    }
    throw _responseException(
      response,
      fallbackMessage: 'Inpainting submission failed.',
    );
  }

  RemoteDataSourceException _responseException(
    http.Response response, {
    required String fallbackMessage,
  }) {
    String code = 'http_${response.statusCode}';
    String message = fallbackMessage;

    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          code = detail['code'] as String? ?? code;
          message = detail['message'] as String? ?? message;
        } else if (detail is String && detail.trim().isNotEmpty) {
          message = detail;
        }
      }
    } on FormatException {
      // Keep the safe fallback for non-JSON backend responses.
    }

    return RemoteDataSourceException(
      message: message,
      code: code,
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> checkJobStatus(
    String jobId, {
    required String type,
  }) async {
    String path;
    if (type == 'inpainting') {
      path = '/api/v1/inpainting/job-status/$jobId';
    } else if (type == 'placement') {
      path = '/api/v1/generation/placement-job-status/$jobId';
    } else {
      path = '/api/v1/generation/job-status/$jobId';
    }

    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(uri).timeout(AppConfig.jobStatusTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Status check failed');
  }

  Future<Map<String, dynamic>> placeFurniture({
    required String imageId,
    required double x,
    required double y,
    required double w,
    required double h,
    required String description,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/generation/place-furniture');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'image_id': imageId,
            'bbox_x': x,
            'bbox_y': y,
            'bbox_w': w,
            'bbox_h': h,
            'furniture_description': description,
          }),
        )
        .timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Furniture placement failed');
  }

  Future<Map<String, dynamic>> generateDesign({
    required String imageId,
    required String style,
    String? modelId,
    double? guidanceScale,
    int? steps,
    int? seed,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/generation/generate-design');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'image_id': imageId,
            'style': style,
            'model_id': ?modelId,
            'guidance_scale': ?guidanceScale,
            'steps': ?steps,
            'seed': ?seed,
          }),
        )
        .timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Design generation failed');
  }

  Future<Map<String, dynamic>> getSegmentationBackendDebug() async {
    final uri = Uri.parse('$_baseUrl/api/v1/segmentation/debug/backend');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Debug endpoint failed: ${response.statusCode}');
  }

  /// Fetch available design styles from backend
  Future<List<Map<String, dynamic>>> getStyles() async {
    final uri = Uri.parse('$_baseUrl/api/v1/generation/styles');
    final response = await _client.get(uri).timeout(AppConfig.jobStatusTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['styles'] ?? []);
    }
    throw Exception('Failed to fetch styles: ${response.statusCode}');
  }

  Future<Uint8List> fetchImageBytes(String pathOrUrl) async {
    final uri = Uri.parse(AppConfig.resolveUrl(pathOrUrl));
    final response = await _client.get(uri).timeout(AppConfig.receiveTimeout);
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Image download failed: ${response.statusCode}');
  }

  String getImageUrl(String imageId) =>
      AppConfig.resolveUrl('/api/v1/segmentation/image/$imageId');
  String getMaskUrl(String maskId) =>
      AppConfig.resolveUrl('/api/v1/segmentation/mask-image/$maskId');
  String getInpaintingResultUrl(String resultId) =>
      AppConfig.resolveUrl('/api/v1/inpainting/result/$resultId');
  String getPlacementResultUrl(String resultId) =>
      AppConfig.resolveUrl('/api/v1/generation/placement-result/$resultId');
  String getGenerationResultUrl(String resultId) =>
      AppConfig.resolveUrl('/api/v1/generation/result/$resultId');
}
