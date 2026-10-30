import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

/// Windows desktop case register backed by the existing user-scoped
/// repository.
///
/// The table drops columns as the window narrows so the register stays
/// readable on a laptop screen without becoming a horizontally scrolling
/// strip.
class WindowsCasesScreen extends StatefulWidget {
  const WindowsCasesScreen({super.key, this.initialStatus = 'all'});

  final String initialStatus;

  @override
  State<WindowsCasesScreen> createState() => _WindowsCasesScreenState();
}

class _WindowsCasesScreenState extends State<WindowsCasesScreen> {
  final _search = TextEditingController();
  String _status = 'all';
  String _sort = 'hearing';
  String _hearingFilter = 'today';

  /// Held in state so a failed load can be retried by re-subscribing.
  late Stream<List<CaseModel>> _stream = _openStream();

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  Stream<List<CaseModel>> _openStream() =>
      CaseRepository(database: AppDatabase.instance).watchCasesForCurrentUser();

  void _retry() {
    setState(() {
      _stream = _openStream();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _pageTitle => switch (_status) {
    'completed' => 'Completed cases',
    'starred' => 'Starred cases',
    'urgent' => 'Urgent cases',
    'active' => 'Active cases',
    _ => 'All cases',
  };

  void _openCase(BuildContext context, CaseModel item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WindowsDesktopShell(
          activeRoute: '/cases',
          child: WindowsCaseDetailScreen(caseItem: item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: StreamBuilder<List<CaseModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            final allCases = snapshot.data ?? const <CaseModel>[];
            final query = _search.text.trim().toLowerCase();

            var cases = allCases.where((item) {
              if (item.isDeleted) return false;
              if (_status == 'active' && item.status != 'active') {
                return false;
              }
              if (_status == 'completed' && !item.isCompleted) return false;
              if (_status == 'urgent' && !item.isUrgent) return false;
              if (_status == 'starred' && !item.isStarred) return false;
              if (_hearingFilter != 'all') {
                final hearing = item.nextHearingDate;
                if (hearing == null) return false;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final hearingDay = DateTime(hearing.year, hearing.month, hearing.day);
                if (_hearingFilter == 'today' && hearingDay != today) return false;
                if (_hearingFilter == 'week') {
                  final weekStart = today.subtract(Duration(days: today.weekday - 1));
                  final weekEnd = weekStart.add(const Duration(days: 7));
                  if (hearingDay.isBefore(weekStart) || !hearingDay.isBefore(weekEnd)) return false;
                }
                if (_hearingFilter == 'month' &&
                    (hearingDay.year != today.year || hearingDay.month != today.month)) {
                  return false;
                }
              }
              if (query.isEmpty) return true;

              return '${item.caseTitle} ${item.caseNumber} '
                      '${item.clientName} ${item.courtName}'
                  .toLowerCase()
                  .contains(query);
            }).toList();

            if (_sort == 'title') {
              cases.sort(
                (a, b) => a.caseTitle.toLowerCase().compareTo(
                  b.caseTitle.toLowerCase(),
                ),
              );
            } else if (_sort == 'updated') {
              cases.sort(
                (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
                  a.updatedAt ?? DateTime(2000),
                ),
              );
            } else {
              cases.sort((a, b) {
                final ad = a.nextHearingDate;
                final bd = b.nextHearingDate;

                if (ad == null && bd == null) return 0;
                if (ad == null) return 1;
                if (bd == null) return -1;

                return ad.compareTo(bd);
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WindowsPageHeader(
                    eyebrow: 'CASE REGISTER',
                    title: _pageTitle,
                    subtitle:
                        'Search, review and organize your legal matters. Today’s hearings are shown by default.',
                    actions: FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/add_case'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New case'),
                      style: WindowsButtonStyles.primary(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppPalette.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.borderLight),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final search = WindowsSearchField(
                          controller: _search,
                          hint: 'Search title, client, case number or court',
                          width: constraints.maxWidth < 520
                              ? constraints.maxWidth
                              : 360,
                          onChanged: (_) => setState(() {}),
                        );

                        final sort = SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            initialValue: _sort,
                            decoration: const WindowsFieldDecoration(
                              hint: 'Sort by',
                            ).build().copyWith(
                              labelText: 'Sort by',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'hearing',
                                child: Text('Next hearing'),
                              ),
                              DropdownMenuItem(
                                value: 'updated',
                                child: Text('Recently updated'),
                              ),
                              DropdownMenuItem(
                                value: 'title',
                                child: Text('Case title'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _sort = value ?? 'hearing'),
                          ),
                        );

                        final hearingFilter = SizedBox(
                          width: 165,
                          child: DropdownButtonFormField<String>(
                            initialValue: _hearingFilter,
                            decoration: const WindowsFieldDecoration(
                              hint: 'Hearing date',
                            ).build().copyWith(
                              labelText: 'Hearing date',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'today', child: Text("Today's cases")),
                              DropdownMenuItem(value: 'all', child: Text('All dates')),
                              DropdownMenuItem(value: 'week', child: Text('This week')),
                              DropdownMenuItem(value: 'month', child: Text('This month')),
                            ],
                            onChanged: (value) => setState(
                              () => _hearingFilter = value ?? 'today',
                            ),
                          ),
                        );

                        final filters = WindowsFilterBar(
                          options: const [
                            ('all', 'All'),
                            ('active', 'Active'),
                            ('urgent', 'Urgent'),
                            ('completed', 'Completed'),
                            ('starred', 'Starred'),
                          ],
                          selected: _status,
                          onChanged: (value) =>
                              setState(() => _status = value),
                        );

                        if (constraints.maxWidth < 900) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              search,
                              const SizedBox(height: 12),
                              filters,
                              const SizedBox(height: 12),
                              hearingFilter,
                              const SizedBox(height: 12),
                              sort,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                search,
                                const Spacer(),
                                hearingFilter,
                                const SizedBox(width: 12),
                                sort,
                              ],
                            ),
                            const SizedBox(height: 14),
                            filters,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${cases.length} '
                          '${cases.length == 1 ? 'matter' : 'matters'}',
                          style: const TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          query.isEmpty
                              ? 'from your authorized local case register'
                              : 'matching “$query”',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: AppPalette.accentGold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppPalette.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: snapshot.hasError
                          ? WindowsMessageState(
                              icon: Icons.error_outline_rounded,
                              title: 'Cases could not be loaded',
                              message: '${snapshot.error}',
                              isError: true,
                              action: OutlinedButton.icon(
                                onPressed: _retry,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 17,
                                ),
                                label: const Text('Try again'),
                                style: WindowsButtonStyles.secondary(),
                              ),
                            )
                          : cases.isEmpty
                          ? WindowsMessageState(
                              icon: Icons.folder_open_outlined,
                              title: query.isEmpty
                                  ? 'No cases in this view'
                                  : 'No matching cases',
                              message: query.isEmpty
                                  ? 'Try another filter or create a case to '
                                        'get started.'
                                  : 'No matter matches “$_search.text.trim()”. '
                                        'Try a different search term.',
                              action: OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pushNamed(
                                      '/add_case',
                                    ),
                                icon: const Icon(Icons.add_rounded, size: 17),
                                label: const Text('Create case'),
                                style: WindowsButtonStyles.secondary(),
                              ),
                            )
                          : _CaseRegister(
                              cases: cases,
                              onOpen: (item) => _openCase(context, item),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The structured register of matters.
///
/// The column set is chosen from the available width so the register keeps
/// its shape on a wide monitor and stays legible on a small laptop screen.
class _CaseRegister extends StatelessWidget {
  const _CaseRegister({required this.cases, required this.onOpen});

  final List<CaseModel> cases;
  final ValueChanged<CaseModel> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showClient = width >= 760;
        final showCourt = width >= 940;
        final showType = width >= 1080;

        return Column(
          children: [
            WindowsListHeader(
              columns: [
                const WindowsColumnLabel('Case', flex: 5),
                if (showClient) const WindowsColumnLabel('Client', flex: 3),
                if (showCourt) const WindowsColumnLabel('Court', flex: 3),
                const WindowsColumnLabel('Next hearing', flex: 3),
                const WindowsColumnLabel('Status', flex: 2),
                if (showType) const WindowsColumnLabel('Type', flex: 2),
              ],
            ),
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  itemCount: cases.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: AppPalette.borderLight,
                  ),
                  itemBuilder: (context, index) {
                    final item = cases[index];
                    return WindowsListRow(
                      onTap: () => onOpen(item),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.caseTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.primaryGreen,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.caseNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppPalette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showClient) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.clientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          if (showCourt) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.courtName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              _date(item.nextHearingDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.nextHearingDate == null
                                    ? AppPalette.textMuted
                                    : AppPalette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _StatusChip(status: item.status),
                            ),
                          ),
                          if (showType) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.caseType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return 'Not scheduled';

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }
}

/// A status label rendered with the shared chip.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'urgent' => AppPalette.statusDanger,
      'completed' => AppPalette.statusSuccess,
      'upcoming' => AppPalette.statusWarningDark,
      _ => AppPalette.primaryGreen,
    };

    return WindowsStatusChip(
      label: status.toUpperCase(),
      color: color,
    );
  }
}
