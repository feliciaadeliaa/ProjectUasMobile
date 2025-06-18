import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/project_models.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../utils/safe_context.dart';
import '../widgets/task_detail_dialog.dart';
import '../widgets/edit_task_dialog.dart';

class ProjectKanbanScreen extends StatefulWidget {
  final PocketBase pb;
  final Project project;

  const ProjectKanbanScreen({
    super.key,
    required this.pb,
    required this.project,
  });

  @override
  ProjectKanbanScreenState createState() => ProjectKanbanScreenState();
}

class ProjectKanbanScreenState extends State<ProjectKanbanScreen> {
  List<BoardColumn> columns = [];
  List<Task> allTasks = [];
  bool _isLoading = true;
  late ProjectService projectService;
  late SafeContext _safeContext;
  Board? currentBoard;

  @override
  void initState() {
    super.initState();
    projectService = ProjectService(widget.pb);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
    if (_isLoading) {
      _loadProjectData();
    }
  }

  @override
  void dispose() {
    _safeContext.dispose();
    super.dispose();
  }

  Future<void> _loadProjectData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get project boards
      final boards = await projectService.getProjectBoards(widget.project.id);
      
      if (boards.isNotEmpty) {
        currentBoard = boards.first;
        
        // Get board columns
        final boardColumns = await projectService.getBoardColumns(currentBoard!.id);
        
        // Get project tasks
        final tasks = await projectService.getProjectTasks(
          projectId: widget.project.id,
          boardId: currentBoard!.id,
        );
        
        if (!mounted) return;
        
        setState(() {
          columns = boardColumns;
          allTasks = tasks;
          _isLoading = false;
        });
        
        debugPrint('✅ Loaded project data: ${columns.length} columns, ${tasks.length} tasks');
        debugPrint('📋 Tasks loaded: ${tasks.map((t) => '${t.title} - ${_getTaskStatus(t)}').join(', ')}');
      } else {
        setState(() {
          _isLoading = false;
        });
        _safeContext.showSnackBar('No boards found for this project', Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Error loading project data: $e');
      _safeContext.showSnackBar('Failed to load project data: $e', Colors.red);
    }
  }

  List<Task> _getTasksForColumn(String columnId) {
    final column = columns.firstWhere((col) => col.id == columnId, orElse: () => columns.first);
    final columnName = column.name.toLowerCase();
    
    // Determine expected status for this column
    String expectedStatus = 'todo';
    if (columnName.contains('progress') || columnName.contains('in progress')) {
      expectedStatus = 'in_progress';
    } else if (columnName.contains('review')) {
      expectedStatus = 'review';
    } else if (columnName.contains('done') || columnName.contains('completed')) {
      expectedStatus = 'done';
    }
    
    final filteredTasks = allTasks.where((task) {
      final taskStatus = _getTaskStatus(task);
      final matches = taskStatus == expectedStatus;
      return matches;
    }).toList();
    
    debugPrint('🔍 Column ${column.name} expects: $expectedStatus, found: ${filteredTasks.map((t) => '${t.title}(${_getTaskStatus(t)})').join(', ')}');
    
    return filteredTasks;
  }

  double _getTaskProgress(Task task) {
    if (task.todos.isEmpty) return 0.0;
    final completedTodos = task.todos.where((todo) => todo.completed).length;
    return completedTodos / task.todos.length;
  }

  String _getStatusFromColumn(String columnName) {
    final lowerColumnName = columnName.toLowerCase();
    if (lowerColumnName.contains('progress') || lowerColumnName.contains('in progress')) {
      return 'in_progress';
    } else if (lowerColumnName.contains('review')) {
      return 'review';
    } else if (lowerColumnName.contains('done') || lowerColumnName.contains('completed')) {
      return 'done';
    } else {
      return 'todo';
    }
  }

  Future<void> _createTask(String columnName) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateTaskDialog(
        columnName: columnName,
        projectId: widget.project.id,
        boardId: currentBoard?.id ?? '',
      ),
    );

    if (result != null && currentBoard != null) {
      try {
        final targetColumn = columns.firstWhere(
          (col) => col.name.toLowerCase().contains(columnName.toLowerCase()),
          orElse: () => columns.first,
        );

        final status = _getStatusFromColumn(columnName);
        String description = result['description'] ?? '';
        
        // Add status tag to description for tracking
        description = _addStatusToDescription(description, status);

        final task = Task(
          id: '',
          title: result['title']!,
          description: description,
          userId: widget.pb.authStore.model?.id ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          todos: result['todos'] ?? [],
          completed: status == 'done',
        );

        debugPrint('🆕 Creating task "${task.title}" with status: $status in column: $columnName');

        final createdTask = await projectService.createProjectTask(
          task,
          projectId: widget.project.id,
          boardId: currentBoard!.id,
          columnId: targetColumn.id,
        );
        
        if (!mounted) return;
        
        setState(() {
          allTasks.insert(0, createdTask);
        });
        
        debugPrint('✅ Task created successfully: ${createdTask.title} - Status: ${_getTaskStatus(createdTask)}');
        _safeContext.showSnackBar('Task created successfully in $columnName!', Colors.green);
      } catch (e) {
        debugPrint('❌ Error creating task: $e');
        _safeContext.showSnackBar('Failed to create task: $e', Colors.red);
      }
    }
  }

  String _addStatusToDescription(String description, String status) {
    // Remove existing status tag if present
    description = description.replaceAll(RegExp(r'\[STATUS:\w+\]'), '').trim();
    
    // Add new status tag
    final statusTag = '[STATUS:${status.toUpperCase()}]';
    if (description.isNotEmpty) {
      return '$description $statusTag';
    } else {
      return statusTag;
    }
  }

  void _showTaskDetail(Task task) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        onToggleTodo: _toggleTodo,
        onToggleTask: _toggleTask,
        onEditTask: _editTask,
        onDeleteTask: _deleteTask,
      ),
    );
  }

  Future<void> _toggleTodo(Task task, int todoIndex) async {
    try {
      final updatedTodos = List<Todo>.from(task.todos);
      updatedTodos[todoIndex] = Todo(
        title: updatedTodos[todoIndex].title,
        completed: !updatedTodos[todoIndex].completed,
      );

      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        completed: task.completed,
        userId: task.userId,
        createdAt: task.createdAt,
        updatedAt: DateTime.now(),
        todos: updatedTodos,
      );

      await projectService.updateProjectTask(updatedTask);
      
      if (!mounted) return;
      
      setState(() {
        final index = allTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          allTasks[index] = updatedTask;
        }
      });
    } catch (e) {
      _safeContext.showSnackBar('Failed to update todo: $e', Colors.red);
    }
  }

  Future<void> _toggleTask(Task task) async {
    try {
      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        completed: !task.completed,
        userId: task.userId,
        createdAt: task.createdAt,
        updatedAt: DateTime.now(),
        todos: task.todos,
      );

      await projectService.updateProjectTask(updatedTask);
      
      if (!mounted) return;
      
      setState(() {
        final index = allTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          allTasks[index] = updatedTask;
        }
      });
    } catch (e) {
      _safeContext.showSnackBar('Failed to update task: $e', Colors.red);
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) async {
          return await projectService.updateProjectTask(updatedTask);
        },
      ),
    );

    if (result != null) {
      setState(() {
        final index = allTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          allTasks[index] = result;
        }
      });
      _safeContext.showSnackBar('Task updated successfully!', Colors.green);
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await projectService.deleteProjectTask(task.id);
        
        if (!mounted) return;
        
        setState(() {
          allTasks.removeWhere((t) => t.id == task.id);
        });
        
        Navigator.pop(context); // Close task detail dialog
        _safeContext.showSnackBar('Task deleted successfully!', Colors.green);
      } catch (e) {
        _safeContext.showSnackBar('Failed to delete task: $e', Colors.red);
      }
    }
  }

  Future<void> _moveTask(Task task, String targetColumnId) async {
  final targetColumn = columns.firstWhere((col) => col.id == targetColumnId);
  final newStatus = _getStatusFromColumn(targetColumn.name);
  final oldStatus = _getTaskStatus(task);
  
  debugPrint('🔄 Moving task "${task.title}" from $oldStatus to $newStatus (${targetColumn.name})');
  
  if (oldStatus == newStatus) {
    debugPrint('⚠️ Task already in correct status, skipping move');
    return;
  }
  
  try {
    // Clean description and add new status
    String cleanDescription = task.description.replaceAll(RegExp(r'\[STATUS:\w+\]'), '').trim();
    String updatedDescription = _addStatusToDescription(cleanDescription, newStatus);
    
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: updatedDescription,
      completed: newStatus == 'done',
      userId: task.userId,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
      todos: task.todos,
    );

    debugPrint('💾 Updating task with new description: "$updatedDescription"');
    
    await projectService.updateProjectTask(updatedTask);
    
    if (!mounted) return;
    
    setState(() {
      final index = allTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        allTasks[index] = updatedTask;
        debugPrint('✅ Task updated in local state');
      }
    });
    
    // Force refresh to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {});
    }
    
    debugPrint('✅ Task moved successfully: ${updatedTask.title} - New status: ${_getTaskStatus(updatedTask)}');
    _safeContext.showSnackBar('Task moved to ${targetColumn.name}!', Colors.green);
  } catch (e) {
    debugPrint('❌ Error moving task: $e');
    _safeContext.showSnackBar('Failed to move task: $e', Colors.red);
  }
}

  String _getTaskStatus(Task task) {
  // First check for explicit status tag in description
  if (task.description.contains('[STATUS:')) {
    final statusMatch = RegExp(r'\[STATUS:(\w+)\]').firstMatch(task.description);
    if (statusMatch != null) {
      final status = statusMatch.group(1)?.toLowerCase() ?? 'todo';
      debugPrint('📋 Task "${task.title}" has explicit status: $status');
      return status;
    }
  }
  
  // Fallback logic based on completion and progress
  final progress = _getTaskProgress(task);
  String fallbackStatus = 'todo';
  
  if (task.completed) {
    fallbackStatus = 'done';
  } else if (progress == 1.0) {
    fallbackStatus = 'review';
  } else if (progress > 0) {
    fallbackStatus = 'in_progress';
  }
  
  debugPrint('📋 Task "${task.title}" fallback status: $fallbackStatus (progress: $progress, completed: ${task.completed})');
  return fallbackStatus;
}

  void _debugTaskStatuses() {
  debugPrint('🐛 === DEBUGGING TASK STATUSES ===');
  for (final task in allTasks) {
    final status = _getTaskStatus(task);
    debugPrint('🐛 Task: "${task.title}" | Status: $status | Description: "${task.description}"');
  }
  debugPrint('🐛 === END DEBUG ===');
}

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(int.parse(widget.project.color.replaceFirst('#', '0xFF')));
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name),
            if (widget.project.description.isNotEmpty)
              Text(
                widget.project.description,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: projectColor.withValues(alpha: 0.1),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _debugTaskStatuses,
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug',
          ),
          IconButton(
            onPressed: _loadProjectData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProjectData,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Project Stats
                    Card(
                      color: projectColor.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              _getIconData(widget.project.icon),
                              color: projectColor,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${allTasks.length} Total Tasks',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${allTasks.where((t) => t.completed).length} Completed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (allTasks.isNotEmpty)
                              CircularProgressIndicator(
                                value: allTasks.where((t) => t.completed).length / allTasks.length,
                                strokeWidth: 4,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(projectColor),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Kanban Board
                    Expanded(
                      child: columns.isEmpty
                          ? _buildEmptyBoard()
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: columns.map((column) {
                                final columnTasks = _getTasksForColumn(column.id);
                                final columnColor = Color(int.parse(column.color.replaceFirst('#', '0xFF')));
                                
                                return _buildKanbanColumn(
                                  column: column,
                                  tasks: columnTasks,
                                  color: columnColor,
                                  onAddTask: () => _createTask(column.name),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyBoard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_kanban,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Setting up your board...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn({
  required BoardColumn column,
  required List<Task> tasks,
  required Color color,
  required VoidCallback onAddTask,
}) {
  return Expanded(
    child: DragTarget<Task>(
      onWillAccept: (task) {
        if (task == null) return false;
        final taskStatus = _getTaskStatus(task);
        final columnStatus = _getStatusFromColumn(column.name);
        final canAccept = taskStatus != columnStatus;
        debugPrint('🎯 Can accept "${task.title}" in "${column.name}"? $canAccept (task: $taskStatus, column: $columnStatus)');
        return canAccept;
      },
      onAccept: (task) {
        debugPrint('🎯 Task "${task.title}" accepted by column "${column.name}"');
        _moveTask(task, column.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isHighlighted 
                ? color.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted 
                  ? color.withValues(alpha: 0.8)
                  : color.withValues(alpha: 0.3),
              width: isHighlighted ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              // Column Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHighlighted 
                      ? color.withValues(alpha: 0.4)
                      : color.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        column.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Add Task Button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAddTask,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('Add to ${column.name}', style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.2),
                      foregroundColor: color,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              
              // Drop Zone Indicator
              if (isHighlighted) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Drop here to move to ${column.name}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // Tasks List
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No tasks in\n${column.name}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskCard(task, color);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _buildTaskCard(Task task, Color columnColor) {
    final completedTodos = task.todos.where((todo) => todo.completed).length;
    final totalTodos = task.todos.length;
    final progress = _getTaskProgress(task);

    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: columnColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskCardContent(task, columnColor, completedTodos, totalTodos, progress),
      ),
      child: _buildTaskCardContent(task, columnColor, completedTodos, totalTodos, progress),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'todo':
        return Colors.grey;
      case 'in_progress':
        return Colors.orange;
      case 'review':
        return Colors.blue;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'todo':
        return 'TO DO';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'review':
        return 'REVIEW';
      case 'done':
        return 'DONE';
      default:
        return 'TO DO';
    }
  }

  Widget _buildTaskCardContent(Task task, Color columnColor, int completedTodos, int totalTodos, double progress) {
    final taskStatus = _getTaskStatus(task);
    final statusColor = _getStatusColor(taskStatus);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showTaskDetail(task),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicator and drag handle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusDisplayName(taskStatus),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Task Title
              Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: task.completed ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Task Description (without status tag)
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description.replaceAll(RegExp(r'\[STATUS:\w+\]'), '').trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 8),
              
              // Progress Section
              if (totalTodos > 0) ...[
                Row(
                  children: [
                    Icon(Icons.checklist, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$completedTodos/$totalTodos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0 ? Colors.green : columnColor,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(),
                  Text(
                    '${task.createdAt.day}/${task.createdAt.month}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'school':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_cart;
      case 'health':
        return Icons.favorite;
      case 'travel':
        return Icons.flight;
      default:
        return Icons.folder;
    }
  }
}

class _CreateTaskDialog extends StatefulWidget {
  final String columnName;
  final String projectId;
  final String boardId;

  const _CreateTaskDialog({
    required this.columnName,
    required this.projectId,
    required this.boardId,
  });

  @override
  _CreateTaskDialogState createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<Todo> _todos = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addTodo() {
    showDialog(
      context: context,
      builder: (context) {
        final todoController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Todo Item'),
          content: TextField(
            controller: todoController,
            decoration: const InputDecoration(
              labelText: 'Todo description',
              hintText: 'Enter todo item...',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (todoController.text.trim().isNotEmpty) {
                  setState(() {
                    _todos.add(Todo(
                      title: todoController.text.trim(),
                      completed: false,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final columnColor = _getColumnColor(widget.columnName);
    
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: columnColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Add Task to ${widget.columnName}'),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Status Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: columnColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: columnColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: columnColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This task will be created in "${widget.columnName}" column',
                        style: TextStyle(
                          fontSize: 12,
                          color: columnColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Task Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title *',
                  hintText: 'Enter task title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              
              const SizedBox(height: 16),
              
              // Task Description
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter task description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              
              const SizedBox(height: 16),
              
              // Todos Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Todo Items (${_todos.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  TextButton.icon(
                    onPressed: _addTodo,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Todo'),
                  ),
                ],
              ),
              
              if (_todos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: todo.completed,
                            onChanged: (value) {
                              setState(() {
                                _todos[index] = Todo(
                                  title: todo.title,
                                  completed: value ?? false,
                                );
                              });
                            },
                          ),
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              decoration: todo.completed 
                                  ? TextDecoration.lineThrough 
                                  : null,
                              fontSize: 14,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () => _removeTodo(index),
                            color: Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter task title')),
              );
              return;
            }
            
            Navigator.pop(context, {
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
              'todos': _todos,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: columnColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Task'),
        ),
      ],
    );
  }

  Color _getColumnColor(String columnName) {
    final lowerColumnName = columnName.toLowerCase();
    if (lowerColumnName.contains('progress')) {
      return Colors.orange;
    } else if (lowerColumnName.contains('review')) {
      return Colors.blue;
    } else if (lowerColumnName.contains('done') || lowerColumnName.contains('completed')) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }
}
