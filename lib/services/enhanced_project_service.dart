import 'package:pocketbase/pocketbase.dart';
import '../models/project_models.dart';
import '../models/task.dart';
import 'auth_service.dart';

class EnhancedProjectService {
  final PocketBase pb;
  late AuthService authService;

  EnhancedProjectService(this.pb) {
    authService = AuthService(pb);
  }

  // =====================================================
  // AUTHENTICATION HELPERS
  // =====================================================

  Future<void> _ensureAuthenticated() async {
    if (!authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }
    
    // Validate and refresh token if needed
    final isValid = await authService.validateAuth();
    if (!isValid) {
      throw Exception('Authentication expired. Please login again.');
    }
  }

  String get _currentUserId {
    final userId = authService.currentUserId;
    if (userId == null) {
      throw Exception('User ID not found');
    }
    return userId;
  }

  // =====================================================
  // PROJECT OPERATIONS
  // =====================================================

  Future<List<Project>> getProjects({bool includeArchived = false}) async {
    try {
      await _ensureAuthenticated();
      
      String filter = 'userId = "${_currentUserId}"';
      if (!includeArchived) {
        filter += ' && isArchived = false';
      }

      print('🔍 Fetching projects with filter: $filter');

      final records = await pb.collection('projects').getFullList(
        filter: filter,
        sort: '-created',
      );

      print('📦 Fetched ${records.length} project records');

      final projects = records.map((record) {
        return Project.fromJson({
          'id': record.id,
          'name': record.data['name'] ?? '',
          'description': record.data['description'] ?? '',
          'color': record.data['color'] ?? '#6366F1',
          'icon': record.data['icon'] ?? 'folder',
          'isArchived': record.data['isArchived'] ?? false,
          'settings': record.data['settings'] ?? {},
          'userId': record.data['userId'] ?? '',
          'created': record.created,
          'updated': record.updated,
          'boards': [], // Will be loaded separately if needed
          'members': [], // Will be loaded separately if needed
        });
      }).toList();

      print('✅ Successfully parsed ${projects.length} projects');
      return projects;
    } catch (e) {
      print('❌ Error fetching projects: $e');
      rethrow;
    }
  }

  Future<Project> getProject(String projectId) async {
    try {
      await _ensureAuthenticated();
      
      print('🔍 Fetching project: $projectId');

      final record = await pb.collection('projects').getOne(projectId);

      // Check if user has access to this project
      if (record.data['userId'] != _currentUserId) {
        // Check if user is a member
        final memberRecords = await pb.collection('project_members').getFullList(
          filter: 'projectId = "$projectId" && userId = "${_currentUserId}" && isActive = true',
        );
        
        if (memberRecords.isEmpty) {
          throw Exception('Access denied to this project');
        }
      }

      // Get project boards
      final boardRecords = await pb.collection('boards').getFullList(
        filter: 'projectId = "$projectId" && isArchived = false',
        sort: 'position',
      );

      final boards = boardRecords.map((boardRecord) {
        return Board.fromJson({
          'id': boardRecord.id,
          'name': boardRecord.data['name'] ?? '',
          'description': boardRecord.data['description'] ?? '',
          'color': boardRecord.data['color'] ?? '#6366F1',
          'type': boardRecord.data['type'] ?? 'kanban',
          'isDefault': boardRecord.data['isDefault'] ?? false,
          'isArchived': boardRecord.data['isArchived'] ?? false,
          'position': boardRecord.data['position'] ?? 0,
          'settings': boardRecord.data['settings'] ?? {},
          'projectId': boardRecord.data['projectId'] ?? '',
          'userId': boardRecord.data['userId'] ?? '',
          'created': boardRecord.created,
          'updated': boardRecord.updated,
          'columns': [], // Will be loaded when needed
        });
      }).toList();

      final project = Project.fromJson({
        'id': record.id,
        'name': record.data['name'] ?? '',
        'description': record.data['description'] ?? '',
        'color': record.data['color'] ?? '#6366F1',
        'icon': record.data['icon'] ?? 'folder',
        'isArchived': record.data['isArchived'] ?? false,
        'settings': record.data['settings'] ?? {},
        'userId': record.data['userId'] ?? '',
        'created': record.created,
        'updated': record.updated,
        'boards': boards,
        'members': [], // Will be loaded separately if needed
      });

      print('✅ Successfully fetched project: ${project.name}');
      return project;
    } catch (e) {
      print('❌ Error fetching project: $e');
      rethrow;
    }
  }

  Future<Project> createProject(Project project, {String? templateId}) async {
    try {
      await _ensureAuthenticated();
      
      print('📝 Creating project: ${project.name}');

      final projectData = {
        'name': project.name,
        'description': project.description,
        'color': project.color,
        'icon': project.icon,
        'isArchived': false,
        'settings': project.settings,
        'userId': _currentUserId,
      };

      final projectRecord = await pb.collection('projects').create(body: projectData);
      print('✅ Project created with ID: ${projectRecord.id}');

      // Create boards from template or default
      if (templateId != null) {
        await _createProjectFromTemplate(projectRecord.id, templateId);
      } else {
        await _createDefaultBoard(projectRecord.id);
      }

      // Add user as project owner
      await _addProjectMember(projectRecord.id, _currentUserId, ProjectRole.owner);

      // Log activity
      await _logActivity(
        action: ActivityAction.created,
        entityType: EntityType.project,
        entityId: projectRecord.id,
        entityName: project.name,
        description: 'Created project "${project.name}"',
        projectId: projectRecord.id,
      );

      // Return the created project
      return Project.fromJson({
        'id': projectRecord.id,
        'name': projectRecord.data['name'] ?? '',
        'description': projectRecord.data['description'] ?? '',
        'color': projectRecord.data['color'] ?? '#6366F1',
        'icon': projectRecord.data['icon'] ?? 'folder',
        'isArchived': projectRecord.data['isArchived'] ?? false,
        'settings': projectRecord.data['settings'] ?? {},
        'userId': projectRecord.data['userId'] ?? '',
        'created': projectRecord.created,
        'updated': projectRecord.updated,
        'boards': [],
        'members': [],
      });
    } catch (e) {
      print('❌ Error creating project: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultBoard(String projectId) async {
    try {
      print('📋 Creating default board for project: $projectId');
      
      // Create default board
      final boardData = {
        'name': 'Main Board',
        'description': 'Default kanban board',
        'type': 'kanban',
        'isDefault': true,
        'isArchived': false,
        'position': 0,
        'settings': {},
        'projectId': projectId,
        'userId': _currentUserId,
      };

      final boardRecord = await pb.collection('boards').create(body: boardData);
      print('✅ Default board created: ${boardRecord.id}');

      // Create default columns
      final defaultColumns = [
        {'name': 'To Do', 'color': '#6B7280', 'position': 0},
        {'name': 'In Progress', 'color': '#F59E0B', 'position': 1},
        {'name': 'Review', 'color': '#3B82F6', 'position': 2},
        {'name': 'Done', 'color': '#10B981', 'position': 3},
      ];

      for (final columnData in defaultColumns) {
        final columnBody = {
          'name': columnData['name'],
          'color': columnData['color'],
          'position': columnData['position'],
          'boardId': boardRecord.id,
          'projectId': projectId,
          'settings': {},
        };

        await pb.collection('columns').create(body: columnBody);
        print('✅ Created column: ${columnData['name']}');
      }
    } catch (e) {
      print('❌ Error creating default board: $e');
      rethrow;
    }
  }

  Future<void> _createProjectFromTemplate(String projectId, String templateId) async {
    try {
      print('📋 Creating project from template: $templateId');
      
      final template = await pb.collection('project_templates').getOne(templateId);
      final templateData = template.data['template'] as Map<String, dynamic>;
      
      final boards = templateData['boards'] as List<dynamic>? ?? [];
      
      for (int boardIndex = 0; boardIndex < boards.length; boardIndex++) {
        final boardData = boards[boardIndex] as Map<String, dynamic>;
        
        // Create board
        final boardBody = {
          'name': boardData['name'] ?? 'Board ${boardIndex + 1}',
          'description': boardData['description'] ?? '',
          'type': boardData['type'] ?? 'kanban',
          'isDefault': boardIndex == 0,
          'isArchived': false,
          'position': boardIndex,
          'settings': boardData['settings'] ?? {},
          'projectId': projectId,
          'userId': _currentUserId,
        };

        final boardRecord = await pb.collection('boards').create(body: boardBody);
        print('✅ Created board from template: ${boardData['name']}');

        // Create columns for this board
        final columns = boardData['columns'] as List<dynamic>? ?? [];
        for (final columnData in columns) {
          final columnBody = {
            'name': columnData['name'] ?? 'Column',
            'color': columnData['color'] ?? '#6B7280',
            'position': columnData['position'] ?? 0,
            'boardId': boardRecord.id,
            'projectId': projectId,
            'settings': columnData['settings'] ?? {},
          };

          await pb.collection('columns').create(body: columnBody);
          print('✅ Created column from template: ${columnData['name']}');
        }
      }
    } catch (e) {
      print('❌ Error creating project from template: $e');
      rethrow;
    }
  }

  Future<void> _addProjectMember(String projectId, String userId, ProjectRole role) async {
    try {
      final memberData = {
        'projectId': projectId,
        'userId': userId,
        'role': role.value,
        'permissions': _getDefaultPermissions(role),
        'isActive': true,
      };

      await pb.collection('project_members').create(body: memberData);
      print('✅ Added project member: $userId as ${role.value}');
    } catch (e) {
      print('❌ Error adding project member: $e');
      // Don't rethrow - this shouldn't break project creation
    }
  }

  Map<String, dynamic> _getDefaultPermissions(ProjectRole role) {
    switch (role) {
      case ProjectRole.owner:
        return {
          'canCreateBoards': true,
          'canDeleteTasks': true,
          'canInviteMembers': true,
          'canEditProject': true,
          'canArchiveProject': true,
        };
      case ProjectRole.admin:
        return {
          'canCreateBoards': true,
          'canDeleteTasks': true,
          'canInviteMembers': true,
          'canEditProject': false,
          'canArchiveProject': false,
        };
      case ProjectRole.member:
        return {
          'canCreateBoards': false,
          'canDeleteTasks': false,
          'canInviteMembers': false,
          'canEditProject': false,
          'canArchiveProject': false,
        };
      case ProjectRole.viewer:
        return {
          'canCreateBoards': false,
          'canDeleteTasks': false,
          'canInviteMembers': false,
          'canEditProject': false,
          'canArchiveProject': false,
        };
    }
  }

  // =====================================================
  // BOARD OPERATIONS
  // =====================================================

  Future<List<BoardColumn>> getBoardColumns(String boardId) async {
    try {
      await _ensureAuthenticated();
      
      print('🔍 Fetching columns for board: $boardId');

      final records = await pb.collection('columns').getFullList(
        filter: 'boardId = "$boardId"',
        sort: 'position',
      );

      final columns = records.map((record) {
        return BoardColumn.fromJson({
          'id': record.id,
          'name': record.data['name'] ?? '',
          'description': record.data['description'] ?? '',
          'color': record.data['color'] ?? '#6B7280',
          'position': record.data['position'] ?? 0,
          'wipLimit': record.data['wipLimit'],
          'isCollapsed': record.data['isCollapsed'] ?? false,
          'settings': record.data['settings'] ?? {},
          'boardId': record.data['boardId'] ?? '',
          'projectId': record.data['projectId'] ?? '',
          'created': record.created,
          'updated': record.updated,
          'tasks': [], // Will be loaded separately
        });
      }).toList();

      print('✅ Successfully fetched ${columns.length} columns');
      return columns;
    } catch (e) {
      print('❌ Error fetching board columns: $e');
      rethrow;
    }
  }

  // =====================================================
  // TASK OPERATIONS
  // =====================================================

  Future<List<Task>> getProjectTasks({
    required String projectId,
    String? boardId,
    String? columnId,
  }) async {
    try {
      await _ensureAuthenticated();
      
      String filter = 'projectId = "$projectId"';
      if (boardId != null) filter += ' && boardId = "$boardId"';
      if (columnId != null) filter += ' && columnId = "$columnId"';

      print('🔍 Fetching project tasks with filter: $filter');

      final records = await pb.collection('tasks').getFullList(
        filter: filter,
        sort: 'position',
      );

      final tasks = records.map((record) {
        return Task.fromJson({
          'id': record.id,
          'title': record.data['title'] ?? '',
          'description': record.data['description'] ?? '',
          'completed': record.data['completed'] ?? false,
          'userId': record.data['userId'] ?? '',
          'todos': record.data['todos'] ?? [],
          'created': record.created,
          'updated': record.updated,
        });
      }).toList();

      print('✅ Successfully fetched ${tasks.length} project tasks');
      return tasks;
    } catch (e) {
      print('❌ Error fetching project tasks: $e');
      rethrow;
    }
  }

  Future<Task> createProjectTask(Task task, {
    required String projectId,
    required String boardId,
    required String columnId,
  }) async {
    try {
      await _ensureAuthenticated();
      
      print('📝 Creating project task: ${task.title}');

      final taskData = {
        'title': task.title,
        'description': task.description,
        'completed': task.completed,
        'userId': _currentUserId,
        'todos': task.todos.map((todo) => {
          'title': todo.title,
          'completed': todo.completed,
        }).toList(),
        'projectId': projectId,
        'boardId': boardId,
        'columnId': columnId,
        'position': 0, // Add to top of column
      };

      final record = await pb.collection('tasks').create(body: taskData);

      // Log activity
      await _logActivity(
        action: ActivityAction.created,
        entityType: EntityType.task,
        entityId: record.id,
        entityName: task.title,
        description: 'Created task "${task.title}"',
        projectId: projectId,
        boardId: boardId,
      );

      final createdTask = Task.fromJson({
        'id': record.id,
        'title': record.data['title'] ?? '',
        'description': record.data['description'] ?? '',
        'completed': record.data['completed'] ?? false,
        'userId': record.data['userId'] ?? '',
        'todos': record.data['todos'] ?? [],
        'created': record.created,
        'updated': record.updated,
      });

      print('✅ Successfully created project task: ${createdTask.id}');
      return createdTask;
    } catch (e) {
      print('❌ Error creating project task: $e');
      rethrow;
    }
  }

  // =====================================================
  // TEMPLATE OPERATIONS
  // =====================================================

  Future<List<ProjectTemplate>> getProjectTemplates() async {
    try {
      await _ensureAuthenticated();
      
      print('🔍 Fetching project templates');

      final records = await pb.collection('project_templates').getFullList(
        filter: 'isPublic = true || userId = "${_currentUserId}"',
        sort: 'name',
      );

      final templates = records.map((record) {
        return ProjectTemplate.fromJson({
          'id': record.id,
          'name': record.data['name'] ?? '',
          'description': record.data['description'] ?? '',
          'category': record.data['category'] ?? 'general',
          'icon': record.data['icon'] ?? 'template',
          'isPublic': record.data['isPublic'] ?? true,
          'template': record.data['template'] ?? {},
          'userId': record.data['userId'],
          'created': record.created,
          'updated': record.updated,
        });
      }).toList();

      print('✅ Successfully fetched ${templates.length} project templates');
      return templates;
    } catch (e) {
      print('❌ Error fetching project templates: $e');
      rethrow;
    }
  }

  // =====================================================
  // ACTIVITY LOGGING
  // =====================================================

  Future<void> _logActivity({
    required ActivityAction action,
    required EntityType entityType,
    required String entityId,
    String? entityName,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String description = '',
    required String projectId,
    String? boardId,
  }) async {
    try {
      final activityData = {
        'action': action.value,
        'entityType': entityType.value,
        'entityId': entityId,
        'entityName': entityName,
        'oldValue': oldValue,
        'newValue': newValue,
        'description': description,
        'projectId': projectId,
        'boardId': boardId,
        'userId': _currentUserId,
      };

      await pb.collection('activity_logs').create(body: activityData);
      print('📝 Activity logged: ${action.value} ${entityType.value}');
    } catch (e) {
      print('❌ Error logging activity: $e');
      // Don't rethrow - activity logging shouldn't break main functionality
    }
  }

  // =====================================================
  // STATISTICS & ANALYTICS
  // =====================================================

  Future<Map<String, dynamic>> getProjectStatistics(String projectId) async {
    try {
      await _ensureAuthenticated();
      
      print('📊 Fetching project statistics for: $projectId');

      final tasks = await getProjectTasks(projectId: projectId);
      final project = await getProject(projectId);
      
      final totalTasks = tasks.length;
      final completedTasks = tasks.where((task) => task.completed).length;
      final pendingTasks = totalTasks - completedTasks;
      
      final stats = {
        'totalBoards': project.boards.length,
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'pendingTasks': pendingTasks,
        'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0,
        'boardsData': project.boards.map((board) => {
          'id': board.id,
          'name': board.name,
          'taskCount': board.totalTasks,
          'completedCount': board.completedTasks,
        }).toList(),
      };

      print('✅ Successfully calculated project statistics');
      return stats;
    } catch (e) {
      print('❌ Error getting project statistics: $e');
      rethrow;
    }
  }
}
