import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_ticket_model.dart';
import '../services/support_service.dart';
import 'windows_desktop_shell.dart';

class WindowsSupportScreen extends StatefulWidget {
  const WindowsSupportScreen({super.key});
  @override
  State<WindowsSupportScreen> createState() => _WindowsSupportScreenState();
}

class _WindowsSupportScreenState extends State<WindowsSupportScreen> {
  int _tab = 0;
  static const _faqs = <(String, String)>[
    ('Can I use LED offline?', 'LED has a local-first case register for supported case workflows. Cloud-backed features still require a connection, and pending changes need a configured synchronization workflow.'),
    ('How do I find a matter?', 'Open Search cases and search by case title, client name or case number. Use status and sorting controls to narrow the register.'),
    ('Where can I review hearing dates?', 'Use Calendar & hearings for the month and selected-day agenda, or Cause list for a specific date.'),
    ('How do I request help?', 'Submit a request, select its category and type, and describe the issue without including passwords or unnecessary confidential client information.'),
    ('Is cloud sync configured?', 'The app contains cloud and subscription screens, but actual synchronization and account configuration must be verified for your environment.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WindowsDesktopShell.canvas,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ASSISTANCE & ACCOUNT CARE', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 7),
        const Text('Help & support', style: TextStyle(fontFamily: 'Georgia', color: WindowsDesktopShell.forest, fontSize: 29, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Text('Find guidance or contact the LED support team.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 13)),
        const SizedBox(height: 20),
        Row(children: [
          _tabButton('Knowledge center', 0), const SizedBox(width: 8),
          _tabButton('My requests', 1), const Spacer(),
          FilledButton.icon(onPressed: _submitRequest, icon: const Icon(Icons.add_comment_outlined, size: 18), label: const Text('Submit request'), style: FilledButton.styleFrom(backgroundColor: WindowsDesktopShell.forest, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
        ]),
        const SizedBox(height: 16),
        Expanded(child: _tab == 0 ? _buildFaq() : _buildTickets()),
      ]),
    )),
  );

  Widget _tabButton(String label, int index) => OutlinedButton(
    onPressed: () => setState(() => _tab = index),
    style: OutlinedButton.styleFrom(backgroundColor: _tab == index ? WindowsDesktopShell.forest : Colors.white, foregroundColor: _tab == index ? Colors.white : WindowsDesktopShell.ink, side: BorderSide(color: _tab == index ? WindowsDesktopShell.forest : WindowsDesktopShell.border), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  );

  Widget _buildFaq() => ListView(children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: WindowsDesktopShell.forest, borderRadius: BorderRadius.circular(16)), child: const Row(children: [
      Icon(Icons.support_agent_rounded, color: WindowsDesktopShell.gold, size: 34), SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A focused answer, when you need it.', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700)),
        SizedBox(height: 6), Text('Browse common questions or send a support request and track follow-up.', style: TextStyle(color: Color(0xFFD8E1D9), fontSize: 12, height: 1.5)),
      ])),
    ])),
    const SizedBox(height: 16),
    for (final faq in _faqs) Padding(padding: const EdgeInsets.only(bottom: 9), child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: WindowsDesktopShell.border)),
      child: ExpansionTile(leading: const Icon(Icons.help_outline_rounded, color: WindowsDesktopShell.gold), title: Text(faq.$1, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 13, fontWeight: FontWeight.w800)), childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18), children: [Text(faq.$2, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 12, height: 1.6))]),
    )),
  ]);

  Widget _buildTickets() => StreamBuilder<List<SupportTicketModel>>(
    stream: SupportService.instance.watchMyTickets(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _empty('Requests are unavailable', 'Could not load your support requests. Please try again later.');
      if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) return const Center(child: CircularProgressIndicator(color: WindowsDesktopShell.forest));
      final tickets = snapshot.data ?? const <SupportTicketModel>[];
      if (tickets.isEmpty) return _empty('No support requests yet', 'Requests you submit will appear here with their current status.');
      return ListView.separated(
        itemCount: tickets.length, separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final t = tickets[index];
          final color = t.status == 'resolved' ? const Color(0xFF536D5A) : t.status == 'under_review' ? const Color(0xFF9B782B) : WindowsDesktopShell.forest;
          return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: WindowsDesktopShell.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.confirmation_number_outlined, color: WindowsDesktopShell.gold, size: 28), const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.subject, style: const TextStyle(color: WindowsDesktopShell.ink, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(t.category + ' · ' + t.type + ' · ' + (t.createdAt == null ? 'Date pending' : DateFormat('dd MMM yyyy').format(t.createdAt!)), style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 10)),
              const SizedBox(height: 8), Text(t.message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 12, height: 1.5)),
            ])),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(7)), child: Text(t.status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800))),
          ]));
        },
      );
    },
  );

  Widget _empty(String title, String subtitle) => Center(child: Container(width: 460, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: WindowsDesktopShell.border)), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.support_agent_rounded, color: WindowsDesktopShell.gold, size: 40), const SizedBox(height: 12),
    Text(title, textAlign: TextAlign.center, style: const TextStyle(color: WindowsDesktopShell.ink, fontFamily: 'Georgia', fontSize: 19, fontWeight: FontWeight.w700)),
    const SizedBox(height: 7), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: WindowsDesktopShell.muted, fontSize: 12, height: 1.5)),
  ]));

  Future<void> _submitRequest() async {
    final key = GlobalKey<FormState>();
    final subject = TextEditingController();
    final message = TextEditingController();
    String type = 'inquiry';
    String category = 'Case Management';
    bool busy = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Submit support request', style: TextStyle(color: WindowsDesktopShell.forest, fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        content: SizedBox(width: 500, child: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Do not include passwords or unnecessary confidential client details.', style: TextStyle(color: WindowsDesktopShell.muted, fontSize: 11)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Request type'), items: const [
            DropdownMenuItem(value: 'inquiry', child: Text('Question')), DropdownMenuItem(value: 'bug', child: Text('Report a bug')), DropdownMenuItem(value: 'feature', child: Text('Feature request')), DropdownMenuItem(value: 'feedback', child: Text('Feedback')),
          ], onChanged: (v) { if (v != null) setDialogState(() => type = v); }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'), items: const [
            DropdownMenuItem(value: 'Case Management', child: Text('Case management')), DropdownMenuItem(value: 'Cloud Sync', child: Text('Cloud sync')), DropdownMenuItem(value: 'Billing & Fees', child: Text('Billing & fees')), DropdownMenuItem(value: 'Other', child: Text('Other')),
          ], onChanged: (v) { if (v != null) setDialogState(() => category = v); }),
          const SizedBox(height: 10),
          TextFormField(controller: subject, decoration: const InputDecoration(labelText: 'Subject'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a subject' : null),
          const SizedBox(height: 10),
          TextFormField(controller: message, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Describe the issue', alignLabelWithHint: true), validator: (v) => v == null || v.trim().isEmpty ? 'Describe the request' : null),
        ]))),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: busy ? null : () async {
            if (!key.currentState!.validate()) return;
            setDialogState(() => busy = true);
            final id = await SupportService.instance.submitSupportTicket(type: type, category: category, subject: subject.text, message: message.text);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop(id != null);
          }, style: FilledButton.styleFrom(backgroundColor: WindowsDesktopShell.forest), child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send request')),
        ],
      )),
    );
    subject.dispose();
    message.dispose();
    if (!mounted) return;
    if (result == true) {
      setState(() => _tab = 1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support request submitted.')));
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request was not submitted. You can try again.')));
    }
  }
}
