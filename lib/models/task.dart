import 'package:hive/hive.dart';

enum TaskCategory { trabajo, personal, estudio, urgente }

enum TaskPriority { alta, media, baja }

class Task {
  final String id;
  final String userId;
  String title;
  String description;
  TaskCategory category;
  TaskPriority priority;
  DateTime dueDate;
  bool isCompleted;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  bool synced;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.category,
    required this.priority,
    required this.dueDate,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.synced = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? synced,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category.name,
      'priority': priority.name,
      'completed': isCompleted,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'synced': synced,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: TaskCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => TaskCategory.personal,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.media,
      ),
      isCompleted: json['completed'] as bool? ?? false,
      dueDate: DateTime.parse(json['due_date'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      synced: json['synced'] as bool? ?? true,
    );
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final map = Map<String, dynamic>.from(reader.readMap());
    return Task.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeMap(obj.toJson());
  }
}