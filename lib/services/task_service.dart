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

  // Get ONLY personal tasks (not project tasks and not deleted)
  Future<List<Task>> getTasks() async {
    try {
      if (!await testConnection()) {
        throw Exception('PocketBase connection failed');
      }

      if (!await testAuth()) {
        throw Exception('User not authenticated');
      }

      final userId = pb.authStore.model?.id;
      print('🔍 Fetching personal tasks for user: $userId');

      // Only get tasks that are not soft deleted
      final records = await pb
          .collection('tasks')
          .getFullList(
            filter: 'userId = "$userId" && (isDeleted != true)',
            sort: '-created',
          );

      print('📦 Fetched ${records.length} personal task records from database');

      final tasks =
          records.map((record) {
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

      print('✅ Successfully parsed ${tasks.length} personal tasks');
      return tasks;
    } catch (e) {
      print('❌ Error fetching personal tasks: $e');
      // If filter fails, try without filter
      try {
        final userId = pb.authStore.model?.id;
        final records = await pb
            .collection('tasks')
            .getFullList(filter: 'userId = "$userId"', sort: '-created');

        final tasks =
            records.where((record) => record.data['isDeleted'] != true).map((
              record,
            ) {
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

        return tasks;
      } catch (fallbackError) {
        rethrow;
      }
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
      print('👤 Creating personal task for user: $userId');

      final taskData = <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'completed': task.completed,
        'userId': userId,
        'todos':
            task.todos
                .map(
                  (todo) => {'title': todo.title, 'completed': todo.completed},
                )
                .toList(),
        'isPersonalTask': true,
        'isDeleted': false, // Explicitly set as not deleted
      };

      print('📝 Personal task data to send: $taskData');

      final record = await pb.collection('tasks').create(body: taskData);

      print('✅ Personal task created successfully!');

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
      print('❌ Error creating personal task: $e');
      if (e.toString().contains('404')) {
        throw Exception(
          'Collection "tasks" not found. Please create it in PocketBase Admin Dashboard.',
        );
      } else if (e.toString().contains('403')) {
        throw Exception(
          'Permission denied. Check your PocketBase collection rules.',
        );
      } else if (e.toString().contains('400')) {
        throw Exception('Invalid data format. Check required fields.');
      }
      rethrow;
    }
  }

  Future<Task> updateTask(String taskId, Task task) async {
    try {
      print('🔄 Updating personal task $taskId');

      final taskData = <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'completed': task.completed,
        'todos':
            task.todos
                .map(
                  (todo) => {'title': todo.title, 'completed': todo.completed},
                )
                .toList(),
      };

      print('📝 Update data: $taskData');

      final record = await pb
          .collection('tasks')
          .update(taskId, body: taskData);

      print('✅ Personal task updated successfully');

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
      print('❌ Error updating personal task: $e');
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
      print('🗑️ Starting delete process for task: $taskId');

      final userId = pb.authStore.model?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Step 1: Verify task exists and belongs to user
      try {
        final task = await pb.collection('tasks').getOne(taskId);

        if (task.data['userId'] != userId) {
          throw Exception(
            'Permission denied. You can only delete your own tasks.',
          );
        }

        print('✅ Task ownership verified');
      } catch (e) {
        if (e.toString().contains('404')) {
          print('ℹ️ Task not found, considering it already deleted');
          return; // Task doesn't exist, consider deletion successful
        }
        rethrow;
      }

      // Step 2: Try soft delete first (safer approach)
      try {
        print('🔄 Attempting soft delete...');
        await pb
            .collection('tasks')
            .update(
              taskId,
              body: {
                'isDeleted': true,
                'deletedAt': DateTime.now().toIso8601String(),
                'title': '[DELETED] ${DateTime.now().millisecondsSinceEpoch}',
              },
            );

        print('✅ Task soft deleted successfully');
        return;
      } catch (softDeleteError) {
        print('⚠️ Soft delete failed: $softDeleteError');
      }

      // Step 3: If soft delete fails, try hard delete
      try {
        print('🔄 Attempting hard delete...');
        await pb.collection('tasks').delete(taskId);
        print('✅ Task hard deleted successfully');
        return;
      } catch (hardDeleteError) {
        print('❌ Hard delete failed: $hardDeleteError');

        // Step 4: Handle specific relation reference error
        if (hardDeleteError.toString().contains(
          'required relation reference',
        )) {
          print('⚠️ Task has dependencies, using alternative soft delete...');

          try {
            // Mark as deleted with more aggressive approach
            await pb
                .collection('tasks')
                .update(
                  taskId,
                  body: {
                    'isDeleted': true,
                    'deletedAt': DateTime.now().toIso8601String(),
                    'title': '[DELETED]',
                    'description': 'This task has been deleted',
                    'completed': true,
                    'todos': [], // Clear todos to reduce dependencies
                  },
                );

            print('✅ Task marked as deleted (alternative method)');
            return;
          } catch (finalError) {
            print('❌ All delete methods failed: $finalError');
            throw Exception(
              'Unable to delete task. It may be referenced by other records. Please contact support.',
            );
          }
        } else {
          // Re-throw other errors
          rethrow;
        }
      }
    } catch (e) {
      print('❌ Error in delete process: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('404')) {
        return; // Task not found, consider it deleted
      } else if (e.toString().contains('403')) {
        throw Exception(
          'Permission denied. You can only delete your own tasks.',
        );
      } else if (e.toString().contains('required relation reference')) {
        throw Exception(
          'Task cannot be deleted because it is referenced by other data. The task has been hidden instead.',
        );
      } else {
        throw Exception('Failed to delete task: ${e.toString()}');
      }
    }
  }

  Future<Task> toggleTaskCompletion(String taskId, bool completed) async {
    try {
      print('🔄 Toggling personal task $taskId completion to: $completed');

      final record = await pb
          .collection('tasks')
          .update(taskId, body: {'completed': completed});

      print('✅ Personal task completion toggled successfully');

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
      print('❌ Error toggling personal task completion: $e');
      rethrow;
    }
  }

  Future<Task> updateTodoCompletion(
    String taskId,
    int todoIndex,
    bool completed,
  ) async {
    try {
      print(
        '🔄 Updating todo $todoIndex in personal task $taskId to: $completed',
      );

      final record = await pb.collection('tasks').getOne(taskId);
      final todos = List<Map<String, dynamic>>.from(record.data['todos'] ?? []);

      if (todoIndex >= 0 && todoIndex < todos.length) {
        todos[todoIndex]['completed'] = completed;

        final updatedRecord = await pb
            .collection('tasks')
            .update(taskId, body: {'todos': todos});

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
