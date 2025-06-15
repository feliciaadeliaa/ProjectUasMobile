import 'package:pocketbase/pocketbase.dart';
import '../models/kanban_models.dart';

class KanbanService {
  final PocketBase pb;

  KanbanService(this.pb);

  // =====================================================
  // BOARD OPERATIONS
  // =====================================================

  Future<List<Board>> getBoards() async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      final records = await pb.collection('boards').getFullList(
        filter: 'userId = "$userId"',
        sort: '-created',
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
      print('❌ Error fetching boards: $e');
      rethrow;
    }
  }

  Future<Board> createBoard(Board board) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      final boardData = board.toJson();
      boardData['userId'] = userId;

      final record = await pb.collection('boards').create(body: boardData);

      // Create default columns
      await _createDefaultColumns(record.id);

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

  Future<void> _createDefaultColumns(String boardId) async {
    final defaultColumns = [
      {'title': 'To Do', 'color': '#6B7280', 'position': 0},
      {'title': 'In Progress', 'color': '#F59E0B', 'position': 1},
      {'title': 'Review', 'color': '#3B82F6', 'position': 2},
      {'title': 'Completed', 'color': '#10B981', 'position': 3},
    ];

    for (final columnData in defaultColumns) {
      await pb.collection('columns').create(body: {
        ...columnData,
        'boardId': boardId,
        'isDefault': true,
        'settings': {},
      });
    }
  }

  // =====================================================
  // COLUMN OPERATIONS
  // =====================================================

  Future<List<Column>> getColumns(String boardId) async {
    try {
      final records = await pb.collection('columns').getFullList(
        filter: 'boardId = "$boardId"',
        sort: 'position',
        expand: 'tasks',
      );

      return records.map((record) => Column.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
        'tasks': record.expand['tasks'] ?? [],
      })).toList();
    } catch (e) {
      print('❌ Error fetching columns: $e');
      rethrow;
    }
  }

  Future<Column> createColumn(Column column) async {
    try {
      final record = await pb.collection('columns').create(body: column.toJson());

      return Column.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error creating column: $e');
      rethrow;
    }
  }

  // =====================================================
  // TASK OPERATIONS
  // =====================================================

  Future<List<Task>> getTasks({String? boardId, String? columnId}) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      String filter = 'userId = "$userId"';
      if (boardId != null) filter += ' && boardId = "$boardId"';
      if (columnId != null) filter += ' && columnId = "$columnId"';

      final records = await pb.collection('tasks').getFullList(
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
      print('❌ Error fetching tasks: $e');
      rethrow;
    }
  }

  Future<Task> createTask(Task task) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      final taskData = task.toJson();
      taskData['userId'] = userId;

      final record = await pb.collection('tasks').create(body: taskData);

      // Log activity
      await _logActivity(
        action: ActivityAction.created,
        entityType: EntityType.task,
        entityId: record.id,
        description: 'Created task "${task.title}"',
        boardId: task.boardId,
      );

      return Task.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error creating task: $e');
      rethrow;
    }
  }

  Future<Task> updateTask(String taskId, Task task) async {
    try {
      final record = await pb.collection('tasks').update(taskId, body: task.toJson());

      // Log activity
      await _logActivity(
        action: ActivityAction.updated,
        entityType: EntityType.task,
        entityId: taskId,
        description: 'Updated task "${task.title}"',
        boardId: task.boardId,
      );

      return Task.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      // Get task info before deletion for logging
      final task = await pb.collection('tasks').getOne(taskId);
      
      await pb.collection('tasks').delete(taskId);

      // Log activity
      await _logActivity(
        action: ActivityAction.deleted,
        entityType: EntityType.task,
        entityId: taskId,
        description: 'Deleted task "${task.data['title']}"',
        boardId: task.data['boardId'],
      );
    } catch (e) {
      print('❌ Error deleting task: $e');
      rethrow;
    }
  }

  Future<Task> moveTask(String taskId, String newColumnId, int newPosition) async {
    try {
      // Get current task data
      final currentTask = await pb.collection('tasks').getOne(taskId);
      final oldColumnId = currentTask.data['columnId'];
      final oldPosition = currentTask.data['position'];

      // Update task with new column and position
      final record = await pb.collection('tasks').update(taskId, body: {
        'columnId': newColumnId,
        'position': newPosition,
      });

      // Log activity
      await _logActivity(
        action: ActivityAction.moved,
        entityType: EntityType.task,
        entityId: taskId,
        oldValue: {'columnId': oldColumnId, 'position': oldPosition},
        newValue: {'columnId': newColumnId, 'position': newPosition},
        description: 'Moved task "${currentTask.data['title']}"',
        boardId: currentTask.data['boardId'],
      );

      return Task.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      });
    } catch (e) {
      print('❌ Error moving task: $e');
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
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String description = '',
    required String boardId,
  }) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) return;

      await pb.collection('activity_logs').create(body: {
        'action': action.value,
        'entityType': entityType.value,
        'entityId': entityId,
        'oldValue': oldValue,
        'newValue': newValue,
        'description': description,
        'userId': userId,
        'boardId': boardId,
      });
    } catch (e) {
      print('❌ Error logging activity: $e');
      // Don't rethrow - activity logging shouldn't break main functionality
    }
  }

  // =====================================================
  // STATISTICS & ANALYTICS
  // =====================================================

  Future<Map<String, dynamic>> getBoardStatistics(String boardId) async {
    try {
      final tasks = await getTasks(boardId: boardId);
      
      final totalTasks = tasks.length;
      final completedTasks = tasks.where((task) => task.completed).length;
      final inProgressTasks = tasks.where((task) => 
        task.status == TaskStatus.inProgress).length;
      final overdueTasks = tasks.where((task) => task.isOverdue).length;
      
      final highPriorityTasks = tasks.where((task) => 
        task.priority == TaskPriority.high || task.priority == TaskPriority.urgent).length;

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'inProgressTasks': inProgressTasks,
        'overdueTasks': overdueTasks,
        'highPriorityTasks': highPriorityTasks,
        'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0,
      };
    } catch (e) {
      print('❌ Error getting board statistics: $e');
      rethrow;
    }
  }

  // =====================================================
  // SEARCH & FILTERING
  // =====================================================

  Future<List<Task>> searchTasks({
    required String query,
    String? boardId,
    TaskPriority? priority,
    TaskStatus? status,
    List<String>? tags,
  }) async {
    try {
      final userId = pb.authStore.model?.id;
      if (userId == null) throw Exception('User not authenticated');

      String filter = 'userId = "$userId"';
      
      if (boardId != null) filter += ' && boardId = "$boardId"';
      if (priority != null) filter += ' && priority = "${priority.value}"';
      if (status != null) filter += ' && status = "${status.value}"';
      
      if (query.isNotEmpty) {
        filter += ' && (title ~ "$query" || description ~ "$query")';
      }

      final records = await pb.collection('tasks').getFullList(
        filter: filter,
        sort: '-updated',
      );

      List<Task> tasks = records.map((record) => Task.fromJson({
        'id': record.id,
        ...record.data,
        'created': record.created,
        'updated': record.updated,
      })).toList();

      // Filter by tags if specified
      if (tags != null && tags.isNotEmpty) {
        tasks = tasks.where((task) => 
          tags.any((tag) => task.tags.contains(tag))).toList();
      }

      return tasks;
    } catch (e) {
      print('❌ Error searching tasks: $e');
      rethrow;
    }
  }
}
