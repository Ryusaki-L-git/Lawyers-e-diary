import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../models/reminder_model.dart';
import '../repositories/case_repository.dart';
import '../services/firestore_service.dart';
import '../services/case_sync_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';

/// Desktop-first legal command center.
///
/// Every figure and row on this screen comes from the signed-in user's own
/// authorised sources: the local case register for matters and hearings, and
/// the user-scoped reminders collection for deadlines. Nothing is mocked and
/// no counts are invented.
class WindowsHomeScreen extends StatefulWidget {
  const WindowsHomeScreen({super.key});

  @override
  State<WindowsHomeScreen> createState() => _WindowsHomeScreenState();
}

class _WindowsHomeScreenState extends State<WindowsHomeScreen> {
  final _search = TextEditingController();
  final _repository = CaseRepository(database: AppDatabase.instance);
  bool _syncingCases = false;

  @override
  void initState() {
    super.initState();
    // Windows uses a local-first case register. Reconcile its pending changes
    // and pull the user's cloud cases after the workspace first renders so
    // JURIS and Smart Refresh can use authorized, synchronized case records.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCases(showResult: false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _syncCases({bool showResult = true}) async {
    if (_syncingCases || FirebaseAuth.instance.currentUser == null) return;
    setState(() => _syncingCases = true);
    try {
      final result = await CaseSyncEngine(
        repository: _repository,
        dataSource: FirestoreCaseSyncDataSource(),
      ).sync();
      if (!mounted) return;

      final hasChanges = result.uploaded > 0 || result.downloaded > 0;
      final hasIssues = result.failed > 0 ||
          result.conflicts > 0 ||
          result.rejected > 0 ||
          result.pullError != null;
      if (showResult || hasIssues) {
        final message = hasIssues
            ? 'Case sync finished with issues: '
                '${result.uploaded} uploaded, ${result.downloaded} downloaded, '
                '${result.conflicts} conflicts, ${result.failed} failed.'
            : hasChanges
            ? 'Cases synchronized: ${result.uploaded} uploaded, '
                '${result.downloaded} downloaded.'
            : 'Cases are already synchronized.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.pullError == null
                  ? message
                  : '$message Cloud pull: ${result.pullError}',
            ),
          ),
        );
      }
    } catch (error) {
      // A failed automatic sync must be visible too: otherwise a user may
      // assume a local-only case is available to cloud-backed services.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Case sync unavailable: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingCases = false);
    }
  }

  /// Hands the typed query to the dedicated search surface.
  ///
  /// The search screen already filters the user's own case register, so the
  /// workspace passes the term across instead of duplicating the filtering
  /// here.
  void _runSearch() {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    Navigator.of(context).pushNamed('/search_cases', arguments: query);
  }

  @override
  Widget build(BuildContext context) {
    // The authentication lookup is guarded so that a session that cannot be
    // resolved degrades to the signed-out workspace instead of taking the
    // whole window down.
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    if (user == null) {
      return const Scaffold(
        backgroundColor: WindowsDesktopShell.canvas,
        body: SafeArea(
          child: Center(
            child: WindowsMessageState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to open your workspace',
              message:
                  'Your matters, hearings and reminders stay scoped to your '
                  'account.',
            ),
          ),
        ),
      );
    }

    final name = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : ((user.email ?? '').split('@').first);

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(now).toUpperCase();

    return Scaffold(
      backgroundColor: WindowsDesktopShell.canvas,
      body: SafeArea(
        child: StreamBuilder<List<CaseModel>>(
          stream: _repository.watchCasesForCurrentUser(),
          builder: (context, snapshot) {
            final cases = snapshot.data ?? const <CaseModel>[];
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));
            final horizon = today.add(const Duration(days: 14));

            final live = cases
                .where((item) => !item.isDeleted && !item.isCompleted)
                .toList();

            final hearings = live
                .where((item) {
                  final date = item.nextHearingDate;
                  return date != null &&
                      !date.isBefore(today) &&
                      date.isBefore(tomorrow);
                })
                .toList()
              ..sort(
                (a, b) => a.nextHearingDate!.compareTo(b.nextHearingDate!),
              );

            final upcoming = live
                .where((item) {
                  final date = item.nextHearingDate;
                  return date != null &&
                      !date.isBefore(tomorrow) &&
                      date.isBefore(horizon);
                })
                .toList()
              ..sort(
                (a, b) => a.nextHearingDate!.compareTo(b.nextHearingDate!),
              );

            final active = live.length;
            final urgent = live.where((c) => c.isUrgent).length;
            final starred = live.where((c) => c.isStarred).length;

            final recent = [...cases]
              ..sort(
                (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
                  a.updatedAt ?? DateTime(2000),
                ),
              );

            return LayoutBuilder(
              builder: (context, constraints) {
                final breakpoint = WindowsLayout.breakpointOf(
                  constraints.maxWidth,
                );
                final gutters = breakpoint.isCompact ? 20.0 : 30.0;

                // The stat tiles sit inside the page gutters, so the width
                // available to them is the content width, not the full
                // window width. Measuring the wrong one is what makes a
                // four-column row wrap after three tiles.
                final contentWidth = constraints.maxWidth - gutters * 2;
                final columns = WindowsLayout.statColumnsOf(contentWidth);

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    gutters,
                    26,
                    gutters,
                    34,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WindowsPageHeader(
                        eyebrow: dateLabel,
                        title:
                            '$greeting, ${name.isEmpty ? 'Counsel' : name}',
                        subtitle: 'Your practice, clearly in view.',
                        actions: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _syncingCases
                                  ? 'Synchronizing cases'
                                  : 'Synchronize cases',
                              onPressed: _syncingCases
                                  ? null
                                  : () => _syncCases(),
                              icon: _syncingCases
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              style: IconButton.styleFrom(
                                foregroundColor: AppPalette.primaryGreen,
                                backgroundColor: AppPalette.cardBackground,
                                side: const BorderSide(
                                  color: AppPalette.borderLight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                minimumSize: const Size(44, 44),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: () => Navigator.of(
                                context,
                              ).pushNamed('/notifications'),
                              icon: const Icon(Icons.notifications_none_rounded),
                              style: IconButton.styleFrom(
                                foregroundColor: AppPalette.primaryGreen,
                                backgroundColor: AppPalette.cardBackground,
                                side: const BorderSide(
                                  color: AppPalette.borderLight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                minimumSize: const Size(44, 44),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushNamed('/add_case'),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New case'),
                              style: WindowsButtonStyles.primary(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _CommandPanel(
                        search: _search,
                        onSearch: _runSearch,
                        onDocket: () => Navigator.of(
                          context,
                        ).pushNamed('/cases'),
                        onCalendar: () => Navigator.of(
                          context,
                        ).pushNamed('/calendar'),
                      ),
                      const SizedBox(height: 18),
                      const WindowsSectionHeading('Quick actions'),
                      const SizedBox(height: 12),
                      const _PrimaryQuickActions(),
                      const SizedBox(height: 22),
                      if (snapshot.hasError)
                        _ErrorNotice(
                          message:
                              'The case register could not be loaded: '
                              '${snapshot.error}',
                        ),
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          color: AppPalette.accentGold,
                        ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          WindowsStatTile(
                            title: 'Active matters',
                            value: active.toString(),
                            caption: 'Your current docket',
                            icon: Icons.folder_open_outlined,
                            color: AppPalette.primaryGreen,
                            width: _tileWidth(contentWidth, columns),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/cases'),
                          ),
                          WindowsStatTile(
                            title: "Today's hearings",
                            value: hearings.length.toString(),
                            caption: 'Scheduled for today',
                            icon: Icons.calendar_today_outlined,
                            color: AppPalette.statusWarningDark,
                            width: _tileWidth(contentWidth, columns),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/calendar'),
                          ),
                          WindowsStatTile(
                            title: 'Urgent matters',
                            value: urgent.toString(),
                            caption: 'Marked for attention',
                            icon: Icons.priority_high_rounded,
                            color: AppPalette.statusDanger,
                            width: _tileWidth(contentWidth, columns),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(
                              '/cases',
                            ),
                          ),
                          WindowsStatTile(
                            title: 'Starred cases',
                            value: starred.toString(),
                            caption: 'Quick-access matters',
                            icon: Icons.star_outline_rounded,
                            color: AppPalette.statusSuccess,
                            width: _tileWidth(contentWidth, columns),
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/starred'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      _WorkspaceGrid(
                        breakpoint: breakpoint,
                        hearings: hearings,
                        upcoming: upcoming,
                        recent: recent,
                        loading:
                            snapshot.connectionState == ConnectionState.waiting,
                      ),
                      const SizedBox(height: 26),
                      const WindowsSectionHeading('Explore your workspace'),
                      const SizedBox(height: 13),
                      const _QuickAccessRow(),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The width of one stat tile in a wrap of [columns] columns.
  static double _tileWidth(double available, int columns) {
    if (columns <= 1) return available;
    return (available - 14 * (columns - 1)) / columns;
  }
}

/// The forest green command panel that carries the workspace search and the
/// two destinations that matter most: the docket and the calendar.
class _CommandPanel extends StatelessWidget {
  const _CommandPanel({
    required this.search,
    required this.onSearch,
    required this.onDocket,
    required this.onCalendar,
  });

  final TextEditingController search;
  final VoidCallback onSearch;
  final VoidCallback onDocket;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 250),
        decoration: BoxDecoration(
          color: AppPalette.primaryGreen,
          border: Border.all(color: AppPalette.onForestBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/Statue.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppPalette.primaryGreen.withValues(alpha: 0.98),
                    AppPalette.primaryGreen.withValues(alpha: 0.82),
                    AppPalette.primaryGreen.withValues(alpha: 0.20),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 650;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'YOUR PRACTICE. IN COMMAND.',
                        style: TextStyle(
                          color: AppPalette.accentGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A clearer view of justice.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: AppTypography.heading,
                          fontSize: compact ? 27 : 34,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your matters, hearings and deadlines — together in one place.',
                        maxLines: 2,
                        style: TextStyle(
                          color: AppPalette.onForestMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: compact ? constraints.maxWidth : 340,
                            child: WindowsSearchField(
                              controller: search,
                              hint: 'Search cases, clients, matters…',
                              onDark: true,
                              width: double.infinity,
                              onSubmitted: (_) => onSearch(),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: onDocket,
                            style: WindowsButtonStyles.onForest(filled: true),
                            icon: const Icon(Icons.folder_open_outlined, size: 17),
                            label: const Text('Open docket'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onCalendar,
                            style: WindowsButtonStyles.onForest(),
                            icon: const Icon(Icons.calendar_month_outlined, size: 17),
                            label: const Text('Hearings'),
                          ),
                        ],
                      ),
                    ],
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

/// The two-column workspace body: the day's hearings beside the deadlines
/// that need attention, and the fortnight ahead beside recent activity.
class _WorkspaceGrid extends StatelessWidget {
  const _WorkspaceGrid({
    required this.breakpoint,
    required this.hearings,
    required this.upcoming,
    required this.recent,
    required this.loading,
  });

  final WindowsBreakpoint breakpoint;
  final List<CaseModel> hearings;
  final List<CaseModel> upcoming;
  final List<CaseModel> recent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final todayPanel = _HearingPanel(
      title: "Today's hearings",
      subtitle: 'The matters on your schedule today',
      cases: hearings,
      loading: loading,
      emptyTitle: 'No hearings scheduled today',
      emptyDetail: 'Your docket is clear for today.',
      onAction: () =>
          Navigator.of(context).pushNamed('/calendar'),
      actionLabel: 'Open calendar',
    );

    final recentPanel = _RecentPanel(
      cases: recent.take(6).toList(),
      loading: loading,
    );

    final remindersPanel = _RemindersPanel();

    if (breakpoint.isCompact) {
      return Column(
        children: [
          todayPanel,
          const SizedBox(height: 18),
          remindersPanel,
          const SizedBox(height: 18),
          _UpcomingPanel(
            cases: upcoming,
            loading: loading,
            onAction: () =>
                Navigator.of(context).pushNamed('/calendar'),
          ),
          const SizedBox(height: 18),
          recentPanel,
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: todayPanel),
            const SizedBox(width: 18),
            Expanded(child: remindersPanel),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _UpcomingPanel(
                cases: upcoming,
                loading: loading,
                onAction: () => Navigator.of(
                  context,
                ).pushNamed('/calendar'),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(child: recentPanel),
          ],
        ),
      ],
    );
  }
}

/// A panel that lists the matters that have a hearing on a given day.
class _HearingPanel extends StatelessWidget {
  const _HearingPanel({
    required this.title,
    required this.subtitle,
    required this.cases,
    required this.loading,
    required this.emptyTitle,
    required this.emptyDetail,
    required this.onAction,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final List<CaseModel> cases;
  final bool loading;
  final String emptyTitle;
  final String emptyDetail;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      title: title,
      subtitle: subtitle,
      action: TextButton(
        onPressed: onAction,
        style: WindowsButtonStyles.ghost(),
        child: Text(actionLabel),
      ),
      child: loading && cases.isEmpty
          ? const WindowsLoadingPanel()
          : cases.isEmpty
          ? WindowsMessageState(
              icon: Icons.event_available_outlined,
              title: emptyTitle,
              message: emptyDetail,
              action: OutlinedButton(
                onPressed: onAction,
                style: WindowsButtonStyles.secondary(),
                child: Text(actionLabel),
              ),
            )
          : Column(
              children: [
                for (final item in cases)
                  _CaseRow(caseItem: item, showHearing: false),
              ],
            ),
    );
  }
}

/// A panel that lists the hearings falling in the next fortnight.
class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({
    required this.cases,
    required this.loading,
    required this.onAction,
  });

  final List<CaseModel> cases;
  final bool loading;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      title: 'Coming up',
      subtitle: 'Hearings scheduled in the next 14 days',
      action: TextButton(
        onPressed: onAction,
        style: WindowsButtonStyles.ghost(),
        child: const Text('Calendar'),
      ),
      child: loading && cases.isEmpty
          ? const WindowsLoadingPanel()
          : cases.isEmpty
          ? const WindowsMessageState(
              icon: Icons.event_note_outlined,
              title: 'Nothing scheduled ahead',
              message: 'No hearings are recorded in the next two weeks.',
            )
          : Column(
              children: [
                for (final item in cases)
                  _CaseRow(caseItem: item, showHearing: true),
              ],
            ),
    );
  }
}

/// A panel that lists the most recently touched matters.
class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.cases, required this.loading});

  final List<CaseModel> cases;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      title: 'Recently updated',
      subtitle: 'Your latest case activity',
      action: TextButton(
        onPressed: () => Navigator.of(context).pushNamed('/cases'),
        style: WindowsButtonStyles.ghost(),
        child: const Text('All cases'),
      ),
      child: loading && cases.isEmpty
          ? const WindowsLoadingPanel()
          : cases.isEmpty
          ? const WindowsMessageState(
              icon: Icons.folder_open_outlined,
              title: 'Your docket starts here',
              message: 'Create a case to see your work organized.',
            )
          : Column(
              children: [
                for (final item in cases)
                  _CaseRow(caseItem: item, showHearing: false),
              ],
            ),
    );
  }
}

/// A panel that lists the deadlines the user still has to meet.
///
/// The reminders collection is already scoped to the signed-in user by the
/// service, so this panel never widens the access boundary.
class _RemindersPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return _Surface(
      title: 'Deadlines',
      subtitle: 'Your open reminders',
      action: TextButton(
        onPressed: () =>
            Navigator.of(context).pushNamed('/reminders'),
        style: WindowsButtonStyles.ghost(),
        child: const Text('All reminders'),
      ),
      child: StreamBuilder<List<ReminderModel>>(
        stream: service.watchReminders(showCompleted: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const WindowsMessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Deadlines unavailable',
              message:
                  'The reminder service could not be reached. Your cases '
                  'are unaffected.',
              isError: true,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const WindowsLoadingPanel();
          }

          final items = (snapshot.data ?? const <ReminderModel>[])
              .where((item) => !item.isCompleted)
              .toList()
            ..sort(
              (a, b) => a.dueDateTime.compareTo(b.dueDateTime),
            );

          if (items.isEmpty) {
            return const WindowsMessageState(
              icon: Icons.task_alt_rounded,
              title: 'No open deadlines',
              message: 'Reminders you add will appear here.',
            );
          }

          return Column(
            children: [
              for (final item in items.take(6))
                _ReminderRow(reminder: item),
            ],
          );
        },
      ),
    );
  }
}

/// The shared white panel used by every workspace section.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A single matter inside a workspace panel.
class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.caseItem, required this.showHearing});

  final CaseModel caseItem;

  /// When true the row shows the hearing date on its own column.
  final bool showHearing;

  @override
  Widget build(BuildContext context) {
    final date = caseItem.nextHearingDate;

    final label = date == null
        ? 'Date not set'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';

    return WindowsListRow(
      onTap: () => Navigator.of(context).pushNamed('/cases'),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: AppPalette.primaryGreen,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caseItem.caseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${caseItem.caseNumber} · '
                  '${caseItem.clientName} · '
                  '${caseItem.courtName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (showHearing)
            Text(
              label,
              style: const TextStyle(
                color: AppPalette.primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (caseItem.isUrgent)
            const WindowsStatusChip(
              label: 'Urgent',
              color: AppPalette.statusDanger,
            )
          else if (caseItem.isStarred)
            const WindowsStatusChip(
              label: 'Starred',
              color: AppPalette.statusWarningDark,
            ),
        ],
      ),
    );
  }
}

/// A single open reminder inside the deadlines panel.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder});

  final ReminderModel reminder;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.isOverdue;
    final due = reminder.dueDateTime;
    final when = DateFormat('d MMM · HH:mm').format(due);

    return WindowsListRow(
      onTap: () =>
          Navigator.of(context).pushNamed('/reminders'),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: overdue
                  ? AppPalette.statusDangerTile
                  : AppPalette.statusTile,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              overdue
                  ? Icons.priority_high_rounded
                  : Icons.notifications_none_rounded,
              color: overdue
                  ? AppPalette.statusDanger
                  : AppPalette.primaryGreen,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.caseTitle ?? 'General deadline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          WindowsStatusChip(
            label: overdue ? 'Overdue' : when,
            color: overdue ? AppPalette.statusDanger : AppPalette.textMuted,
          ),
        ],
      ),
    );
  }
}

/// A compact notice used when a data source cannot be reached.
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppPalette.errorFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppPalette.statusDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppPalette.statusDanger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppPalette.statusDangerDark,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// High-frequency actions surfaced directly on the Windows workspace.
/// Each action routes to the existing screen; no duplicate business logic is
/// introduced here.
class _PrimaryQuickActions extends StatelessWidget {
  const _PrimaryQuickActions();

  @override
  Widget build(BuildContext context) {
    const actions = <(String, IconData, String)>[
      ('Cases', Icons.folder_open_outlined, '/cases'),
      ('Calendar', Icons.calendar_month_outlined, '/calendar'),
      ('Reminders', Icons.notifications_none_rounded, '/reminders'),
      ('Fees', Icons.account_balance_wallet_outlined, '/fee'),
      ('Starred', Icons.star_outline_rounded, '/starred'),
      ('Team', Icons.groups_2_outlined, '/team'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final itemWidth = compact
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 5 * 12) / 6;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickActionTile(
                  title: action.$1,
                  icon: action.$2,
                  onTap: () => Navigator.of(context).pushNamed(action.$3),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: AppPalette.cardBackground,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _hovered ? AppPalette.accentGold : AppPalette.borderLight,
          ),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: Color(0x0D1F3D2B),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppPalette.statusTile,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(widget.icon, color: AppPalette.primaryGreen, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_outward_rounded,
                      size: 14, color: AppPalette.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quick access row that surfaces the secondary destinations.
class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context) {
    const entries = <(String, IconData, String)>[
      ('Clients', Icons.people_outline_rounded, '/clients'),
      ('Reminders', Icons.notifications_none_rounded, '/reminders'),
      ('To-Do list', Icons.checklist_rounded, '/todo'),
      ('Fees & transactions', Icons.account_balance_wallet_outlined, '/fee'),
      ('Team workspace', Icons.groups_2_outlined, '/team'),
      ('JURIS intelligence', Icons.auto_awesome_outlined, '/juris'),
      ('Starred cases', Icons.star_outline_rounded, '/starred'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in entries)
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(entry.$3),
            icon: Icon(entry.$2, size: 17),
            label: Text(entry.$1),
            style: WindowsButtonStyles.secondary(),
          ),
      ],
    );
  }
}
