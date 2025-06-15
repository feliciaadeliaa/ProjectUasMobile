import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:async';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/task_detail_dialog.dart';
import '../utils/safe_context.dart';

class HomeScreen extends StatefulWidget {
  final PocketBase pb;

  const HomeScreen({super.key, required this.pb});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Task> tasks = [];
  List<Task> filteredTasks = [];
  String searchQuery = '';
  int _selectedIndex = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String _userName = 'User';
  String? _profilePictureUrl;
  late TaskService taskService;
  late SafeContext _safeContext;
  final List<Completer> _activeOperations = [];

  @override
  void initState() {
    super.initState();
    taskService = TaskService(widget.pb);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
    if (_isLoading) {
      _fetchUserData();
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
    _controller.dispose();
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

  Future<void> _fetchUserData() async {
    try {
      final userId = widget.pb.authStore.model?.id;
      if (userId == null) return;

      final record = await widget.pb.collection('users').getOne(userId);
      if (!mounted) return;
      
      setState(() {
        _userName = record.data['name'] ?? 'User';
        if (record.data['profilePicture'] != null) {
          _profilePictureUrl = widget.pb.files
              .getUrl(record, record.data['profilePicture'])
              .toString();
        }
      });
    } catch (e) {
      // Handle error silently or show a message
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    
    try {
      final fetchedTasks = await _safeAsyncOperation(() => taskService.getTasks());
      if (!mounted) return;
      
      setState(() {
        tasks = fetchedTasks;
        _filterTasks();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      _safeContext.showSnackBar('Failed to fetch tasks: $e', Colors.red);
    }
  }

  void _filterTasks() {
    setState(() {
      filteredTasks = tasks
          .where((task) =>
              task.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              task.description.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });
    _filterTasks();
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
        _filterTasks();
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
        _filterTasks();
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
    // This will be implemented when needed
    _safeContext.showSnackBar('Edit feature coming soon!', Colors.blue);
  }

  Future<void> _deleteTask(Task task) async {
    // This will be implemented when needed
    _safeContext.showSnackBar('Delete feature coming soon!', Colors.blue);
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.pushNamed(context, '/add_task');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/kanban');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  int get pendingTasksCount => tasks.where((task) => !task.completed).length;
  int get completedTasksCount => tasks.where((task) => task.completed).length;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _fetchTasks,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hello, $_userName!',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: _profilePictureUrl != null
                          ? NetworkImage(_profilePictureUrl!)
                          : const NetworkImage(
                              'https://via.placeholder.com/150'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Tasks',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$pendingTasksCount Tasks',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(fontSize: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Active',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completed Tasks',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$completedTasksCount Tasks',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(fontSize: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Done',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Recent Tasks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredTasks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                searchQuery.isEmpty
                                    ? 'No tasks yet. Create your first task!'
                                    : 'No tasks found matching "$searchQuery"',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              return Card(
                                child: ListTile(
                                  leading: Checkbox(
                                    value: task.completed,
                                    onChanged: (_) => _toggleTaskCompletion(task),
                                    activeColor: const Color(0xFFF8E1E1),
                                  ),
                                  title: Text(
                                    task.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          decoration: task.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                  subtitle: task.description.isNotEmpty
                                      ? Text(
                                          task.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: Text(
                                    '${task.todos.where((todo) => todo.completed).length}/${task.todos.length}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  onTap: () => _showTaskDetail(task),
                                ),
                              );
                            },
                          ),
              ],
            ),
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
