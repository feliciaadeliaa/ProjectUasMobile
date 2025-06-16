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
  _ProjectKanbanScreenState createState() => _ProjectKanbanScreenState();
}

class _ProjectKanbanScreenState extends State<ProjectKanbanScreen> {
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
        currentBoard = boards.first; // Use first board or default board
        
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
      } else {
        // No boards found, this shouldn't happen if project creation works correctly
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
    return allTasks.where((task) {
      // For now, we'll use task status to determine column
      // This is a simplified approach - in a full implementation,
      // tasks would have a columnId field
      if (columnId.contains('todo') || columnId.contains('To Do')) {
        return !task.completed && _getTaskProgress(task) == 0;
      } else if (columnId.contains('progress') || columnId.contains('In Progress')) {
        return !task.completed && _getTaskProgress(task) > 0 && _getTaskProgress(task) < 1;
      } else if (columnId.contains('review') || columnId.contains('Review')) {
        return !task.completed && _getTaskProgress(task) == 1;
      } else if (columnId.contains('done') || columnId.contains('Done')) {
        return task.completed;
      }
      return false;
    }).toList();
  }

  double _getTaskProgress(Task task) {
    if (task.todos.isEmpty) return 0.0;
    final completedTodos = task.todos.where((todo) => todo.completed).length;
    return completedTodos / task.todos.length;
  }

  Future<void> _createTask(String columnName) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _CreateTaskDialog(columnName: columnName),
    );

    if (result != null && currentBoard != null) {
      try {
        final task = Task(
          id: '',
          title: result['title']!,
          description: result['description'] ?? '',
          userId: widget.pb.authStore.model?.id ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          todos: [],
        );

        // Find the appropriate column
        final targetColumn = columns.firstWhere(
          (col) => col.name.toLowerCase().contains(columnName.toLowerCase()),
          orElse: () => columns.first,
        );

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
        
        _safeContext.showSnackBar('Task created successfully!', Colors.green);
      } catch (e) {
        _safeContext.showSnackBar('Failed to create task: $e', Colors.red);
      }
    }
  }

  void _showTaskDetail(Task task) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => TaskDetailDialog(
        task: task,
        onToggleTodo: (task, todoIndex) async {
          // TODO: Implement todo toggle
        },
        onToggleTask: (task) async {
          // TODO: Implement task toggle
        },
        onEditTask: (task) async {
          // TODO: Implement task edit
        },
        onDeleteTask: (task) async {
          // TODO: Implement task delete
        },
      ),
    );
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
        backgroundColor: projectColor.withOpacity(0.1),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadProjectData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                // TODO: Project settings
              } else if (value == 'members') {
                // TODO: Project members
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Project Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'members',
                child: Row(
                  children: [
                    Icon(Icons.people),
                    SizedBox(width: 8),
                    Text('Manage Members'),
                  ],
                ),
              ),
            ],
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
                      color: projectColor.withOpacity(0.1),
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
                                  title: column.name,
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
          const SizedBox(height: 8),
          Text(
            'Please wait while we prepare your kanban board',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required List<Task> tasks,
    required Color color,
    required VoidCallback onAddTask,
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
                  onPressed: onAddTask,
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

  const _CreateTaskDialog({required this.columnName});

  @override
  _CreateTaskDialogState createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Task to ${widget.columnName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Task Title *',
              hintText: 'Enter task title',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter task description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
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
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
