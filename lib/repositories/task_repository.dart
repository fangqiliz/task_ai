import '../models/task.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

class TaskRepository {
  final HiveService _hiveService;
  final SyncService _syncService;

  TaskRepository({
    required HiveService hiveService,
    required SyncService syncService,
  })  : _hiveService = hiveService,
        _syncService = syncService;

  List<Task> getTasks(String userId) {
    return _hiveService.getTasks(userId);
  }

  Future<void> createTask(Task task) async {
    final offlineTask = task.copyWith(synced: false);
    await _hiveService.saveTask(offlineTask);
    // Background push
    _syncService.pushLocalChanges(task.userId);
  }

  Future<void> updateTask(Task task) async {
    final offlineTask = task.copyWith(
      synced: false,
      updatedAt: DateTime.now(),
    );
    await _hiveService.saveTask(offlineTask);
    // Background push
    _syncService.pushLocalChanges(task.userId);
  }

  Future<void> deleteTask(String id, String userId) async {
    await _hiveService.deleteTask(id);
    // Background push
    _syncService.pushLocalChanges(userId);
  }

  Future<void> toggleComplete(String id, String userId) async {
    final task = _hiveService.getTask(id);
    if (task != null) {
      final updated = task.copyWith(
        isCompleted: !task.isCompleted,
        updatedAt: DateTime.now(),
        synced: false,
      );
      await _hiveService.saveTask(updated);
      _syncService.pushLocalChanges(userId);
    }
  }

  Future<void> sync(String userId) async {
    await _syncService.syncAll(userId);
  }
}
