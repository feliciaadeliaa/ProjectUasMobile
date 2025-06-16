import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/project_models.dart';
import '../services/project_service.dart';
import '../utils/safe_context.dart';
import 'project_kanban_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final PocketBase pb;

  const ProjectsScreen({super.key, required this.pb});

  @override
  _ProjectsScreenState createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> projects = [];
  bool _isLoading = true;
  late ProjectService projectService;
  late SafeContext _safeContext;
  int _selectedIndex = 4; // New tab for projects

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
      _fetchProjects();
    }
  }

  @override
  void dispose() {
    _safeContext.dispose();
    super.dispose();
  }

  Future<void> _fetchProjects() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedProjects = await projectService.getProjects();
      if (!mounted) return;
      
      setState(() {
        projects = fetchedProjects;
        _isLoading = false;
      });
      debugPrint('✅ Successfully fetched ${projects.length} projects');
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ Error fetching projects: $e');
      _safeContext.showSnackBar('Failed to fetch projects: $e', Colors.red);
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _CreateProjectDialog(),
    );

    if (result != null) {
      try {
        final project = Project(
          id: '',
          name: result['name']!,
          description: result['description']!,
          color: result['color'] ?? '#6366F1',
          icon: result['icon'] ?? 'folder',
          userId: widget.pb.authStore.model?.id ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdProject = await projectService.createProject(project);
        
        if (!mounted) return;
        
        setState(() {
          projects.insert(0, createdProject);
        });
        
        _safeContext.showSnackBar('Project created successfully!', Colors.green);
      } catch (e) {
        _safeContext.showSnackBar('Failed to create project: $e', Colors.red);
      }
    }
  }

  void _openProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectKanbanScreen(
          pb: widget.pb,
          project: project,
        ),
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
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/projects'); // Updated from '/kanban' to '/projects'
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchProjects,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProjects,
              child: projects.isEmpty
                  ? _buildEmptyState()
                  : _buildProjectsList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
        tooltip: 'Create Project',
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add Task'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: 'Projects'), // Updated icon and label
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Projects Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first project to organize your tasks',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add),
            label: const Text('Create Project'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${projects.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'Total Projects',
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
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${projects.fold(0, (sum, p) => sum + p.totalTasks)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Projects Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return _buildProjectCard(project);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final color = Color(int.parse(project.color.replaceFirst('#', '0xFF')));
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openProject(project),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Icon and Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconData(project.icon),
                      color: color,
                      size: 24,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        // TODO: Edit project
                      } else if (value == 'delete') {
                        // TODO: Delete project
                      }
                    },
                    itemBuilder: (context) => [
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
                    child: Icon(Icons.more_vert, color: Colors.grey[600]),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Project Name
              Text(
                project.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Project Description
              if (project.description.isNotEmpty) ...[
                Text(
                  project.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              
              const Spacer(),
              
              // Progress and Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${project.totalTasks} Tasks',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (project.totalTasks > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${project.completionPercentage.round()}% Complete',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (project.totalTasks > 0)
                    CircularProgressIndicator(
                      value: project.completionPercentage / 100,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

class _CreateProjectDialog extends StatefulWidget {
  @override
  _CreateProjectDialogState createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedColor = '#6366F1';
  String _selectedIcon = 'folder';

  final List<Map<String, dynamic>> _colors = [
    {'name': 'Blue', 'value': '#6366F1'},
    {'name': 'Green', 'value': '#10B981'},
    {'name': 'Purple', 'value': '#8B5CF6'},
    {'name': 'Red', 'value': '#EF4444'},
    {'name': 'Orange', 'value': '#F59E0B'},
    {'name': 'Pink', 'value': '#EC4899'},
  ];

  final List<Map<String, dynamic>> _icons = [
    {'name': 'Folder', 'value': 'folder', 'icon': Icons.folder},
    {'name': 'Work', 'value': 'work', 'icon': Icons.work},
    {'name': 'Home', 'value': 'home', 'icon': Icons.home},
    {'name': 'School', 'value': 'school', 'icon': Icons.school},
    {'name': 'Shopping', 'value': 'shopping', 'icon': Icons.shopping_cart},
    {'name': 'Health', 'value': 'health', 'icon': Icons.favorite},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Project'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name *',
                hintText: 'Enter project name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 16),
            
            // Project Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter project description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            
            const SizedBox(height: 16),
            
            // Color Selection
            const Text(
              'Choose Color:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((colorData) {
                final color = Color(int.parse(colorData['value'].replaceFirst('#', '0xFF')));
                final isSelected = _selectedColor == colorData['value'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorData['value'];
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Icon Selection
            const Text(
              'Choose Icon:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((iconData) {
                final isSelected = _selectedIcon == iconData['value'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = iconData['value'];
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[100] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.blue, width: 2)
                          : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Icon(
                      iconData['icon'],
                      color: isSelected ? Colors.blue : Colors.grey[600],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter project name')),
              );
              return;
            }
            
            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'description': _descriptionController.text.trim(),
              'color': _selectedColor,
              'icon': _selectedIcon,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
