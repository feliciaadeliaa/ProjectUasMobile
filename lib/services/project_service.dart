import 'package:pocketbase/pocketbase.dart';
import '../models/project_models.dart';
import '../models/task.dart';

class ProjectService {
  final PocketBase pb;

  ProjectService(this.pb);

  // =====================================================
  // PROJECT OPERATIONS
  // =====================================================

  Future<List<Project>> getProjects({bool includeArchived = false}) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      String filter = 'userId = "$userId"';
      if (!includeArchived) {
        filter += ' && isArchived = false';
      }

      final records = await pb.collection('projects').getFullList(
        filter: filter,
        sort: '-created',
        expand: 'boards,members',
      );

      return records.map((record) => Project.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
        'boards': record.expand['boards'] ?? [],
        'members': record.expand['members'] ?? [],
      })).toList();
    } catch (e) {
      print('❌ Error fetching projects: $e');
      rethrow;
    }
  }

  Future<Project> getProject(String projectId) async {
    try {
      final record = await pb.collection('projects').getOne(
        projectId,
        expand: 'boards,members',
      );

      return Project.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
        'boards': record.expand['boards'] ?? [],
        'members': record.expand['members'] ?? [],
      });
    } catch (e) {
      print('❌ Error fetching project: $e');
      rethrow;
    }
  }

  Future<Project> createProject(Project project, {String? templateId}) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      final projectData = project.toJson();
      projectData['userId'] = userId;

      final record = await pb.collection('projects').create(body: projectData);

      // If template is specified, create boards and columns from template
      if (templateId != null) {
        await _createProjectFromTemplate(record.id, templateId);
      } else {
        // Create default board and columns
        await _createDefaultBoard(record.id);
      }

      // Add user as project owner
      await _addProjectMember(record.id, userId, ProjectRole.owner);

      // Log activity
      await _logActivity(
        action: ActivityAction.created,
        entityType: EntityType.project,
        entityId: record.id,
        entityName: project.name,
        description: 'Created project "${project.name}"',
        projectId: record.id,
      );

      return Project.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error creating project: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultBoard(String projectId) async {
    final userId = pb.authStore.model?.id;
    
    // Create default board
    final boardRecord = await pb.collection('boards').create(body: {
      'name': 'Main Board',
      'description': 'Default kanban board',
      'type': 'kanban',
      'isDefault': true,
      'projectId': projectId,
      'userId': userId,
      'position': 0,
      'settings': {},
    });

    // Create default columns
    final defaultColumns = [
      {'name': 'To Do', 'color': '#6B7280', 'position': 0},
      {'name': 'In Progress', 'color': '#F59E0B', 'position': 1},
      {'name': 'Review', 'color': '#3B82F6', 'position': 2},
      {'name': 'Done', 'color': '#10B981', 'position': 3},
    ];

    for (final columnData in defaultColumns) {
      await pb.collection('columns').create(body: {
        ...columnData,
        'boardId': boardRecord.id,
        'projectId': projectId,
        'settings': {},
      });
    }
  }

  Future<void> _createProjectFromTemplate(String projectId, String templateId) async {
    try {
      final template = await pb.collection('project_templates').getOne(templateId);
      final templateData = template.data['template'] as Map<String, dynamic>;
      
      final boards = templateData['boards'] as List<dynamic>? ?? [];
      
      for (int boardIndex = 0; boardIndex < boards.length; boardIndex++) {
        final boardData = boards[boardIndex] as Map<String, dynamic>;
        
        // Create board
        final boardRecord = await pb.collection('boards').create(body: {
          'name': boardData['name'] ?? 'Board ${boardIndex + 1}',
          'description': boardData['description'] ?? '',
          'type': boardData['type'] ?? 'kanban',
          'isDefault': boardIndex == 0,
          'projectId': projectId,
          'userId': pb.authStore.model?.id,
          'position': boardIndex,
          'settings': boardData['settings'] ?? {},
        });

        // Create columns for this board
        final columns = boardData['columns'] as List<dynamic>? ?? [];
        for (final columnData in columns) {
          await pb.collection('columns').create(body: {
            'name': columnData['name'] ?? 'Column',
            'color': columnData['color'] ?? '#6B7280',
            'position': columnData['position'] ?? 0,
            'boardId': boardRecord.id,
            'projectId': projectId,
            'settings': columnData['settings'] ?? {},
          });
        }
      }
    } catch (e) {
      print('❌ Error creating project from template: $e');
      rethrow;
    }
  }

  Future<void> _addProjectMember(String projectId, String userId, ProjectRole role) async {
    try {
      await pb.collection('project_members').create(body: {
        'projectId': projectId,
        'userId': userId,
        'role': role.value,
        'permissions': _getDefaultPermissions(role),
        'isActive': true,
      });
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

  Future<List<Board>> getProjectBoards(String projectId) async {
    try {
      final records = await pb.collection('boards').getFullList(
        filter: 'projectId = "$projectId" && isArchived = false',
        sort: 'position',
        expand: 'columns',
      );

      return records.map((record) => Board.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
        'columns': record.expand['columns'] ?? [],
      })).toList();
    } catch (e) {
      print('❌ Error fetching project boards: $e');
      rethrow;
    }
  }

  Future<Board> createBoard(Board board) async {
    try {
      final record = await pb.collection('boards').create(body: board.toJson());

      // Create default columns for new board
      await _createDefaultColumnsForBoard(record.id, board.projectId);

      // Log activity
      await _logActivity(
        action: ActivityAction.created,
        entityType: EntityType.board,
        entityId: record.id,
        entityName: board.name,
        description: 'Created board "${board.name}"',
        projectId: board.projectId,
        boardId: record.id,
      );

      return Board.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error creating board: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultColumnsForBoard(String boardId, String projectId) async {
    final defaultColumns = [
      {'name': 'To Do', 'color': '#6B7280', 'position': 0},
      {'name': 'In Progress', 'color': '#F59E0B', 'position': 1},
      {'name': 'Done', 'color': '#10B981', 'position': 2},
    ];

    for (final columnData in defaultColumns) {
      await pb.collection('columns').create(body: {
        ...columnData,
        'boardId': boardId,
        'projectId': projectId,
        'settings': {},
      });
    }
  }

  // =====================================================
  // COLUMN OPERATIONS
  // =====================================================

  Future<List<BoardColumn>> getBoardColumns(String boardId) async {
    try {
      final records = await pb.collection('columns').getFullList(
        filter: 'boardId = "$boardId"',
        sort: 'position',
        expand: 'tasks',
      );

      return records.map((record) => BoardColumn.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
        'tasks': record.expand['tasks'] ?? [],
      })).toList();
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
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      String filter = 'projectId = "$projectId" && (userId = "$userId" || assigneeId = "$userId")';
      if (boardId != null) filter += ' && boardId = "$boardId"';
      if (columnId != null) filter += ' && columnId = "$columnId"';

      final records = await pb.collection('project_tasks').getFullList(
        filter: filter,
        sort: 'position',
      );

      return records.map((record) => Task.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      })).toList();
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
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      final taskData = task.toJson();
      taskData.addAll({
        'projectId': projectId,
        'boardId': boardId,
        'columnId': columnId,
        'userId': userId,
        'position': 0, // Add to top of column
        'isProjectTask': true, // Mark as project task
      });

      // Use separate collection for project tasks
      final record = await pb.collection('project_tasks').create(body: taskData);

      // Log activity
      await _logActivity(
        action: ActivityAction.created,
        entityType: EntityType.task,
        entityId: record.id,
        entityName: task.title,
        description: 'Created task "${task.title}" in project',
        projectId: projectId,
        boardId: boardId,
      );

      return Task.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error creating project task: $e');
      rethrow;
    }
  }

  Future<void> updateProjectTask(Task task) async {
    try {
      await pb.collection('project_tasks').update(task.id, body: task.toJson());
    } catch (e) {
      print('❌ Error updating project task: $e');
      rethrow;
    }
  }

  Future<void> deleteProjectTask(String taskId) async {
    try {
      await pb.collection('project_tasks').delete(taskId);
    } catch (e) {
      print('❌ Error deleting project task: $e');
      rethrow;
    }
  }

  // =====================================================
  // TEMPLATE OPERATIONS
  // =====================================================

  Future<List<ProjectTemplate>> getProjectTemplates() async {
    try {
      final userId = pb.authStore.model?.id;
      
      final records = await pb.collection('project_templates').getFullList(
        filter: 'isPublic = true || userId = "$userId"',
        sort: 'name',
      );

      return records.map((record) => ProjectTemplate.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      })).toList();
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
      final userId = pb.authStore.model?.id;
      if (userId == null) return;

      await pb.collection('activity_logs').create(body: {
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
      });
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
      final tasks = await getProjectTasks(projectId: projectId);
      final boards = await getProjectBoards(projectId);
      
      final totalTasks = tasks.length;
      final completedTasks = tasks.where((task) => task.completed).length;
      final overdueTasks = tasks.where((task) => 
        task.todos.isNotEmpty && 
        task.todos.any((todo) => !todo.completed)
      ).length;
      
      return {
        'totalBoards': boards.length,
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'pendingTasks': totalTasks - completedTasks,
        'overdueTasks': overdueTasks,
        'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0,
        'boardsData': boards.map((board) => {
          'id': board.id,
          'name': board.name,
          'taskCount': board.totalTasks,
          'completedCount': board.completedTasks,
        }).toList(),
      };
    } catch (e) {
      print('❌ Error getting project statistics: $e');
      rethrow;
    }
  }

  // =====================================================
  // PROJECT UPDATE & DELETE OPERATIONS
  // =====================================================

  Future<Project> updateProject(Project project) async {
    try {
      final record = await pb.collection('projects').update(
        project.id,
        body: project.toJson(),
      );

      // Log activity
      await _logActivity(
        action: ActivityAction.updated,
        entityType: EntityType.project,
        entityId: project.id,
        entityName: project.name,
        description: 'Updated project "${project.name}"',
        projectId: project.id,
      );

      return Project.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error updating project: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      // Get project details for logging
      final project = await getProject(projectId);
      
      // Archive project instead of hard delete to preserve data integrity
      await pb.collection('projects').update(projectId, body: {
        'isArchived': true,
        'archivedAt': DateTime.now().toIso8601String(),
      });

      // Log activity
      await _logActivity(
        action: ActivityAction.deleted,
        entityType: EntityType.project,
        entityId: projectId,
        entityName: project.name,
        description: 'Archived project "${project.name}"',
        projectId: projectId,
      );
    } catch (e) {
      print('❌ Error deleting project: $e');
      rethrow;
    }
  }

  Future<void> permanentDeleteProject(String projectId) async {
    try {
      // Get project details for logging
      final project = await getProject(projectId);
      
      // Delete all related data first
      await _deleteProjectRelatedData(projectId);
      
      // Delete the project
      await pb.collection('projects').delete(projectId);

      // Log activity (this will fail since project is deleted, but we try anyway)
      try {
        await _logActivity(
          action: ActivityAction.deleted,
          entityType: EntityType.project,
          entityId: projectId,
          entityName: project.name,
          description: 'Permanently deleted project "${project.name}"',
          projectId: projectId,
        );
      } catch (e) {
        print('⚠️ Could not log deletion activity: $e');
      }
    } catch (e) {
      print('❌ Error permanently deleting project: $e');
      rethrow;
    }
  }

  Future<void> _deleteProjectRelatedData(String projectId) async {
    try {
      // Delete project tasks
      final projectTasks = await pb.collection('project_tasks').getFullList(
        filter: 'projectId = "$projectId"',
      );
      for (final task in projectTasks) {
        await pb.collection('project_tasks').delete(task.id);
      }

      // Delete columns
      final columns = await pb.collection('columns').getFullList(
        filter: 'projectId = "$projectId"',
      );
      for (final column in columns) {
        await pb.collection('columns').delete(column.id);
      }

      // Delete boards
      final boards = await pb.collection('boards').getFullList(
        filter: 'projectId = "$projectId"',
      );
      for (final board in boards) {
        await pb.collection('boards').delete(board.id);
      }

      // Delete project members
      final members = await pb.collection('project_members').getFullList(
        filter: 'projectId = "$projectId"',
      );
      for (final member in members) {
        await pb.collection('project_members').delete(member.id);
      }

      // Delete activity logs
      final activities = await pb.collection('activity_logs').getFullList(
        filter: 'projectId = "$projectId"',
      );
      for (final activity in activities) {
        await pb.collection('activity_logs').delete(activity.id);
      }
    } catch (e) {
      print('❌ Error deleting project related data: $e');
      // Don't rethrow - continue with project deletion
    }
  }
}
