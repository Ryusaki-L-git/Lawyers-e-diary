import 'package:flutter/material.dart';

import '../models/case_model.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// Desktop team case allocation surface.
///
/// The three steps are gated exactly as the team service enforces them: an
/// active owner or leader can assign a team-shared case to another active,
/// verified member of the same team.
class WindowsTransferCaseScreen extends StatefulWidget {
  const WindowsTransferCaseScreen({super.key});

  @override
  State<WindowsTransferCaseScreen> createState() =>
      _WindowsTransferCaseScreenState();
}

class _WindowsTransferCaseScreenState extends State<WindowsTransferCaseScreen> {
  final _service = TeamService.instance;

  String? _teamId, _caseId, _memberId;
  String _caseTitle = '', _memberName = '';
  bool _busy = false;

  Stream<List<TeamModel>>? _teamsStream;
  Stream<List<CaseModel>>? _casesStream;
  Stream<TeamMembership?>? _membershipStream;
  Stream<List<TeamMembership>>? _membersStream;

  Stream<List<TeamModel>> get _teams =>
      _teamsStream ??= _service.watchUserTeams();

  Stream<List<CaseModel>> get _cases =>
      _casesStream ??= _service.watchTeamCases(_teamId!);

  Stream<TeamMembership?> get _membership =>
      _membershipStream ??= _service.watchMyMembership(_teamId!);

  Stream<List<TeamMembership>> get _members =>
      _membersStream ??= _service.watchMembers(_teamId!);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WindowsPageHeader(
              eyebrow: 'TEAM CASE ALLOCATION',
              title: 'Assign a team case',
              subtitle:
                  'Assign a case already shared with one of your teams to an active member of that same team.',
            ),
            const SizedBox(height: 22),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: ListView(
                    children: [
                      _panel(
                        '1. Choose a team you can manage',
                        Icons.groups_2_outlined,
                        [
                          StreamBuilder<List<TeamModel>>(
                            stream: _teams,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return WindowsMessageState(
                                  icon: Icons.error_outline_rounded,
                                  title: 'Your teams could not be loaded',
                                  message:
                                      'Could not load your teams. Check your access and connectivity.',
                                  isError: true,
                                  action: OutlinedButton(
                                    onPressed: _retryTeams,
                                    style: WindowsButtonStyles.secondary(),
                                    child: const Text('Try again'),
                                  ),
                                );
                              }

                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  snapshot.data == null) {
                                return const WindowsLoadingPanel();
                              }

                              final teams =
                                  snapshot.data ?? const <TeamModel>[];

                              if (teams.isEmpty) {
                                return const WindowsMessageState(
                                  icon: Icons.groups_2_outlined,
                                  title: 'No teams available',
                                  message:
                                      'No active teams are available to this account. Create or join a team first.',
                                );
                              }

                              final selected = teams
                                  .where((t) => t.id == _teamId)
                                  .toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const WindowsFieldLabel('Team / chambers'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: selected.isEmpty
                                        ? null
                                        : _teamId,
                                    decoration: const WindowsFieldDecoration(
                                      hint: 'Choose a team you can manage',
                                    ).build(),
                                    items: teams
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t.id,
                                            child: Text(
                                              '${t.name} · ${t.lawFirm.isEmpty ? 'Practice team' : t.lawFirm}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _busy
                                        ? null
                                        : (id) => setState(() {
                                            _teamId = id;
                                            _caseId = null;
                                            _memberId = null;
                                            _caseTitle = '';
                                            _memberName = '';
                                            _casesStream = null;
                                            _membershipStream = null;
                                            _membersStream = null;
                                          }),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      if (_teamId != null) ...[
                        _panel(
                          '2. Choose a case in this team',
                          Icons.folder_open_outlined,
                          [
                            StreamBuilder<List<CaseModel>>(
                              stream: _cases,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return WindowsMessageState(
                                    icon: Icons.error_outline_rounded,
                                    title: 'Team cases could not be loaded',
                                    message:
                                        'Could not load cases for this team. Check team membership and Firestore access.',
                                    isError: true,
                                    action: OutlinedButton(
                                      onPressed: _retryCases,
                                      style: WindowsButtonStyles.secondary(),
                                      child: const Text('Try again'),
                                    ),
                                  );
                                }

                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    snapshot.data == null) {
                                  return const WindowsLoadingPanel();
                                }

                                final cases =
                                    (snapshot.data ?? const <CaseModel>[])
                                        .where(
                                          (c) =>
                                              !c.isDeleted && !c.isCompleted,
                                        )
                                        .toList();

                                if (cases.isEmpty) {
                                  return const WindowsMessageState(
                                    icon: Icons.folder_open_outlined,
                                    title: 'No assignable cases',
                                    message:
                                        'This team has no active shared cases available for assignment. Private/local-only cases are not shown.',
                                  );
                                }

                                final selected = cases
                                    .where((c) => c.id == _caseId)
                                    .toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const WindowsFieldLabel('Team case'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: selected.isEmpty
                                          ? null
                                          : _caseId,
                                      decoration: const WindowsFieldDecoration(
                                        hint: 'Choose a shared case in this team',
                                      ).build(),
                                      items: cases
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(
                                                '${c.caseTitle} · ${c.caseNumber}',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _busy
                                          ? null
                                          : (id) {
                                              final found = cases.where(
                                                (c) => c.id == id,
                                              );

                                              setState(() {
                                                _caseId = id;
                                                _caseTitle = found.isEmpty
                                                    ? ''
                                                    : found.first.caseTitle;
                                                _memberId = null;
                                                _memberName = '';
                                              });
                                            },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _panel(
                          '3. Choose an active team member',
                          Icons.person_add_alt_1_outlined,
                          [
                            StreamBuilder<TeamMembership?>(
                              stream: _membership,
                              builder: (context, ownSnapshot) {
                                if (ownSnapshot.hasError) {
                                  return WindowsMessageState(
                                    icon: Icons.error_outline_rounded,
                                    title: 'Your team role could not be checked',
                                    message:
                                        'Could not verify your team role. Assignment is disabled until access can be checked.',
                                    isError: true,
                                    action: OutlinedButton(
                                      onPressed: _retryMembership,
                                      style: WindowsButtonStyles.secondary(),
                                      child: const Text('Try again'),
                                    ),
                                  );
                                }

                                if (ownSnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    ownSnapshot.data == null) {
                                  return const WindowsLoadingPanel();
                                }

                                final own = ownSnapshot.data;

                                final canManage =
                                    own?.isActive == true &&
                                    (own!.role == TeamRole.owner ||
                                        own.role == TeamRole.leader);

                                if (!canManage) {
                                  return const WindowsMessageState(
                                    icon: Icons.admin_panel_settings_outlined,
                                    title: 'Owner or leader access required',
                                    message:
                                        'Only an active team owner or leader can assign cases.',
                                  );
                                }

                                return StreamBuilder<List<TeamMembership>>(
                                  stream: _members,
                                  builder: (context, membersSnapshot) {
                                    if (membersSnapshot.hasError) {
                                      return WindowsMessageState(
                                        icon: Icons.error_outline_rounded,
                                        title: 'Team members could not be loaded',
                                        message: 'Could not load team membership.',
                                        isError: true,
                                        action: OutlinedButton(
                                          onPressed: _retryMembers,
                                          style: WindowsButtonStyles.secondary(),
                                          child: const Text('Try again'),
                                        ),
                                      );
                                    }

                                    if (membersSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        membersSnapshot.data == null) {
                                      return const WindowsLoadingPanel();
                                    }

                                    final members =
                                        (membersSnapshot.data ??
                                                const <TeamMembership>[])
                                            .where(
                                              (m) =>
                                                  m.isActive &&
                                                  m.hasFirebaseIdentity &&
                                                  m.userId !=
                                                      _service.currentUserId,
                                            )
                                            .toList();

                                    if (members.isEmpty) {
                                      return const WindowsMessageState(
                                        icon: Icons.person_add_alt_1_outlined,
                                        title: 'No members available',
                                        message:
                                            'No other active, verified LED members are available in this team.',
                                      );
                                    }

                                    final selected = members
                                        .where((m) => m.userId == _memberId)
                                        .toList();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const WindowsFieldLabel(
                                          'Receiving member',
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: selected.isEmpty
                                              ? null
                                              : _memberId,
                                          decoration:
                                              const WindowsFieldDecoration(
                                                hint:
                                                    'Choose the receiving team member',
                                              ).build(),
                                          items: members
                                              .map(
                                                (m) => DropdownMenuItem(
                                                  value: m.userId,
                                                  child: Text(
                                                    '${m.displayName} · ${m.role.label}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: _busy
                                              ? null
                                              : (id) {
                                                  final found = members.where(
                                                    (m) => m.userId == id,
                                                  );

                                                  if (found.isNotEmpty) {
                                                    setState(() {
                                                      _memberId = id;
                                                      _memberName =
                                                          found.first.displayName;
                                                    });
                                                  }
                                                },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: AppPalette.noteFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppPalette.noteBorder),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppPalette.statusWarning,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This workflow only assigns an existing team-shared cloud case. It does not transfer private local cases, change case ownership, or move attachments. The team service validates active membership before recording the assignment.',
                                style: TextStyle(
                                  color: AppPalette.textMuted,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed:
                              _busy ||
                                  _teamId == null ||
                                  _caseId == null ||
                                  _memberId == null
                              ? null
                              : _confirm,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.assignment_ind_outlined),
                          label: Text(
                            _busy ? 'Assigning…' : 'Confirm assignment',
                          ),
                          style: WindowsButtonStyles.primary(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _panel(String title, IconData icon, List<Widget> children) =>
      WindowsPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppPalette.accentGold, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...children,
          ],
        ),
      );

  void _retryTeams() {
    setState(() {
      _teamsStream = _service.watchUserTeams();
    });
  }

  void _retryCases() {
    setState(() {
      _casesStream = _service.watchTeamCases(_teamId!);
    });
  }

  void _retryMembership() {
    setState(() {
      _membershipStream = _service.watchMyMembership(_teamId!);
    });
  }

  void _retryMembers() {
    setState(() {
      _membersStream = _service.watchMembers(_teamId!);
    });
  }

  Future<void> _confirm() async {
    final team = _teamId;
    final caseId = _caseId;
    final member = _memberId;

    if (team == null ||
        caseId == null ||
        member == null ||
        _caseTitle.isEmpty) {
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm team assignment'),
        content: Text('Assign "$_caseTitle" to $_memberName within this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: WindowsButtonStyles.ghost(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: WindowsButtonStyles.primary(),
            child: const Text('Assign case'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      return;
    }

    setState(() => _busy = true);

    try {
      await _service.assignCase(
        teamId: team,
        caseId: caseId,
        caseTitle: _caseTitle,
        memberId: member,
        memberName: _memberName,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team case assignment saved.')),
      );

      Navigator.of(context).pushReplacementNamed('/team');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Assignment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
