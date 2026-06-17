import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import 'hive_service.dart';
import 'supabase_service.dart';

class SyncService {
  final HiveService _hiveService;
  final SupabaseService _supabaseService;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _currentUserId;
  VoidCallback? _onSyncCompleted;

  SyncService({
    required HiveService hiveService,
    required SupabaseService supabaseService,
  })  : _hiveService = hiveService,
        _supabaseService = supabaseService;

  void init(String userId, VoidCallback onSyncCompleted) {
    _currentUserId = userId;
    _onSyncCompleted = onSyncCompleted;
    
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _currentUserId != null) {
        syncAll(_currentUserId!);
      }
    });

    setupRealtime(userId);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _supabaseService.unsubscribe();
  }

  Future<void> syncAll(String userId) async {
    try {
      // 1. Push local changes to Supabase
      await pushLocalChanges(userId);
      // 2. Pull remote changes from Supabase
      await pullRemoteChanges(userId);
      // 3. Notify UI
      _onSyncCompleted?.call();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  Future<void> pushLocalChanges(String userId) async {
    final unsynced = _hiveService.getUnsyncedTasks(userId);
    for (final task in unsynced) {
      try {
        if (task.deletedAt != null) {
          // Sync the soft deletion
          await _supabaseService.upsertTask(task);
          // Hard delete locally since it's now synced
          await _hiveService.hardDeleteTask(task.id);
        } else {
          await _supabaseService.upsertTask(task);
          await _hiveService.saveTask(task.copyWith(synced: true));
        }
      } catch (e) {
        debugPrint('Failed to push task ${task.id}: $e');
      }
    }
  }

  Future<void> pullRemoteChanges(String userId) async {
    final remoteTasks = await _supabaseService.fetchTasks();
    for (final remote in remoteTasks) {
      final local = _hiveService.getTask(remote.id);
      
      if (remote.deletedAt != null) {
        await _hiveService.hardDeleteTask(remote.id);
      } else if (local == null) {
        await _hiveService.saveTask(remote.copyWith(synced: true));
      } else {
        // Last Write Wins
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          await _hiveService.saveTask(remote.copyWith(synced: true));
        } else if (local.updatedAt.isAfter(remote.updatedAt) && !local.synced) {
          // Local is newer and unsynced, keep it for next push
        } else {
          await _hiveService.saveTask(remote.copyWith(synced: true));
        }
      }
    }
  }

  void setupRealtime(String userId) {
    _supabaseService.subscribeToChanges((payload) async {
      final eventType = payload.eventType;
      final newRecord = payload.newRecord;
      final oldRecord = payload.oldRecord;

      if (eventType == PostgresChangeEvent.delete) {
        if (oldRecord != null && oldRecord.containsKey('id')) {
          final id = oldRecord['id'] as String;
          await _hiveService.hardDeleteTask(id);
        }
      } else if (newRecord != null && newRecord.isNotEmpty) {
        final remote = Task.fromJson(newRecord);
        if (remote.userId != userId) return;

        if (remote.deletedAt != null) {
          await _hiveService.hardDeleteTask(remote.id);
        } else {
          final local = _hiveService.getTask(remote.id);
          if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
            await _hiveService.saveTask(remote.copyWith(synced: true));
          }
        }
      }
      _onSyncCompleted?.call();
    });
  }
}
