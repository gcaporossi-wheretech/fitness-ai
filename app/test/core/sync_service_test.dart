import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/core/sync/sync_service.dart';

void main() {
  group('SyncStatus', () {
    test('all sync statuses are defined', () {
      expect(SyncStatus.values.length, 5);
      expect(SyncStatus.synced, isNotNull);
      expect(SyncStatus.pending, isNotNull);
      expect(SyncStatus.syncing, isNotNull);
      expect(SyncStatus.error, isNotNull);
      expect(SyncStatus.offline, isNotNull);
    });

    test('SyncStatus enum names are correct', () {
      expect(SyncStatus.synced.name, 'synced');
      expect(SyncStatus.pending.name, 'pending');
      expect(SyncStatus.syncing.name, 'syncing');
      expect(SyncStatus.error.name, 'error');
      expect(SyncStatus.offline.name, 'offline');
    });
  });
}
