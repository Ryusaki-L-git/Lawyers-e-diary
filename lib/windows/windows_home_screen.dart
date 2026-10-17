import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import 'windows_desktop_shell.dart';

/// Desktop-first legal command center using LED's authenticated local case repository.
class WindowsHomeScreen extends StatelessWidget {
  const WindowsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = WindowsDesktopShell.forest;
    const gold = WindowsDesktopShell.gold;
    const canvas = WindowsDesktopShell.canvas;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(backgroundColor: canvas, body: Center(child: Text('Please sign in to view your legal workspace.')));
    }
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final name = (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : ((user.email ?? '').split('@').first);
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final dateLabel = weekdays[now.weekday - 1].toUpperCase() + ', ' + months[now.month - 1] + ' ' + now.day.toString() + ', ' + now.year.toString();
    final repository = CaseRepository(database: AppDatabase.instance);

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: StreamBuilder<List<CaseModel>>(
          stream: repository.watchCasesForCurrentUser(),
          builder: (context, snapshot) {
            final cases = snapshot.data ?? const <CaseModel>[];
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));
            final hearings = cases.where((item) {
              final d = item.nextHearingDate;
              return d != null && !d.isBefore(today) && d.isBefore(tomorrow) && !item.isDeleted && !item.isCompleted;
            }).toList()..sort((a, b) => a.nextHearingDate!.compareTo(b.nextHearingDate!));
            final active = cases.where((c) => !c.isDeleted && !c.isCompleted).length;
            final urgent = cases.where((c) => c.isUrgent && !c.isDeleted).length;
            final starred = cases.where((c) => c.isStarred && !c.isDeleted).length;
            final recent = [...cases]..sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));

            return LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final columns = constraints.maxWidth >= 1120 ? 4 : constraints.maxWidth >= 660 ? 2 : 1;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(wide ? 32 : 22, 28, wide ? 32 : 22, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dateLabel, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 9),
                      Text(greeting + ', ' + (name.isEmpty ? 'Counsel' : name), style: TextStyle(fontFamily: 'Georgia', fontSize: wide ? 31 : 25, height: 1.15, fontWeight: FontWeight.w700, color: forest, letterSpacing: -0.7)),
                      const SizedBox(height: 8),
                      const Text('Your practice, clearly in view.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 14)),
                    ])),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/add_case'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New case'),
                      style: OutlinedButton.styleFrom(foregroundColor: forest, side: const BorderSide(color: forest), padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ]),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: forest, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF345640))),
                    child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 20, runSpacing: 16, children: [
                      const SizedBox(width: 350, child: Row(children: [
                        Icon(Icons.balance_rounded, color: gold, size: 30),
                        SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Your legal command center', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 19, fontWeight: FontWeight.w700)),
                          SizedBox(height: 6),
                          Text('Keep your docket, hearings and daily priorities within reach.', style: TextStyle(color: Color(0xFFD9E2DA), fontSize: 12, height: 1.4)),
                        ])),
                      ])),
                      Wrap(spacing: 9, children: [
                        FilledButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/cases'), style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: forest), child: const Text('View docket')),
                        OutlinedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/calendar'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x66FFFFFF))), child: const Text('Calendar')),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  if (snapshot.hasError) Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(11)), child: Text('Case data could not be loaded: ' + snapshot.error.toString(), style: const TextStyle(color: Color(0xFF7B4B1E), fontSize: 12))),
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) const LinearProgressIndicator(minHeight: 2, color: gold),
                  const SizedBox(height: 18),
                  Wrap(spacing: 14, runSpacing: 14, children: [
                    _MetricCard(title: 'Active matters', value: active.toString(), caption: 'Your current docket', icon: Icons.folder_open_outlined, color: forest, width: (constraints.maxWidth - 14 * (columns - 1)) / columns),
                    _MetricCard(title: "Today's hearings", value: hearings.length.toString(), caption: 'Scheduled for today', icon: Icons.calendar_today_outlined, color: const Color(0xFF8B6A25), width: (constraints.maxWidth - 14 * (columns - 1)) / columns),
                    _MetricCard(title: 'Urgent matters', value: urgent.toString(), caption: 'Marked for attention', icon: Icons.priority_high_rounded, color: const Color(0xFF9A4A3F), width: (constraints.maxWidth - 14 * (columns - 1)) / columns),
                    _MetricCard(title: 'Starred cases', value: starred.toString(), caption: 'Quick-access matters', icon: Icons.star_outline_rounded, color: const Color(0xFF536D5A), width: (constraints.maxWidth - 14 * (columns - 1)) / columns),
                  ]),
                  const SizedBox(height: 28),
                  if (wide)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 7, child: _CasePanel(title: "Today's hearings", subtitle: 'The matters on your schedule today', cases: hearings, loading: snapshot.connectionState == ConnectionState.waiting, emptyTitle: 'No hearings scheduled today', emptyDetail: 'Your docket is clear for today.', onAction: () => Navigator.of(context).pushReplacementNamed('/calendar'), actionLabel: 'Open calendar')),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: _CasePanel(title: 'Recently updated', subtitle: 'Your latest case activity', cases: recent.take(5).toList(), loading: snapshot.connectionState == ConnectionState.waiting, emptyTitle: 'Your docket starts here', emptyDetail: 'Create a case to see your work organized.', onAction: () => Navigator.of(context).pushReplacementNamed('/cases'), actionLabel: 'All cases')),
                    ])
                  else ...[
                    _CasePanel(title: "Today's hearings", subtitle: 'The matters on your schedule today', cases: hearings, loading: snapshot.connectionState == ConnectionState.waiting, emptyTitle: 'No hearings scheduled today', emptyDetail: 'Your docket is clear for today.', onAction: () => Navigator.of(context).pushReplacementNamed('/calendar'), actionLabel: 'Open calendar'),
                    const SizedBox(height: 18),
                    _CasePanel(title: 'Recently updated', subtitle: 'Your latest case activity', cases: recent.take(5).toList(), loading: snapshot.connectionState == ConnectionState.waiting, emptyTitle: 'Your docket starts here', emptyDetail: 'Create a case to see your work organized.', onAction: () => Navigator.of(context).pushReplacementNamed('/cases'), actionLabel: 'All cases'),
                  ],
                  const SizedBox(height: 28),
                  const Text('QUICK ACCESS', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 13),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _QuickAccess('Clients', Icons.people_outline_rounded, () => Navigator.of(context).pushReplacementNamed('/clients')),
                    _QuickAccess('Reminders', Icons.notifications_none_rounded, () => Navigator.of(context).pushReplacementNamed('/reminders')),
                    _QuickAccess('Fees & transactions', Icons.account_balance_wallet_outlined, () => Navigator.of(context).pushReplacementNamed('/fee')),
                    _QuickAccess('Team workspace', Icons.groups_2_outlined, () => Navigator.of(context).pushReplacementNamed('/team')),
                    _QuickAccess('JURIS intelligence', Icons.auto_awesome_outlined, () => Navigator.of(context).pushReplacementNamed('/juris')),
                    _QuickAccess('Starred cases', Icons.star_outline_rounded, () => Navigator.of(context).pushReplacementNamed('/starred')),
                  ]),
                ]),
              );
            });
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.caption, required this.icon, required this.color, required this.width});
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: WindowsDesktopShell.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 12, fontWeight: FontWeight.w600))), Container(width: 35, height: 35, decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 19))]),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
      const SizedBox(height: 5),
      Text(caption, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
    ]),
  ));
}

class _CasePanel extends StatelessWidget {
  const _CasePanel({required this.title, required this.subtitle, required this.cases, required this.loading, required this.emptyTitle, required this.emptyDetail, required this.onAction, required this.actionLabel});
  final String title;
  final String subtitle;
  final List<CaseModel> cases;
  final bool loading;
  final String emptyTitle;
  final String emptyDetail;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: WindowsDesktopShell.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
      ])), TextButton(onPressed: onAction, child: Text(actionLabel))]),
      const SizedBox(height: 8),
      if (loading && cases.isEmpty) const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator(color: WindowsDesktopShell.gold))
      else if (cases.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(8, 24, 8, 26), child: Center(child: Column(children: [
        const Icon(Icons.event_available_outlined, size: 30, color: WindowsDesktopShell.gold),
        const SizedBox(height: 11),
        Text(emptyTitle, textAlign: TextAlign.center, style: const TextStyle(color: WindowsDesktopShell.ink, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 5),
        Text(emptyDetail, textAlign: TextAlign.center, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
        const SizedBox(height: 10),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ])))
      else for (final item in cases) _CaseRow(caseItem: item),
    ]),
  );
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.caseItem});
  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final date = caseItem.nextHearingDate ?? caseItem.updatedAt;
    final label = date == null ? 'Date not set' : date.day.toString().padLeft(2, '0') + '/' + date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WindowsDesktopShell.border))),
      child: Row(children: [
        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: WindowsDesktopShell.canvas, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.folder_open_outlined, color: WindowsDesktopShell.forest, size: 19)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(caseItem.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(caseItem.caseNumber + ' · ' + caseItem.clientName + ' · ' + caseItem.courtName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10)),
        ])),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: WindowsDesktopShell.forest, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: OutlinedButton.styleFrom(foregroundColor: WindowsDesktopShell.forest, side: const BorderSide(color: WindowsDesktopShell.border), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
  );
}
