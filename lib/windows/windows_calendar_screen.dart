import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
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
  DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final _repository = CaseRepository(database: AppDatabase.instance);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WindowsDesktopShell.canvas,
    body: SafeArea(child: StreamBuilder<List<CaseModel>>(
      stream: _repository.watchCasesForCurrentUser(),
      builder: (context, snapshot) {
        final cases = (snapshot.data ?? const <CaseModel>[]).where((c) => !c.isDeleted && !c.isCompleted && c.nextHearingDate != null).toList();
        final selectedHearings = cases.where((c) => _sameDay(c.nextHearingDate!, _selected)).toList()..sort((a,b) => a.caseTitle.compareTo(b.caseTitle));
        final monthHearings = cases.where((c) => c.nextHearingDate!.year == _month.year && c.nextHearingDate!.month == _month.month).toList();
        final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
        final monthName = _monthName(_month.month);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HEARINGS & SCHEDULE', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                SizedBox(height: 7),
                Text('Calendar', style: TextStyle(fontFamily: 'Georgia', color: WindowsDesktopShell.forest, fontSize: 29, fontWeight: FontWeight.w700)),
                SizedBox(height: 5),
                Text('Plan the docket around your upcoming hearing dates.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 13)),
              ])),
              OutlinedButton.icon(onPressed: () => Navigator.of(context).pushNamed('/cause_list'), icon: const Icon(Icons.gavel_rounded, size: 17), label: const Text('Cause list')),
              const SizedBox(width: 10),
              FilledButton.icon(onPressed: () => Navigator.of(context).pushNamed('/add_case'), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New case'), style: FilledButton.styleFrom(backgroundColor: WindowsDesktopShell.forest)),
            ]),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final calendarPanel = Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: WindowsDesktopShell.border)), child: Column(children: [
                Row(children: [
                  IconButton(onPressed: () => setState(() { _month = DateTime(_month.year, _month.month - 1, 1); _selected = DateTime(_month.year, _month.month, 1); }), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(child: Column(children: [
                    Text(monthName, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(_month.year.toString() + ' · ' + monthHearings.length.toString() + ' scheduled matters', style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
                  ])),
                  IconButton(onPressed: () => setState(() { _month = DateTime(_month.year, _month.month + 1, 1); _selected = DateTime(_month.year, _month.month, 1); }), icon: const Icon(Icons.chevron_right_rounded)),
                ]),
                const SizedBox(height: 18),
                const Row(children: [
                  _Weekday('SUN'), _Weekday('MON'), _Weekday('TUE'), _Weekday('WED'), _Weekday('THU'), _Weekday('FRI'), _Weekday('SAT'),
                ]),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cellCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 7, crossAxisSpacing: 7, childAspectRatio: 0.95),
                  itemBuilder: (context, index) {
                    final day = index - firstWeekday + 1;
                    if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                    final date = DateTime(_month.year, _month.month, day);
                    final count = monthHearings.where((c) => _sameDay(c.nextHearingDate!, date)).length;
                    final selected = _sameDay(date, _selected);
                    final today = _sameDay(date, DateTime.now());
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selected = date),
                      child: Container(
                        decoration: BoxDecoration(color: selected ? WindowsDesktopShell.forest : today ? const Color(0xFFE9EEE9) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? WindowsDesktopShell.forest : today ? const Color(0xFFB8C8BB) : Colors.transparent)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(day.toString(), style: TextStyle(color: selected ? Colors.white : WindowsDesktopShell.ink, fontSize: 13, fontWeight: selected || today ? FontWeight.w800 : FontWeight.w500)),
                          const SizedBox(height: 5),
                          if (count > 0) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(width: 5, height: 5, decoration: BoxDecoration(color: selected ? WindowsDesktopShell.gold : const Color(0xFF9B782B), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(count.toString(), style: TextStyle(color: selected ? Colors.white : WindowsDesktopShell.forest, fontSize: 9, fontWeight: FontWeight.w800)),
                          ]) else const SizedBox(height: 10),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 15),
                Row(children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: WindowsDesktopShell.gold, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  const Text('Dates with scheduled hearings show a count.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10)),
                ]),
              ]));
              final agenda = Container(padding: const EdgeInsets.all(21), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: WindowsDesktopShell.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selected.day.toString().padLeft(2, '0') + ' ' + _monthName(_selected.month) + ' ' + _selected.year.toString(), style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(selectedHearings.length.toString() + ' hearing' + (selectedHearings.length == 1 ? '' : 's') + ' scheduled', style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
                const SizedBox(height: 18),
                if (snapshot.hasError) Text('Could not load the hearing agenda: ' + snapshot.error.toString(), style: const TextStyle(color: Color(0xFF9A4A3F), fontSize: 12))
                else if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) const LinearProgressIndicator(color: WindowsDesktopShell.gold)
                else if (selectedHearings.isEmpty) const _AgendaEmpty()
                else for (final item in selectedHearings) _HearingTile(item: item, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WindowsDesktopShell(activeRoute: '/cases', child: WindowsCaseDetailScreen(caseItem: item))))),
              ]));
              if (!wide) return Column(children: [calendarPanel, const SizedBox(height: 18), agenda]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: calendarPanel), const SizedBox(width: 18), Expanded(flex: 5, child: agenda)]);
            }),
          ]),
        );
      },
    )),
  );

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  String _monthName(int month) => const ['January','February','March','April','May','June','July','August','September','October','November','December'][month - 1];
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(child: Center(child: Text(label, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5))));
}

class _HearingTile extends StatelessWidget {
  const _HearingTile({required this.item, required this.onTap});
  final CaseModel item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: WindowsDesktopShell.canvas, borderRadius: BorderRadius.circular(11), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(11), child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 37, height: 39, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.gavel_outlined, color: WindowsDesktopShell.forest, size: 18)),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.caseTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(item.caseNumber + ' · ' + item.clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10)),
      const SizedBox(height: 5),
      Text(item.courtName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WindowsDesktopShell.forest, fontSize: 10, fontWeight: FontWeight.w700)),
    ])),
    const Icon(Icons.chevron_right_rounded, color: WindowsDesktopShell.muted, size: 18),
  ]))))));
}

class _AgendaEmpty extends StatelessWidget {
  const _AgendaEmpty();
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.symmetric(vertical: 35), child: Center(child: Column(children: [
    Icon(Icons.event_available_outlined, size: 34, color: WindowsDesktopShell.gold),
    SizedBox(height: 12),
    Text('No hearings on this date', style: TextStyle(color: WindowsDesktopShell.ink, fontSize: 13, fontWeight: FontWeight.w800)),
    SizedBox(height: 5),
    Text('Choose a marked day to review scheduled matters.', textAlign: TextAlign.center, style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
  ])));
}
