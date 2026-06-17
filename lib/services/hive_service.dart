import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';

class HiveService {
  static const String _boxName = 'tasks_box';

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }
    await Hive.openBox<Task>(_boxName);
  }

  Box<Task> get _box => Hive.box<Task>(_boxName);

  List<Task> getTasks(String userId) {
    return _box.values
        .where((task) => task.userId == userId && task.deletedAt == null)
        .toList();
  }

  List<Task> getUnsyncedTasks(String userId) {
    return _box.values
        .where((task) => task.userId == userId && !task.synced)
        .toList();
  }

  Task? getTask(String id) {
    return _box.get(id);
  }

  Future<void> saveTask(Task task) async {
    await _box.put(task.id, task);
  }

  Future<void> saveTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return;
    final Map<String, Task> taskMap = {for (var t in tasks) t.id: t};
    await _box.putAll(taskMap);
  }

  Future<void> deleteTask(String id) async {
    final task = _box.get(id);
    if (task != null) {
      if (task.deletedAt != null) return;
      
      final updated = task.copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        synced: false,
      );
      await _box.put(id, updated);
    }
  }

  Future<void> hardDeleteTask(String id) async {
    await _box.delete(id);
  }

  Future<void> clearUserTasks(String userId) async {
    final keysToDelete = _box.values
        .where((task) => task.userId == userId)
        .map((task) => task.id)
        .toList();
    await _box.deleteAll(keysToDelete);
  }
}
