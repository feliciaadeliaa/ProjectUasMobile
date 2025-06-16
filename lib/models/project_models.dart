// =====================================================
// PROJECT-BASED KANBAN MODELS
// =====================================================

import 'task.dart'; // Import existing Task model

// Project Model (Top Level)
class Project {
  final String id;
  final String name;
  final String description;
  final String color;
  final String icon;
  final bool isArchived;
  final Map<String, dynamic> settings;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Board> boards;
  final List<ProjectMember> members;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '#6366F1',
    this.icon = 'folder',
    this.isArchived = false,
    this.settings = const {},
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.boards = const [],
    this.members = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6366F1',
      icon: json['icon'] ?? 'folder',
      isArchived: json['isArchived'] ?? false,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      boards: (json['boards'] as List<dynamic>?)
          ?.map((board) => Board.fromJson(board as Map<String, dynamic>))
          .toList() ?? [],
      members: (json['members'] as List<dynamic>?)
          ?.map((member) => ProjectMember.fromJson(member as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'isArchived': isArchived,
      'settings': settings,
      'userId': userId,
    };
  }

  // Helper methods
  int get totalTasks => boards.fold(0, (sum, board) => sum + board.totalTasks);
  int get completedTasks => boards.fold(0, (sum, board) => sum + board.completedTasks);
  double get completionPercentage => totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;
  Board? get defaultBoard => boards.where((board) => board.isDefault).firstOrNull;
}

// Board Model (Enhanced)
class Board {
  final String id;
  final String name;
  final String description;
  final String color;
  final BoardType type;
  final bool isDefault;
  final bool isArchived;
  final int position;
  final Map<String, dynamic> settings;
  final String projectId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BoardColumn> columns;

  Board({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '#6366F1',
    this.type = BoardType.kanban,
    this.isDefault = false,
    this.isArchived = false,
    this.position = 0,
    this.settings = const {},
    required this.projectId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.columns = const [],
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6366F1',
      type: BoardType.fromString(json['type'] ?? 'kanban'),
      isDefault: json['isDefault'] ?? false,
      isArchived: json['isArchived'] ?? false,
      position: json['position'] ?? 0,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      projectId: json['projectId'] ?? '',
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      columns: (json['columns'] as List<dynamic>?)
          ?.map((col) => BoardColumn.fromJson(col as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'type': type.value,
      'isDefault': isDefault,
      'isArchived': isArchived,
      'position': position,
      'settings': settings,
      'projectId': projectId,
      'userId': userId,
    };
  }

  // Helper methods
  int get totalTasks => columns.fold(0, (sum, column) => sum + column.tasks.length);
  int get completedTasks => columns.fold(0, (sum, column) => 
    sum + column.tasks.where((task) => task.completed).length);
}

// Board Type Enum
enum BoardType {
  kanban('kanban'),
  scrum('scrum'),
  calendar('calendar');

  const BoardType(this.value);
  final String value;

  static BoardType fromString(String value) {
    return BoardType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => BoardType.kanban,
    );
  }
}

// Board Column Model (Enhanced)
class BoardColumn {
  final String id;
  final String name;
  final String description;
  final String color;
  final int position;
  final int? wipLimit;
  final bool isCollapsed;
  final Map<String, dynamic> settings;
  final String boardId;
  final String projectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Task> tasks;

  BoardColumn({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '#6B7280',
    required this.position,
    this.wipLimit,
    this.isCollapsed = false,
    this.settings = const {},
    required this.boardId,
    required this.projectId,
    required this.createdAt,
    required this.updatedAt,
    this.tasks = const [],
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#6B7280',
      position: json['position'] ?? 0,
      wipLimit: json['wipLimit'],
      isCollapsed: json['isCollapsed'] ?? false,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      boardId: json['boardId'] ?? '',
      projectId: json['projectId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((task) => Task.fromJson(task as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'position': position,
      'wipLimit': wipLimit,
      'isCollapsed': isCollapsed,
      'settings': settings,
      'boardId': boardId,
      'projectId': projectId,
    };
  }

  // Helper methods
  bool get isWipLimitExceeded => wipLimit != null && tasks.length > wipLimit!;
  int get completedTasksCount => tasks.where((task) => task.completed).length;
}

// Enhanced Task Model (extends existing)
class ProjectTask extends Task {
  final String projectId;
  final String boardId;
  final String columnId;
  final String? assigneeId;
  final String? parentTaskId;
  final DateTime? startDate;
  final Map<String, dynamic> customFields;

  ProjectTask({
    required super.id,
    required super.title,
    super.description = '',
    super.completed = false,
    super.userId = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    super.todos = const [],
    required this.projectId,
    required this.boardId,
    required this.columnId,
    this.assigneeId,
    this.parentTaskId,
    this.startDate,
    this.customFields = const {},
  }) : super(
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );

  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    return ProjectTask(
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
      projectId: json['projectId'] ?? '',
      boardId: json['boardId'] ?? '',
      columnId: json['columnId'] ?? '',
      assigneeId: json['assigneeId'],
      parentTaskId: json['parentTaskId'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      customFields: Map<String, dynamic>.from(json['customFields'] ?? {}),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'projectId': projectId,
      'boardId': boardId,
      'columnId': columnId,
      'assigneeId': assigneeId,
      'parentTaskId': parentTaskId,
      'startDate': startDate?.toIso8601String(),
      'customFields': customFields,
    });
    return json;
  }
}

// Project Member Model
class ProjectMember {
  final String id;
  final String projectId;
  final String userId;
  final ProjectRole role;
  final Map<String, dynamic> permissions;
  final String? invitedBy;
  final DateTime joinedAt;
  final bool isActive;

  ProjectMember({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.role,
    this.permissions = const {},
    this.invitedBy,
    required this.joinedAt,
    this.isActive = true,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      userId: json['userId'] ?? '',
      role: ProjectRole.fromString(json['role'] ?? 'member'),
      permissions: Map<String, dynamic>.from(json['permissions'] ?? {}),
      invitedBy: json['invitedBy'],
      joinedAt: DateTime.parse(json['joinedAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'userId': userId,
      'role': role.value,
      'permissions': permissions,
      'invitedBy': invitedBy,
      'isActive': isActive,
    };
  }
}

// Project Role Enum
enum ProjectRole {
  owner('owner'),
  admin('admin'),
  member('member'),
  viewer('viewer');

  const ProjectRole(this.value);
  final String value;

  static ProjectRole fromString(String value) {
    return ProjectRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ProjectRole.member,
    );
  }
}

// Project Template Model
class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final TemplateCategory category;
  final String icon;
  final bool isPublic;
  final Map<String, dynamic> template;
  final String? userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.category = TemplateCategory.general,
    this.icon = 'template',
    this.isPublic = true,
    required this.template,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectTemplate.fromJson(Map<String, dynamic> json) {
    return ProjectTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: TemplateCategory.fromString(json['category'] ?? 'general'),
      icon: json['icon'] ?? 'template',
      isPublic: json['isPublic'] ?? true,
      template: Map<String, dynamic>.from(json['template'] ?? {}),
      userId: json['userId'],
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category.value,
      'icon': icon,
      'isPublic': isPublic,
      'template': template,
      'userId': userId,
    };
  }
}

// Template Category Enum
enum TemplateCategory {
  software('software'),
  marketing('marketing'),
  design('design'),
  general('general');

  const TemplateCategory(this.value);
  final String value;

  static TemplateCategory fromString(String value) {
    return TemplateCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => TemplateCategory.general,
    );
  }
}

// Activity Log Model (Enhanced)
class ActivityLog {
  final String id;
  final ActivityAction action;
  final EntityType entityType;
  final String entityId;
  final String? entityName;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String description;
  final String projectId;
  final String? boardId;
  final String userId;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.oldValue,
    this.newValue,
    this.description = '',
    required this.projectId,
    this.boardId,
    required this.userId,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      action: ActivityAction.fromString(json['action'] ?? 'created'),
      entityType: EntityType.fromString(json['entityType'] ?? 'task'),
      entityId: json['entityId'] ?? '',
      entityName: json['entityName'],
      oldValue: json['oldValue'] != null ? Map<String, dynamic>.from(json['oldValue']) : null,
      newValue: json['newValue'] != null ? Map<String, dynamic>.from(json['newValue']) : null,
      description: json['description'] ?? '',
      projectId: json['projectId'] ?? '',
      boardId: json['boardId'],
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.value,
      'entityType': entityType.value,
      'entityId': entityId,
      'entityName': entityName,
      'oldValue': oldValue,
      'newValue': newValue,
      'description': description,
      'projectId': projectId,
      'boardId': boardId,
      'userId': userId,
    };
  }
}

// Activity Action Enum (Enhanced)
enum ActivityAction {
  created('created'),
  updated('updated'),
  deleted('deleted'),
  moved('moved'),
  assigned('assigned'),
  completed('completed'),
  archived('archived');

  const ActivityAction(this.value);
  final String value;

  static ActivityAction fromString(String value) {
    return ActivityAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => ActivityAction.created,
    );
  }
}

// Entity Type Enum (Enhanced)
enum EntityType {
  project('project'),
  board('board'),
  column('column'),
  task('task'),
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
