import 'package:flutter/material.dart';
import '../models/task.dart';

class EnhancedEditTaskDialog extends StatefulWidget {
  final Task task;
  final Future<Task> Function(Task) onSave;

  const EnhancedEditTaskDialog({
    super.key,
    required this.task,
    required this.onSave,
  });

  @override
  _EnhancedEditTaskDialogState createState() => _EnhancedEditTaskDialogState();
}

class _EnhancedEditTaskDialogState extends State<EnhancedEditTaskDialog> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late List<Map<String, dynamic>> todos;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.task.title);
    descriptionController = TextEditingController(text: widget.task.description);
    
    // Convert todos to Map format
    todos = widget.task.todos.map((todo) {
      return {
        'title': todo.title,
        'completed': todo.completed,
      };
    }).toList();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _addTodo() {
    TextEditingController todoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add To-Do'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: TextField(
            controller: todoController,
            decoration: const InputDecoration(labelText: 'To-Do'),
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
                    todos.add({
                      'title': todoController.text.trim(),
                      'completed': false,
                    });
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

  void _editTodo(int index) {
    TextEditingController todoController = TextEditingController(text: todos[index]['title']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit To-Do'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: TextField(
            controller: todoController,
            decoration: const InputDecoration(labelText: 'To-Do'),
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
                    todos[index] = {
                      'title': todoController.text.trim(),
                      'completed': todos[index]['completed'],
                    };
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _removeTodo(int index) {
    setState(() {
      todos.removeAt(index);
    });
  }

  void _toggleTodo(int index) {
    setState(() {
      todos[index]['completed'] = !todos[index]['completed'];
    });
  }

  Future<void> _saveTask() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Convert Map back to Todo objects
      final todoObjects = todos.map((todoMap) {
        return Todo(
          title: todoMap['title'] ?? '',
          completed: todoMap['completed'] ?? false,
        );
      }).toList();

      final updatedTask = Task(
        id: widget.task.id,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        completed: widget.task.completed,
        userId: widget.task.userId,
        createdAt: widget.task.createdAt,
        updatedAt: DateTime.now(),
        todos: todoObjects,
      );

      final savedTask = await widget.onSave(updatedTask);
      Navigator.pop(context, savedTask);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Task'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title *',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              
              // Todos Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'To-Do Items (${todos.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _addTodo,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add To-Do',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (todos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No to-do items yet'),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return ListTile(
                        dense: true,
                        leading: Checkbox(
                          value: todo['completed'] ?? false,
                          onChanged: (_) => _toggleTodo(index),
                        ),
                        title: Text(
                          todo['title'] ?? '',
                          style: TextStyle(
                            decoration: (todo['completed'] ?? false)
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editTodo(index),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _removeTodo(index),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _saveTask,
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
