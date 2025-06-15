import 'package:pocketbase/pocketbase.dart';
import '../models/task.dart';

class TaskService {
  final PocketBase pb;

  TaskService(this.pb);

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

  Future<List<Task>> getTasks() async {
    try {
      if (!await testConnection()) {
        throw Exception('PocketBase connection failed');
      }
      
      if (!await testAuth()) {
        throw Exception('User not authenticated');
      }

      final userId = pb.authStore.model?.id;
      print('🔍 Fetching tasks for user: $userId');

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

      print('✅ Successfully parsed ${tasks.length} tasks');
      return tasks;
    } catch (e) {
      print('❌ Error fetching tasks: $e');
      rethrow;
    }
  }

  Future<Task> createTask(Task task) async {
    try {
      if (!await testConnection()) {
        throw Exception('PocketBase connection failed');
      }
      
      if (!await testAuth()) {
        throw Exception('User not authenticated');
      }

      final userId = pb.authStore.model?.id;
      print('👤 Creating task for user: $userId');
      
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

      print('📝 Task data to send: $taskData');

      final record = await pb.collection('tasks').create(body: taskData);
      
      print('✅ Task created successfully!');

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
      print('❌ Error creating task: $e');
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

  Future<Task> updateTask(String taskId, Task task) async {
    try {
      print('🔄 Updating task $taskId');
      
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
      
      print('✅ Task updated successfully');
      
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
      print('❌ Error updating task: $e');
      if (e.toString().contains('404')) {
        throw Exception('Task not found');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. You can only edit your own tasks.');
      }
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      print('🗑️ Deleting task: $taskId');
      
      // First check if task exists and belongs to user
      final userId = pb.authStore.model?.id;
      final task = await pb.collection('tasks').getOne(taskId);
      
      if (task.data['userId'] != userId) {
        throw Exception('Permission denied. You can only delete your own tasks.');
      }
      
      await pb.collection('tasks').delete(taskId);
      print('✅ Task deleted successfully');
    } catch (e) {
      print('❌ Error deleting task: $e');
      if (e.toString().contains('404')) {
        throw Exception('Task not found');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. You can only delete your own tasks.');
      }
      rethrow;
    }
  }

  Future<Task> toggleTaskCompletion(String taskId, bool completed) async {
    try {
      print('🔄 Toggling task $taskId completion to: $completed');
      
      final record = await pb.collection('tasks').update(taskId, body: {
        'completed': completed,
      });
      
      print('✅ Task completion toggled successfully');
      
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
      print('❌ Error toggling task completion: $e');
      rethrow;
    }
  }

  Future<Task> updateTodoCompletion(String taskId, int todoIndex, bool completed) async {
    try {
      print('🔄 Updating todo $todoIndex in task $taskId to: $completed');
      
      // First get the current task
      final record = await pb.collection('tasks').getOne(taskId);
      final todos = List<Map<String, dynamic>>.from(record.data['todos'] ?? []);
      
      if (todoIndex >= 0 && todoIndex < todos.length) {
        todos[todoIndex]['completed'] = completed;
        
        // Update the task with new todos
        final updatedRecord = await pb.collection('tasks').update(taskId, body: {
          'todos': todos,
        });
        
        print('✅ Todo completion updated successfully');
        
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
      print('❌ Error updating todo completion: $e');
      rethrow;
    }
  }
}
