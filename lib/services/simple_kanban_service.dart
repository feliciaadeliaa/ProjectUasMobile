import 'package:pocketbase/pocketbase.dart';
import '../models/task.dart';

class SimpleKanbanService {
  final PocketBase pb;

  SimpleKanbanService(this.pb);

  // Test koneksi ke PocketBase
  Future<bool> testConnection() async {
    try {
      await pb.health.check();
      print('✅ PocketBase connection successful');
      return true;
    } catch (e) {
      print('❌ PocketBase connection failed: $e');
      return false;
    }
  }

  // Test authentication
  Future<bool> testAuth() async {
    try {
      final isValid = pb.authStore.isValid;
      final userId = pb.authStore.model?.id;
      print('Auth valid: $isValid, User ID: $userId');
      return isValid && userId != null;
    } catch (e) {
      print('❌ Auth test failed: $e');
      return false;
    }
  }

  // Get tasks untuk Kanban (menggunakan existing tasks collection)
  Future<List<Task>> getKanbanTasks() async {
    try {
      if (!await testConnection()) {
        throw Exception('PocketBase connection failed');
      }
      
      if (!await testAuth()) {
        throw Exception('User not authenticated');
      }

      final userId = pb.authStore.model?.id;
      print('🔍 Fetching Kanban tasks for user: $userId');

      final records = await pb.collection('tasks').getFullList(
        filter: 'userId = "$userId"',
        sort: '-created',
      );

      print('📦 Fetched ${records.length} records from database');
      
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

      print('✅ Successfully parsed ${tasks.length} tasks for Kanban');
      return tasks;
    } catch (e) {
      print('❌ Error fetching Kanban tasks: $e');
      rethrow;
    }
  }

  // Kategorisasi tasks untuk Kanban columns
  List<Task> getTasksByStatus(List<Task> allTasks, String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return allTasks.where((task) => 
          !task.completed && _getTaskProgress(task) == 0).toList();
      case 'in_progress':
        return allTasks.where((task) => 
          !task.completed && _getTaskProgress(task) > 0 && _getTaskProgress(task) < 1).toList();
      case 'completed':
        return allTasks.where((task) => task.completed).toList();
      default:
        return [];
    }
  }

  // Helper untuk menghitung progress task
  double _getTaskProgress(Task task) {
    if (task.todos.isEmpty) return 0.0;
    final completedTodos = task.todos.where((todo) => todo.completed).length;
    return completedTodos / task.todos.length;
  }

  // Get task status untuk display
  String getTaskStatus(Task task) {
    if (task.completed) return 'Completed';
    final progress = _getTaskProgress(task);
    if (progress == 0) return 'To Do';
    if (progress < 1) return 'In Progress';
    return 'Ready to Complete';
  }

  // Get status color
  String getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return '#6B7280';
      case 'In Progress':
        return '#F59E0B';
      case 'Ready to Complete':
        return '#3B82F6';
      case 'Completed':
        return '#10B981';
      default:
        return '#6B7280';
    }
  }

  // Create task (menggunakan existing method)
  Future<Task> createTask(Task task) async {
    try {
      if (!await testConnection()) {
        throw Exception('PocketBase connection failed');
      }
      
      if (!await testAuth()) {
        throw Exception('User not authenticated');
      }

      final userId = pb.authStore.model?.id;
      print('👤 Creating Kanban task for user: $userId');
      
      final taskData = <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'completed': task.completed,
        'userId': userId,
        'todos': task.todos.map((todo) => {
          'title': todo.title,
          'completed': todo.completed,
        }).toList(),
      };

      print('📝 Kanban task data to send: $taskData');

      final record = await pb.collection('tasks').create(body: taskData);
      
      print('✅ Kanban task created successfully!');

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

      return createdTask;
    } catch (e) {
      print('❌ Error creating Kanban task: $e');
      if (e.toString().contains('404')) {
        throw Exception('Collection "tasks" not found. Please create it in PocketBase Admin Dashboard.');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. Check your PocketBase collection rules.');
      } else if (e.toString().contains('400')) {
        throw Exception('Invalid data format. Check required fields.');
      }
      rethrow;
    }
  }

  // Update task (menggunakan existing method)
  Future<Task> updateTask(String taskId, Task task) async {
    try {
      print('🔄 Updating Kanban task $taskId');
      
      final taskData = <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'completed': task.completed,
        'todos': task.todos.map((todo) => {
          'title': todo.title,
          'completed': todo.completed,
        }).toList(),
      };

      print('📝 Update data: $taskData');

      final record = await pb.collection('tasks').update(taskId, body: taskData);
      
      print('✅ Kanban task updated successfully');
      
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
    } catch (e) {
      print('❌ Error updating Kanban task: $e');
      if (e.toString().contains('404')) {
        throw Exception('Task not found');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. You can only edit your own tasks.');
      }
      rethrow;
    }
  }

  // Delete task (menggunakan existing method)
  Future<void> deleteTask(String taskId) async {
    try {
      print('🗑️ Deleting Kanban task: $taskId');
      
      // First check if task exists and belongs to user
      final userId = pb.authStore.model?.id;
      final task = await pb.collection('tasks').getOne(taskId);
      
      if (task.data['userId'] != userId) {
        throw Exception('Permission denied. You can only delete your own tasks.');
      }
      
      await pb.collection('tasks').delete(taskId);
      print('✅ Kanban task deleted successfully');
    } catch (e) {
      print('❌ Error deleting Kanban task: $e');
      if (e.toString().contains('404')) {
        throw Exception('Task not found');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. You can only delete your own tasks.');
      }
      rethrow;
    }
  }

  // Toggle task completion
  Future<Task> toggleTaskCompletion(String taskId, bool completed) async {
    try {
      print('🔄 Toggling Kanban task $taskId completion to: $completed');
      
      final record = await pb.collection('tasks').update(taskId, body: {
        'completed': completed,
      });
      
      print('✅ Kanban task completion toggled successfully');
      
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
    } catch (e) {
      print('❌ Error toggling Kanban task completion: $e');
      rethrow;
    }
  }

  // Update todo completion
  Future<Task> updateTodoCompletion(String taskId, int todoIndex, bool completed) async {
    try {
      print('🔄 Updating todo $todoIndex in Kanban task $taskId to: $completed');
      
      // First get the current task
      final record = await pb.collection('tasks').getOne(taskId);
      final todos = List<Map<String, dynamic>>.from(record.data['todos'] ?? []);
      
      if (todoIndex >= 0 && todoIndex < todos.length) {
        todos[todoIndex]['completed'] = completed;
        
        // Update the task with new todos
        final updatedRecord = await pb.collection('tasks').update(taskId, body: {
          'todos': todos,
        });
        
        print('✅ Kanban todo completion updated successfully');
        
        return Task.fromJson({
          'id': updatedRecord.id,
          'title': updatedRecord.data['title'] ?? '',
          'description': updatedRecord.data['description'] ?? '',
          'completed': updatedRecord.data['completed'] ?? false,
          'userId': updatedRecord.data['userId'] ?? '',
          'todos': updatedRecord.data['todos'] ?? [],
          'created': updatedRecord.created,
          'updated': updatedRecord.updated,
        });
      } else {
        throw Exception('Todo index out of range');
      }
    } catch (e) {
      print('❌ Error updating Kanban todo completion: $e');
      rethrow;
    }
  }
}
