import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:taskflow/models/task.dart';
import '../services/task_service.dart';

class DebugPanel extends StatefulWidget {
  final PocketBase pb;

  const DebugPanel({super.key, required this.pb});

  @override
  _DebugPanelState createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late TaskService taskService;
  String debugInfo = '';

  @override
  void initState() {
    super.initState();
    taskService = TaskService(widget.pb);
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      debugInfo = 'Running diagnostics...\n';
    });

    // Test 1: PocketBase Connection
    try {
      final connectionOk = await taskService.testConnection();
      setState(() {
        debugInfo += connectionOk 
          ? '✅ PocketBase connection: OK\n' 
          : '❌ PocketBase connection: FAILED\n';
      });
    } catch (e) {
      setState(() {
        debugInfo += '❌ PocketBase connection error: $e\n';
      });
    }

    // Test 2: Authentication
    try {
      final authOk = await taskService.testAuth();
      final userId = widget.pb.authStore.model?.id;
      setState(() {
        debugInfo += authOk 
          ? '✅ Authentication: OK (User: $userId)\n' 
          : '❌ Authentication: FAILED\n';
      });
    } catch (e) {
      setState(() {
        debugInfo += '❌ Authentication error: $e\n';
      });
    }

    // Test 3: Collection Access
    try {
      await widget.pb.collection('tasks').getList(page: 1, perPage: 1);
      setState(() {
        debugInfo += '✅ Collection "tasks": ACCESSIBLE\n';
      });
    } catch (e) {
      setState(() {
        debugInfo += '❌ Collection "tasks" error: $e\n';
      });
    }

    // Test 4: User Collection Access
    try {
      final userId = widget.pb.authStore.model?.id;
      await widget.pb.collection('users').getOne(userId!);
      setState(() {
        debugInfo += '✅ User record: ACCESSIBLE\n';
      });
    } catch (e) {
      setState(() {
        debugInfo += '❌ User record error: $e\n';
      });
    }

    setState(() {
      debugInfo += '\n--- Diagnostics Complete ---\n';
    });
  }

  Future<void> _testCreateTask() async {
    setState(() {
      debugInfo += '\n🧪 Testing task creation...\n';
    });

    try {
      final testTask = Task(
        id: '',
        title: 'Test Task ${DateTime.now().millisecondsSinceEpoch}',
        description: 'This is a test task',
        userId: widget.pb.authStore.model?.id ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        todos: [
          Todo(title: 'Test todo 1', completed: false),
          Todo(title: 'Test todo 2', completed: true),
        ],
      );

      final createdTask = await taskService.createTask(testTask);
      setState(() {
        debugInfo += '✅ Test task created successfully!\n';
        debugInfo += 'Task ID: ${createdTask.id}\n';
        debugInfo += 'Task Title: ${createdTask.title}\n';
      });
    } catch (e) {
      setState(() {
        debugInfo += '❌ Test task creation failed: $e\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Panel'),
        backgroundColor: Colors.red[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PocketBase Debug Panel',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _runDiagnostics,
                  child: const Text('Run Diagnostics'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _testCreateTask,
                  child: const Text('Test Create Task'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    debugInfo.isEmpty ? 'Click "Run Diagnostics" to start...' : debugInfo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
