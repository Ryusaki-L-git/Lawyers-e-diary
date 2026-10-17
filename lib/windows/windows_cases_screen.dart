import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

/// Windows desktop case table backed by the existing user-scoped repository.
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

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  String get _pageTitle => switch (_status) {
    'completed' => 'Completed cases',
    'starred' => 'Starred cases',
    'urgent' => 'Urgent cases',
    'active' => 'Active cases',
    _ => 'All cases',
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openCase(BuildContext context, CaseModel item) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WindowsDesktopShell(
        activeRoute: '/cases',
        child: WindowsCaseDetailScreen(caseItem: item),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repository = CaseRepository(database: AppDatabase.instance);
    return Scaffold(
      backgroundColor: WindowsDesktopShell.canvas,
      body: SafeArea(
        child: StreamBuilder<List<CaseModel>>(
          stream: repository.watchCasesForCurrentUser(),
          builder: (context, snapshot) {
            final allCases = snapshot.data ?? const <CaseModel>[];
            final query = _search.text.trim().toLowerCase();
            var cases = allCases.where((item) {
              if (item.isDeleted) return false;
              if (_status == 'active' && item.status != 'active') return false;
              if (_status == 'completed' && !item.isCompleted) return false;
              if (_status == 'urgent' && !item.isUrgent) return false;
              if (_status == 'starred' && !item.isStarred) return false;
              if (query.isEmpty) return true;
              return (item.caseTitle + ' ' + item.caseNumber + ' ' + item.clientName + ' ' + item.courtName).toLowerCase().contains(query);
            }).toList();

            if (_sort == 'title') {
              cases.sort((a, b) => a.caseTitle.toLowerCase().compareTo(b.caseTitle.toLowerCase()));
            } else if (_sort == 'updated') {
              cases.sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CASE REGISTER', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    SizedBox(height: 7),
                    Text(_pageTitle, style: const TextStyle(fontFamily: 'Georgia', color: WindowsDesktopShell.forest, fontSize: 28, fontWeight: FontWeight.w700)),
                    SizedBox(height: 5),
                    Text('Search, review and organize your legal matters.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 13)),
                  ])),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/add_case'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New case'),
                    style: FilledButton.styleFrom(backgroundColor: WindowsDesktopShell.forest, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                  ),
                ]),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: WindowsDesktopShell.border)),
                  child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 12, children: [
                    SizedBox(
                      width: 360,
                      height: 42,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search title, client, case number or court',
                          prefixIcon: const Icon(Icons.search_rounded, size: 19),
                          filled: true,
                          fillColor: WindowsDesktopShell.canvas,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: WindowsDesktopShell.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: WindowsDesktopShell.border)),
                        ),
                      ),
                    ),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      for (final option in const [('all', 'All'), ('active', 'Active'), ('urgent', 'Urgent'), ('completed', 'Completed'), ('starred', 'Starred')])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: _status == option.$1,
                          onSelected: (_) => setState(() => _status = option.$1),
                          selectedColor: const Color(0xFFE7EDE7),
                          labelStyle: TextStyle(color: _status == option.$1 ? WindowsDesktopShell.forest : WindowsDesktopShell.muted, fontWeight: _status == option.$1 ? FontWeight.w700 : FontWeight.w500, fontSize: 11),
                          side: BorderSide(color: _status == option.$1 ? WindowsDesktopShell.forest : WindowsDesktopShell.border),
                        ),
                    ]),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        value: _sort,
                        decoration: InputDecoration(
                          labelText: 'Sort by',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: WindowsDesktopShell.border)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hearing', child: Text('Next hearing')),
                          DropdownMenuItem(value: 'updated', child: Text('Recently updated')),
                          DropdownMenuItem(value: 'title', child: Text('Case title')),
                        ],
                        onChanged: (value) => setState(() => _sort = value ?? 'hearing'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text(cases.length.toString() + ' matters', style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  const Text('from your authorized local case register', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
                  const Spacer(),
                  if (snapshot.connectionState == ConnectionState.waiting) const SizedBox(width: 100, child: LinearProgressIndicator(minHeight: 2, color: WindowsDesktopShell.gold)),
                ]),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: WindowsDesktopShell.border)),
                    child: snapshot.hasError
                        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Cases could not be loaded: ' + snapshot.error.toString())))
                        : cases.isEmpty
                            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.folder_open_outlined, color: WindowsDesktopShell.gold, size: 36),
                                const SizedBox(height: 12),
                                Text(query.isEmpty ? 'No cases in this view' : 'No matching cases', style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 5),
                                const Text('Try another filter or create a case to get started.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 12)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/add_case'), icon: const Icon(Icons.add_rounded), label: const Text('Create case')),
                              ]))
                            : Scrollbar(
                                child: SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF9F8F6)),
                                      headingTextStyle: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800),
                                      dataTextStyle: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 12),
                                      horizontalMargin: 22,
                                      columnSpacing: 30,
                                      columns: const [
                                        DataColumn(label: Text('CASE')),
                                        DataColumn(label: Text('CLIENT')),
                                        DataColumn(label: Text('COURT')),
                                        DataColumn(label: Text('NEXT HEARING')),
                                        DataColumn(label: Text('STATUS')),
                                        DataColumn(label: Text('TYPE')),
                                      ],
                                      rows: [
                                        for (final item in cases)
                                          DataRow(
                                            onSelectChanged: (_) => _openCase(context, item),
                                            cells: [
                                              DataCell(SizedBox(width: 240, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text(item.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: WindowsDesktopShell.forest)),
                                                const SizedBox(height: 3),
                                                Text(item.caseNumber, style: const TextStyle(fontSize: 10, color: WindowsDesktopShell.muted)),
                                              ]))),
                                              DataCell(SizedBox(width: 140, child: Text(item.clientName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                                              DataCell(SizedBox(width: 160, child: Text(item.courtName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                                              DataCell(Text(_date(item.nextHearingDate))),
                                              DataCell(_StatusPill(status: item.status)),
                                              DataCell(Text(item.caseType)),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return 'Not scheduled';
    return value.day.toString().padLeft(2, '0') + '/' + value.month.toString().padLeft(2, '0') + '/' + value.year.toString();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'urgent' ? const Color(0xFF9A4A3F) : normalized == 'completed' ? const Color(0xFF536D5A) : WindowsDesktopShell.forest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(7)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
    );
  }
}
