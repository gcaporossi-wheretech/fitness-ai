import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/network/api_exception.dart';
import 'package:fitness_ai/features/ai/domain/ai_job.dart';
import 'package:fitness_ai/features/ai/domain/coach_result.dart';

/// Repository for AI operations (vision scan, coach generation).
/// All AI operations are async: submit job, poll for result.
class AIRepository {
  AIRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Submit a vision scan image for equipment recognition.
  Future<AIJob> submitVisionScan({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });
      final response = await apiClient.post(
        ApiConstants.aiVisionScan,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = response.data as Map<String, dynamic>;
      return AIJob(
        jobId: data['job_id'] as String,
        jobType: 'vision_scan',
        status: (data['status'] ?? 'pending') as String,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Submit a coach generation request.
  Future<AIJob> submitCoachGeneration() async {
    try {
      final response = await apiClient.post(ApiConstants.aiCoachGenerate);
      final data = response.data as Map<String, dynamic>;
      return AIJob(
        jobId: data['job_id'] as String,
        jobType: 'coach_generate',
        status: (data['status'] ?? 'pending') as String,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Poll job status. Returns the job with current status and result.
  Future<AIJob> getJobStatus(String jobId) async {
    try {
      final response = await apiClient.get('/ai/jobs/$jobId');
      return AIJob.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Poll until job completes or fails (max attempts).
  /// Returns the completed job or throws on timeout/failure.
  Future<AIJob> pollUntilComplete(String jobId, {int maxAttempts = 60}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final job = await getJobStatus(jobId);
      if (job.isCompleted || job.isFailed) return job;
    }
    throw const ApiException(message: 'Job timed out after 2 minutes.');
  }

  /// Parse a coach result from a completed job.
  CoachResult parseCoachResult(AIJob job) {
    if (job.result == null) {
      throw const ApiException(message: 'Job has no result.');
    }
    return CoachResult.fromJson(job.result!);
  }
}

/// Provider for AI repository.
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepository(apiClient: ref.watch(apiClientProvider));
});
