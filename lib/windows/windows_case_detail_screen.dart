import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// The desktop case workspace.
///
/// The screen presents a single matter from the local case register: its
/// hearing, the parties on file, the case notes and the attached documents.
class WindowsCaseDetailScreen extends StatefulWidget {
  const WindowsCaseDetailScreen({super.key, required this.caseItem});

  final CaseModel caseItem;

  @override
  State<WindowsCaseDetailScreen> createState() =>
      _WindowsCaseDetailScreenState();
}

class _WindowsCaseDetailScreenState extends State<WindowsCaseDetailScreen> {
  late bool _starred = widget.caseItem.isStarred;
  bool _busy = false;
  final _repository = CaseRepository(database: AppDatabase.instance);

  @override
  Widget build(BuildContext context) {
    final item = widget.caseItem;

    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WindowsPageHeader(
                eyebrow: 'CASE WORKSPACE',
                title: 'Case file',
                leading: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to case register',
                ),
                actions: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _toggleStar,
                      icon: Icon(
                        _starred
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppPalette.accentGold,
                      ),
                      label: Text(_starred ? 'Starred' : 'Star case'),
                      style: WindowsButtonStyles.secondary(),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        '/juris',
                        arguments: {
                          'caseId': item.id,
                          'caseTitle': item.caseTitle,
                        },
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Discuss with JURIS'),
                      style: WindowsButtonStyles.primary(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(27),
                decoration: BoxDecoration(
                  color: AppPalette.primaryGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final summary = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.caseType.toUpperCase(),
                          style: const TextStyle(
                            color: AppPalette.accentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.caseTitle,
                          style: TextStyle(
                            color: AppPalette.onForestText,
                            fontFamily: AppTypography.heading,
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 9,
                          runSpacing: 8,
                          children: [
                            WindowsStatusChip(
                              label: item.caseNumber,
                              color: AppPalette.accentGold,
                            ),
                            WindowsStatusChip(
                              label: item.courtName,
                              color: AppPalette.accentGold,
                            ),
                            WindowsStatusChip(
                              label: item.status.toUpperCase(),
                              color: _statusColor(item.status),
                              filled: item.isUrgent,
                            ),
                          ],
                        ),
                      ],
                    );

                    final hearing = Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEXT HEARING',
                            style: TextStyle(
                              color: AppPalette.onForestMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _date(item.nextHearingDate),
                            style: const TextStyle(
                              color: AppPalette.onForestText,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Keep the next date in view.',
                            style: TextStyle(
                              color: AppPalette.onForestMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );

                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          summary,
                          const SizedBox(height: 18),
                          hearing,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 3, child: summary),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: hearing),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final left = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WindowsPanel(
                        title: 'Parties',
                        child: Column(
                          children: [
                            _FactRow('Client', item.clientName),
                            if (item.opponentName.trim().isNotEmpty)
                              _FactRow('Opposing party', item.opponentName),
                            if (item.clientPhone?.trim().isNotEmpty == true)
                              _FactRow('Client phone', item.clientPhone!),
                            _FactRow('Handled by', item.handledBy),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      WindowsPanel(
                        title: 'Court & schedule',
                        child: Column(
                          children: [
                            _FactRow('Court / forum', item.courtName),
                            _FactRow(
                              'Next hearing',
                              _date(item.nextHearingDate),
                            ),
                            _FactRow('Created', _date(item.createdAt)),
                            _FactRow('Last updated', _date(item.updatedAt)),
                          ],
                        ),
                      ),
                    ],
                  );

                  final right = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WindowsPanel(
                        title: 'Case notes',
                        child: item.notes.isEmpty
                            ? const WindowsMessageState(
                                icon: Icons.notes_rounded,
                                title: 'No notes yet',
                                message:
                                    'No notes are attached to this case yet.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final note in item.notes)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: AppPalette.accentGold,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              note,
                                              style: const TextStyle(
                                                color: AppPalette.textPrimary,
                                                fontSize: 13,
                                                height: 1.55,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      WindowsPanel(
                        title: 'Documents',
                        child: item.documents.isEmpty
                            ? const WindowsMessageState(
                                icon: Icons.description_outlined,
                                title: 'No documents yet',
                                message: 'No documents are attached to this case yet.',
                              )
                            : Column(
                                children: [
                                  for (final document in item.documents)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.description_outlined,
                                        color: AppPalette.primaryGreen,
                                      ),
                                      title: Text(
                                        document.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${document.type} · ${document.size}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppPalette.textMuted,
                                        ),
                                      ),
                                      trailing: Icon(
                                        document.url == null
                                            ? Icons.info_outline_rounded
                                            : Icons.open_in_new_rounded,
                                        color: AppPalette.textMuted,
                                        size: 17,
                                      ),
                                      onTap: document.url == null
                                          ? null
                                          : () => _openDocument(document),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 940) {
                    return Column(
                      children: [left, const SizedBox(height: 16), right],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 18),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _archiveCase,
                  icon: const Icon(
                    Icons.archive_outlined,
                    color: AppPalette.statusDanger,
                    size: 18,
                  ),
                  label: const Text('Move to deleted cases'),
                  style: WindowsButtonStyles.danger(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return status.toLowerCase() == 'urgent'
        ? AppPalette.statusDanger
        : AppPalette.onForestMuted;
  }

  Future<void> _openDocument(CaseDocumentModel document) async {
    final rawUrl = document.url?.trim();
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);

    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This document does not have a valid secure link.'),
          ),
        );
      }
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this document link.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this document link.')),
        );
      }
    }
  }

  Future<void> _toggleStar() async {
    setState(() => _busy = true);

    try {
      await _repository.setCaseStarred(widget.caseItem.id, !_starred);

      if (mounted) {
        setState(() => _starred = !_starred);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update starred status: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _archiveCase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move case to deleted cases?'),
        content: Text(
          '"${widget.caseItem.caseTitle}" will be marked deleted in the local case register.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: WindowsButtonStyles.ghost(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: WindowsButtonStyles.primary(),
            child: const Text('Move to deleted'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busy = true);

    try {
      await _repository.softDeleteCase(widget.caseItem.id);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not archive case: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Not scheduled';

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
