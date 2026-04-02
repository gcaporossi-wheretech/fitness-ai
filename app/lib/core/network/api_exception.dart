import 'package:dio/dio.dart';

/// Structured API exception with user-friendly messages.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.detail,
  });

  /// Create from a Dio exception.
  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Connection timeout. Check your internet.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Cannot reach server. Check your connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        String detail = '';
        if (data is Map<String, dynamic>) {
          detail = (data['detail'] ?? data['message'] ?? '').toString();
        }
        return ApiException(
          message: _messageForStatus(statusCode),
          statusCode: statusCode,
          detail: detail.isNotEmpty ? detail : null,
        );
      default:
        return ApiException(
          message: e.message ?? 'An unexpected error occurred.',
        );
    }
  }

  final String message;
  final int? statusCode;
  final String? detail;

  static String _messageForStatus(int? code) {
    switch (code) {
      case 400:
        return 'Invalid request.';
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        return 'You do not have permission.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict with existing data.';
      case 422:
        return 'Invalid data provided.';
      case 429:
        return 'Too many requests. Please wait.';
      case 500:
        return 'Server error. Try again later.';
      default:
        return 'An unexpected error occurred.';
    }
  }

  @override
  String toString() => detail ?? message;
}
