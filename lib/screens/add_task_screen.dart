import 'package:flutter/material.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  TextEditingController taskTitleController = TextEditingController();
  List<Map<String, dynamic>> tasks = []; // List untuk menyimpan task
  int _selectedIndex = 1;

  void _onItemTapped(int index) {
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

  // Fungsi untuk menambahkan task baru
  void _addTask() {
    if (taskTitleController.text.isNotEmpty) {
      setState(() {
        tasks.add({
          'title': taskTitleController.text,
          'todos': <Map<String, dynamic>>[], // Inisialisasi to-do list kosong
        });
        taskTitleController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a task title',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
        ),
      );
    }
  }

  // Fungsi untuk menambahkan to-do ke task tertentu
  void _addTodoToTask(int taskIndex) {
    TextEditingController todoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add To-Do',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 20,
                ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Theme.of(context).cardColor,
          content: TextField(
            controller: todoController,
            decoration: const InputDecoration(
              labelText: 'To-Do',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (todoController.text.isNotEmpty) {
                  setState(() {
                    tasks[taskIndex]['todos'].add({
                      'title': todoController.text,
                      'completed': false,
                    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'Add New Task',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Add Task'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Tasks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks yet. Add a task to get started.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          color: Theme.of(context).cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tasks[index]['title'],
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => _addTodoToTask(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                tasks[index]['todos'].isEmpty
                                    ? Text(
                                        'No to-dos yet.',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: tasks[index]['todos'].length,
                                        itemBuilder: (context, todoIndex) {
                                          return CheckboxListTile(
                                            title: Text(
                                              tasks[index]['todos'][todoIndex]['title'],
                                              style: TextStyle(
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                            value: tasks[index]['todos'][todoIndex]['completed'],
                                            activeColor: const Color(0xFFF8E1E1),
                                            onChanged: (value) {
                                              setState(() {
                                                tasks[index]['todos'][todoIndex]['completed'] = value!;
                                              });
                                            },
                                            checkColor: Colors.black87,
                                            tileColor: Theme.of(context).cardColor,
                                            controlAffinity: ListTileControlAffinity.leading,
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (tasks.isNotEmpty) {
                  Navigator.pushReplacementNamed(context, '/');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please add at least one task',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : Colors.white,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save All Tasks', style: TextStyle(fontSize: 16)),
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
        selectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white70
            : Colors.black87,
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white54
            : Colors.black54,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        elevation: 8,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}