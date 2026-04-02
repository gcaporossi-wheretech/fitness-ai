import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/network/api_exception.dart';

void main() {
  group('ApiException', () {
    test('fromDioException handles connection timeout', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('timeout'));
    });

    test('fromDioException handles connection error', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('reach server'));
    });

    test('fromDioException handles 401 bad response', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/test'),
          data: {'detail': 'Token expired'},
        ),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.statusCode, 401);
      expect(exception.detail, 'Token expired');
    });

    test('fromDioException handles 409 conflict', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 409,
          requestOptions: RequestOptions(path: '/test'),
          data: {'detail': 'Email already exists'},
        ),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.statusCode, 409);
      expect(exception.toString(), 'Email already exists');
    });

    test('fromDioException handles 500 server error', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/test'),
        ),
      );
      final exception = ApiException.fromDioException(dioError);
      expect(exception.statusCode, 500);
      expect(exception.message, contains('Server error'));
    });

    test('toString returns detail when available', () {
      const exception = ApiException(
        message: 'Generic error',
        detail: 'Specific detail',
      );
      expect(exception.toString(), 'Specific detail');
    });

    test('toString returns message when no detail', () {
      const exception = ApiException(message: 'Generic error');
      expect(exception.toString(), 'Generic error');
    });
  });
}
