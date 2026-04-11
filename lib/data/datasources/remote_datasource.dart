import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/app_config.dart';

class RemoteDataSource {
  final String _baseUrl = AppConfig.baseUrl;

  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/v1/segmentation/segment');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamedResponse = await request.send().timeout(AppConfig.uploadTimeout);
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
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'image_id': imageId,
        'points': points,
        if (backend != null) 'segmentation_backend': backend,
        if (textPrompt != null) 'text_prompt': textPrompt,
      }),
    ).timeout(AppConfig.receiveTimeout);

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
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'image_id': imageId, 'mask_id': maskId}),
    ).timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body)['job_id'];
    }
    throw Exception('Inpainting submission failed');
  }

  Future<Map<String, dynamic>> checkJobStatus(String jobId, {required String type}) async {
    String path;
    if (type == 'inpainting') {
      path = '/api/v1/inpainting/job-status/$jobId';
    } else if (type == 'placement') {
      path = '/api/v1/generation/placement-job-status/$jobId';
    } else {
      path = '/api/v1/generation/job-status/$jobId';
    }

    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.get(uri).timeout(AppConfig.jobStatusTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Status check failed');
  }

  Future<Map<String, dynamic>> placeFurniture({
    required String imageId,
    required double x, required double y, required double w, required double h,
    required String description,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/generation/place-furniture');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'image_id': imageId,
        'bbox_x': x, 'bbox_y': y, 'bbox_w': w, 'bbox_h': h,
        'furniture_description': description,
      }),
    ).timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Furniture placement failed');
  }

  Future<Map<String, dynamic>> generateDesign({
    required String imageId,
    required String style,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/generation/generate-design');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'image_id': imageId, 'style': style}),
    ).timeout(AppConfig.receiveTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Design generation failed');
  }

  String getImageUrl(String imageId) => '$_baseUrl/api/v1/segmentation/image/$imageId';
  String getMaskUrl(String maskId) => '$_baseUrl/api/v1/segmentation/mask-image/$maskId';
  String getInpaintingResultUrl(String resultId) => '$_baseUrl/api/v1/inpainting/result/$resultId';
  String getPlacementResultUrl(String resultId) => '$_baseUrl/api/v1/generation/placement-result/$resultId';
  String getGenerationResultUrl(String resultId) => '$_baseUrl/api/v1/generation/result/$resultId';
}
