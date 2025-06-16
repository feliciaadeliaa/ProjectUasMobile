import 'package:pocketbase/pocketbase.dart';
import '../models/enhanced_task_models.dart';
import '../models/task.dart';
import '../services/auth_service.dart';

class EnhancedTaskService {
  final PocketBase pb;
  late AuthService authService;

  EnhancedTaskService(this.pb) {
    authService = AuthService(pb);
  }

  // =====================================================
  // AUTHENTICATION HELPERS
  // =====================================================

  Future<void> _ensureAuthenticated() async {
    if (!authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }
    
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
  // TASK CATEGORY OPERATIONS
  // =====================================================

  Future<List<TaskCategory>> getTaskCategories() async {
    try {
      await _ensureAuthenticated();
      
      final records = await pb.collection('task_categories').getFullList(
        filter: 'userId = "${_currentUserId}" || isDefault = true',
        sort: 'position,name',
      );

      final categories = records.map((record) {
        return TaskCategory.fromJson({
          'id': record.id,
          'name': record.data['name'] ?? '',
          'description': record.data['description'] ?? '',
          'color': record.data['color'] ?? '#6366F1',
          'icon': record.data['icon'] ?? 'category',
          'userId': record.data['userId'] ?? '',
          'isDefault': record.data['isDefault'] ?? false,
          'position': record.data['position'] ?? 0,
          'created': record.created,
          'updated': record.updated,
        });
      }).toList();

      print('✅ Successfully fetched ${categories.length} task categories');
      return categories;
    } catch (e) {
      print('❌ Error fetching task categories: $e');
      rethrow;
    }
  }

  Future<TaskCategory> createTaskCategory(TaskCategory category) async {
    try {
      await _ensureAuthenticated();
      
      final categoryData = category.toJson();
      categoryData['userId'] = _currentUserId;

      final record = await pb.collection('task_categories').create(body: categoryData);

      final createdCategory = TaskCategory.fromJson({
        'id': record.id,
        'name': record.data['name'] ?? '',
        'description': record.data['description'] ?? '',
        'color': record.data['color'] ?? '#6366F1',
        'icon': record.data['icon'] ?? 'category',
        'userId': record.data['userId'] ?? '',
        'isDefault': record.data['isDefault'] ?? false,
        'position': record.data['position'] ?? 0,
        'created': record.created,
        'updated': record.updated,
      });

      print('✅ Successfully created task category: ${createdCategory.name}');
      return createdCategory;
    } catch (e) {
      print('❌ Error creating task category: $e');
      rethrow;
    }
  }

  // =====================================================
  // TASK LABEL OPERATIONS
  // =====================================================

  Future<List<TaskLabel>> getTaskLabels() async {
    try {
      await _ensureAuthenticated();
      
      final records = await pb.collection('task_labels').getFullList(
        filter: 'userId = "${_currentUserId}" || userId = ""',
        sort: 'name',
      );

      final labels = records.map((record) {
        return TaskLabel.fromJson({
          'id': record.id,
          'name': record.data['name'] ?? '',
          'color': record.data['color'] ?? '#6B7280',
          'userId': record.data['userId'] ?? '',
          'created': record.created,
          'updated': record.updated,
        });
      }).toList();

      print('✅ Successfully fetched ${labels.length} task labels');
      return labels;
    } catch (e) {
      print('❌ Error fetching task labels: $e');
      rethrow;
    }
  }

  Future<TaskLabel> createTaskLabel(TaskLabel label) async {
    try {
      await _ensureAuthenticated();
      
      final labelData = label.toJson();
      labelData['userId'] = _currentUserId;

      final record = await pb.collection('task_labels').create(body: labelData);

      final createdLabel = TaskLabel.fromJson({
        'id': record.id,
        'name': record.data['name'] ?? '',
        'color': record.data['color'] ?? '#6B7280',
        'userId': record.data['userId'] ?? '',
        'created': record.created,
        'updated': record.updated,
      });

      print('✅ Successfully created task label: ${createdLabel.name}');
      return createdLabel;
    } catch (e) {
      print('❌ Error creating task label: $e');
      rethrow;
    }
  }

  // =====================================================
  // ENHANCED TASK OPERATIONS
  // =====================================================

  Future<List<EnhancedTask>> getEnhancedTasks({
    String? categoryId,
    TaskPriority? priority,
    TaskStatus? status,
    bool? isOverdue,
  }) async {
    try {
      await _ensureAuthenticated();
      
      String filter = 'userId = "${_currentUserId}"';
      
      if (categoryId != null) {
        filter += ' && categoryId = "$categoryId"';
      }
      
      if (priority != null) {
        filter += ' && priority = "${priority.value}"';
      }
      
      if (status != null) {
        filter += ' && status = "${status.value}"';
      }

      if (isOverdue == true) {
        final now = DateTime.now().toIso8601String();
        filter += ' && dueDate < "$now" && completed = false';
      }

      final records = await pb.collection('tasks').getFullList(
        filter: filter,
        sort: '-created',
        expand: 'categoryId',
      );

      final tasks = <EnhancedTask>[];
      
      for (final record in records) {
        // Get task labels
        final labelRecords = await pb.collection('task_label_relations').getFullList(
          filter: 'taskId = "${record.id}"',
          expand: 'labelId',
        );
        
        final labels = labelRecords.map((labelRecord) {
          final labelData = labelRecord.expand['labelId']?.first;
          if (labelData != null) {
            return TaskLabel.fromJson({
              'id': labelData.id,
              'name': labelData.data['name'] ?? '',
              'color': labelData.data['color'] ?? '#6B7280',
              'userId': labelData.data['userId'] ?? '',
              'created': labelData.created,
              'updated': labelData.updated,
            });
          }
          return null;
        }).where((label) => label != null).cast<TaskLabel>().toList();

        // Get task comments
        final commentRecords = await pb.collection('task_comments').getFullList(
          filter: 'taskId = "${record.id}"',
          sort: 'created',
        );
        
        final comments = commentRecords.map((commentRecord) {
          return TaskComment.fromJson({
            'id': commentRecord.id,
            'taskId': commentRecord.data['taskId'] ?? '',
            'userId': commentRecord.data['userId'] ?? '',
            'content': commentRecord.data['content'] ?? '',
            'parentId': commentRecord.data['parentId'],
            'isEdited': commentRecord.data['isEdited'] ?? false,
            'created': commentRecord.created,
            'updated': commentRecord.updated,
          });
        }).toList();

        // Get task attachments
        final attachmentRecords = await pb.collection('task_attachments').getFullList(
          filter: 'taskId = "${record.id}"',
          sort: 'created',
        );
        
        final attachments = attachmentRecords.map((attachmentRecord) {
          return TaskAttachment.fromJson({
            'id': attachmentRecord.id,
            'taskId': attachmentRecord.data['taskId'] ?? '',
            'fileName': attachmentRecord.data['fileName'] ?? '',
            'fileSize': attachmentRecord.data['fileSize'] ?? 0,
            'fileType': attachmentRecord.data['fileType'] ?? '',
            'filePath': attachmentRecord.data['filePath'] ?? '',
            'uploadedBy': attachmentRecord.data['uploadedBy'] ?? '',
            'created': attachmentRecord.created,
          });
        }).toList();

        // Get time entries
        final timeEntryRecords = await pb.collection('time_entries').getFullList(
          filter: 'taskId = "${record.id}"',
          sort: 'created',
        );
        
        final timeEntries = timeEntryRecords.map((timeRecord) {
          return TimeEntry.fromJson({
            'id': timeRecord.id,
            'taskId': timeRecord.data['taskId'] ?? '',
            'userId': timeRecord.data['userId'] ?? '',
            'description': timeRecord.data['description'] ?? '',
            'startTime': timeRecord.data['startTime'] ?? DateTime.now().toIso8601String(),
            'endTime': timeRecord.data['endTime'],
            'duration': timeRecord.data['duration'] ?? 0,
            'isRunning': timeRecord.data['isRunning'] ?? false,
            'created': timeRecord.created,
            'updated': timeRecord.updated,
          });
        }).toList();

        final task = EnhancedTask.fromJson({
          'id': record.id,
          'title': record.data['title'] ?? '',
          'description': record.data['description'] ?? '',
          'completed': record.data['completed'] ?? false,
          'userId': record.data['userId'] ?? '',
          'todos': record.data['todos'] ?? [],
          'created': record.created,
          'updated': record.updated,
          'categoryId': record.data['categoryId'],
          'priority': record.data['priority'] ?? 'medium',
          'dueDate': record.data['dueDate'],
          'estimatedHours': record.data['estimatedHours'] ?? 0,
          'actualHours': record.data['actualHours'] ?? 0,
          'status': record.data['status'] ?? 'todo',
          'assigneeId': record.data['assigneeId'],
          'position': record.data['position'] ?? 0,
          'labels': labels,
          'comments': comments,
          'attachments': attachments,
          'timeEntries': timeEntries,
        });

        tasks.add(task);
      }

      print('✅ Successfully fetched ${tasks.length} enhanced tasks');
      return tasks;
    } catch (e) {
      print('❌ Error fetching enhanced tasks: $e');
      rethrow;
    }
  }

  Future<EnhancedTask> createEnhancedTask(EnhancedTask task) async {
    try {
      await _ensureAuthenticated();
      
      final taskData = task.toJson();
      taskData['userId'] = _currentUserId;

      final record = await pb.collection('tasks').create(body: taskData);

      // Add labels if any
      for (final label in task.labels) {
        await pb.collection('task_label_relations').create(body: {
          'taskId': record.id,
          'labelId': label.id,
        });
      }

      print('✅ Successfully created enhanced task: ${task.title}');
      
      // Return the created task with full data
      final createdTasks = await getEnhancedTasks();
      return createdTasks.firstWhere((t) => t.id == record.id);
    } catch (e) {
      print('❌ Error creating enhanced task: $e');
      rethrow;
    }
  }

  // =====================================================
  // TIME TRACKING OPERATIONS
  // =====================================================

  Future<TimeEntry> startTimeTracking(String taskId, {String description = ''}) async {
    try {
      await _ensureAuthenticated();
      
      // Stop any running time entries for this user
      await _stopAllRunningTimeEntries();

      final timeEntryData = {
        'taskId': taskId,
        'userId': _currentUserId,
        'description': description,
        'startTime': DateTime.now().toIso8601String(),
        'isRunning': true,
      };

      final record = await pb.collection('time_entries').create(body: timeEntryData);

      final timeEntry = TimeEntry.fromJson({
        'id': record.id,
        'taskId': record.data['taskId'] ?? '',
        'userId': record.data['userId'] ?? '',
        'description': record.data['description'] ?? '',
        'startTime': record.data['startTime'] ?? DateTime.now().toIso8601String(),
        'endTime': record.data['endTime'],
        'duration': record.data['duration'] ?? 0,
        'isRunning': record.data['isRunning'] ?? false,
        'created': record.created,
        'updated': record.updated,
      });

      print('✅ Started time tracking for task: $taskId');
      return timeEntry;
    } catch (e) {
      print('❌ Error starting time tracking: $e');
      rethrow;
    }
  }

  Future<TimeEntry> stopTimeTracking(String timeEntryId) async {
    try {
      await _ensureAuthenticated();
      
      final record = await pb.collection('time_entries').getOne(timeEntryId);
      final startTime = DateTime.parse(record.data['startTime']);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inSeconds;

      final updatedRecord = await pb.collection('time_entries').update(timeEntryId, body: {
        'endTime': endTime.toIso8601String(),
        'duration': duration,
        'isRunning': false,
      });

      final timeEntry = TimeEntry.fromJson({
        'id': updatedRecord.id,
        'taskId': updatedRecord.data['taskId'] ?? '',
        'userId': updatedRecord.data['userId'] ?? '',
        'description': updatedRecord.data['description'] ?? '',
        'startTime': updatedRecord.data['startTime'] ?? DateTime.now().toIso8601String(),
        'endTime': updatedRecord.data['endTime'],
        'duration': updatedRecord.data['duration'] ?? 0,
        'isRunning': updatedRecord.data['isRunning'] ?? false,
        'created': updatedRecord.created,
        'updated': updatedRecord.updated,
      });

      print('✅ Stopped time tracking: ${timeEntry.durationFormatted}');
      return timeEntry;
    } catch (e) {
      print('❌ Error stopping time tracking: $e');
      rethrow;
    }
  }

  Future<void> _stopAllRunningTimeEntries() async {
    try {
      final runningEntries = await pb.collection('time_entries').getFullList(
        filter: 'userId = "${_currentUserId}" && isRunning = true',
      );

      for (final entry in runningEntries) {
        await stopTimeTracking(entry.id);
      }
    } catch (e) {
      print('❌ Error stopping running time entries: $e');
      // Don't rethrow - this is a cleanup operation
    }
  }

  // =====================================================
  // NOTIFICATION OPERATIONS
  // =====================================================

  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    try {
      await _ensureAuthenticated();
      
      String filter = 'userId = "${_currentUserId}"';
      if (unreadOnly) {
        filter += ' && isRead = false';
      }

      final records = await pb.collection('notifications').getFullList(
        filter: filter,
        sort: '-created',
      );

      final notifications = records.map((record) {
        return AppNotification.fromJson({
          'id': record.id,
          'userId': record.data['userId'] ?? '',
          'title': record.data['title'] ?? '',
          'message': record.data['message'] ?? '',
          'type': record.data['type'] ?? 'info',
          'entityType': record.data['entityType'] ?? '',
          'entityId': record.data['entityId'] ?? '',
          'isRead': record.data['isRead'] ?? false,
          'actionUrl': record.data['actionUrl'] ?? '',
          'created': record.created,
        });
      }).toList();

      print('✅ Successfully fetched ${notifications.length} notifications');
      return notifications;
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _ensureAuthenticated();
      
      await pb.collection('notifications').update(notificationId, body: {
        'isRead': true,
      });

      print('✅ Marked notification as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      await _ensureAuthenticated();
      
      final unreadNotifications = await getNotifications(unreadOnly: true);
      
      for (final notification in unreadNotifications) {
        await markNotificationAsRead(notification.id);
      }

      print('✅ Marked all notifications as read');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // =====================================================
  // USER SETTINGS OPERATIONS
  // =====================================================

  Future<UserSettings> getUserSettings() async {
    try {
      await _ensureAuthenticated();
      
      final records = await pb.collection('user_settings').getFullList(
        filter: 'userId = "${_currentUserId}"',
      );

      if (records.isNotEmpty) {
        final record = records.first;
        return UserSettings.fromJson({
          'id': record.id,
          'userId': record.data['userId'] ?? '',
          'emailNotifications': record.data['emailNotifications'] ?? true,
          'pushNotifications': record.data['pushNotifications'] ?? true,
          'taskReminders': record.data['taskReminders'] ?? true,
          'weeklyDigest': record.data['weeklyDigest'] ?? true,
          'theme': record.data['theme'] ?? 'light',
          'language': record.data['language'] ?? 'en',
          'timezone': record.data['timezone'] ?? 'UTC',
          'dateFormat': record.data['dateFormat'] ?? 'DD/MM/YYYY',
          'timeFormat': record.data['timeFormat'] ?? '24h',
          'created': record.created,
          'updated': record.updated,
        });
      } else {
        // Create default settings
        return await createDefaultUserSettings();
      }
    } catch (e) {
      print('❌ Error fetching user settings: $e');
      rethrow;
    }
  }

  Future<UserSettings> createDefaultUserSettings() async {
    try {
      await _ensureAuthenticated();
      
      final settingsData = {
        'userId': _currentUserId,
        'emailNotifications': true,
        'pushNotifications': true,
        'taskReminders': true,
        'weeklyDigest': true,
        'theme': 'light',
        'language': 'en',
        'timezone': 'UTC',
        'dateFormat': 'DD/MM/YYYY',
        'timeFormat': '24h',
      };

      final record = await pb.collection('user_settings').create(body: settingsData);

      final settings = UserSettings.fromJson({
        'id': record.id,
        'userId': record.data['userId'] ?? '',
        'emailNotifications': record.data['emailNotifications'] ?? true,
        'pushNotifications': record.data['pushNotifications'] ?? true,
        'taskReminders': record.data['taskReminders'] ?? true,
        'weeklyDigest': record.data['weeklyDigest'] ?? true,
        'theme': record.data['theme'] ?? 'light',
        'language': record.data['language'] ?? 'en',
        'timezone': record.data['timezone'] ?? 'UTC',
        'dateFormat': record.data['dateFormat'] ?? 'DD/MM/YYYY',
        'timeFormat': record.data['timeFormat'] ?? '24h',
        'created': record.created,
        'updated': record.updated,
      });

      print('✅ Created default user settings');
      return settings;
    } catch (e) {
      print('❌ Error creating default user settings: $e');
      rethrow;
    }
  }

  Future<UserSettings> updateUserSettings(UserSettings settings) async {
    try {
      await _ensureAuthenticated();
      
      final record = await pb.collection('user_settings').update(settings.id, 
        body: settings.toJson());

      final updatedSettings = UserSettings.fromJson({
        'id': record.id,
        'userId': record.data['userId'] ?? '',
        'emailNotifications': record.data['emailNotifications'] ?? true,
        'pushNotifications': record.data['pushNotifications'] ?? true,
        'taskReminders': record.data['taskReminders'] ?? true,
        'weeklyDigest': record.data['weeklyDigest'] ?? true,
        'theme': record.data['theme'] ?? 'light',
        'language': record.data['language'] ?? 'en',
        'timezone': record.data['timezone'] ?? 'UTC',
        'dateFormat': record.data['dateFormat'] ?? 'DD/MM/YYYY',
        'timeFormat': record.data['timeFormat'] ?? '24h',
        'created': record.created,
        'updated': record.updated,
      });

      print('✅ Updated user settings');
      return updatedSettings;
    } catch (e) {
      print('❌ Error updating user settings: $e');
      rethrow;
    }
  }

  // =====================================================
  // ANALYTICS & STATISTICS
  // =====================================================

  Future<Map<String, dynamic>> getTaskStatistics() async {
    try {
      await _ensureAuthenticated();
      
      final tasks = await getEnhancedTasks();
      
      final totalTasks = tasks.length;
      final completedTasks = tasks.where((task) => task.completed).length;
      final pendingTasks = totalTasks - completedTasks;
      final overdueTasks = tasks.where((task) => task.isOverdue).length;
      final dueTodayTasks = tasks.where((task) => task.isDueToday).length;
      final dueSoonTasks = tasks.where((task) => task.isDueSoon).length;
      
      // Priority breakdown
      final urgentTasks = tasks.where((task) => task.priority == TaskPriority.urgent).length;
      final highTasks = tasks.where((task) => task.priority == TaskPriority.high).length;
      final mediumTasks = tasks.where((task) => task.priority == TaskPriority.medium).length;
      final lowTasks = tasks.where((task) => task.priority == TaskPriority.low).length;
      
      // Status breakdown
      final todoTasks = tasks.where((task) => task.status == TaskStatus.todo).length;
      final inProgressTasks = tasks.where((task) => task.status == TaskStatus.inProgress).length;
      final reviewTasks = tasks.where((task) => task.status == TaskStatus.review).length;
      final doneTasks = tasks.where((task) => task.status == TaskStatus.done).length;
      
      // Time tracking
      final totalTimeSpent = tasks.fold(Duration.zero, (total, task) => 
        total + task.totalTimeSpent);
      
      final stats = {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'pendingTasks': pendingTasks,
        'overdueTasks': overdueTasks,
        'dueTodayTasks': dueTodayTasks,
        'dueSoonTasks': dueSoonTasks,
        'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0,
        'priorityBreakdown': {
          'urgent': urgentTasks,
          'high': highTasks,
          'medium': mediumTasks,
          'low': lowTasks,
        },
        'statusBreakdown': {
          'todo': todoTasks,
          'inProgress': inProgressTasks,
          'review': reviewTasks,
          'done': doneTasks,
        },
        'totalTimeSpent': totalTimeSpent.inHours,
        'averageTimePerTask': totalTasks > 0 ? totalTimeSpent.inMinutes / totalTasks : 0,
      };

      print('✅ Successfully calculated task statistics');
      return stats;
    } catch (e) {
      print('❌ Error getting task statistics: $e');
      rethrow;
    }
  }

  // Ensure user is authenticated before any operation
  Future<void> _ensureUserAuthenticated() async {
    if (!authService.isAuthenticated) {
      throw Exception('User not authenticated. Please login first.');
    }

    // Validate and refresh auth if needed
    final isValid = await authService.validateAuth();
    if (!isValid) {
      throw Exception('Authentication expired. Please login again.');
    }
  }

  // Test koneksi ke PocketBase
  Future<bool> testConnection() async {
    return await authService.testConnection();
  }

  // Test authentication
  Future<bool> testAuth() async {
    try {
      await _ensureAuthenticated();
      print('✅ Authentication test successful');
      return true;
    } catch (e) {
      print('❌ Authentication test failed: $e');
      return false;
    }
  }

  Future<List<Task>> getTasks() async {
    try {
      // Ensure user is authenticated
      await _ensureAuthenticated();
      
      final userId = authService.currentUserId!;
      print('🔍 Fetching tasks for authenticated user: $userId');

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
      
      // Handle specific authentication errors
      if (e.toString().contains('not authenticated') || 
          e.toString().contains('Authentication expired')) {
        rethrow; // Let the UI handle auth errors
      }
      
      // Handle other errors
      if (e.toString().contains('404')) {
        throw Exception('Tasks collection not found. Please check PocketBase setup.');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. Check your PocketBase collection rules.');
      } else {
        throw Exception('Failed to fetch tasks: ${e.toString()}');
      }
    }
  }

  Future<Task> createTask(Task task) async {
    try {
      await _ensureAuthenticated();

      final userId = authService.currentUserId!;
      print('👤 Creating task for authenticated user: $userId');
      
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
      
      if (e.toString().contains('not authenticated') || 
          e.toString().contains('Authentication expired')) {
        rethrow;
      }
      
      if (e.toString().contains('404')) {
        throw Exception('Tasks collection not found. Please check PocketBase setup.');
      } else if (e.toString().contains('403')) {
        throw Exception('Permission denied. Check your PocketBase collection rules.');
      } else if (e.toString().contains('400')) {
        throw Exception('Invalid task data. Check required fields.');
      }
      rethrow;
    }
  }

  Future<Task> updateTask(String taskId, Task task) async {
    try {
      await _ensureAuthenticated();
      
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
      
      if (e.toString().contains('not authenticated') || 
          e.toString().contains('Authentication expired')) {
        rethrow;
      }
      
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
      await _ensureAuthenticated();
      
      print('🗑️ Deleting task: $taskId');
      
      // First check if task exists and belongs to user
      final userId = authService.currentUserId!;
      final task = await pb.collection('tasks').getOne(taskId);
      
      if (task.data['userId'] != userId) {
        throw Exception('Permission denied. You can only delete your own tasks.');
      }
      
      await pb.collection('tasks').delete(taskId);
      print('✅ Task deleted successfully');
    } catch (e) {
      print('❌ Error deleting task: $e');
      
      if (e.toString().contains('not authenticated') || 
          e.toString().contains('Authentication expired')) {
        rethrow;
      }
      
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
      await _ensureAuthenticated();
      
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
      
      if (e.toString().contains('not authenticated') || 
          e.toString().contains('Authentication expired')) {
        rethrow;
      }
      
      rethrow;
    }
  }

  Future<Task> updateTodoCompletion(String taskId, int todoIndex, bool completed) async {
    try {
      await _ensureAuthenticated();
      
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
      
      if (e.toString().contains('not authenticated') || 
          e.toString().contains('Authentication expired')) {
        rethrow;
      }
      
      rethrow;
    }
  }
}
