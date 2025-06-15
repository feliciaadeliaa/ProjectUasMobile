import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task.dart';
import '../utils/safe_context.dart';

class TaskDetailDialog extends StatefulWidget {
  final Task task;
  final Function(Task, int) onToggleTodo;
  final Function(Task) onToggleTask;
  final Function(Task) onEditTask;
  final Function(Task) onDeleteTask;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.onToggleTodo,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onDeleteTask,
  });

  @override
  _TaskDetailDialogState createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  late Task currentTask;
  bool isUpdating = false;
  late SafeContext _safeContext;
  final List<Completer> _activeOperations = [];

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

  Future<void> _toggleTask() async {
    if (!mounted || isUpdating) return;
    
    setState(() {
      isUpdating = true;
    });

    try {
      await _safeAsyncOperation(() => widget.onToggleTask(currentTask));
      
      if (!mounted) return;
      
      setState(() {
        currentTask = Task(
          id: currentTask.id,
          title: currentTask.title,
          description: currentTask.description,
          completed: !currentTask.completed,
          userId: currentTask.userId,
          createdAt: currentTask.createdAt,
          updatedAt: DateTime.now(),
          todos: currentTask.todos,
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
      await _safeAsyncOperation(() => widget.onToggleTodo(currentTask, index));
      
      if (!mounted) return;
      
      final updatedTodos = List<Todo>.from(currentTask.todos);
      updatedTodos[index] = Todo(
        title: updatedTodos[index].title,
        completed: !updatedTodos[index].completed,
      );
      
      setState(() {
        currentTask = Task(
          id: currentTask.id,
          title: currentTask.title,
          description: currentTask.description,
          completed: currentTask.completed,
          userId: currentTask.userId,
          createdAt: currentTask.createdAt,
          updatedAt: DateTime.now(),
          todos: updatedTodos,
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

  @override
  Widget build(BuildContext context) {
    final completedTodos = currentTask.todos.where((todo) => todo.completed).length;
    final totalTodos = currentTask.todos.length;
    final progressPercentage = totalTodos > 0 ? (completedTodos / totalTodos * 100).round() : 0;

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
              // Task Status Card
              Card(
                color: currentTask.completed ? Colors.green[50] : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isUpdating ? null : _toggleTask,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: currentTask.completed ? Colors.green : Colors.transparent,
                            border: Border.all(
                              color: currentTask.completed ? Colors.green : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: currentTask.completed
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTask.completed ? 'Task Completed' : 'Task Pending',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: currentTask.completed ? Colors.green[700] : Colors.orange[700],
                              ),
                            ),
                            Text(
                              'Tap to ${currentTask.completed ? 'mark as pending' : 'mark as completed'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

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
                        color: progressPercentage == 100 ? Colors.green[100] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedTodos/$totalTodos ($progressPercentage%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: progressPercentage == 100 ? Colors.green[700] : Colors.blue[700],
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
                    widthFactor: totalTodos > 0 ? completedTodos / totalTodos : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressPercentage == 100 ? Colors.green : Colors.blue,
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
                          trailing: todo.completed
                              ? Icon(Icons.check_circle, color: Colors.green[600], size: 16)
                              : Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 16),
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
          onPressed: () {
            Navigator.pop(context);
            widget.onDeleteTask(currentTask);
          },
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
}
