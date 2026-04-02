import 'package:dio/dio.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/token_storage.dart';

/// Dio interceptor that attaches JWT access token to every request
/// and handles automatic token refresh on 401 responses.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;
  bool _isRefreshing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for login/register/refresh endpoints
    final noAuthPaths = [
      ApiConstants.authLogin,
      ApiConstants.authRegister,
      ApiConstants.authRefresh,
    ];
    if (noAuthPaths.any((path) => options.path.contains(path))) {
      return handler.next(options);
    }

    final token = await tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        await tokenStorage.clearTokens();
        return handler.next(err);
      }

      // Attempt token refresh
      final response = await dio.post(
        ApiConstants.authRefresh,
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await tokenStorage.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );

        // Retry the original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] =
            'Bearer ${data['access_token']}';
        final retryResponse = await dio.fetch(opts);
        return handler.resolve(retryResponse);
      }
    } catch (_) {
      // Refresh failed — clear tokens and propagate error
      await tokenStorage.clearTokens();
    } finally {
      _isRefreshing = false;
    }

    return handler.next(err);
  }
}
