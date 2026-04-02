import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/features/workout/data/workout_repository.dart';

/// Sync status for the UI indicator.
enum SyncStatus {
  synced,    // All data is synced
  pending,   // There are pending items to sync
  syncing,   // Sync is in progress
  error,     // Last sync attempt failed
  offline,   // No network connection
}

/// Service that manages offline-first sync with the backend.
/// Listens for connectivity changes, queues operations, and
/// batch-syncs when connection is available.
class SyncService extends ChangeNotifier {
  SyncService({required this.workoutRepo});

  final WorkoutRepository workoutRepo;

  SyncStatus _status = SyncStatus.synced;
  String? _lastError;
  int _pendingCount = 0;
  DateTime? _lastSyncAt;
  Timer? _periodicSync;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Initialize the sync service: listen for connectivity and start periodic sync.
  void initialize() {
    _updatePendingCount();

    // Listen for connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _pendingCount > 0) {
        syncAll();
      } else if (!hasConnection) {
        _status = SyncStatus.offline;
        notifyListeners();
      }
    });

    // Periodic sync every 5 minutes
    _periodicSync = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_pendingCount > 0) syncAll();
    });
  }

  /// Add an item to the sync queue.
  Future<void> enqueue({
    required String type,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await HiveStorage.syncQueue.put(id, {
      'type': type,
      'id': id,
      'data': data,
      'queued_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    _updatePendingCount();
  }

  /// Sync all pending items.
  Future<void> syncAll() async {
    if (_status == SyncStatus.syncing) return;

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      // Sync workout sessions
      final syncedCount = await workoutRepo.syncAllPending();

      // Process remaining queue items
      final queue = HiveStorage.syncQueue.toMap();
      int errors = 0;

      for (final entry in queue.entries) {
        final item = Map<String, dynamic>.from(entry.value);
        final attempts = (item['attempts'] ?? 0) as int;

        if (attempts >= 3) {
          // Max retries reached, remove from queue
          await HiveStorage.syncQueue.delete(entry.key);
          continue;
        }

        try {
          await _processQueueItem(item);
          await HiveStorage.syncQueue.delete(entry.key);
        } catch (_) {
          errors++;
          item['attempts'] = attempts + 1;
          await HiveStorage.syncQueue.put(entry.key, item);
        }
      }

      _lastSyncAt = DateTime.now();
      _updatePendingCount();

      if (_pendingCount == 0) {
        _status = SyncStatus.synced;
      } else if (errors > 0) {
        _status = SyncStatus.error;
        _lastError = '$errors items failed to sync';
      } else {
        _status = SyncStatus.pending;
      }
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
    }

    notifyListeners();
  }

  Future<void> _processQueueItem(Map<String, dynamic> item) async {
    // Extensible: add more sync types as needed
    final type = item['type'] as String;
    switch (type) {
      case 'session':
        // Sessions are synced via workoutRepo.syncAllPending()
        break;
      case 'plan':
        // Plan sync would go here
        break;
      default:
        break;
    }
  }

  void _updatePendingCount() {
    final unsyncedSessions = workoutRepo.getUnsyncedSessions().length;
    final queueItems = HiveStorage.syncQueue.length;
    _pendingCount = unsyncedSessions + queueItems;

    if (_status != SyncStatus.syncing) {
      _status = _pendingCount > 0 ? SyncStatus.pending : SyncStatus.synced;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _periodicSync?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}

/// Provider for the sync service singleton.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    workoutRepo: ref.watch(workoutRepositoryProvider),
  );
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
