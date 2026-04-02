import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/auth_interceptor.dart';
import 'package:fitness_ai/core/network/token_storage.dart';

/// Central HTTP client for all API calls.
/// Configured with auth interceptor for automatic JWT handling.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiConstants.devBaseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(AuthInterceptor(
      dio: _dio,
      tokenStorage: tokenStorage,
    ));
  }

  final Dio _dio;

  /// Access the underlying Dio instance for advanced use cases.
  Dio get dio => _dio;

  /// GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(path,
        queryParameters: queryParameters, options: options);
  }

  /// POST request.
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  /// PATCH request.
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _dio.patch<T>(path, data: data, options: options);
  }

  /// DELETE request.
  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) {
    return _dio.delete<T>(path, options: options);
  }
}

/// Provider for the API client singleton.
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage: tokenStorage);
});
