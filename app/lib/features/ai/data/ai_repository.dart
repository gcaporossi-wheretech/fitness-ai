import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/network/api_exception.dart';
import 'package:fitness_ai/features/ai/domain/coach_result.dart';
import 'package:fitness_ai/features/ai/domain/vision_result.dart';

/// Repository for AI operations (vision scan, coach generation).
/// The backend processes these synchronously and returns the result
/// directly in the HTTP response (no job polling).
class AIRepository {
  AIRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Scan an equipment image and return the recognized equipment + exercises.
  Future<VisionResult> scanEquipment({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    try {
      final form = FormData();
      form.files.add(MapEntry(
        'image',
        MultipartFile.fromBytes(
          imageBytes,
          filename: filename.isNotEmpty ? filename : 'scan.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      ));
      final response = await apiClient.post(
        ApiConstants.aiVisionScan,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return VisionResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Generate a personalized workout plan from optional body photos + profile.
  Future<CoachResult> generateCoachPlan({
    required List<({Uint8List bytes, String filename})> photos,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final form = FormData();
      form.fields.add(MapEntry('data', jsonEncode(userData)));
      for (final p in photos) {
        form.files.add(MapEntry(
          'photos',
          MultipartFile.fromBytes(
            p.bytes,
            filename: p.filename,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ));
      }
      final response = await apiClient.post(
        ApiConstants.aiCoachGenerate,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return CoachResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Provider for AI repository.
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepository(apiClient: ref.watch(apiClientProvider));
});
