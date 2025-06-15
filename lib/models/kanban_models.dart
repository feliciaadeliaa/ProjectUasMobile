// =====================================================
// KANBAN MODELS untuk Flutter App
// =====================================================

import 'package:json_annotation/json_annotation.dart';

// Board Model
class Board {
  final String id;
  final String title;
  final String description;
  final String color;
  final bool isDefault;
  final String userId;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Column> columns;

  Board({
    required this.id,
    required this.title,
    this.description = '',
    this.color = '#6366F1',
    this.isDefault = false,
    required this.userId,
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
    this.columns = const [],
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6366F1',
      isDefault: json['isDefault'] ?? false,
      userId: json['userId'] ?? '',
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      columns: (json['columns'] as List<dynamic>?)
          ?.map((col) => Column.fromJson(col as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'color': color,
      'isDefault': isDefault,
      'userId': userId,
      'settings': settings,
    };
  }
}

// Column Model
class Column {
  final String id;
  final String title;
  final String description;
  final String color;
  final int position;
  final String boardId;
  final bool isDefault;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Task> tasks;

  Column({
    required this.id,
    required this.title,
    this.description = '',
    this.color = '#6B7280',
    required this.position,
    required this.boardId,
    this.isDefault = false,
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
    this.tasks = const [],
  });

  factory Column.fromJson(Map<String, dynamic> json) {
    return Column(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6B7280',
      position: json['position'] ?? 0,
      boardId: json['boardId'] ?? '',
      isDefault: json['isDefault'] ?? false,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((task) => Task.fromJson(task as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'color': color,
      'position': position,
      'boardId': boardId,
      'isDefault': isDefault,
      'settings': settings,
    };
  }
}

// Enhanced Task Model
class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final TaskPriority priority;
  final TaskStatus status;
  final int position;
  final DateTime? dueDate;
  final double? estimatedHours;
  final double? actualHours;
  final List<String> tags;
  final List<TaskAttachment> attachments;
  final List<Todo> todos;
  final String userId;
  final String boardId;
  final String columnId;
  final String? assigneeId;
  final String? parentTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.position = 0,
    this.dueDate,
    this.estimatedHours,
    this.actualHours,
    this.tags = const [],
    this.attachments = const [],
    this.todos = const [],
    required this.userId,
    required this.boardId,
    required this.columnId,
    this.assigneeId,
    this.parentTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      completed: json['completed'] ?? false,
      priority: TaskPriority.fromString(json['priority'] ?? 'medium'),
      status: TaskStatus.fromString(json['status'] ?? 'todo'),
      position: json['position'] ?? 0,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      estimatedHours: json['estimatedHours']?.toDouble(),
      actualHours: json['actualHours']?.toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((att) => TaskAttachment.fromJson(att as Map<String, dynamic>))
          .toList() ?? [],
      todos: (json['todos'] as List<dynamic>?)
          ?.map((todo) => Todo.fromJson(todo as Map<String, dynamic>))
          .toList() ?? [],
      userId: json['userId'] ?? '',
      boardId: json['boardId'] ?? '',
      columnId: json['columnId'] ?? '',
      assigneeId: json['assigneeId'],
      parentTaskId: json['parentTaskId'],
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'completed': completed,
      'priority': priority.value,
      'status': status.value,
      'position': position,
      'dueDate': dueDate?.toIso8601String(),
      'estimatedHours': estimatedHours,
      'actualHours': actualHours,
      'tags': tags,
      'attachments': attachments.map((att) => att.toJson()).toList(),
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'userId': userId,
      'boardId': boardId,
      'columnId': columnId,
      'assigneeId': assigneeId,
      'parentTaskId': parentTaskId,
    };
  }

  // Helper methods
  double get progressPercentage {
    if (todos.isEmpty) return completed ? 1.0 : 0.0;
    final completedTodos = todos.where((todo) => todo.completed).length;
    return completedTodos / todos.length;
  }

  bool get isOverdue {
    if (dueDate == null || completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  int get completedTodosCount => todos.where((todo) => todo.completed).length;
}

// Task Priority Enum
enum TaskPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const TaskPriority(this.value);
  final String value;

  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

// Task Status Enum
enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  review('review'),
  completed('completed');

  const TaskStatus(this.value);
  final String value;

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskStatus.todo,
    );
  }
}

// Task Attachment Model
class TaskAttachment {
  final String id;
  final String name;
  final String url;
  final int size;
  final String type;
  final DateTime createdAt;

  TaskAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.type,
    required this.createdAt,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      size: json['size'] ?? 0,
      type: json['type'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'size': size,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Todo Model (Enhanced)
class Todo {
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    required this.createdAt,
    this.completedAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      completed: json['completed'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

// Comment Model
class Comment {
  final String id;
  final String content;
  final String taskId;
  final String userId;
  final String? parentCommentId;
  final List<TaskAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.content,
    required this.taskId,
    required this.userId,
    this.parentCommentId,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      parentCommentId: json['parentCommentId'],
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((att) => TaskAttachment.fromJson(att as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'taskId': taskId,
      'userId': userId,
      'parentCommentId': parentCommentId,
      'attachments': attachments.map((att) => att.toJson()).toList(),
    };
  }
}

// Label Model
class Label {
  final String id;
  final String name;
  final String color;
  final String description;
  final String userId;
  final String? boardId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Label({
    required this.id,
    required this.name,
    required this.color,
    this.description = '',
    required this.userId,
    this.boardId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      color: json['color'] ?? '#6B7280',
      description: json['description'] ?? '',
      userId: json['userId'] ?? '',
      boardId: json['boardId'],
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
      'description': description,
      'userId': userId,
      'boardId': boardId,
    };
  }
}

// Activity Log Model
class ActivityLog {
  final String id;
  final ActivityAction action;
  final EntityType entityType;
  final String entityId;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String description;
  final String userId;
  final String boardId;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValue,
    this.newValue,
    this.description = '',
    required this.userId,
    required this.boardId,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      action: ActivityAction.fromString(json['action'] ?? 'created'),
      entityType: EntityType.fromString(json['entityType'] ?? 'task'),
      entityId: json['entityId'] ?? '',
      oldValue: json['oldValue'] != null ? Map<String, dynamic>.from(json['oldValue']) : null,
      newValue: json['newValue'] != null ? Map<String, dynamic>.from(json['newValue']) : null,
      description: json['description'] ?? '',
      userId: json['userId'] ?? '',
      boardId: json['boardId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.value,
      'entityType': entityType.value,
      'entityId': entityId,
      'oldValue': oldValue,
      'newValue': newValue,
      'description': description,
      'userId': userId,
      'boardId': boardId,
    };
  }
}

// Activity Action Enum
enum ActivityAction {
  created('created'),
  updated('updated'),
  deleted('deleted'),
  moved('moved'),
  assigned('assigned'),
  completed('completed');

  const ActivityAction(this.value);
  final String value;

  static ActivityAction fromString(String value) {
    return ActivityAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => ActivityAction.created,
    );
  }
}

// Entity Type Enum
enum EntityType {
  task('task'),
  board('board'),
  column('column'),
  comment('comment');

  const EntityType(this.value);
  final String value;

  static EntityType fromString(String value) {
    return EntityType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => EntityType.task,
    );
  }
}
