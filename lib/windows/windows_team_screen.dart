import 'package:flutter/material.dart';

import '../models/team_model.dart';
import '../screens/team/create_team_screen.dart';
import '../screens/team/team_entry_screen.dart';
import '../services/team_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_desktop_shell.dart';

/// Windows desktop view of the user's firm teams.
///
/// Teams and their members are watched through the shared [TeamService]
/// contract, so the desktop view and the mobile workspace show the same
/// chambers. The screen only presents the team register and the actions that
/// open the team and creation surfaces.
class WindowsTeamScreen extends StatefulWidget {
  const WindowsTeamScreen({super.key});

  @override
  State<WindowsTeamScreen> createState() => _WindowsTeamScreenState();
}

class _WindowsTeamScreenState extends State<WindowsTeamScreen> {
  int _retryToken = 0;
  int _memberRetryToken = 0;

  void _retry() {
    setState(() => _retryToken++);
  }

  void _retryMembers() {
    setState(() => _memberRetryToken++);
  }

  void _openTeamWorkspace() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WindowsDesktopShell(
          activeRoute: '/team',
          child: TeamEntryScreen(),
        ),
      ),
    );
  }

  void _openCreateTeam() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WindowsDesktopShell(
          activeRoute: '/team',
          child: CreateTeamScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WindowsPageHeader(
                eyebrow: 'COLLABORATIVE PRACTICE',
                title: 'Team & chambers',
                subtitle: 'Your firm teams, members and shared practice.',
                actions: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openTeamWorkspace,
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Open team workspace'),
                      style: WindowsButtonStyles.secondary(),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _openCreateTeam,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create team'),
                      style: WindowsButtonStyles.primary(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: StreamBuilder<List<TeamModel>>(
                  key: ValueKey<int>(_retryToken),
                  stream: TeamService.instance.watchUserTeams(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return WindowsMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load teams',
                        message: snapshot.error.toString(),
                        isError: true,
                        action: OutlinedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                          style: WindowsButtonStyles.secondary(),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const WindowsLoadingPanel();
                    }

                    final teams = snapshot.data ?? const <TeamModel>[];

                    if (teams.isEmpty) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: WindowsPanel(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: AppPalette.statusTile,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.groups_2_outlined,
                                    color: AppPalette.primaryGreen,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Build your chamber workspace',
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontFamily: AppTypography.heading,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                const Text(
                                  'Create a team to organize colleagues, '
                                  'shared matters and team communication. '
                                  'Existing personal cases stay in your '
                                  'personal workspace.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                FilledButton.icon(
                                  onPressed: _openCreateTeam,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Establish firm team'),
                                  style: WindowsButtonStyles.primary(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: teams.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) => _teamCard(teams[index]),
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

  Widget _teamCard(TeamModel team) {
    return WindowsPanel(
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPalette.primaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: AppPalette.accentGold,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team.lawFirm.isEmpty
                          ? 'Firm name not specified'
                          : team.lawFirm,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              WindowsStatusChip(
                label: '${team.memberCount} members',
                color: AppPalette.primaryGreen,
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _openTeamWorkspace,
                style: WindowsButtonStyles.secondary(),
                child: const Text('Manage team'),
              ),
            ],
          ),
          if (team.description.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                team.description,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 17),
          StreamBuilder<List<TeamMembership>>(
            key: ValueKey<String>('${team.id}-$_memberRetryToken'),
            stream: TeamService.instance.watchMembers(team.id),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.hasError) {
                return WindowsMessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load members',
                  message: '${memberSnapshot.error}',
                  isError: true,
                  action: OutlinedButton.icon(
                    onPressed: _retryMembers,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                    style: WindowsButtonStyles.secondary(),
                  ),
                );
              }

              if (memberSnapshot.connectionState == ConnectionState.waiting &&
                  memberSnapshot.data == null) {
                return const WindowsLoadingPanel();
              }

              final members = memberSnapshot.data ?? const <TeamMembership>[];

              return Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [for (final member in members) _memberChip(member)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _memberChip(TeamMembership member) {
    final name = member.displayName.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppPalette.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppPalette.onForestTile,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppPalette.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName.isEmpty
                      ? 'Team member'
                      : member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.role.label,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
