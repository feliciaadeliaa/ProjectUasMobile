import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:async';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/debug_panel.dart';
import '../widgets/edit_task_dialog.dart';
import '../widgets/task_detail_dialog.dart';
import '../utils/safe_context.dart';

class AddTaskScreen extends StatefulWidget {
  final PocketBase pb;

  const AddTaskScreen({super.key, required this.pb});

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> with TickerProviderStateMixin {
  TextEditingController taskTitleController = TextEditingController();
  TextEditingController taskDescriptionController = TextEditingController();
  List<Todo> currentTodos = [];
  List<Task> tasks = [];
  int _selectedIndex = 1;
  bool _isLoading = false;
  bool _isLoadingTasks = true;
  late TaskService taskService;
  late TabController _tabController;
  late SafeContext _safeContext;
  final List<Completer> _activeOperations = [];

  @override
  void initState() {
    super.initState();
    taskService = TaskService(widget.pb);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
    // Only fetch tasks once
    if (_isLoadingTasks) {
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
    _tabController.dispose();
    taskTitleController.dispose();
    taskDescriptionController.dispose();
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

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingTasks = true;
    });

    try {
      final fetchedTasks = await _safeAsyncOperation(() => taskService.getTasks());
      if (!mounted) return;
      
      setState(() {
        tasks = fetchedTasks;
        _isLoadingTasks = false;
      });
      debugPrint('✅ Successfully fetched ${tasks.length} tasks');
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingTasks = false;
      });
      debugPrint('❌ Error fetching tasks: $e');
      _safeContext.showSnackBar('Failed to fetch tasks: $e', Colors.red);
    }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/kanban');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  Future<void> _addTask() async {
    if (!mounted) return;
    
    if (taskTitleController.text.trim().isEmpty) {
      _safeContext.showSnackBar('Please enter a task title', Colors.orange);
      return;
    }

    if (!widget.pb.authStore.isValid) {
      _safeContext.showSnackBar('Please login to create tasks', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = widget.pb.authStore.model?.id;
      
      final task = Task(
        id: '',
        title: taskTitleController.text.trim(),
        description: taskDescriptionController.text.trim(),
        userId: userId ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        todos: List.from(currentTodos),
      );

      final createdTask = await _safeAsyncOperation(() => taskService.createTask(task));
      
      if (!mounted) return;

      setState(() {
        tasks.insert(0, createdTask);
      });

      taskTitleController.clear();
      taskDescriptionController.clear();
      setState(() {
        currentTodos.clear();
      });

      _safeContext.showSnackBar('Task created successfully!', Colors.green);
      _tabController.animateTo(1);
    } catch (e) {
      _safeContext.showSnackBar('Failed to create task: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        final index = tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          tasks[index] = updatedTask;
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
        final index = tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          tasks[index] = updatedTask;
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
              final index = tasks.indexWhere((t) => t.id == task.id);
              if (index != -1) {
                tasks[index] = savedTask;
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
                  tasks.removeWhere((t) => t.id == task.id);
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

  void _addTodo() {
    if (!mounted) return;
    
    TextEditingController todoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add To-Do',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 20),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Theme.of(context).cardColor,
          content: TextField(
            controller: todoController,
            decoration: const InputDecoration(labelText: 'To-Do'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
            ),
            ElevatedButton(
              onPressed: () {
                if (todoController.text.trim().isNotEmpty) {
                  setState(() {
                    currentTodos.add(Todo(title: todoController.text.trim()));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.black87)),
            ),
          ],
        );
      },
    );
  }

  void _removeTodo(int index) {
    if (!mounted) return;
    
    setState(() {
      currentTodos.removeAt(index);
    });
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

  void _openDebugPanel() {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugPanel(pb: widget.pb),
      ),
    );
  }

  Widget _buildAddTaskTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create New Task',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24),
              ),
              IconButton(
                onPressed: _openDebugPanel,
                icon: const Icon(Icons.bug_report, color: Colors.red),
                tooltip: 'Debug Panel',
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: taskTitleController,
            decoration: const InputDecoration(
              labelText: 'Task Title *',
              prefixIcon: Icon(Icons.title),
              hintText: 'Enter task title...',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: taskDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              prefixIcon: Icon(Icons.description),
              hintText: 'Enter task description...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To-Do Items (${currentTodos.length})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: _addTodo,
                icon: const Icon(Icons.add),
                label: const Text('Add To-Do'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: currentTodos.isEmpty
                ? Center(
                    child: Text(
                      'No to-do items yet. Add some to organize your task.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : Card(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: currentTodos.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: Checkbox(
                            value: currentTodos[index].completed,
                            onChanged: (value) {
                              setState(() {
                                currentTodos[index] = Todo(
                                  title: currentTodos[index].title,
                                  completed: value ?? false,
                                );
                              });
                            },
                            activeColor: const Color(0xFFF8E1E1),
                          ),
                          title: Text(
                            currentTodos[index].title,
                            style: TextStyle(
                              decoration: currentTodos[index].completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeTodo(index),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _addTask,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Create Task', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksListTab() {
    return RefreshIndicator(
      onRefresh: _fetchTasks,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Tasks',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 24),
                ),
                Text(
                  '${tasks.length} tasks',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoadingTasks
                  ? const Center(child: CircularProgressIndicator())
                  : tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks yet',
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      fontSize: 20,
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first task to get started!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final completedTodos = task.todos.where((todo) => todo.completed).length;
                            final totalTodos = task.todos.length;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Checkbox(
                                  value: task.completed,
                                  onChanged: (_) => _toggleTaskCompletion(task),
                                  activeColor: const Color(0xFFF8E1E1),
                                ),
                                title: Text(
                                  task.title,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        decoration: task.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (task.description.isNotEmpty)
                                      Text(
                                        task.description,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.checklist, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$completedTodos/$totalTodos completed',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                        if (totalTodos > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 50,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: totalTodos > 0 ? completedTodos / totalTodos : 0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: completedTodos == totalTodos 
                                                    ? Colors.green 
                                                    : const Color(0xFFF8E1E1),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'view') {
                                      _showTaskDetail(task);
                                    } else if (value == 'edit') {
                                      _editTask(task);
                                    } else if (value == 'delete') {
                                      _deleteTask(task);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility),
                                          SizedBox(width: 8),
                                          Text('View Details'),
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
                                ),
                                onTap: () => _showTaskDetail(task),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add), text: 'Add Task'),
            Tab(icon: Icon(Icons.list), text: 'My Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddTaskTab(),
          _buildTasksListTab(),
        ],
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
