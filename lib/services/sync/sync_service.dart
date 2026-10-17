import 'dart:async';
import '../../models/reading_model.dart';
import '../storage/database_service.dart';

/// Sync service simulating background network synchronization and offline queue (FR-35, FR-37).
class SyncService {
  final DatabaseService _db = DatabaseService.instance;
  bool _isOnline = true;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  void setOnlineMode(bool online) {
    _isOnline = online;
  }

  /// Triggers synchronization of all unsynced local readings
  Future<int> syncPendingReadings({void Function()? onProgress}) async {
    if (!_isOnline) return 0;
    if (_isSyncing) return 0;

    _isSyncing = true;
    int syncedCount = 0;

    final pending = _db.readings.where(
      (r) => r.syncStatus == SyncStatus.savedOffline || r.syncStatus == SyncStatus.failed,
    ).toList();

    for (final reading in pending) {
      // Simulate network request latency
      await Future.delayed(const Duration(milliseconds: 300));

      final updated = reading.copyWith(
        syncStatus: SyncStatus.synced,
        syncedAt: DateTime.now(),
      );
      await _db.saveReading(updated);
      syncedCount++;
      onProgress?.call();
    }

    _isSyncing = false;
    return syncedCount;
  }
}
