import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/auth/domain/user.dart';

void main() {
  group('User', () {
    final testJson = {
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'email': 'test@example.com',
      'name': 'Test User',
      'age': 30,
      'goals': {'build_muscle': true},
      'limitations': null,
      'ai_credits': 10,
      'language': 'it',
      'created_at': '2026-01-01T00:00:00.000Z',
    };

    test('fromJson creates user correctly', () {
      final user = User.fromJson(testJson);

      expect(user.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.age, 30);
      expect(user.aiCredits, 10);
      expect(user.language, 'it');
    });

    test('toJson produces valid map', () {
      final user = User.fromJson(testJson);
      final json = user.toJson();

      expect(json['id'], user.id);
      expect(json['email'], user.email);
      expect(json['ai_credits'], user.aiCredits);
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {
        'id': 'abc-123',
        'email': 'minimal@example.com',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final user = User.fromJson(minimalJson);
      expect(user.name, isNull);
      expect(user.age, isNull);
      expect(user.aiCredits, 0);
      expect(user.language, 'it');
    });

    test('copyWith updates specified fields', () {
      final user = User.fromJson(testJson);
      final updated = user.copyWith(name: 'New Name', aiCredits: 20);

      expect(updated.name, 'New Name');
      expect(updated.aiCredits, 20);
      expect(updated.email, user.email); // unchanged
    });

    test('fromJson roundtrip preserves data', () {
      final user = User.fromJson(testJson);
      final json = user.toJson();
      final restored = User.fromJson(json);

      expect(restored.id, user.id);
      expect(restored.email, user.email);
      expect(restored.name, user.name);
      expect(restored.aiCredits, user.aiCredits);
    });
  });
}
