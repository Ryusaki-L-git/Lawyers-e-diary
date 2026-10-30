import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

/// Windows month calendar and hearing agenda backed by the current user's
/// existing local case repository.
class WindowsCalendarScreen extends StatefulWidget {
  const WindowsCalendarScreen({super.key});

  @override
  State<WindowsCalendarScreen> createState() => _WindowsCalendarScreenState();
}

class _WindowsCalendarScreenState extends State<WindowsCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  final _repository = CaseRepository(database: AppDatabase.instance);
  late Stream<List<CaseModel>> _casesStream =
      _repository.watchCasesForCurrentUser();

  void _retryLoad() {
    setState(() {
      _casesStream = _repository.watchCasesForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: StreamBuilder<List<CaseModel>>(
        stream: _casesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(30),
              child: WindowsMessageState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load your calendar',
                message: 'Your hearing schedule is temporarily unavailable. Retry to reconnect to your local case register.',
                isError: true,
                action: OutlinedButton.icon(
                  onPressed: _retryLoad,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Try again'),
                  style: WindowsButtonStyles.secondary(),
                ),
              ),
            );
          }
          final cases = (snapshot.data ?? const <CaseModel>[])
              .where(
                (c) =>
                    !c.isDeleted && !c.isCompleted && c.nextHearingDate != null,
              )
              .toList();

          final selectedHearings =
              cases
                  .where((c) => _sameDay(c.nextHearingDate!, _selected))
                  .toList()
                ..sort((a, b) => a.caseTitle.compareTo(b.caseTitle));

          final monthHearings = cases
              .where(
                (c) =>
                    c.nextHearingDate!.year == _month.year &&
                    c.nextHearingDate!.month == _month.month,
              )
              .toList();

          final firstWeekday =
              DateTime(_month.year, _month.month, 1).weekday % 7;
          final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
          final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
          final monthName = _monthName(_month.month);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final actions = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/cause_list'),
                          icon: const Icon(Icons.gavel_rounded, size: 17),
                          label: const Text('Cause list'),
                          style: WindowsButtonStyles.secondary(),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/add_case'),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New case'),
                          style: WindowsButtonStyles.primary(),
                        ),
                      ],
                    );

                    final stacked = constraints.maxWidth < 500;

                    return WindowsPageHeader(
                      eyebrow: 'HEARINGS & SCHEDULE',
                      title: 'Calendar',
                      subtitle:
                          'Plan the docket around your upcoming hearing dates.',
                      actions: stacked ? null : actions,
                      trailing: stacked ? actions : null,
                    );
                  },
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 960;

                    final calendarPanel = WindowsPanel(
                      child: Column(
                        children: [
                          _monthHeader(monthName, monthHearings.length),
                          const SizedBox(height: 18),
                          const Row(
                            children: [
                              _Weekday('SUN'),
                              _Weekday('MON'),
                              _Weekday('TUE'),
                              _Weekday('WED'),
                              _Weekday('THU'),
                              _Weekday('FRI'),
                              _Weekday('SAT'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, grid) {
                              final spacing = grid.maxWidth / 7 < 52
                                  ? 4.0
                                  : 7.0;
                              final cellWidth =
                                  (grid.maxWidth - spacing * 6) / 7;
                              final cellHeight = math.max(
                                cellWidth * 1.05,
                                44.0,
                              );
                              final dayFont = cellWidth < 48 ? 11.0 : 13.0;
                              final countFont = cellWidth < 48 ? 8.0 : 9.0;

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: cellCount,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      mainAxisSpacing: spacing,
                                      crossAxisSpacing: spacing,
                                      childAspectRatio: cellWidth / cellHeight,
                                    ),
                                itemBuilder: (context, index) {
                                  final day = index - firstWeekday + 1;

                                  if (day < 1 || day > daysInMonth) {
                                    return const SizedBox.shrink();
                                  }

                                  final date = DateTime(
                                    _month.year,
                                    _month.month,
                                    day,
                                  );

                                  final count = monthHearings
                                      .where(
                                        (c) =>
                                            _sameDay(c.nextHearingDate!, date),
                                      )
                                      .length;

                                  final selected = _sameDay(date, _selected);
                                  final today = _sameDay(date, DateTime.now());

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () =>
                                        setState(() => _selected = date),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppPalette.primaryGreen
                                            : today
                                            ? AppPalette.statusTile
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? AppPalette.primaryGreen
                                              : today
                                              ? AppPalette.onForestFaint
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            day.toString(),
                                            style: TextStyle(
                                              color: selected
                                                  ? Colors.white
                                                  : AppPalette.textPrimary,
                                              fontSize: dayFont,
                                              fontWeight: selected || today
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          if (count > 0)
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? AppPalette.accentGold
                                                        : AppPalette
                                                              .statusWarning,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    count.toString(),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: selected
                                                          ? Colors.white
                                                          : AppPalette
                                                                .primaryGreen,
                                                      fontSize: countFont,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            const SizedBox(height: 10),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          const Row(
                            children: [
                              _LegendDot(),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Dates with scheduled hearings show a count.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    final agenda = WindowsPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selected.day.toString().padLeft(2, '0')} ${_monthName(_selected.month)} ${_selected.year}',
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${selectedHearings.length} hearing${selectedHearings.length == 1 ? '' : 's'} scheduled',
                            style: const TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (snapshot.hasError)
                            WindowsMessageState(
                              icon: Icons.error_outline_rounded,
                              title: 'Could not load the hearing agenda',
                              message: snapshot.error.toString(),
                              isError: true,
                              action: OutlinedButton.icon(
                                onPressed: _retryLoad,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Retry'),
                                style: WindowsButtonStyles.secondary(),
                              ),
                            )
                          else if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              snapshot.data == null)
                            const WindowsLoadingPanel()
                          else if (selectedHearings.isEmpty)
                            const WindowsMessageState(
                              icon: Icons.event_available_outlined,
                              title: 'No hearings on this date',
                              message: 'Choose a marked day to review scheduled matters.',
                            )
                          else
                            for (final item in selectedHearings)
                              _HearingTile(
                                item: item,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => WindowsDesktopShell(
                                      activeRoute: '/cases',
                                      child: WindowsCaseDetailScreen(
                                        caseItem: item,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    );

                    if (!wide) {
                      return Column(
                        children: [
                          calendarPanel,
                          const SizedBox(height: 18),
                          agenda,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: calendarPanel),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: agenda),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  /// The month navigation strip shown above the grid.
  Widget _monthHeader(String monthName, int hearingCount) {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() {
            _month = DateTime(_month.year, _month.month - 1, 1);
            _selected = DateTime(_month.year, _month.month, 1);
          }),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                monthName,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_month.year} · $hearingCount scheduled matters',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() {
            _month = DateTime(_month.year, _month.month + 1, 1);
            _selected = DateTime(_month.year, _month.month, 1);
          }),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Expanded(child: Center(child: WindowsColumnLabel(label)));
}

/// The gold marker that explains the hearing count on the grid.
class _LegendDot extends StatelessWidget {
  const _LegendDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(
      color: AppPalette.accentGold,
      shape: BoxShape.circle,
    ),
  );
}

class _HearingTile extends StatelessWidget {
  const _HearingTile({required this.item, required this.onTap});

  final CaseModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: AppPalette.canvas,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 37,
                height: 39,
                decoration: BoxDecoration(
                  color: AppPalette.cardBackground,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.gavel_outlined,
                  color: AppPalette.primaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.caseTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.caseNumber} · ${item.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.courtName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
