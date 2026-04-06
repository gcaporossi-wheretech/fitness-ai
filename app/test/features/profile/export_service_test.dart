import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/features/profile/data/export_service.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApi;
  late ExportService service;

  setUp(() {
    mockApi = MockApiClient();
    service = ExportService(mockApi);
  });

  group('exportAsJson', () {
    test('returns structured JSON with profile, plans, and sessions', () async {
      when(() => mockApi.get('/auth/me')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'id': 'user-1', 'email': 'test@example.com', 'name': 'Test'},
        ),
      );
      when(() => mockApi.get('/workouts/plans?per_page=100')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'items': [
              {'id': 'plan-1', 'name': 'Push Pull'},
            ],
          },
        ),
      );
      when(() => mockApi.get('/workouts/sessions?per_page=500')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'items': [
              {
                'id': 'session-1',
                'started_at': '2026-01-01T10:00:00Z',
                'exercises': [],
              },
            ],
          },
        ),
      );

      final jsonStr = await service.exportAsJson();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(parsed['export_version'], '1.0');
      expect(parsed['exported_at'], isNotNull);
      expect(parsed['profile']['email'], 'test@example.com');
      expect((parsed['workout_plans'] as List).length, 1);
      expect((parsed['workout_sessions'] as List).length, 1);
    });

    test('handles empty data gracefully', () async {
      when(() => mockApi.get('/auth/me')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'id': 'user-1', 'email': 'test@example.com'},
        ),
      );
      when(() => mockApi.get('/workouts/plans?per_page=100')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'items': []},
        ),
      );
      when(() => mockApi.get('/workouts/sessions?per_page=500')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'items': []},
        ),
      );

      final jsonStr = await service.exportAsJson();
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect((parsed['workout_plans'] as List), isEmpty);
      expect((parsed['workout_sessions'] as List), isEmpty);
    });
  });

  group('exportSessionsCsv', () {
    test('returns CSV with header and session rows', () async {
      when(() => mockApi.get('/workouts/sessions?per_page=500')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'items': [
              {
                'started_at': '2026-01-01T10:00:00Z',
                'day_name': 'Push Day',
                'duration_seconds': 3600,
                'exercises': [
                  {
                    'name': 'Bench Press',
                    'sets': [
                      {'reps': 10, 'weight_kg': 80},
                      {'reps': 8, 'weight_kg': 85},
                    ],
                  },
                ],
                'notes': null,
              },
            ],
          },
        ),
      );

      final csv = await service.exportSessionsCsv();
      final lines = csv.trim().split('\n');

      expect(lines.length, 2); // header + 1 row
      expect(lines[0], contains('date'));
      expect(lines[0], contains('total_volume_kg'));
      expect(lines[1], contains('Push Day'));
      expect(lines[1], contains('60')); // 3600s = 60min
    });

    test('calculates volume correctly', () async {
      when(() => mockApi.get('/workouts/sessions?per_page=500')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'items': [
              {
                'started_at': '2026-01-01T10:00:00Z',
                'day_name': 'Legs',
                'duration_seconds': 1800,
                'exercises': [
                  {
                    'name': 'Squat',
                    'sets': [
                      {'reps': 5, 'weight_kg': 100}, // 500
                      {'reps': 5, 'weight_kg': 100}, // 500
                    ],
                  },
                ],
                'notes': '',
              },
            ],
          },
        ),
      );

      final csv = await service.exportSessionsCsv();
      // Volume = 5*100 + 5*100 = 1000
      expect(csv, contains('1000.0'));
    });

    test('handles empty sessions', () async {
      when(() => mockApi.get('/workouts/sessions?per_page=500')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'items': []},
        ),
      );

      final csv = await service.exportSessionsCsv();
      final lines = csv.trim().split('\n');

      expect(lines.length, 1); // header only
    });

    test('escapes CSV fields with commas', () async {
      when(() => mockApi.get('/workouts/sessions?per_page=500')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'items': [
              {
                'started_at': '2026-01-01T10:00:00Z',
                'day_name': 'Push, Pull',
                'duration_seconds': 60,
                'exercises': [],
                'notes': 'Good session, felt strong',
              },
            ],
          },
        ),
      );

      final csv = await service.exportSessionsCsv();
      expect(csv, contains('"Push, Pull"'));
      expect(csv, contains('"Good session, felt strong"'));
    });
  });
}
