import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:async';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/edit_task_dialog.dart';
import '../widgets/task_detail_dialog.dart';
import '../utils/safe_context.dart';

class KanbanScreen extends StatefulWidget {
  final PocketBase pb;

  const KanbanScreen({super.key, required this.pb});

  @override
  _KanbanScreenState createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  List<Task> allTasks = [];
  bool _isLoading = true;
  int _selectedIndex = 2;
  late TaskService taskService;
  late SafeContext _safeContext;
  final List<Completer> _activeOperations = [];

  // Kanban columns
  List<Task> get todoTasks => allTasks.where((task) => !task.completed && _getTaskProgress(task) == 0).toList();
  List<Task> get inProgressTasks => allTasks.where((task) => !task.completed && _getTaskProgress(task) > 0 && _getTaskProgress(task) < 1).toList();
  List<Task> get completedTasks => allTasks.where((task) => task.completed).toList();

  @override
  void initState() {
    super.initState();
    taskService = TaskService(widget.pb);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
    if (_isLoading) {
      _fetchTasks();
    }
  }

  @override
  void dispose() {
    _safeContext.dispose();
    // Cancel all active operations
    for (final completer in _activeOperations) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _activeOperations.clear();
    super.dispose();
  }

  Future<T> _safeAsyncOperation<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();
    _activeOperations.add(completer);

    try {
      final result = await operation();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    } finally {
      _activeOperations.remove(completer);
    }
  }

  double _getTaskProgress(Task task) {
    if (task.todos.isEmpty) return 0.0;
    final completedTodos = task.todos.where((todo) => todo.completed).length;
    return completedTodos / task.todos.length;
  }

  String _getTaskStatus(Task task) {
    if (task.completed) return 'Completed';
    final progress = _getTaskProgress(task);
    if (progress == 0) return 'To Do';
    if (progress < 1) return 'In Progress';
    return 'Ready to Complete';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.grey;
      case 'In Progress':
        return Colors.orange;
      case 'Ready to Complete':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedTasks = await _safeAsyncOperation(() => taskService.getTasks());
      if (!mounted) return;
      
      setState(() {
        allTasks = fetchedTasks;
        _isLoading = false;
      });
      debugPrint('✅ Successfully fetched ${allTasks.length} tasks for Kanban');
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Error fetching tasks: $e');
      _safeContext.showSnackBar('Failed to fetch tasks: $e', Colors.red);
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    if (!mounted) return;
    
    try {
      final updatedTask = await _safeAsyncOperation(
        () => taskService.toggleTaskCompletion(task.id, !task.completed)
      );
      
      if (!mounted) return;
      
      setState(() {
        final index = allTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          allTasks[index] = updatedTask;
        }
      });
      
      _safeContext.showSnackBar(
        updatedTask.completed ? 'Task completed!' : 'Task marked as pending',
        updatedTask.completed ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _safeContext.showSnackBar('Failed to update task: $e', Colors.red);
    }
  }

  Future<void> _toggleTodoCompletion(Task task, int todoIndex) async {
    if (!mounted) return;
    
    try {
      final currentTodo = task.todos[todoIndex];
      final updatedTask = await _safeAsyncOperation(
        () => taskService.updateTodoCompletion(task.id, todoIndex, !currentTodo.completed)
      );
      
      if (!mounted) return;
      
      setState(() {
        final index = allTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          allTasks[index] = updatedTask;
        }
      });
      
      _safeContext.showSnackBar(
        !currentTodo.completed ? 'Todo completed!' : 'Todo marked as pending',
        !currentTodo.completed ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _safeContext.showSnackBar('Failed to update todo: $e', Colors.red);
    }
  }

  Future<void> _editTask(Task task) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => EditTaskDialog(
        task: task,
        onSave: (updatedTask) async {
          try {
            final savedTask = await _safeAsyncOperation(
              () => taskService.updateTask(task.id, updatedTask)
            );
            
            if (!mounted) return;
            
            setState(() {
              final index = allTasks.indexWhere((t) => t.id == task.id);
              if (index != -1) {
                allTasks[index] = savedTask;
              }
            });
            
            _safeContext.showSnackBar('Task updated successfully!', Colors.green);
          } catch (e) {
            throw Exception('Failed to update task: $e');
          }
        },
      ),
    );
  }

  Future<void> _deleteTask(Task task) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this task?'),
            const SizedBox(height: 8),
            Text(
              '"${task.title}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (task.todos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'This will also delete ${task.todos.length} to-do item(s).',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              _safeContext.showSnackBar('Deleting task...', Colors.orange);
              
              try {
                await _safeAsyncOperation(() => taskService.deleteTask(task.id));
                
                if (!mounted) return;
                
                setState(() {
                  allTasks.removeWhere((t) => t.id == task.id);
                });
                
                _safeContext.showSnackBar('Task deleted successfully', Colors.green);
              } catch (e) {
                _safeContext.showSnackBar('Failed to delete task: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTaskDetail(Task task) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        onToggleTodo: _toggleTodoCompletion,
        onToggleTask: _toggleTaskCompletion,
        onEditTask: _editTask,
        onDeleteTask: _deleteTask,
      ),
    );
  }

  Future<void> _createQuickTask(String columnType) async {
    if (!mounted) return;
    
    TextEditingController titleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quick Add Task to $columnType'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Task Title',
            hintText: 'Enter task title...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              
              Navigator.pop(context);
              
              try {
                final userId = widget.pb.authStore.model?.id;
                
                final task = Task(
                  id: '',
                  title: titleController.text.trim(),
                  description: '',
                  userId: userId ?? '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  todos: [],
                );

                final createdTask = await _safeAsyncOperation(() => taskService.createTask(task));
                
                if (!mounted) return;

                setState(() {
                  allTasks.insert(0, createdTask);
                });

                _safeContext.showSnackBar('Task created successfully!', Colors.green);
              } catch (e) {
                _safeContext.showSnackBar('Failed to create task: $e', Colors.red);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/add_task');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  Widget _buildKanbanColumn({
    required String title,
    required List<Task> tasks,
    required Color color,
    required String columnType,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Column Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.8),
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
                  onPressed: () => _createQuickTask(columnType),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Task', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                    foregroundColor: color,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            
            // Tasks List
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No tasks in $title',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildTaskCard(Task task, Color columnColor) {
    final progress = _getTaskProgress(task);
    final completedTodos = task.todos.where((todo) => todo.completed).length;
    final totalTodos = task.todos.length;

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
              // Task Title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editTask(task);
                      } else if (value == 'delete') {
                        _deleteTask(task);
                      } else if (value == 'toggle') {
                        _toggleTaskCompletion(task);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(task.completed ? Icons.undo : Icons.check),
                            const SizedBox(width: 8),
                            Text(task.completed ? 'Mark Pending' : 'Mark Complete'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(Icons.more_vert, size: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
              
              // Task Description
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description,
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
              
              // Status and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_getTaskStatus(task)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTaskStatus(task),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(_getTaskStatus(task)),
                      ),
                    ),
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban Board'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchTasks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchTasks,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.grey[100],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    '${allTasks.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Total Tasks',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            color: Colors.green[100],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    '${completedTasks.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const Text(
                                    'Completed',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            color: Colors.orange[100],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text(
                                    '${inProgressTasks.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const Text(
                                    'In Progress',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Kanban Columns
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKanbanColumn(
                            title: 'To Do',
                            tasks: todoTasks,
                            color: Colors.grey,
                            columnType: 'To Do',
                          ),
                          _buildKanbanColumn(
                            title: 'In Progress',
                            tasks: inProgressTasks,
                            color: Colors.orange,
                            columnType: 'In Progress',
                          ),
                          _buildKanbanColumn(
                            title: 'Completed',
                            tasks: completedTasks,
                            color: Colors.green,
                            columnType: 'Completed',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add Task'),
          BottomNavigationBarItem(icon: Icon(Icons.view_kanban), label: 'Kanban'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
