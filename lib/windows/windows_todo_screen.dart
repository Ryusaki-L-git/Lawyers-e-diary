import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/todo_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';

/// Windows desktop to-do workspace.
///
/// Tasks are persisted through the shared [FirestoreService] contract into the
/// `todos` collection, which the Firestore rules scope to the owning user.
/// The screen supports the complete task lifecycle the project defines:
/// create, complete, reopen and delete.
class WindowsTodoScreen extends StatefulWidget {
  const WindowsTodoScreen({super.key});

  @override
  State<WindowsTodoScreen> createState() => _WindowsTodoScreenState();
}

class _WindowsTodoScreenState extends State<WindowsTodoScreen> {
  final _service = FirestoreService();
  final _dateFmt = DateFormat('dd MMM yyyy');

  String _filter = 'Open';
  bool _showCompleted = false;

  int _retryToken = 0;

  static const _filters = <String>['Open', 'All', 'Completed'];

  void _retry() {
    setState(() => _retryToken++);
  }

  Future<void> _setCompleted(TodoModel todo, bool value) async {
    try {
      await _service.setTodoCompleted(todo.id, value);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The task could not be updated. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deleteTodo(TodoModel todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete this task?',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '"${todo.title}" will be permanently removed from your to-do list.',
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: WindowsButtonStyles.ghost(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: WindowsButtonStyles.danger(),
            child: const Text('Delete task'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _service.deleteTodo(todo.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The task could not be deleted. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const WindowsDesktopShell(
          activeRoute: '/todo',
          child: WindowsTodoComposerScreen(),
        ),
      ),
    );
    if (created == true && mounted) {
      setState(() {
        _filter = 'Open';
        _showCompleted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WindowsPageHeader(
                eyebrow: 'PRACTICE WORKFLOW',
                title: 'To-Do list',
                subtitle: 'Capture, prioritise and close the outstanding work on your matters.',
                actions: FilledButton.icon(
                  onPressed: _openComposer,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('New task'),
                  style: WindowsButtonStyles.primary(),
                ),
              ),
              const SizedBox(height: 20),
              _filterRow(),
              const SizedBox(height: 14),
              Expanded(
                child: StreamBuilder<List<TodoModel>>(
                  key: ValueKey<int>(_retryToken),
                  stream: _service.watchTodos(showCompleted: _showCompleted),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return WindowsMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load your tasks',
                        message: snapshot.error.toString(),
                        isError: true,
                        action: OutlinedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                          style: WindowsButtonStyles.secondary(),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const WindowsLoadingPanel();
                    }
                    final todos = snapshot.data ?? const <TodoModel>[];
                    final visible = _filter == 'Completed'
                        ? todos.where((t) => t.isCompleted).toList()
                        : _filter == 'Open'
                        ? todos.where((t) => !t.isCompleted).toList()
                        : todos;
                    if (visible.isEmpty) {
                      return WindowsMessageState(
                        icon: Icons.checklist_rounded,
                        title: _emptyTitle,
                        message: _emptySubtitle,
                      );
                    }
                    return ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) => _taskRow(visible[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _emptyTitle {
    switch (_filter) {
      case 'Completed':
        return 'No completed tasks yet';
      case 'All':
        return 'Your to-do list is empty';
      default:
        return 'Nothing outstanding';
    }
  }

  String get _emptySubtitle {
    switch (_filter) {
      case 'Completed':
        return 'Tasks you complete will be listed here.';
      case 'All':
        return 'Capture the next task on your matter to get started.';
      default:
        return 'Every task is done. Add another when the next one arrives.';
    }
  }

  Widget _filterRow() {
    return WindowsFilterBar(
      options: [for (final filter in _filters) (filter, filter)],
      selected: _filter,
      onChanged: (filter) => setState(() {
        _filter = filter;
        _showCompleted = filter != 'Open';
      }),
    );
  }

  Widget _taskRow(TodoModel todo) {
    final done = todo.isCompleted;
    return WindowsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: done,
              onChanged: (v) => _setCompleted(todo, v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: const BorderSide(color: AppPalette.borderLight, width: 1.5),
              activeColor: AppPalette.primaryGreen,
              checkColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: done ? AppPalette.textMuted : AppPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (todo.description != null &&
                    todo.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    todo.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    WindowsStatusChip(
                      label: todo.priority.label,
                      color: todo.priority == TodoPriority.high
                          ? AppPalette.statusDanger
                          : todo.priority == TodoPriority.low
                          ? AppPalette.textMuted
                          : AppPalette.statusWarning,
                    ),
                    if (todo.caseTitle != null &&
                        todo.caseTitle!.trim().isNotEmpty)
                      WindowsStatusChip(
                        label: todo.caseTitle!,
                        color: AppPalette.primaryGreen,
                      ),
                    if (todo.dueDateTime != null)
                      WindowsStatusChip(
                        label: todo.isOverdue
                            ? 'Overdue · ${_dateFmt.format(todo.dueDateTime!)}'
                            : 'Due ${_dateFmt.format(todo.dueDateTime!)}',
                        color: todo.isOverdue
                            ? AppPalette.statusDanger
                            : AppPalette.textMuted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteTodo(todo),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: AppPalette.textMuted,
            tooltip: 'Delete task',
          ),
        ],
      ),
    );
  }
}

/// Windows desktop composer used to capture a new to-do item.
class WindowsTodoComposerScreen extends StatefulWidget {
  const WindowsTodoComposerScreen({super.key});

  @override
  State<WindowsTodoComposerScreen> createState() =>
      _WindowsTodoComposerScreenState();
}

class _WindowsTodoComposerScreenState extends State<WindowsTodoComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = FirestoreService();

  TodoPriority _priority = TodoPriority.normal;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select an optional deadline',
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    String? id;
    try {
      id = await _service.addTodo(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        priority: _priority,
        dueDateTime: _dueDate,
      );
    } catch (_) {
      id = null;
    }

    if (!mounted) {
      return;
    }
    if (id == null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The task could not be saved. Please try again.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WindowsPageHeader(
                      eyebrow: 'PRACTICE WORKFLOW',
                      title: 'Capture a task',
                      leading: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back to to-do list',
                      ),
                      actions: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppPalette.accentGold,
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.check_rounded, size: 19),
                              label: const Text('Save task'),
                              style: WindowsButtonStyles.primary(),
                            ),
                    ),
                    const SizedBox(height: 22),
                    WindowsPanel(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const WindowsFieldLabel('Task title'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _titleController,
                              autofocus: true,
                              style: const TextStyle(
                                color: AppPalette.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: const WindowsFieldDecoration(
                                hint: 'e.g. Draft the client engagement letter',
                              ).build(),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'A task title is required';
                                }
                                if (v.trim().length > 160) {
                                  return 'Keep the title under 160 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            const WindowsFieldLabel('Details (optional)'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 3,
                              maxLines: 5,
                              style: const TextStyle(
                                color: AppPalette.textPrimary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                              decoration: const WindowsFieldDecoration(
                                hint: 'Add context, a client request or the next step',
                              ).build(),
                            ),
                            const SizedBox(height: 18),
                            const WindowsFieldLabel('Priority'),
                            const SizedBox(height: 7),
                            WindowsFilterBar(
                              options: [
                                for (final priority in TodoPriority.values)
                                  (priority.value, priority.label),
                              ],
                              selected: _priority.value,
                              onChanged: (value) => setState(
                                () => _priority = TodoPriorityExt.fromString(
                                  value,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const WindowsFieldLabel('Deadline (optional)'),
                            const SizedBox(height: 7),
                            OutlinedButton.icon(
                              onPressed: _pickDueDate,
                              icon: const Icon(
                                Icons.event_outlined,
                                size: 18,
                                color: AppPalette.primaryGreen,
                              ),
                              label: Text(
                                _dueDate == null
                                    ? 'No deadline set'
                                    : DateFormat('dd MMM yyyy')
                                          .format(_dueDate!),
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              style: WindowsButtonStyles.secondary(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
