import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reminder_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/app_nav_controller.dart';
import '../../widgets/app_palette.dart';
import 'add_reminder_screen.dart';

/// Full-page Reminders list with All / Pending / Completed tab filter.
class RemindersListScreen extends StatefulWidget {
  const RemindersListScreen({super.key});

  @override
  State<RemindersListScreen> createState() => _RemindersListScreenState();
}

class _RemindersListScreenState extends State<RemindersListScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  late TabController _tabController;

  // 0 = All, 1 = Pending, 2 = Completed
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }
      setState(() => _tabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Keep one subscription while tabs or other local state changes; rebuilding
  // the page must not repeatedly replace the Firestore stream.
  late Stream<List<ReminderModel>> _reminderStream = _service.watchReminders(
    showCompleted: true,
  );

  void _retryLoad() {
    setState(() {
      _reminderStream = _service.watchReminders(showCompleted: true);
    });
  }

  List<ReminderModel> _filter(List<ReminderModel> all) {
    switch (_tabIndex) {
      case 1: // Pending
        return all.where((r) => !r.isCompleted).toList();
      case 2: // Completed
        return all.where((r) => r.isCompleted).toList();
      default: // All
        return all;
    }
  }

  Future<void> _openAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddReminderScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder saved.'),
          backgroundColor: AppPalette.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleDone(ReminderModel r) async {
    try {
      await _service.toggleReminderDone(r.id, r.isCompleted);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The reminder could not be updated. Please try again.'),
          backgroundColor: AppPalette.statusDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete(ReminderModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Reminder?',
          style: TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${r.title}" will be permanently deleted.',
          style: const TextStyle(color: AppPalette.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppPalette.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppPalette.statusDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _service.deleteReminder(r.id);
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The reminder could not be deleted. Please try again.',
            ),
            backgroundColor: AppPalette.statusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: AppBar(
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Reminders',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppPalette.primaryGreen,
              size: 28,
            ),
            onPressed: _openAdd,
            tooltip: 'Add Reminder',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _TabBar(controller: _tabController),
        ),
      ),
      body: StreamBuilder<List<ReminderModel>>(
        stream: _reminderStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 38,
                      color: AppPalette.statusDanger,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Reminders could not be loaded',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your reminder list is temporarily unavailable. Try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _retryLoad,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final items = _filter(all);

          if (items.isEmpty) {
            return _EmptyState(tabIndex: _tabIndex, onAdd: _openAdd);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _ReminderCard(
                reminder: items[index],
                onToggle: () => _toggleDone(items[index]),
                onDelete: () => _delete(items[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: AppPalette.primaryGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Reminder',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(
        currentIndex: 0,
        mode: NavMode.home,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      indicatorColor: AppPalette.primaryGreen,
      indicatorWeight: 2.5,
      labelColor: AppPalette.primaryGreen,
      unselectedLabelColor: AppPalette.textMuted,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      tabs: const [
        Tab(text: 'All'),
        Tab(text: 'Pending'),
        Tab(text: 'Completed'),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = reminder.isCompleted;
    final isOverdue = reminder.isOverdue;

    Color iconBg;
    Color iconColor;
    IconData icon;
    if (isCompleted) {
      iconBg = AppPalette.statusTile;
      iconColor = AppPalette.primaryGreen;
      icon = Icons.check_circle_rounded;
    } else if (isOverdue) {
      iconBg = AppPalette.statusDangerTile;
      iconColor = AppPalette.statusDanger;
      icon = Icons.warning_amber_rounded;
    } else {
      iconBg = AppPalette.statusTile;
      iconColor = AppPalette.primaryGreen;
      icon = Icons.notifications_active_rounded;
    }

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppPalette.statusDanger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppPalette.statusDanger,
          size: 24,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // let the stream update handle removal
      },
      child: Material(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          color: isCompleted
                              ? AppPalette.textMuted
                              : AppPalette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (reminder.description != null &&
                          reminder.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          reminder.description!,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (reminder.caseTitle != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.gavel_rounded,
                              size: 12,
                              color: AppPalette.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                reminder.caseTitle!,
                                style: const TextStyle(
                                  color: AppPalette.primaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isOverdue && !isCompleted
                                ? AppPalette.statusDanger
                                : AppPalette.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMM · hh:mm a')
                                .format(reminder.dueDateTime),
                            style: TextStyle(
                              color: isOverdue && !isCompleted
                                  ? AppPalette.statusDanger
                                  : AppPalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (reminder.repeatRule != ReminderRepeat.none) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.borderLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reminder.repeatRule.label,
                                style: const TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppPalette.primaryGreen
                            : Colors.transparent,
                        border: Border.all(
                          color: isCompleted
                              ? AppPalette.primaryGreen
                              : AppPalette.borderLight,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tabIndex, required this.onAdd});

  final int tabIndex;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final messages = [
      ('No reminders yet', 'Tap + to create your first reminder.'),
      ('No pending reminders', 'All caught up! Great work.'),
      ('No completed reminders', 'Complete a reminder to see it here.'),
    ];
    final (title, sub) = messages[tabIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.statusTile,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppPalette.primaryGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 14),
            ),
            if (tabIndex == 0) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Add Reminder',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
