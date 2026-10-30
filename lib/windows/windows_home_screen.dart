import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../models/reminder_model.dart';
import '../repositories/case_repository.dart';
import '../services/case_sync_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';

/// Windows home workspace styled to match the supplied legal editorial reference.
class WindowsHomeScreen extends StatefulWidget {
  const WindowsHomeScreen({super.key});

  @override
  State<WindowsHomeScreen> createState() => _WindowsHomeScreenState();
}

class _WindowsHomeScreenState extends State<WindowsHomeScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _cases = CaseRepository(database: AppDatabase.instance);
  final _firestore = FirestoreService();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(false));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _sync([bool notify = true]) async {
    if (_syncing || FirebaseAuth.instance.currentUser == null) return;
    setState(() => _syncing = true);
    try {
      final result = await CaseSyncEngine(
        repository: _cases,
        dataSource: FirestoreCaseSyncDataSource(),
      ).sync();
      if (!mounted) return;
      final issue = result.failed > 0 || result.conflicts > 0 ||
          result.rejected > 0 || result.pullError != null;
      if (notify || issue) {
        final message = issue
            ? 'Sync completed with issues: ${result.uploaded} uploaded, ${result.downloaded} downloaded.'
            : result.uploaded + result.downloaded > 0
                ? 'Workspace synchronized successfully.'
                : 'Your workspace is already up to date.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not synchronize cases: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _go(String route) => Navigator.of(context).pushNamed(route);

  void _runSearch() {
    final query = _search.text.trim();
    if (query.isNotEmpty) {
      Navigator.of(context).pushNamed('/search_cases', arguments: query);
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (user == null) {
      return const Scaffold(
        backgroundColor: WindowsDesktopShell.canvas,
        body: Center(
          child: WindowsMessageState(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to open your workspace',
            message: 'Your matters, hearings and reminders stay scoped to your account.',
          ),
        ),
      );
    }

    final name = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (user.email ?? 'Advocate').split('@').first;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'GOOD MORNING'
        : now.hour < 17
            ? 'GOOD AFTERNOON'
            : 'GOOD EVENING';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F1),
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _searchFocus.requestFocus(),
          },
          child: Focus(
            autofocus: true,
            child: StreamBuilder<List<CaseModel>>(
          stream: _cases.watchCasesForCurrentUser(),
          builder: (context, caseSnapshot) {
            final all = caseSnapshot.data ?? const <CaseModel>[];
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));
            final live = all.where((c) => !c.isDeleted && !c.isCompleted).toList();
            final todayCases = live.where((c) {
              final d = c.nextHearingDate;
              return d != null && !d.isBefore(today) && d.isBefore(tomorrow);
            }).toList()
              ..sort((a, b) => a.nextHearingDate!.compareTo(b.nextHearingDate!));
            final upcoming = live.where((c) {
              final d = c.nextHearingDate;
              return d != null && !d.isBefore(tomorrow) &&
                  d.isBefore(today.add(const Duration(days: 15)));
            }).toList()
              ..sort((a, b) => a.nextHearingDate!.compareTo(b.nextHearingDate!));

            return StreamBuilder<List<ReminderModel>>(
              stream: _firestore.watchReminders(),
              builder: (context, reminderSnapshot) {
                final reminders = (reminderSnapshot.data ?? const <ReminderModel>[])
                    .where((r) => !r.isCompleted).toList()
                  ..sort((a, b) => a.dueDateTime.compareTo(b.dueDateTime));
                return Column(
                  children: [
                    _TopBar(
                      controller: _search,
                      focusNode: _searchFocus,
                      user: user!,
                      syncing: _syncing,
                      onSearch: _runSearch,
                      onSync: () => _sync(),
                      onNotifications: () => _go('/notifications'),
                      onProfile: () => _go('/profile'),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1120;
                          final narrow = constraints.maxWidth < 820;
                          final gutter = narrow ? 14.0 : 16.0;
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeroPanel(
                                  greeting: greeting,
                                  name: name,
                                  date: DateFormat('EEEE, d MMMM yyyy').format(now),
                                ),
                                const SizedBox(height: 12),
                                _Panel(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const _SectionHeading(
                                        title: 'Quick Actions',
                                        subtitle: 'Access your most-used features',
                                      ),
                                      const SizedBox(height: 10),
                                      _QuickActions(compact: narrow, onTap: _go),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (caseSnapshot.hasError)
                                  _Notice('The case register could not be loaded: ${caseSnapshot.error}'),
                                if (reminderSnapshot.hasError)
                                  _Notice('Reminders could not be loaded: ${reminderSnapshot.error}'),
                                if (compact) ...[
                                  _SchedulePanel(cases: todayCases, upcoming: upcoming, onCalendar: () => _go('/calendar')),
                                  const SizedBox(height: 12),
                                  _WorkspacePanel(
                                    active: live.length,
                                    hearings: upcoming.length,
                                    reminders: reminders.length,
                                    onTap: _go,
                                  ),
                                  const SizedBox(height: 12),
                                  _RightRail(
                                    now: now,
                                    reminders: reminders,
                                    onCalendar: () => _go('/calendar'),
                                    onReminders: () => _go('/reminders'),
                                  ),
                                ] else Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _SchedulePanel(
                                        cases: todayCases,
                                        upcoming: upcoming,
                                        onCalendar: () => _go('/calendar'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 4,
                                      child: _WorkspacePanel(
                                        active: live.length,
                                        hearings: upcoming.length,
                                        reminders: reminders.length,
                                        onTap: _go,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: constraints.maxWidth < 1180 ? 230 : 285,
                                      child: _RightRail(
                                        now: now,
                                        reminders: reminders,
                                        onCalendar: () => _go('/calendar'),
                                        onReminders: () => _go('/reminders'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _MetricsStrip(
                                  active: live.length,
                                  hearings: upcoming.length,
                                  urgent: live.where((c) => c.isUrgent).length,
                                  starred: live.where((c) => c.isStarred).length,
                                  onTap: _go,
                                ),
                                if (caseSnapshot.connectionState == ConnectionState.waiting &&
                                    !caseSnapshot.hasData)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                      color: AppPalette.accentGold,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
          ),
        ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.focusNode,
    required this.user,
    required this.syncing,
    required this.onSearch,
    required this.onSync,
    required this.onNotifications,
    required this.onProfile,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final User user;
  final bool syncing;
  final VoidCallback onSearch;
  final VoidCallback onSync;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName ?? '').trim().isEmpty
        ? (user.email ?? 'Advocate').split('@').first
        : user.displayName!.trim();
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F4),
        border: Border(bottom: BorderSide(color: Color(0xFFE6E1D8))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSearch(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF202820)),
                decoration: InputDecoration(
                  hintText: 'Search cases, clients, matters…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixText: 'Ctrl + K',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE3DED5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE3DED5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCCA046), width: 1.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: syncing ? 'Synchronizing' : 'Synchronize',
            onPressed: syncing ? null : onSync,
            icon: syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            color: const Color(0xFF1F3D2B),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
            color: const Color(0xFF1F3D2B),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 30, color: const Color(0xFFDCD6CC)),
          const SizedBox(width: 12),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF1F3D2B),
                    backgroundImage: user.photoURL == null ? null : NetworkImage(user.photoURL!),
                    child: user.photoURL == null
                        ? Text(name.isEmpty ? 'A' : name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 145),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF202820))),
                        const Text('Advocate workspace', style: TextStyle(fontSize: 10, color: Color(0xFF7B807B))),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.greeting, required this.name, required this.date});
  final String greeting;
  final String name;
  final String date;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1200;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: 222,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/led_hero_statue.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF0B241A)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF071D16).withValues(alpha: .98),
                    const Color(0xFF071D16).withValues(alpha: .82),
                    const Color(0xFF071D16).withValues(alpha: .10),
                  ],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(greeting, style: const TextStyle(color: Color(0xFFE5B957), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Palatino Linotype', fontSize: compact ? 32 : 42, height: 1.05, color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const Text('Here’s what’s happening with your practice today.',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 17),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.white),
                    const SizedBox(width: 7),
                    Text(date, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    const SizedBox(width: 18),
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    const Text('Your legal workspace', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ],
              ),
            ),
            if (!compact)
            const Positioned(
                right: 22,
                bottom: 25,
                width: 165,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“The law is not just a profession, it’s a purpose.”',
                      style: TextStyle(fontFamily: 'Palatino Linotype', fontStyle: FontStyle.italic, color: Colors.white, fontSize: 16, height: 1.4)),
                    SizedBox(height: 8),
                    SizedBox(width: 28, child: Divider(color: Color(0xFFE5B957), thickness: 2)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(title, style: const TextStyle(fontFamily: 'Palatino Linotype', fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
      const SizedBox(width: 10),
      Padding(padding: const EdgeInsets.only(bottom: 2),
        child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF858982)))),
    ],
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.compact, required this.onTap});
  final bool compact;
  final ValueChanged<String> onTap;
  static const items = <(String, String, IconData, String)>[
    ('Cases', 'View & manage all cases', Icons.folder_open_outlined, '/cases'),
    ('Calendar', 'Check hearings & appointments', Icons.calendar_month_outlined, '/calendar'),
    ('Reminders', 'Stay on top of important tasks', Icons.notifications_none_rounded, '/reminders'),
    ('Fees', 'Manage fees & payments', Icons.calculate_outlined, '/fee'),
    ('Starred', 'Your important cases', Icons.star_outline_rounded, '/starred'),
    ('Team', 'Manage your team', Icons.groups_2_outlined, '/team'),
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = 9.0;
      final width = compact ? (c.maxWidth - gap) / 2 : (c.maxWidth - gap * 5) / 6;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Material(
                color: const Color(0xFFFBFAF7),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onTap(item.$4),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 112),
                    padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2DED6)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: const BoxDecoration(color: Color(0xFF103426), shape: BoxShape.circle),
                          child: Icon(item.$3, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: Text(item.$1, style: const TextStyle(fontFamily: 'Palatino Linotype', fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF17221B)))),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF68716A)),
                        ]),
                        const SizedBox(height: 2),
                        Text(item.$2, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, height: 1.35, color: Color(0xFF858982))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFFFBFAF7),
      border: Border.all(color: const Color(0xFFE2DED6)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.cases, required this.upcoming, required this.onCalendar});
  final List<CaseModel> cases;
  final List<CaseModel> upcoming;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.calendar_month_outlined, color: Color(0xFF103426), size: 25),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today’s Schedule', style: TextStyle(fontFamily: 'Palatino Linotype', fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
          Text('Your hearings and appointments for today', style: TextStyle(fontSize: 10, color: Color(0xFF858982))),
        ])),
        TextButton(onPressed: onCalendar, child: const Text('View Calendar  →', style: TextStyle(fontSize: 10, color: Color(0xFF103426)))),
      ]),
      const Divider(height: 18, color: Color(0xFFE9E5DE)),
      if (cases.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Center(child: Text('No hearings scheduled for today.', style: TextStyle(fontSize: 12, color: Color(0xFF858982)))))
      else
        for (final c in cases.take(5)) _HearingRow(caseItem: c),
      if (upcoming.isNotEmpty) ...[
        const Divider(height: 16, color: Color(0xFFE9E5DE)),
        Text('UP NEXT  ·  ${upcoming.length} HEARINGS IN 14 DAYS',
          style: const TextStyle(fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: Color(0xFF858982))),
        const SizedBox(height: 8),
        for (final c in upcoming.take(2))
          Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFCCA046)),
            const SizedBox(width: 7),
            Expanded(child: Text(c.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF17221B)))),
            Text(DateFormat('d MMM').format(c.nextHearingDate!), style: const TextStyle(fontSize: 10, color: Color(0xFF858982))),
          ])),
      ],
    ]),
  );
}

class _HearingRow extends StatelessWidget {
  const _HearingRow({required this.caseItem});
  final CaseModel caseItem;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFECE8E1)))),
    child: Row(children: [
      Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF318267), shape: BoxShape.circle)),
      const SizedBox(width: 12),
      SizedBox(width: 67, child: Text(DateFormat('hh:mm a').format(caseItem.nextHearingDate!),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF17221B)))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(caseItem.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
        const SizedBox(height: 3),
        Text('${caseItem.clientName}  ·  ${caseItem.courtName}', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: Color(0xFF858982))),
      ])),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFE5F0E8), borderRadius: BorderRadius.circular(20)),
        child: const Text('Hearing', style: TextStyle(fontSize: 9, color: Color(0xFF1F5B42), fontWeight: FontWeight.w700))),
    ]),
  );
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({required this.active, required this.hearings, required this.reminders, required this.onTap});
  final int active, hearings, reminders;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: const [
        Icon(Icons.grid_view_rounded, size: 25, color: Color(0xFF103426)),
        SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Workspace', style: TextStyle(fontFamily: 'Palatino Linotype', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
          Text('Your customized workspace for quick access', style: TextStyle(fontSize: 10, color: Color(0xFF858982))),
        ]),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _WorkspaceMetric(icon: Icons.folder_open_outlined, label: 'Cases', value: active.toString(), onTap: () => onTap('/cases'))),
        const SizedBox(width: 7),
        Expanded(child: _WorkspaceMetric(icon: Icons.calendar_month_outlined, label: 'Hearings', value: hearings.toString(), onTap: () => onTap('/calendar'))),
        const SizedBox(width: 7),
        Expanded(child: _WorkspaceMetric(icon: Icons.notifications_none_rounded, label: 'Reminders', value: reminders.toString(), onTap: () => onTap('/reminders'))),
      ]),
      const SizedBox(height: 13),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 112,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/led_stay_focused.png', fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF103426))),
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomLeft, end: Alignment.topRight,
              colors: [Colors.black.withValues(alpha: .75), Colors.transparent],
            ))),
            const Positioned(left: 14, bottom: 13, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stay focused. Stay prepared.', style: TextStyle(fontFamily: 'Palatino Linotype', fontStyle: FontStyle.italic, fontSize: 15, color: Colors.white)),
                SizedBox(height: 3),
                Text('Your work. Our priority.', style: TextStyle(fontSize: 10, color: Colors.white)),
              ],
            )),
          ]),
        ),
      ),
    ]),
  );
}

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2DED6)), borderRadius: BorderRadius.circular(7)),
      child: Column(children: [
        Icon(icon, size: 19, color: const Color(0xFF103426)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF858982))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
      ]),
    ),
  );
}

class _RightRail extends StatelessWidget {
  const _RightRail({required this.now, required this.reminders, required this.onCalendar, required this.onReminders});
  final DateTime now;
  final List<ReminderModel> reminders;
  final VoidCallback onCalendar, onReminders;
  @override
  Widget build(BuildContext context) => Column(children: [
    _MiniCalendar(now: now, onCalendar: onCalendar),
    const SizedBox(height: 12),
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.notifications_none_rounded, color: Color(0xFF103426), size: 22),
        const SizedBox(width: 8),
        const Expanded(child: Text('Reminders', style: TextStyle(fontFamily: 'Palatino Linotype', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF17221B)))),
        TextButton(onPressed: onReminders, child: const Text('View all  →', style: TextStyle(fontSize: 10))),
      ]),
      const Divider(height: 12, color: Color(0xFFE9E5DE)),
      if (reminders.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('You’re all caught up.', style: TextStyle(fontSize: 11, color: Color(0xFF858982))))
      else
        for (final r in reminders.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: r.isOverdue ? const Color(0xFFC94A3B) : const Color(0xFFCCA046), shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
                const SizedBox(height: 3),
                Text(DateFormat('d MMM · hh:mm a').format(r.dueDateTime), style: const TextStyle(fontSize: 9, color: Color(0xFF858982))),
              ])),
            ]),
          ),
    ])),
  ]);
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({required this.now, required this.onCalendar});
  final DateTime now;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(now.year, now.month, 1);
    final offset = (first.weekday + 6) % 7;
    final days = DateTime(now.year, now.month + 1, 0).day;
    final total = ((offset + days + 6) ~/ 7) * 7;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.calendar_month_outlined, color: Color(0xFF103426), size: 20),
          const SizedBox(width: 7),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(now),
            style: const TextStyle(fontFamily: 'Palatino Linotype', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF17221B)))),
          IconButton(tooltip: 'Open calendar', onPressed: onCalendar,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13), visualDensity: VisualDensity.compact),
        ]),
        const Divider(height: 10, color: Color(0xFFE9E5DE)),
        Row(children: [
          for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 8, color: Color(0xFF858982), fontWeight: FontWeight.w600)))),
        ]),
        const SizedBox(height: 5),
        for (var week = 0; week < total ~/ 7; week++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              for (var day = 0; day < 7; day++)
                Expanded(child: Center(child: _CalendarDay(
                  value: week * 7 + day - offset + 1,
                  monthDays: days,
                  selected: week * 7 + day - offset + 1 == now.day,
                ))),
            ]),
          ),
      ]),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.value, required this.monthDays, required this.selected});
  final int value, monthDays;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    if (value < 1 || value > monthDays) return const SizedBox(height: 25);
    return Container(
      width: 25, height: 25,
      alignment: Alignment.center,
      decoration: selected ? const BoxDecoration(color: Color(0xFF103426), shape: BoxShape.circle) : null,
      child: Text(value.toString(), style: TextStyle(
        fontSize: 9,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF17221B),
      )),
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({required this.active, required this.hearings, required this.urgent, required this.starred, required this.onTap});
  final int active, hearings, urgent, starred;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) {
    final items = <(String, int, IconData, String)>[
      ('Active Matters', active, Icons.folder_open_outlined, '/cases'),
      ('Upcoming Hearings', hearings, Icons.calendar_month_outlined, '/calendar'),
      ('Urgent Matters', urgent, Icons.warning_amber_rounded, '/cases'),
      ('Starred Cases', starred, Icons.star_outline_rounded, '/starred'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: const Color(0xFFFBFAF7), border: Border.all(color: const Color(0xFFE2DED6)), borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(builder: (context, c) => Wrap(children: [
        for (final item in items)
          SizedBox(
            width: c.maxWidth >= 720 ? c.maxWidth / 4 : c.maxWidth / 2,
            child: InkWell(
              onTap: () => onTap(item.$4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Row(children: [
                  Container(width: 38, height: 38,
                    decoration: const BoxDecoration(color: Color(0xFFF0E8D8), shape: BoxShape.circle),
                    child: Icon(item.$3, color: const Color(0xFF103426), size: 19)),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.$1, style: const TextStyle(fontSize: 9, color: Color(0xFF858982))),
                    Text(item.$2.toString(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF17221B))),
                  ])),
                ]),
              ),
            ),
          ),
      ])),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFFFF3E7), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0xFFE8C9A8))),
    child: Text(message, style: const TextStyle(fontSize: 11, color: Color(0xFF34291D))),
  );
}
