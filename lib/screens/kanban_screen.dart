import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class KanbanScreen extends StatefulWidget {
  final PocketBase pb;

  const KanbanScreen({super.key, required this.pb});

  @override
  _KanbanScreenState createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  int _selectedIndex = 2;
  List<Map<String, dynamic>> projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthAndFetchProjects();
  }

  Future<void> _checkAuthAndFetchProjects() async {
    if (!widget.pb.authStore.isValid) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please login to access projects';
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    try {
      final records = await widget.pb.collection('projects').getFullList();
      setState(() {
        projects = records.map((record) {
          final kanbanData = record.data['kanbanData'] as Map<String, dynamic>?;
          return {
            'id': record.id,
            'name': record.data['name'] ?? 'Untitled Project',
            'kanbanData': kanbanData != null
                ? kanbanData.map((key, value) => MapEntry(
                      key,
                      (value as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
                    ))
                : {
                    'To Do': [],
                    'In Progress': [],
                    'Done': [],
                  },
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch projects: ${e.toString()}';
      });
    }
  }

  Future<void> _addProject() async {
    if (!widget.pb.authStore.isValid) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    TextEditingController projectNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add New Project',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: TextField(
            controller: projectNameController,
            decoration: const InputDecoration(
              labelText: 'Project Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (projectNameController.text.isNotEmpty) {
                  try {
                    final record = await widget.pb.collection('projects').create(
                      body: {
                        'name': projectNameController.text,
                        'kanbanData': {
                          'To Do': [],
                          'In Progress': [],
                          'Done': [],
                        },
                      },
                    );
                    setState(() {
                      projects.add({
                        'id': record.id,
                        'name': record.data['name'],
                        'kanbanData': record.data['kanbanData'],
                      });
                    });
                    Navigator.pop(context);
                  } catch (e) {
                    if (e is ClientException && e.statusCode == 403) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Permission denied. Only superusers can add projects. Please contact an admin.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add project: ${e.toString()}')),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Projects',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addProject,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : projects.isEmpty
                          ? Center(
                              child: Text(
                                'No projects yet. Add a new project to get started.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      projects[index]['name'],
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProjectKanbanScreen(
                                            pb: widget.pb,
                                            projectId: projects[index]['id'],
                                            projectName: projects[index]['name'],
                                            kanbanData: projects[index]['kanbanData'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
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

class ProjectKanbanScreen extends StatefulWidget {
  final PocketBase pb;
  final String projectId;
  final String projectName;
  final Map<String, List<Map<String, dynamic>>> kanbanData;

  const ProjectKanbanScreen({
    super.key,
    required this.pb,
    required this.projectId,
    required this.projectName,
    required this.kanbanData,
  });

  @override
  _ProjectKanbanScreenState createState() => _ProjectKanbanScreenState();
}

class _ProjectKanbanScreenState extends State<ProjectKanbanScreen> {
  late Map<String, List<Map<String, dynamic>>> kanbanData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      kanbanData = widget.kanbanData.map((key, value) {
        if (value is List) {
          return MapEntry(key, value.cast<Map<String, dynamic>>());
        }
        return MapEntry(key, <Map<String, dynamic>>[]);
      });
      kanbanData.putIfAbsent('To Do', () => []);
      kanbanData.putIfAbsent('In Progress', () => []);
      kanbanData.putIfAbsent('Done', () => []);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing Kanban data: ${e.toString()}';
      });
      kanbanData = {
        'To Do': [],
        'In Progress': [],
        'Done': [],
      };
    }
  }

  Future<void> _saveKanbanData() async {
    try {
      await widget.pb.collection('projects').update(
        widget.projectId,
        body: {'kanbanData': kanbanData},
      );
    } catch (e) {
      if (e is ClientException && e.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Permission denied. Only superusers can update projects. Please contact an admin.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save Kanban data: ${e.toString()}')),
        );
      }
    }
  }

  void _onTaskDropped(String newColumn, Map<String, dynamic> task, String oldColumn) {
    setState(() {
      kanbanData[oldColumn]?.remove(task);
      kanbanData[newColumn]?.add(task);
    });
    _saveKanbanData();
  }

  Future<void> _addTask() async {
    TextEditingController titleController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add New Task',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    kanbanData['To Do']?.add({
                      'title': titleController.text,
                      'description': descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : 'No description',
                    });
                  });
                  await _saveKanbanData();
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

  Future<void> _addKanbanColumn() async {
    TextEditingController columnNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add New Column',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: TextField(
            controller: columnNameController,
            decoration: const InputDecoration(
              labelText: 'Column Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (columnNameController.text.isNotEmpty) {
                  if (kanbanData.containsKey(columnNameController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Column name already exists!')),
                    );
                    return;
                  }
                  setState(() {
                    kanbanData[columnNameController.text] = [];
                  });
                  await _saveKanbanData();
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

  void _deleteKanbanColumn(String columnTitle) {
    if (['To Do', 'In Progress', 'Done'].contains(columnTitle)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default columns cannot be deleted!')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete Column',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: Text('Are you sure you want to delete the column "$columnTitle"?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  kanbanData.remove(columnTitle);
                });
                await _saveKanbanData();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.projectName,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTask,
                    ),
                    IconButton(
                      icon: const Icon(Icons.view_kanban),
                      onPressed: _addKanbanColumn,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: kanbanData.keys.map((column) {
                    return _buildKanbanColumn(context, column, kanbanData[column] ?? []);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
      BuildContext context, String columnTitle, List<Map<String, dynamic>> tasks) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        columnTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${tasks.length} Tasks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _deleteKanbanColumn(columnTitle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DragTarget<Map<String, dynamic>>(
                onAccept: (task) {
                  _onTaskDropped(columnTitle, task, task['currentColumn']);
                },
                builder: (context, candidateData, rejectedData) {
                  return Card(
                    child: tasks.isEmpty
                        ? Center(
                            child: Text(
                              'No tasks yet',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return Draggable<Map<String, dynamic>>(
                                data: {...task, 'currentColumn': columnTitle},
                                feedback: Material(
                                  elevation: 4.0,
                                  child: Container(
                                    width: 280,
                                    padding: const EdgeInsets.all(8.0),
                                    color: Theme.of(context).cardColor,
                                    child: Text(
                                      task['title'] ?? 'Untitled Task',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                                childWhenDragging: Container(),
                                child: Card(
                                  child: ListTile(
                                    title: Text(
                                      task['title'] ?? 'Untitled Task',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    subtitle: Text(
                                      task['description'] ?? 'No description',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    onTap: () {},
                                  ),
                                ),
                              );
                            },
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
}