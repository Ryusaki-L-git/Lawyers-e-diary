import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

class WindowsCaseManagementScreen extends StatelessWidget {
  const WindowsCaseManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repository = CaseRepository(database: AppDatabase.instance);
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: StreamBuilder<List<CaseModel>>(
            stream: repository.watchCasesForCurrentUser(sortBy: 'created'),
            builder: (context, snapshot) {
              final cases = snapshot.data ?? const <CaseModel>[];
              // The register returns every matter that is not deleted, which
              // includes the ones already settled. The operational figures
              // below describe the open docket, so they exclude the
              // completed matters.
              final open = cases.where((c) => !c.isCompleted).toList();
              final urgent = open.where((c) => c.isUrgent).length;
              final upcoming = open
                  .where((c) => c.nextHearingDate != null)
                  .length;
              final noDate = open
                  .where((c) => c.nextHearingDate == null)
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WindowsPageHeader(
                    eyebrow: 'DOCKET OPERATIONS',
                    title: 'Case management',
                    subtitle:
                        'A live operational overview of your local case '
                        'register.',
                  ),
                  const SizedBox(height: 22),
                  if (snapshot.hasError)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppPalette.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: Text(
                        'Could not load case statistics: ${snapshot.error}',
                        style: const TextStyle(
                          color: AppPalette.statusDanger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null)
                    const LinearProgressIndicator(
                      color: AppPalette.accentGold,
                    ),
                  if (cases.isEmpty &&
                      !snapshot.hasError &&
                      snapshot.data != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppPalette.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            color: AppPalette.textMuted,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No cases are registered yet. Use the quick operations below to open your docket or register your first matter.',
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1100
                          ? 4
                          : constraints.maxWidth > 700
                          ? 2
                          : 1;
                      final stats = [
                        (
                          'ACTIVE CASES',
                          open.length,
                          Icons.folder_open_outlined,
                          AppPalette.primaryGreen,
                        ),
                        (
                          'URGENT MATTERS',
                          urgent,
                          Icons.priority_high_rounded,
                          AppPalette.statusDanger,
                        ),
                        (
                          'WITH HEARING DATE',
                          upcoming,
                          Icons.calendar_month_outlined,
                          AppPalette.statusSuccess,
                        ),
                        (
                          'DATE NOT SET',
                          noDate,
                          Icons.event_busy_outlined,
                          AppPalette.statusWarning,
                        ),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final s in stats)
                            SizedBox(
                              width:
                                  (constraints.maxWidth - (cols - 1) * 12) /
                                  cols,
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppPalette.cardBackground,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppPalette.borderLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: s.$4.withValues(alpha: .09),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(s.$3, color: s.$4, size: 21),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.$1,
                                            style: const TextStyle(
                                              color: AppPalette.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: .7,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            s.$2.toString(),
                                            style: TextStyle(
                                              color: s.$4,
                                              fontSize: 25,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'QUICK OPERATIONS',
                    style: TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = constraints.maxWidth > 900
                            ? 3
                            : constraints.maxWidth > 600
                            ? 2
                            : 1;
                        final actions = [
                          (
                            'Open master docket',
                            'Search and review your cases',
                            Icons.folder_copy_outlined,
                            '/cases',
                          ),
                          (
                            'Search case records',
                            'Find by title, client or case number',
                            Icons.manage_search_rounded,
                            '/search_cases',
                          ),
                          (
                            'Register a case',
                            'Add a matter to the local docket',
                            Icons.add_circle_outline_rounded,
                            '/add_case',
                          ),
                          (
                            'Calendar & hearings',
                            'Review upcoming scheduled dates',
                            Icons.calendar_month_outlined,
                            '/calendar',
                          ),
                          (
                            'Daily cause list',
                            'Review matters on a selected date',
                            Icons.gavel_outlined,
                            '/cause_list',
                          ),
                          (
                            'Client directory',
                            'Open client records and contacts',
                            Icons.people_outline_rounded,
                            '/clients',
                          ),
                        ];
                        return GridView.count(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 116,
                          children: [
                            for (final a in actions)
                              Material(
                                color: AppPalette.cardBackground,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () =>
                                      Navigator.of(context)
                                          .pushReplacementNamed(a.$4),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(17),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppPalette.borderLight,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppPalette.statusTile,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            a.$3,
                                            color: AppPalette.primaryGreen,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a.$1,
                                                style: const TextStyle(
                                                  color:
                                                      AppPalette.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                a.$2,
                                                style: const TextStyle(
                                                  color:
                                                      AppPalette.textMuted,
                                                  fontSize: 10,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
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
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
