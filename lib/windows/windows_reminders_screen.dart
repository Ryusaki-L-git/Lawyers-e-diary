import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reminder_model.dart';
import '../screens/reminders/add_reminder_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';

class WindowsRemindersScreen extends StatefulWidget {
  const WindowsRemindersScreen({super.key});

  @override
  State<WindowsRemindersScreen> createState() => _WindowsRemindersScreenState();
}

class _WindowsRemindersScreenState extends State<WindowsRemindersScreen> {
  final _service = FirestoreService();
  String _filter = 'All';
  final _dateFormat = DateFormat('dd MMM yyyy · HH:mm');

  /// Held in state so a failed load can be retried by re-subscribing.
  late Stream<List<ReminderModel>> _stream = _service.watchReminders(
    showCompleted: true,
  );

  void _retry() {
    setState(() {
      _stream = _service.watchReminders(showCompleted: true);
    });
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
                eyebrow: 'PRACTICE ORGANIZATION',
                title: 'Reminders',
                subtitle: 'Keep deadlines and follow-ups visible.',
                actions: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New reminder'),
                  style: WindowsButtonStyles.primary(),
                ),
              ),
              const SizedBox(height: 20),
              WindowsFilterBar(
                label: 'Show',
                options: const [
                  ('All', 'All'),
                  ('Pending', 'Pending'),
                  ('Completed', 'Completed'),
                ],
                selected: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<List<ReminderModel>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return WindowsMessageState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load reminders',
                        message:
                            '${snapshot.error}\n\nYour reminders are stored '
                            'against your account and nothing has been lost.',
                        isError: true,
                        action: OutlinedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Try again'),
                          style: WindowsButtonStyles.secondary(),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const WindowsLoadingPanel(
                        label: 'Loading your reminders…',
                      );
                    }
                    var items = snapshot.data ?? const <ReminderModel>[];
                    if (_filter == 'Pending') {
                      items = items.where((r) => !r.isCompleted).toList();
                    }
                    if (_filter == 'Completed') {
                      items = items.where((r) => r.isCompleted).toList();
                    }
                    if (items.isEmpty) {
                      return WindowsMessageState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Nothing to follow up on',
                        message: _filter == 'All'
                            ? 'Create a reminder for a deadline or client '
                                  'follow-up.'
                            : 'There are no reminders in this view.',
                      );
                    }
                    final compactReminders = MediaQuery.sizeOf(context).width < 1100;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppPalette.cardBackground,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            decoration: const BoxDecoration(
                              color: AppPalette.canvas,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppPalette.borderLight,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'REMINDER  ·  ${items.length}',
                                    style: const TextStyle(
                                      color: AppPalette.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                if (!compactReminders)
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      'RELATED MATTER',
                                      style: TextStyle(
                                        color: AppPalette.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'DUE',
                                    style: TextStyle(
                                      color: AppPalette.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 86),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: AppPalette.borderLight,
                              ),
                              itemBuilder: (context, index) {
                                final r = items[index];
                                final overdue =
                                    r.isOverdue && !r.isCompleted;
                                final status = r.isCompleted
                                    ? 'Completed'
                                    : overdue
                                    ? 'Overdue'
                                    : 'Upcoming';
                                final statusColor = r.isCompleted
                                    ? AppPalette.statusSuccess
                                    : overdue
                                    ? AppPalette.statusDanger
                                    : AppPalette.primaryGreen;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 13,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: .09,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          r.isCompleted
                                              ? Icons
                                                    .check_circle_outline_rounded
                                              : overdue
                                              ? Icons.warning_amber_rounded
                                              : Icons.notifications_none_rounded,
                                          color: statusColor,
                                          size: 19,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppPalette.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                decoration: r.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            if ((r.description ?? '')
                                                .trim()
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  r.description!,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppPalette.textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 5),
                                            WindowsStatusChip(
                                              label: status,
                                              color: statusColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!compactReminders)
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (r.caseTitle ?? '').isEmpty
                                                    ? 'General reminder'
                                                    : r.caseTitle!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppPalette.textPrimary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if ((r.clientName ?? '')
                                                  .isNotEmpty)
                                                Text(
                                                  r.clientName!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppPalette.textMuted,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _dateFormat.format(r.dueDateTime),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: overdue
                                                ? AppPalette.statusDanger
                                                : AppPalette.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 86,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              tooltip: r.isCompleted
                                                  ? 'Mark pending'
                                                  : 'Mark completed',
                                              onPressed: () => _toggle(r),
                                              icon: Icon(
                                                r.isCompleted
                                                    ? Icons.undo_rounded
                                                    : Icons.check_rounded,
                                                color:
                                                    AppPalette.primaryGreen,
                                                size: 19,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete reminder',
                                              onPressed: () => _delete(r),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: AppPalette.statusDanger,
                                                size: 19,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
    );
  }

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WindowsDesktopShell(
          activeRoute: '/reminders',
          child: AddReminderScreen(),
        ),
      ),
    );
  }

  /// Marks a reminder complete or pending, reporting a genuine failure.
  Future<void> _toggle(ReminderModel r) async {
    try {
      await _service.toggleReminderDone(r.id, r.isCompleted);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The reminder could not be updated. Please try again.'),
        ),
      );
    }
  }

  Future<void> _delete(ReminderModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('“${r.title}” will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: WindowsButtonStyles.danger(),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _service.deleteReminder(r.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The reminder could not be deleted. Please try again.'),
        ),
      );
    }
  }
}
