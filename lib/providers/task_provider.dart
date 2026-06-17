import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../services/sync_service.dart';

enum StatusFilter { todas, pendientes, completadas }

class TaskProvider extends ChangeNotifier {
  final TaskRepository _repository;
  final SyncService _syncService;
  
  String? _userId;
  List<Task> _tasks = [];
  bool _isSyncing = false;
  DateTime? _lastSyncAt;

  TaskCategory? _categoryFilter; // null = todas las categorías
  StatusFilter _statusFilter = StatusFilter.todas;

  TaskProvider({
    required TaskRepository repository,
    required SyncService syncService,
  })  : _repository = repository,
        _syncService = syncService;

  TaskCategory? get categoryFilter => _categoryFilter;
  StatusFilter get statusFilter => _statusFilter;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get userId => _userId;

  void updateUser(String? newUserId) {
    if (_userId == newUserId) return;
    _userId = newUserId;

    if (_userId != null) {
      // Cargar tareas locales inmediatamente
      _tasks = _repository.getTasks(_userId!);
      notifyListeners();
      
      // Inicializar servicio de sincronización y configurar callback
      _syncService.init(_userId!, () {
        if (_userId != null) {
          _tasks = _repository.getTasks(_userId!);
          _lastSyncAt = DateTime.now();
          _isSyncing = false;
          notifyListeners();
        }
      });

      // Sincronizar en segundo plano
      syncTasks();
    } else {
      _tasks = [];
      _syncService.dispose();
      notifyListeners();
    }
  }

  Future<void> syncTasks() async {
    if (_userId == null || _isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();
    
    await _repository.sync(_userId!);
    
    if (_userId != null) {
      _tasks = _repository.getTasks(_userId!);
      _lastSyncAt = DateTime.now();
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Lista completa, sin filtrar
  List<Task> get tasks => List.unmodifiable(_tasks);

  // Lista filtrada que muestra el Dashboard
  List<Task> get filteredTasks {
    return _tasks.where((t) {
      final matchCategory =
          _categoryFilter == null || t.category == _categoryFilter;
      final matchStatus = switch (_statusFilter) {
        StatusFilter.todas => true,
        StatusFilter.pendientes => !t.isCompleted,
        StatusFilter.completadas => t.isCompleted,
      };
      return matchCategory && matchStatus;
    }).toList();
  }

  void setCategoryFilter(TaskCategory? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setStatusFilter(StatusFilter status) {
    _statusFilter = status;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    if (_userId == null) return;
    await _repository.createTask(task);
    _tasks = _repository.getTasks(_userId!);
    notifyListeners();
  }

  Future<void> updateTask(Task updated) async {
    if (_userId == null) return;
    await _repository.updateTask(updated);
    _tasks = _repository.getTasks(_userId!);
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    if (_userId == null) return;
    await _repository.deleteTask(id, _userId!);
    _tasks = _repository.getTasks(_userId!);
    notifyListeners();
  }

  Future<void> toggleComplete(String id) async {
    if (_userId == null) return;
    await _repository.toggleComplete(id, _userId!);
    _tasks = _repository.getTasks(_userId!);
    notifyListeners();
  }
}