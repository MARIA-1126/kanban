import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2D6CDF),
          secondary: Color(0xFF2D6CDF),
          surface: Color(0xFFF5F7FB),
        ),
        useMaterial3: true,
      ),
      home: const KanbanHomePage(),
    );
  }
}

enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, done }

class KanbanTask {
  KanbanTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.status,
  });

  final String id;
  String title;
  String description;
  TaskPriority priority;
  DateTime dueDate;
  TaskStatus status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.name,
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
    };
  }

  static KanbanTask fromJson(Map<String, dynamic> json) {
    return KanbanTask(
      id: (json['id'] as String?) ?? UniqueKey().toString(),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == (json['priority'] as String?),
        orElse: () => TaskPriority.low,
      ),
      dueDate:
          DateTime.tryParse((json['dueDate'] as String?) ?? '') ??
          DateTime.now(),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String?),
        orElse: () => TaskStatus.todo,
      ),
    );
  }
}

class KanbanHomePage extends StatefulWidget {
  const KanbanHomePage({super.key});

  @override
  State<KanbanHomePage> createState() => _KanbanHomePageState();
}

class _KanbanHomePageState extends State<KanbanHomePage> {
  static const String _storageKey = 'kanban_tasks_v1';

  final List<KanbanTask> _tasks = [];

  bool _loading = true;

  TaskPriority? _priorityFilter; // null means All

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw == null || raw.trim().isEmpty) {
        // Seed with a couple of tasks so the UI is not empty.
        _tasks
          ..clear()
          ..addAll([
            KanbanTask(
              id: UniqueKey().toString(),
              title: 'Welcome',
              description: 'Add your own tasks using the + button.',
              priority: TaskPriority.low,
              dueDate: DateTime.now().add(const Duration(days: 2)),
              status: TaskStatus.todo,
            ),
            KanbanTask(
              id: UniqueKey().toString(),
              title: 'Try dragging',
              description: 'Long-press a card and drop it in another column.',
              priority: TaskPriority.medium,
              dueDate: DateTime.now().add(const Duration(days: 4)),
              status: TaskStatus.inProgress,
            ),
          ]);
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _tasks
            ..clear()
            ..addAll(
              decoded.whereType<Map<String, dynamic>>().map(
                (e) => KanbanTask.fromJson(e),
              ),
            );
        }
      }
    } catch (_) {
      // In case of corrupted storage, fall back to empty.
      _tasks.clear();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveTasks() async {
    // Simple approach: save whole list as JSON each time.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (_) {
      // ignore (in a beginner app we keep it simple)
    }
  }

  List<KanbanTask> _tasksForColumn(TaskStatus status) {
    return _tasks.where((t) {
      final matchesStatus = t.status == status;
      final matchesFilter =
          _priorityFilter == null || t.priority == _priorityFilter;
      return matchesStatus && matchesFilter;
    }).toList();
  }

  void _updateTaskStatus(String taskId, TaskStatus newStatus) {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    setState(() {
      _tasks[idx].status = newStatus;
    });
    _saveTasks();
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return const Color(0xFF34A853); // green
      case TaskPriority.medium:
        return const Color(0xFFF2994A); // orange
      case TaskPriority.high:
        return const Color(0xFFEA4335); // red
    }
  }

  String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String _formatDueDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _showAddTaskSheet() async {
    final now = DateTime.now();

    final titleController = TextEditingController();
    final descController = TextEditingController();

    DateTime due = now.add(const Duration(days: 7));
    TaskPriority priority = TaskPriority.low;
    TaskStatus status = TaskStatus.todo;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Task',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_formatDueDate(due))),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: due,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setModalState(() => due = picked);
                                  }
                                },
                                child: const Text('Pick'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TaskPriority>(
                              value: priority,
                              isExpanded: true,
                              items: TaskPriority.values.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _priorityColor(p),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(_priorityLabel(p)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() => priority = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quick initial column selection (simple and helpful)
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start in',
                            border: OutlineInputBorder(),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TaskStatus>(
                              value: status,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: TaskStatus.todo,
                                  child: Text('To Do'),
                                ),
                                DropdownMenuItem(
                                  value: TaskStatus.inProgress,
                                  child: Text('In Progress'),
                                ),
                                DropdownMenuItem(
                                  value: TaskStatus.done,
                                  child: Text('Done'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() => status = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final desc = descController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Title is required')),
                          );
                          return;
                        }

                        final task = KanbanTask(
                          id: UniqueKey().toString(),
                          title: title,
                          description: desc,
                          priority: priority,
                          dueDate: due,
                          status: status,
                        );

                        setState(() {
                          _tasks.add(task);
                        });
                        _saveTasks();

                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditTaskSheet(KanbanTask task) async {
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);

    DateTime due = task.dueDate;
    TaskPriority priority = task.priority;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Edit Task',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_formatDueDate(due))),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: due,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setModalState(() => due = picked);
                                  }
                                },
                                child: const Text('Pick'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TaskPriority>(
                        value: priority,
                        isExpanded: true,
                        items: TaskPriority.values.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _priorityColor(p),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(_priorityLabel(p)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => priority = v);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Delete
                            setState(() {
                              _tasks.removeWhere((t) => t.id == task.id);
                            });
                            _saveTasks();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Title is required'),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              task.title = title;
                              task.description = descController.text.trim();
                              task.dueDate = due;
                              task.priority = priority;
                            });
                            _saveTasks();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColumn({
    required String title,
    required IconData icon,
    required TaskStatus status,
    required Color headerColor,
  }) {
    final columnTasks = _tasksForColumn(status);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: headerColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(icon, color: headerColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      '${columnTasks.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: DragTarget<KanbanTask>(
                onWillAcceptWithDetails: (_) => true,
                // ignore: deprecated_member_use
                onAccept: (task) {
                  _updateTaskStatus(task.id, status);
                },
                builder: (context, candidateData, rejectedData) {
                  final highlight = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: highlight
                          ? const Color(0xFFEAF2FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: columnTasks.isEmpty
                        ? const Center(
                            child: Text(
                              'No tasks',
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: columnTasks.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final t = columnTasks[i];
                              // Full move-button fallback for the current column.
                              return _buildTaskCardWithMoveButtons(t);
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

  Widget _buildTaskCardWithMoveButtons(KanbanTask task) {
    final prioColor = _priorityColor(task.priority);

    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEditTaskSheet(task),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: prioColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (task.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  task.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF555B66)),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _formatDueDate(task.dueDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: prioColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: prioColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _priorityLabel(task.priority),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: prioColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Move buttons fallback
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _moveButton(task, TaskStatus.todo, 'To Do'),
                  _moveButton(task, TaskStatus.inProgress, 'In Progress'),
                  _moveButton(task, TaskStatus.done, 'Done'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moveButton(KanbanTask task, TaskStatus target, String label) {
    final color = _priorityColor(task.priority);
    final isCurrent = task.status == target;
    return OutlinedButton(
      onPressed: isCurrent ? null : () => _updateTaskStatus(task.id, target),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: isCurrent ? Colors.grey : color,
        side: BorderSide(
          color: (isCurrent ? Colors.grey : color).withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        'Move → $label',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFilterBar() {
    Widget filterButton({required String label, required TaskPriority? value}) {
      final selected = _priorityFilter == value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            setState(() => _priorityFilter = value);
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          filterButton(label: 'All', value: null),
          filterButton(label: 'High Priority', value: TaskPriority.high),
          filterButton(label: 'Medium', value: TaskPriority.medium),
          filterButton(label: 'Low', value: TaskPriority.low),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Task Manager'),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _priorityFilter = null);
            },
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Reset filter',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildColumn(
                        title: 'To Do',
                        icon: Icons.note_alt_outlined,
                        status: TaskStatus.todo,
                        headerColor: Colors.blue,
                      ),
                      _buildColumn(
                        title: 'In Progress',
                        icon: Icons.construction_outlined,
                        status: TaskStatus.inProgress,
                        headerColor: Colors.orange,
                      ),
                      _buildColumn(
                        title: 'Done',
                        icon: Icons.check_circle_outline,
                        status: TaskStatus.done,
                        headerColor: Colors.green,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
