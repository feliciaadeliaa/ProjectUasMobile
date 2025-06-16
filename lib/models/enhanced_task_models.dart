// =====================================================
// ENHANCED TASK MODELS WITH ADDITIONAL FEATURES
// =====================================================

import 'task.dart';

// Task Category Model
class TaskCategory {
  final String id;
  final String name;
  final String description;
  final String color;
  final String icon;
  final String userId;
  final bool isDefault;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '#6366F1',
    this.icon = 'category',
    required this.userId,
    this.isDefault = false,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskCategory.fromJson(Map<String, dynamic> json) {
    return TaskCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6366F1',
      icon: json['icon'] ?? 'category',
      userId: json['userId'] ?? '',
      isDefault: json['isDefault'] ?? false,
      position: json['position'] ?? 0,
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'userId': userId,
      'isDefault': isDefault,
      'position': position,
    };
  }
}

// Task Label Model
class TaskLabel {
  final String id;
  final String name;
  final String color;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskLabel({
    required this.id,
    required this.name,
    this.color = '#6B7280',
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskLabel.fromJson(Map<String, dynamic> json) {
    return TaskLabel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      color: json['color'] ?? '#6B7280',
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'color': color,
      'userId': userId,
    };
  }
}

// Enhanced Task Model
class EnhancedTask extends Task {
  final String? categoryId;
  final TaskPriority priority;
  final DateTime? dueDate;
  final double estimatedHours;
  final double actualHours;
  final TaskStatus status;
  final String? assigneeId;
  final double position;
  final List<TaskLabel> labels;
  final List<TaskComment> comments;
  final List<TaskAttachment> attachments;
  final List<TaskReminder> reminders;
  final List<TimeEntry> timeEntries;

  EnhancedTask({
    required super.id,
    required super.title,
    super.description = '',
    super.completed = false,
    super.userId = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    super.todos = const [],
    this.categoryId,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.estimatedHours = 0,
    this.actualHours = 0,
    this.status = TaskStatus.todo,
    this.assigneeId,
    this.position = 0,
    this.labels = const [],
    this.comments = const [],
    this.attachments = const [],
    this.reminders = const [],
    this.timeEntries = const [],
  }) : super(
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );

  factory EnhancedTask.fromJson(Map<String, dynamic> json) {
    return EnhancedTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      completed: json['completed'] ?? false,
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      todos: (json['todos'] as List<dynamic>?)
          ?.map((todo) => Todo.fromJson(todo as Map<String, dynamic>))
          .toList() ?? [],
      categoryId: json['categoryId'],
      priority: TaskPriority.fromString(json['priority'] ?? 'medium'),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      estimatedHours: (json['estimatedHours'] ?? 0).toDouble(),
      actualHours: (json['actualHours'] ?? 0).toDouble(),
      status: TaskStatus.fromString(json['status'] ?? 'todo'),
      assigneeId: json['assigneeId'],
      position: (json['position'] ?? 0).toDouble(),
      labels: (json['labels'] as List<dynamic>?)
          ?.map((label) => TaskLabel.fromJson(label as Map<String, dynamic>))
          .toList() ?? [],
      comments: (json['comments'] as List<dynamic>?)
          ?.map((comment) => TaskComment.fromJson(comment as Map<String, dynamic>))
          .toList() ?? [],
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((attachment) => TaskAttachment.fromJson(attachment as Map<String, dynamic>))
          .toList() ?? [],
      reminders: (json['reminders'] as List<dynamic>?)
          ?.map((reminder) => TaskReminder.fromJson(reminder as Map<String, dynamic>))
          .toList() ?? [],
      timeEntries: (json['timeEntries'] as List<dynamic>?)
          ?.map((entry) => TimeEntry.fromJson(entry as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'categoryId': categoryId,
      'priority': priority.value,
      'dueDate': dueDate?.toIso8601String(),
      'estimatedHours': estimatedHours,
      'actualHours': actualHours,
      'status': status.value,
      'assigneeId': assigneeId,
      'position': position,
    });
    return json;
  }

  // Helper methods
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !completed;
  bool get isDueToday => dueDate != null && 
    dueDate!.year == DateTime.now().year &&
    dueDate!.month == DateTime.now().month &&
    dueDate!.day == DateTime.now().day;
  bool get isDueSoon => dueDate != null && 
    dueDate!.isAfter(DateTime.now()) &&
    dueDate!.isBefore(DateTime.now().add(const Duration(days: 3)));
  
  double get progressPercentage {
    if (todos.isEmpty) return completed ? 100 : 0;
    final completedTodos = todos.where((todo) => todo.completed).length;
    return (completedTodos / todos.length) * 100;
  }

  Duration get totalTimeSpent {
    return timeEntries.fold(Duration.zero, (total, entry) => 
      total + Duration(seconds: entry.duration));
  }
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

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

// Task Status Enum
enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  review('review'),
  done('done');

  const TaskStatus(this.value);
  final String value;

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskStatus.todo,
    );
  }

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.review:
        return 'Review';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

// Task Comment Model
class TaskComment {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final String? parentId;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    this.parentId,
    this.isEdited = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    return TaskComment(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      parentId: json['parentId'],
      isEdited: json['isEdited'] ?? false,
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'userId': userId,
      'content': content,
      'parentId': parentId,
      'isEdited': isEdited,
    };
  }
}

// Task Attachment Model
class TaskAttachment {
  final String id;
  final String taskId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final String filePath;
  final String uploadedBy;
  final DateTime createdAt;

  TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    this.fileSize = 0,
    this.fileType = '',
    required this.filePath,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      fileType: json['fileType'] ?? '',
      filePath: json['filePath'] ?? '',
      uploadedBy: json['uploadedBy'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileType': fileType,
      'filePath': filePath,
      'uploadedBy': uploadedBy,
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// Task Reminder Model
class TaskReminder {
  final String id;
  final String taskId;
  final String userId;
  final DateTime reminderTime;
  final ReminderType type;
  final String message;
  final bool isTriggered;
  final DateTime createdAt;

  TaskReminder({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.reminderTime,
    this.type = ReminderType.notification,
    this.message = '',
    this.isTriggered = false,
    required this.createdAt,
  });

  factory TaskReminder.fromJson(Map<String, dynamic> json) {
    return TaskReminder(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      reminderTime: DateTime.parse(json['reminderTime'] ?? DateTime.now().toIso8601String()),
      type: ReminderType.fromString(json['type'] ?? 'notification'),
      message: json['message'] ?? '',
      isTriggered: json['isTriggered'] ?? false,
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'userId': userId,
      'reminderTime': reminderTime.toIso8601String(),
      'type': type.value,
      'message': message,
      'isTriggered': isTriggered,
    };
  }
}

// Reminder Type Enum
enum ReminderType {
  notification('notification'),
  email('email');

  const ReminderType(this.value);
  final String value;

  static ReminderType fromString(String value) {
    return ReminderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ReminderType.notification,
    );
  }
}

// Time Entry Model
class TimeEntry {
  final String id;
  final String taskId;
  final String userId;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final int duration; // in seconds
  final bool isRunning;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeEntry({
    required this.id,
    required this.taskId,
    required this.userId,
    this.description = '',
    required this.startTime,
    this.endTime,
    this.duration = 0,
    this.isRunning = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      duration: json['duration'] ?? 0,
      isRunning: json['isRunning'] ?? false,
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'userId': userId,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration,
      'isRunning': isRunning,
    };
  }

  String get durationFormatted {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

// Notification Model
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String entityType;
  final String entityId;
  final bool isRead;
  final String actionUrl;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.entityType = '',
    this.entityId = '',
    this.isRead = false,
    this.actionUrl = '',
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: NotificationType.fromString(json['type'] ?? 'info'),
      entityType: json['entityType'] ?? '',
      entityId: json['entityId'] ?? '',
      isRead: json['isRead'] ?? false,
      actionUrl: json['actionUrl'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.value,
      'entityType': entityType,
      'entityId': entityId,
      'isRead': isRead,
      'actionUrl': actionUrl,
    };
  }
}

// Notification Type Enum
enum NotificationType {
  info('info'),
  success('success'),
  warning('warning'),
  error('error');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.info,
    );
  }
}

// User Settings Model
class UserSettings {
  final String id;
  final String userId;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool taskReminders;
  final bool weeklyDigest;
  final String theme;
  final String language;
  final String timezone;
  final String dateFormat;
  final String timeFormat;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    required this.id,
    required this.userId,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.taskReminders = true,
    this.weeklyDigest = true,
    this.theme = 'light',
    this.language = 'en',
    this.timezone = 'UTC',
    this.dateFormat = 'DD/MM/YYYY',
    this.timeFormat = '24h',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      emailNotifications: json['emailNotifications'] ?? true,
      pushNotifications: json['pushNotifications'] ?? true,
      taskReminders: json['taskReminders'] ?? true,
      weeklyDigest: json['weeklyDigest'] ?? true,
      theme: json['theme'] ?? 'light',
      language: json['language'] ?? 'en',
      timezone: json['timezone'] ?? 'UTC',
      dateFormat: json['dateFormat'] ?? 'DD/MM/YYYY',
      timeFormat: json['timeFormat'] ?? '24h',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'taskReminders': taskReminders,
      'weeklyDigest': weeklyDigest,
      'theme': theme,
      'language': language,
      'timezone': timezone,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
    };
  }
}
