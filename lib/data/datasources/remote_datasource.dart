import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/constants/app_config.dart';
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
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'image_id': imageId, 'mask_id': maskId}),
        )
        .timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body)['job_id'];
    }
    throw Exception('Inpainting submission failed');
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
