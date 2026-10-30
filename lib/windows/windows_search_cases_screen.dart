import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

/// Windows docket discovery surface.
///
/// Searches the signed-in user's own local case register by title, client or
/// case number and narrows the result set by status and ordering.
class WindowsSearchCasesScreen extends StatefulWidget {
  const WindowsSearchCasesScreen({super.key, this.initialQuery});

  /// A query the screen starts with.
  ///
  /// The desktop workspace uses this to hand a search over from the home
  /// screen so the user does not have to retype it.
  final String? initialQuery;

  @override
  State<WindowsSearchCasesScreen> createState() =>
      _WindowsSearchCasesScreenState();
}

class _WindowsSearchCasesScreenState extends State<WindowsSearchCasesScreen> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  final _repo = CaseRepository(database: AppDatabase.instance);

  String _status = 'All';
  String _sort = 'nextHearing';

  int _retry = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
              const WindowsPageHeader(
                eyebrow: 'DOCKET DISCOVERY',
                title: 'Search cases',
                subtitle: 'Search your local case register by title, client, or case number.',
              ),
              const SizedBox(height: 20),
              _filters(),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<CaseModel>>(
                  key: ValueKey(_retry),
                  stream: _repo.watchCasesForCurrentUser(
                    searchQuery: _query.text,
                    status: _status,
                    sortBy: _sort,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return WindowsMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Search unavailable',
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

                    final items = snapshot.data ?? const <CaseModel>[];

                    if (items.isEmpty) {
                      return WindowsMessageState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching cases',
                        message: _query.text.isEmpty
                            ? 'No cases are available in this view yet.'
                            : 'Try a different title, client name, or case number.',
                      );
                    }

                    final compactResults = MediaQuery.sizeOf(context).width < 1100;

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
                                bottom: BorderSide(
                                  color: AppPalette.borderLight,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                WindowsColumnLabel(
                                  'Case register · ${items.length}',
                                  flex: 4,
                                ),
                                if (!compactResults)
                                  const WindowsColumnLabel('Client', flex: 2),
                                const WindowsColumnLabel(
                                  'Next hearing',
                                  flex: 2,
                                ),
                                const WindowsColumnLabel('Status', flex: 2),
                                const SizedBox(width: 19),
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
                                final c = items[index];

                                final color = c.isUrgent
                                    ? AppPalette.statusDanger
                                    : c.isCompleted
                                    ? AppPalette.statusSuccess
                                    : AppPalette.primaryGreen;

                                final hearingDate = c.nextHearingDate;

                                final hearingLabel = hearingDate == null
                                    ? 'Not scheduled'
                                    : '${hearingDate.day.toString().padLeft(2, '0')}/'
                                          '${hearingDate.month.toString().padLeft(2, '0')}/'
                                          '${hearingDate.year}';

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
                                        if (!compactResults)
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
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            hearingLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppPalette.textPrimary,
                                              fontSize: 11,
                                            ),
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
  }

  /// The filter toolbar.
  ///
  /// A narrow window stacks the controls so the field keeps a usable width
  /// and the toolbar never overflows.
  Widget _filters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 640;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchField(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _statusFilter()),
                  const SizedBox(width: 12),
                  Expanded(child: _sortFilter()),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _searchField()),
            const SizedBox(width: 12),
            SizedBox(width: 165, child: _statusFilter()),
            const SizedBox(width: 12),
            SizedBox(width: 190, child: _sortFilter()),
          ],
        );
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _query,
      onChanged: (_) => setState(() {}),
      decoration:
          const WindowsFieldDecoration(
            hint: 'Search title, client or case number',
          ).build().copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: 'Search',
          ),
    );
  }

  Widget _statusFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _status,
      isExpanded: true,
      decoration: const WindowsFieldDecoration(hint: 'All statuses')
          .build()
          .copyWith(labelText: 'Status'),
      items: const ['All', 'active', 'upcoming', 'urgent', 'completed']
          .map(
            (v) => DropdownMenuItem<String>(
              value: v,
              child: Text(
                v == 'All'
                    ? 'All statuses'
                    : v[0].toUpperCase() + v.substring(1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => _status = v);
        }
      },
    );
  }

  Widget _sortFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _sort,
      isExpanded: true,
      decoration: const WindowsFieldDecoration(hint: 'Next hearing')
          .build()
          .copyWith(labelText: 'Sort by'),
      items: const [
        DropdownMenuItem<String>(
          value: 'nextHearing',
          child: Text('Next hearing', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem<String>(
          value: 'title',
          child: Text('Case title', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem<String>(
          value: 'created',
          child: Text('Recently updated', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (v) {
        if (v != null) {
          setState(() => _sort = v);
        }
      },
    );
  }
}
