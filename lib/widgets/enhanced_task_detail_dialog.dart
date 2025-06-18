import 'package:flutter/material.dart';
import 'package:taskflow/models/task.dart';
import '../models/enhanced_task_models.dart';
import '../utils/safe_context.dart';

class EnhancedTaskDetailDialog extends StatefulWidget {
  final EnhancedTask task;
  final Function(EnhancedTask, int) onToggleTodo;
  final Function(EnhancedTask) onToggleTask;
  final Function(EnhancedTask) onEditTask;
  final Function(EnhancedTask) onDeleteTask;
  final Function(EnhancedTask, TaskStatus) onUpdateStatus;
  final Function(EnhancedTask, TaskPriority) onUpdatePriority;

  const EnhancedTaskDetailDialog({
    super.key,
    required this.task,
    required this.onToggleTodo,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onUpdateStatus,
    required this.onUpdatePriority,
  });

  @override
  _EnhancedTaskDetailDialogState createState() => _EnhancedTaskDetailDialogState();
}

class _EnhancedTaskDetailDialogState extends State<EnhancedTaskDetailDialog> {
  late EnhancedTask currentTask;
  bool isUpdating = false;
  late SafeContext _safeContext;

  @override
  void initState() {
    super.initState();
    currentTask = widget.task;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
  }

  @override
  void dispose() {
    _safeContext.dispose();
    super.dispose();
  }

  Future<void> _toggleTask() async {
    if (!mounted || isUpdating) return;
    
    setState(() {
      isUpdating = true;
    });

    try {
      await widget.onToggleTask(currentTask);
      
      if (!mounted) return;
      
      setState(() {
        currentTask = EnhancedTask(
          id: currentTask.id,
          title: currentTask.title,
          description: currentTask.description,
          completed: !currentTask.completed,
          userId: currentTask.userId,
          createdAt: currentTask.createdAt,
          updatedAt: DateTime.now(),
          todos: currentTask.todos,
          priority: currentTask.priority,
          status: currentTask.completed ? TaskStatus.todo : TaskStatus.done,
          dueDate: currentTask.dueDate,
          estimatedHours: currentTask.estimatedHours,
          actualHours: currentTask.actualHours,
        );
      });
    } catch (e) {
      _safeContext.showSnackBar('Failed to update task: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> _toggleTodo(int index) async {
    if (!mounted || isUpdating || index < 0 || index >= currentTask.todos.length) return;

    setState(() {
      isUpdating = true;
    });

    try {
      await widget.onToggleTodo(currentTask, index);
      
      if (!mounted) return;
      
      final updatedTodos = List<Todo>.from(currentTask.todos);
      updatedTodos[index] = Todo(
        title: updatedTodos[index].title,
        completed: !updatedTodos[index].completed,
      );
      
      setState(() {
        currentTask = EnhancedTask(
          id: currentTask.id,
          title: currentTask.title,
          description: currentTask.description,
          completed: currentTask.completed,
          userId: currentTask.userId,
          createdAt: currentTask.createdAt,
          updatedAt: DateTime.now(),
          todos: updatedTodos,
          priority: currentTask.priority,
          status: currentTask.status,
          dueDate: currentTask.dueDate,
          estimatedHours: currentTask.estimatedHours,
          actualHours: currentTask.actualHours,
        );
      });
    } catch (e) {
      _safeContext.showSnackBar('Failed to update todo: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  void _showStatusSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...TaskStatus.values.map((status) {
                final isSelected = currentTask.status == status;
                return ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(status.displayName),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      widget.onUpdateStatus(currentTask, status);
                      setState(() {
                        currentTask = EnhancedTask(
                          id: currentTask.id,
                          title: currentTask.title,
                          description: currentTask.description,
                          completed: status == TaskStatus.done,
                          userId: currentTask.userId,
                          createdAt: currentTask.createdAt,
                          updatedAt: DateTime.now(),
                          todos: currentTask.todos,
                          priority: currentTask.priority,
                          status: status,
                          dueDate: currentTask.dueDate,
                          estimatedHours: currentTask.estimatedHours,
                          actualHours: currentTask.actualHours,
                        );
                      });
                    }
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showPrioritySelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change Priority',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...TaskPriority.values.map((priority) {
                final isSelected = currentTask.priority == priority;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(priority),
                      ),
                    ),
                  ),
                  title: Text(priority.displayName),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      widget.onUpdatePriority(currentTask, priority);
                      setState(() {
                        currentTask = EnhancedTask(
                          id: currentTask.id,
                          title: currentTask.title,
                          description: currentTask.description,
                          completed: currentTask.completed,
                          userId: currentTask.userId,
                          createdAt: currentTask.createdAt,
                          updatedAt: DateTime.now(),
                          todos: currentTask.todos,
                          priority: priority,
                          status: currentTask.status,
                          dueDate: currentTask.dueDate,
                          estimatedHours: currentTask.estimatedHours,
                          actualHours: currentTask.actualHours,
                        );
                      });
                    }
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedTodos = currentTask.todos.where((todo) => todo.completed).length;
    final totalTodos = currentTask.todos.length;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              currentTask.title,
              style: TextStyle(
                decoration: currentTask.completed ? TextDecoration.lineThrough : null,
                color: currentTask.completed ? Colors.grey[600] : null,
              ),
            ),
          ),
          if (isUpdating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status and Priority Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showStatusSelector,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(currentTask.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getStatusColor(currentTask.status).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(currentTask.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  currentTask.status.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showPrioritySelector,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(currentTask.priority).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getPriorityColor(currentTask.priority).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Priority',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(currentTask.priority).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                currentTask.priority.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getPriorityColor(currentTask.priority),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              // Due Date Info
              if (currentTask.dueDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: currentTask.isOverdue ? Colors.red[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentTask.isOverdue ? Colors.red[200]! : Colors.blue[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        currentTask.isOverdue ? Icons.warning : Icons.schedule,
                        color: currentTask.isOverdue ? Colors.red : Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTask.isOverdue ? 'Overdue' : 'Due Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: currentTask.isOverdue ? Colors.red[700] : Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${currentTask.dueDate!.day}/${currentTask.dueDate!.month}/${currentTask.dueDate!.year}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentTask.isOverdue ? Colors.red[700] : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description
              if (currentTask.description.isNotEmpty) ...[
                Text(
                  'Description:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(currentTask.description),
                ),
                const SizedBox(height: 16),
              ],

              // To-Do Items
              if (currentTask.todos.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'To-Do Items:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentTask.progressPercentage == 100 ? Colors.green[100] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedTodos/$totalTodos (${currentTask.progressPercentage.round()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: currentTask.progressPercentage == 100 ? Colors.green[700] : Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Progress Bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: currentTask.progressPercentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: currentTask.progressPercentage == 100 ? Colors.green : Colors.blue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Todo List
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentTask.todos.length,
                    itemBuilder: (context, index) {
                      final todo = currentTask.todos[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: todo.completed ? Colors.green[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: todo.completed ? Colors.green[200]! : Colors.grey[300]!,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: GestureDetector(
                            onTap: isUpdating ? null : () => _toggleTodo(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: todo.completed ? Colors.green : Colors.transparent,
                                border: Border.all(
                                  color: todo.completed ? Colors.green : Colors.grey,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: todo.completed
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 12,
                                    )
                                  : null,
                            ),
                          ),
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              decoration: todo.completed ? TextDecoration.lineThrough : null,
                              color: todo.completed ? Colors.grey[600] : null,
                            ),
                          ),
                          onTap: isUpdating ? null : () => _toggleTodo(index),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No to-do items for this task',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Task Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Created: ${currentTask.createdAt.day}/${currentTask.createdAt.month}/${currentTask.createdAt.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.update, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Updated: ${currentTask.updatedAt.day}/${currentTask.updatedAt.month}/${currentTask.updatedAt.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    if (currentTask.estimatedHours > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Estimated: ${currentTask.estimatedHours}h',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            widget.onEditTask(currentTask);
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        ),
        ElevatedButton.icon(
          onPressed: () => widget.onDeleteTask(currentTask),
          icon: const Icon(Icons.delete),
          label: const Text('Delete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.orange;
      case TaskStatus.review:
        return Colors.blue;
      case TaskStatus.done:
        return Colors.green;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.purple;
    }
  }
}
