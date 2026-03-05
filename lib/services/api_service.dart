import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Service class for API communication with backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Upload image and get image_id plus image dimensions
  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/api/v1/segmentation/upload');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var response = await request.send().timeout(
        AppConfig.uploadTimeout,
        onTimeout: () {
          throw Exception('Upload timeout after ${AppConfig.uploadTimeout.inSeconds}s');
        },
      );
      
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var jsonData = json.decode(responseBody);
        return {
          'image_id': jsonData['image_id'] as String,
          'image_width': jsonData['image_shape']['width'] as int,
          'image_height': jsonData['image_shape']['height'] as int,
        };
      } else {
        var errorBody = await response.stream.bytesToString();
        throw Exception('Upload failed (${response.statusCode}): $errorBody');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  /// Segment image with points
  /// Returns mask_id and mask_url
  Future<Map<String, dynamic>> segmentWithPoints({
    required String imageId,
    required List<Map<String, dynamic>> points,
  }) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/api/v1/segmentation/segment-points');
      var response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_id': imageId,
          'points': points,
        }),
      ).timeout(
        AppConfig.receiveTimeout,
        onTimeout: () {
          throw Exception('Segmentation timeout - SAM took too long');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Segmentation failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Segmentation error: $e');
    }
  }

  /// Get mask image URL
  String getMaskUrl(String maskId) {
    return '${AppConfig.baseUrl}/api/v1/segmentation/mask-image/$maskId';
  }

  /// Get uploaded image URL
  String getImageUrl(String imageId) {
    return '${AppConfig.baseUrl}/api/v1/segmentation/image/$imageId';
  }

  /// Remove object using inpainting (async)
  /// Returns job_id for status polling
  Future<String> removeObjectAsync({
    required String imageId,
    required String maskId,
  }) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/api/v1/inpainting/remove-object-async');
      var response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_id': imageId,
          'mask_id': maskId,
        }),
      ).timeout(
        const Duration(minutes: 26), // 26 minutes: 3 min model load + 20 min processing + buffer
        onTimeout: () {
          throw Exception('Request timeout after 26 minutes - please check backend logs');
        },
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        return jsonData['job_id'] as String;
      } else {
        throw Exception('Remove object failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Remove object error: $e');
    }
  }

  /// Check inpainting job status
  /// Returns status: "pending", "processing", "completed", "failed"
  Future<Map<String, dynamic>> checkJobStatus(String jobId) async {
    try {
      var uri = Uri.parse('${AppConfig.baseUrl}/api/v1/inpainting/job-status/$jobId');
      var response = await http.get(uri).timeout(
        const Duration(seconds: 10), // Longer timeout for status check
        onTimeout: () {
          throw Exception('Status check timeout');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Status check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Status check error: $e');
    }
  }

  /// Get inpainting result image URL
  String getResultUrl(String resultId) {
    return '${AppConfig.baseUrl}/api/v1/inpainting/result/$resultId';
  }

  // ── Generation (Week 3) ─────────────────────────────────────────────────

  /// Get available design styles from backend
  Future<List<Map<String, dynamic>>> getStyles() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/generation/styles');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Styles request timeout'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['styles'] as List);
      } else {
        throw Exception('Get styles failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get styles error: $e');
    }
  }

  /// Submit async ControlNet generation job
  /// [imageId] can be an inpainting result_id or original image_id
  /// Returns full job response map (contains job_id, status, style, message)
  Future<Map<String, dynamic>> generateDesign({
    required String imageId,
    required String style,
    double? guidanceScale,
    int? steps,
    int? seed,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/generation/generate-design');
      final body = <String, dynamic>{
        'image_id': imageId,
        'style': style,
        if (guidanceScale != null) 'guidance_scale': guidanceScale,
        if (steps != null) 'steps': steps,
        if (seed != null) 'seed': seed,
      };
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Generate design request timeout'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Generate design failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Generate design error: $e');
    }
  }

  /// Poll ControlNet generation job status
  Future<Map<String, dynamic>> checkGenerationJobStatus(String jobId) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/generation/job-status/$jobId');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Job status check timeout'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Generation status check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Generation status check error: $e');
    }
  }

  /// Get generation result image URL
  String getGenerationResultUrl(String resultId) {
    return '${AppConfig.baseUrl}/api/v1/generation/result/$resultId';
  }

  // ── Option 1: Targeted Furniture Placement ─────────────────────────────

  /// Submit async furniture placement job.
  /// [imageId] – usually the inpainting result (empty room).
  /// [bboxX/Y/W/H] – normalized coords 0.0–1.0 relative to displayed image.
  Future<Map<String, dynamic>> placeFurniture({
    required String imageId,
    required double bboxX,
    required double bboxY,
    required double bboxW,
    required double bboxH,
    required String furnitureDescription,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/generation/place-furniture');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image_id': imageId,
          'bbox_x': bboxX,
          'bbox_y': bboxY,
          'bbox_w': bboxW,
          'bbox_h': bboxH,
          'furniture_description': furnitureDescription,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Place furniture request timeout'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Place furniture failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Place furniture error: $e');
    }
  }

  /// Poll furniture placement job status.
  Future<Map<String, dynamic>> checkPlacementJobStatus(String jobId) async {
    try {
      final uri = Uri.parse(
          '${AppConfig.baseUrl}/api/v1/generation/placement-job-status/$jobId');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Placement status check timeout'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Placement status check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Placement status check error: $e');
    }
  }

  /// Get placement result image URL.
  String getPlacementResultUrl(String resultId) {
    return '${AppConfig.baseUrl}/api/v1/generation/placement-result/$resultId';
  }
}
