import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/network/api_exception.dart';

/// Repository for analytics data from the analytics service.
class AnalyticsRepository {
  AnalyticsRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Fetch weight progress for an exercise.
  Future<List<Map<String, dynamic>>> fetchProgress({
    String? exerciseName,
    int days = 90,
  }) async {
    try {
      final response = await apiClient.get(
        ApiConstants.analyticsProgress,
        queryParameters: {
          if (exerciseName != null) 'exercise_name': exerciseName,
          'days': days,
        },
      );
      return ((response.data as Map<String, dynamic>)['data'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Fetch volume by muscle group.
  Future<Map<String, double>> fetchVolume({int days = 30}) async {
    try {
      final response = await apiClient.get(
        ApiConstants.analyticsVolume,
        queryParameters: {'days': days},
      );
      final data = (response.data as Map<String, dynamic>)['data'];
      if (data is Map) {
        return data.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Fetch workout adherence (sessions per week).
  Future<Map<String, dynamic>> fetchAdherence({int weeks = 8}) async {
    try {
      final response = await apiClient.get(
        ApiConstants.analyticsAdherence,
        queryParameters: {'weeks': weeks},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Provider for analytics repository.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(apiClient: ref.watch(apiClientProvider));
});
