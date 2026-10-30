import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_ticket_model.dart';
import '../services/support_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// Desktop help and support surface.
///
/// The knowledge centre copy is fixed product guidance, and the request list
/// reads the signed-in user's own support requests from [SupportService].
class WindowsSupportScreen extends StatefulWidget {
  const WindowsSupportScreen({super.key});
  @override
  State<WindowsSupportScreen> createState() => _WindowsSupportScreenState();
}

class _WindowsSupportScreenState extends State<WindowsSupportScreen> {
  int _tab = 0;
  Stream<List<SupportTicketModel>>? _ticketsStream;
  static const _faqs = <(String, String)>[
    (
      'Can I use LED offline?',
      'LED has a local-first case register for supported case workflows. Cloud-backed features still require a connection, and pending changes need a configured synchronization workflow.',
    ),
    (
      'How do I find a matter?',
      'Open Search cases and search by case title, client name or case number. Use status and sorting controls to narrow the register.',
    ),
    (
      'Where can I review hearing dates?',
      'Use Calendar & hearings for the month and selected-day agenda, or Cause list for a specific date.',
    ),
    (
      'How do I request help?',
      'Submit a request, select its category and type, and describe the issue without including passwords or unnecessary confidential client information.',
    ),
    (
      'Is cloud sync configured?',
      'The app contains cloud and subscription screens, but actual synchronization and account configuration must be verified for your environment.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ticketsStream = SupportService.instance.watchMyTickets();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WindowsPageHeader(
              eyebrow: 'ASSISTANCE & ACCOUNT CARE',
              title: 'Help & support',
              subtitle: 'Find guidance or contact the LED support team.',
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final filter = WindowsFilterBar(
                  options: const [
                    ('knowledge', 'Knowledge center'),
                    ('requests', 'My requests'),
                  ],
                  selected: _tab == 0 ? 'knowledge' : 'requests',
                  onChanged: (value) =>
                      setState(() => _tab = value == 'knowledge' ? 0 : 1),
                );
                final action = FilledButton.icon(
                  onPressed: _submitRequest,
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Submit request'),
                  style: WindowsButtonStyles.primary(),
                );
                return compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          filter,
                          const SizedBox(height: 10),
                          action,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: filter),
                          const SizedBox(width: 12),
                          action,
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            Expanded(child: _tab == 0 ? _buildFaq() : _buildTickets()),
          ],
        ),
      ),
    ),
  );

  Widget _buildFaq() => ListView(
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppPalette.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.onForestBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.support_agent_rounded,
              color: AppPalette.accentGold,
              size: 34,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A focused answer, when you need it.',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: AppTypography.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Browse common questions or send a support request and track follow-up.',
                    style: TextStyle(
                      color: AppPalette.onForestMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (final faq in _faqs)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: WindowsPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const Icon(
                Icons.help_outline_rounded,
                color: AppPalette.accentGold,
              ),
              title: Text(
                faq.$1,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              children: [
                Text(
                  faq.$2,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _buildTickets() => StreamBuilder<List<SupportTicketModel>>(
    stream: _ticketsStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return WindowsMessageState(
          icon: Icons.error_outline_rounded,
          title: 'Requests are unavailable',
          message: 'Could not load your support requests. Please try again later.',
          isError: true,
          action: OutlinedButton(
            onPressed: _retryTickets,
            style: WindowsButtonStyles.secondary(),
            child: const Text('Try again'),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting &&
          snapshot.data == null) {
        return const WindowsLoadingPanel();
      }
      final tickets = snapshot.data ?? const <SupportTicketModel>[];
      if (tickets.isEmpty) {
        return const WindowsMessageState(
          icon: Icons.support_agent_rounded,
          title: 'No support requests yet',
          message:
              'Requests you submit will appear here with their current status.',
        );
      }
      return ListView.separated(
        itemCount: tickets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final t = tickets[index];
          final color = t.status == 'resolved'
              ? AppPalette.statusSuccess
              : t.status == 'under_review'
              ? AppPalette.statusWarning
              : AppPalette.primaryGreen;
          return WindowsPanel(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppPalette.accentGold,
                  size: 28,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.subject,
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${t.category} · ${t.type} · ${t.createdAt == null ? 'Date pending' : DateFormat('dd MMM yyyy').format(t.createdAt!)}',
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                WindowsStatusChip(
                  label: t.status.replaceAll('_', ' ').toUpperCase(),
                  color: color,
                ),
              ],
            ),
          );
        },
      );
    },
  );

  void _retryTickets() {
    setState(() {
      _ticketsStream = SupportService.instance.watchMyTickets();
    });
  }

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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppPalette.cardBackground,
          title: Text(
            'Submit support request',
            style: TextStyle(
              color: AppPalette.primaryGreen,
              fontFamily: AppTypography.heading,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Do not include passwords or unnecessary confidential client details.',
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const WindowsFieldLabel('Request type'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const WindowsFieldDecoration(
                        hint: 'Choose a request type',
                      ).build(),
                      items: const [
                        DropdownMenuItem(
                          value: 'inquiry',
                          child: Text('Question'),
                        ),
                        DropdownMenuItem(
                          value: 'bug',
                          child: Text('Report a bug'),
                        ),
                        DropdownMenuItem(
                          value: 'feature',
                          child: Text('Feature request'),
                        ),
                        DropdownMenuItem(
                          value: 'feedback',
                          child: Text('Feedback'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => type = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    const WindowsFieldLabel('Category'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const WindowsFieldDecoration(
                        hint: 'Choose a category',
                      ).build(),
                      items: const [
                        DropdownMenuItem(
                          value: 'Case Management',
                          child: Text('Case management'),
                        ),
                        DropdownMenuItem(
                          value: 'Cloud Sync',
                          child: Text('Cloud sync'),
                        ),
                        DropdownMenuItem(
                          value: 'Billing & Fees',
                          child: Text('Billing & fees'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    const WindowsFieldLabel('Subject'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: subject,
                      decoration: const WindowsFieldDecoration(
                        hint: 'Enter a subject',
                      ).build(),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a subject'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    const WindowsFieldLabel('Describe the issue'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: message,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const WindowsFieldDecoration(
                        hint: 'Describe the request',
                      ).build(),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Describe the request'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              style: WindowsButtonStyles.ghost(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) {
                        return;
                      }
                      setDialogState(() => busy = true);
                      final id = await SupportService.instance
                          .submitSupportTicket(
                            type: type,
                            category: category,
                            subject: subject.text,
                            message: message.text,
                          );
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(id != null);
                      }
                    },
              style: WindowsButtonStyles.primary(),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    message.dispose();
    if (!mounted) {
      return;
    }
    if (result == true) {
      setState(() => _tab = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request submitted.')),
      );
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request was not submitted. You can try again.'),
        ),
      );
    }
  }
}
