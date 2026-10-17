import 'package:flutter/material.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import 'windows_desktop_shell.dart';

class WindowsCaseDetailScreen extends StatefulWidget {
  const WindowsCaseDetailScreen({super.key, required this.caseItem});
  final CaseModel caseItem;

  @override
  State<WindowsCaseDetailScreen> createState() => _WindowsCaseDetailScreenState();
}

class _WindowsCaseDetailScreenState extends State<WindowsCaseDetailScreen> {
  late bool _starred = widget.caseItem.isStarred;
  bool _busy = false;
  final _repository = CaseRepository(database: AppDatabase.instance);

  @override
  Widget build(BuildContext context) {
    final item = widget.caseItem;
    return Scaffold(
      backgroundColor: WindowsDesktopShell.canvas,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Back to case register'),
            const SizedBox(width: 10),
            const Expanded(child: Text('CASE WORKSPACE', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
            OutlinedButton.icon(onPressed: _busy ? null : _toggleStar, icon: Icon(_starred ? Icons.star_rounded : Icons.star_outline_rounded, color: WindowsDesktopShell.gold), label: Text(_starred ? 'Starred' : 'Star case')),
            const SizedBox(width: 10),
            FilledButton.icon(onPressed: () => Navigator.of(context).pushNamed('/juris'), icon: const Icon(Icons.auto_awesome_rounded, size: 18), label: const Text('Discuss with JURIS'), style: FilledButton.styleFrom(backgroundColor: WindowsDesktopShell.forest)),
          ]),
          const SizedBox(height: 24),
          Container(width: double.infinity, padding: const EdgeInsets.all(27), decoration: BoxDecoration(color: WindowsDesktopShell.forest, borderRadius: BorderRadius.circular(18)), child: Wrap(spacing: 24, runSpacing: 18, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 500, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.caseType.toUpperCase(), style: const TextStyle(color: WindowsDesktopShell.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text(item.caseTitle, style: const TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 27, fontWeight: FontWeight.w700, height: 1.2)),
              const SizedBox(height: 12),
              Wrap(spacing: 9, runSpacing: 8, children: [_HeroTag(item.caseNumber), _HeroTag(item.courtName), _HeroTag(item.status.toUpperCase())]),
            ])),
            SizedBox(width: 260, child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NEXT HEARING', style: TextStyle(color: Color(0xFFD9E2DA), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(_date(item.nextHearingDate), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Keep the next date in view.', style: TextStyle(color: Color(0xFFD9E2DA), fontSize: 11)),
            ]))),
          ])),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Panel(title: 'Parties', icon: Icons.people_outline_rounded, child: Column(children: [
                _FactRow('Client', item.clientName),
                if (item.opponentName.trim().isNotEmpty) _FactRow('Opposing party', item.opponentName),
                if (item.clientPhone?.trim().isNotEmpty == true) _FactRow('Client phone', item.clientPhone!),
                _FactRow('Handled by', item.handledBy),
              ])),
              const SizedBox(height: 16),
              _Panel(title: 'Court & schedule', icon: Icons.account_balance_outlined, child: Column(children: [
                _FactRow('Court / forum', item.courtName),
                _FactRow('Next hearing', _date(item.nextHearingDate)),
                _FactRow('Created', _date(item.createdAt)),
                _FactRow('Last updated', _date(item.updatedAt)),
              ])),
            ]);
            final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Panel(title: 'Case notes', icon: Icons.notes_rounded, child: item.notes.isEmpty
                ? const _EmptySection(message: 'No notes are attached to this case yet.')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final note in item.notes) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 6, color: WindowsDesktopShell.gold), const SizedBox(width: 10), Expanded(child: Text(note, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 13, height: 1.55)))]))])),
              const SizedBox(height: 16),
              _Panel(title: 'Documents', icon: Icons.description_outlined, child: item.documents.isEmpty
                ? const _EmptySection(message: 'No documents are attached to this case yet.')
                : Column(children: [for (final document in item.documents) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.description_outlined, color: WindowsDesktopShell.forest), title: Text(document.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), subtitle: Text(document.type + ' · ' + document.size, style: const TextStyle(fontSize: 10, color: WindowsDesktopShell.muted)))])),
            ]);
            if (constraints.maxWidth < 940) return Column(children: [left, const SizedBox(height: 16), right]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 18), Expanded(child: right)]);
          }),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _busy ? null : _archiveCase, icon: const Icon(Icons.archive_outlined, color: Color(0xFF9A4A3F)), label: const Text('Move to deleted cases', style: TextStyle(color: Color(0xFF9A4A3F)))),
        ]),
      )),
    );
  }

  Future<void> _toggleStar() async {
    setState(() => _busy = true);
    try {
      await _repository.setCaseStarred(widget.caseItem.id, !_starred);
      if (mounted) setState(() => _starred = !_starred);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update starred status: ' + error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveCase() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Move case to deleted cases?'),
      content: Text('"' + widget.caseItem.caseTitle + '" will be marked deleted in the local case register.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move to deleted'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.softDeleteCase(widget.caseItem.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not archive case: ' + error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Not scheduled';
    return value.day.toString().padLeft(2, '0') + '/' + value.month.toString().padLeft(2, '0') + '/' + value.year.toString();
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x33FFFFFF))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: WindowsDesktopShell.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, color: WindowsDesktopShell.gold, size: 19), const SizedBox(width: 9), Text(title, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 15, fontWeight: FontWeight.w800))]),
    const SizedBox(height: 15), child,
  ]));
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 125, child: Text(label, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 11, fontWeight: FontWeight.w600))),
    Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 12, fontWeight: FontWeight.w700))),
  ]));
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(message, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 12)));
}
