import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

/// Windows daily court docket surface.
///
/// Shows the matters scheduled for one hearing date, taken from the user's own
/// accessible case register.
class WindowsCauseListScreen extends StatefulWidget {
  const WindowsCauseListScreen({super.key});
  @override
  State<WindowsCauseListScreen> createState() => _WindowsCauseListScreenState();
}

class _WindowsCauseListScreenState extends State<WindowsCauseListScreen> {
  DateTime _date = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final _service = CaseRepository(database: AppDatabase.instance);
  final _dateFormat = DateFormat('EEEE, dd MMMM yyyy');

  int _retry = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
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
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(DateFormat('dd MMM yyyy').format(_date)),
                      style: WindowsButtonStyles.secondary(),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/add_case'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add case'),
                      style: WindowsButtonStyles.primary(),
                    ),
                  ],
                );

                final stacked = constraints.maxWidth < 520;

                return WindowsPageHeader(
                  eyebrow: 'DAILY COURT DOCKET',
                  title: 'Cause list',
                  subtitle: 'Review the matters scheduled for a selected hearing date.',
                  actions: stacked ? null : actions,
                  trailing: stacked ? actions : null,
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.primaryGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppPalette.accentGold,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateFormat.format(_date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your case register · hearing dates currently recorded in LED',
                          style: TextStyle(
                            color: AppPalette.onForestMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _date = DateTime.now()),
                    icon: const Icon(
                      Icons.today_rounded,
                      color: AppPalette.accentGold,
                      size: 17,
                    ),
                    label: const Text(
                      'Today',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<CaseModel>>(
                key: ValueKey(_retry),
                stream: _service.watchCasesForCurrentUser(
                  hearingDateFrom: _date,
                  hearingDateTo: _date
                      .add(const Duration(days: 1))
                      .subtract(const Duration(microseconds: 1)),
                  sortBy: 'nextHearing',
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return WindowsMessageState(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load cause list',
                      message: snapshot.error.toString(),
                      isError: true,
                      action: OutlinedButton.icon(
                        onPressed: () => setState(() => _retry++),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: WindowsButtonStyles.secondary(),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return const WindowsLoadingPanel();
                  }
                  final cases = snapshot.data ?? const <CaseModel>[];
                  if (cases.isEmpty) {
                    return const WindowsMessageState(
                      icon: Icons.event_available_outlined,
                      title: 'No matters scheduled',
                      message: 'No cases in your accessible docket have a hearing date recorded for this day.',
                    );
                  }
                  final compactDocket = MediaQuery.sizeOf(context).width < 1100;

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
                            border: Border(
                              bottom: BorderSide(color: AppPalette.borderLight),
                            ),
                          ),
                          child: Row(
                            children: [
                              WindowsColumnLabel(
                                'Matter · ${cases.length}',
                                flex: 4,
                              ),
                              if (!compactDocket)
                                const WindowsColumnLabel('Client', flex: 2),
                              if (!compactDocket)
                                const WindowsColumnLabel(
                                  'Court / forum',
                                  flex: 2,
                                ),
                              const WindowsColumnLabel('Status', flex: 2),
                              const SizedBox(width: 19),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: cases.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: AppPalette.borderLight,
                            ),
                            itemBuilder: (context, index) {
                              final c = cases[index];
                              final urgent = c.isUrgent;
                              final color = urgent
                                  ? AppPalette.statusDanger
                                  : c.isCompleted
                                  ? AppPalette.statusSuccess
                                  : AppPalette.primaryGreen;
                              return InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => WindowsDesktopShell(
                                      activeRoute: '/cases',
                                      child: WindowsCaseDetailScreen(
                                        caseItem: c,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.caseTitle,
                                              style: const TextStyle(
                                                color: AppPalette.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              c.caseNumber,
                                              style: const TextStyle(
                                                color: AppPalette.textMuted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!compactDocket)
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            c.clientName,
                                          style: const TextStyle(
                                            color: AppPalette.textPrimary,
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!compactDocket)
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            c.courtName,
                                          style: const TextStyle(
                                            color: AppPalette.textPrimary,
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: WindowsStatusChip(
                                            label: c.status,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppPalette.textMuted,
                                        size: 19,
                                      ),
                                    ],
                                  ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }
}
