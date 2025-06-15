class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Todo> todos;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.completed = false,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.todos = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      completed: json['completed'] ?? false,
      userId: json['userId'] ?? '',
      createdAt: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
      todos: (json['todos'] as List<dynamic>?)
          ?.map((todo) => Todo.fromJson(todo as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'completed': completed,
      'userId': userId,
      'todos': todos.map((todo) => todo.toJson()).toList(),
    };
  }

  // Method untuk debugging
  @override
  String toString() {
    return 'Task{id: $id, title: $title, description: $description, completed: $completed, userId: $userId, todos: ${todos.length}}';
  }
}

class Todo {
  final String title;
  final bool completed;

  Todo({
    required this.title,
    this.completed = false,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      title: json['title'] ?? '',
      completed: json['completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'completed': completed,
    };
  }

  @override
  String toString() {
    return 'Todo{title: $title, completed: $completed}';
  }
}
