import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/enhanced_task_models.dart';
import '../models/task.dart';
import '../services/enhanced_task_service.dart';
import '../utils/safe_context.dart';

class EnhancedAddTaskScreen extends StatefulWidget {
  final PocketBase pb;

  const EnhancedAddTaskScreen({super.key, required this.pb});

  @override
  _EnhancedAddTaskScreenState createState() => _EnhancedAddTaskScreenState();
}

class _EnhancedAddTaskScreenState extends State<EnhancedAddTaskScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  late EnhancedTaskService taskService;
  late SafeContext _safeContext;
  late TabController _tabController;
  
  // Task properties
  TaskCategory? _selectedCategory;
  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskStatus _selectedStatus = TaskStatus.todo;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  double _estimatedHours = 0;
  List<TaskLabel> _selectedLabels = [];
  List<Todo> _todos = [];
  
  // Data lists
  List<TaskCategory> _categories = [];
  List<TaskLabel> _availableLabels = [];
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    taskService = EnhancedTaskService(widget.pb);
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeContext = SafeContext(context);
  }

  @override
  void dispose() {
    _safeContext.dispose();
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final categories = await taskService.getTaskCategories();
      final labels = await taskService.getTaskLabels();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _availableLabels = labels;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        _safeContext.showSnackBar('Failed to load data: $e', Colors.red);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    
    if (time != null) {
      setState(() {
        _dueTime = time;
      });
    }
  }

  void _addTodo() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Todo Item'),
          content: TextField(
            controller: controller,
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
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _todos.add(Todo(title: controller.text.trim()));
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

  void _toggleLabel(TaskLabel label) {
    setState(() {
      if (_selectedLabels.contains(label)) {
        _selectedLabels.remove(label);
      } else {
        _selectedLabels.add(label);
      }
    });
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime? finalDueDate;
      if (_dueDate != null) {
        finalDueDate = _dueDate!;
        if (_dueTime != null) {
          finalDueDate = DateTime(
            _dueDate!.year,
            _dueDate!.month,
            _dueDate!.day,
            _dueTime!.hour,
            _dueTime!.minute,
          );
        }
      }

      final task = EnhancedTask(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        todos: _todos,
        categoryId: _selectedCategory?.id,
        priority: _selectedPriority,
        status: _selectedStatus,
        dueDate: finalDueDate,
        estimatedHours: _estimatedHours,
        labels: _selectedLabels,
      );

      await taskService.createEnhancedTask(task);
      
      if (mounted) {
        _safeContext.showSnackBar('Task created successfully!', Colors.green);
        _resetForm();
        _tabController.animateTo(0); // Go back to basic tab
      }
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

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedPriority = TaskPriority.medium;
      _selectedStatus = TaskStatus.todo;
      _dueDate = null;
      _dueTime = null;
      _estimatedHours = 0;
      _selectedLabels.clear();
      _todos.clear();
    });
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/projects');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Basic'),
            Tab(icon: Icon(Icons.tune), text: 'Details'),
            Tab(icon: Icon(Icons.checklist), text: 'Todos'),
          ],
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicTab(),
                  _buildDetailsTab(),
                  _buildTodosTab(),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add Task'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _createTask,
        icon: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Creating...' : 'Create Task'),
      ),
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Task Title *',
              hintText: 'Enter task title...',
              prefixIcon: Icon(Icons.title),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a task title';
              }
              return null;
            },
            textCapitalization: TextCapitalization.sentences,
          ),
          
          const SizedBox(height: 16),
          
          // Task Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter task description...',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          
          const SizedBox(height: 16),
          
          // Category Selection
          DropdownButtonFormField<TaskCategory>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Priority Selection
          const Text(
            'Priority',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TaskPriority.values.map((priority) {
              final isSelected = _selectedPriority == priority;
              Color priorityColor;
              switch (priority) {
                case TaskPriority.low:
                  priorityColor = Colors.green;
                  break;
                case TaskPriority.medium:
                  priorityColor = Colors.orange;
                  break;
                case TaskPriority.high:
                  priorityColor = Colors.red;
                  break;
                case TaskPriority.urgent:
                  priorityColor = Colors.purple;
                  break;
              }
              
              return FilterChip(
                label: Text(priority.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPriority = priority;
                  });
                },
                backgroundColor: priorityColor.withOpacity(0.1),
                selectedColor: priorityColor.withOpacity(0.3),
                checkmarkColor: priorityColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Selection
          const Text(
            'Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TaskStatus.values.map((status) {
              final isSelected = _selectedStatus == status;
              return FilterChip(
                label: Text(status.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Due Date & Time
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Due Date'),
                  subtitle: Text(_dueDate != null 
                      ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                      : 'No due date'),
                  leading: const Icon(Icons.calendar_today),
                  onTap: _selectDueDate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ListTile(
                  title: const Text('Due Time'),
                  subtitle: Text(_dueTime != null 
                      ? _dueTime!.format(context)
                      : 'No time set'),
                  leading: const Icon(Icons.access_time),
                  onTap: _dueDate != null ? _selectDueTime : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Estimated Hours
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Estimated Hours',
              hintText: 'Enter estimated hours...',
              prefixIcon: Icon(Icons.timer),
              border: OutlineInputBorder(),
              suffixText: 'hours',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _estimatedHours = double.tryParse(value) ?? 0;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Labels Selection
          const Text(
            'Labels',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLabels.map((label) {
              final isSelected = _selectedLabels.contains(label);
              return FilterChip(
                label: Text(label.name),
                selected: isSelected,
                onSelected: (selected) => _toggleLabel(label),
                backgroundColor: Color(int.parse(label.color.replaceFirst('#', '0xFF')))
                    .withOpacity(0.1),
                selectedColor: Color(int.parse(label.color.replaceFirst('#', '0xFF')))
                    .withOpacity(0.3),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodosTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Todo Items (${_todos.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _addTodo,
                icon: const Icon(Icons.add),
                label: const Text('Add Todo'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No todo items yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add todo items to break down your task',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        child: ListTile(
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
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeTodo(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
