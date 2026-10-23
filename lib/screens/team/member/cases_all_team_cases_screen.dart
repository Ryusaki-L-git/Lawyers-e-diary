import 'package:flutter/material.dart';

import '../../../models/case_model.dart';
import '../../../models/team_model.dart';
import '../../../services/team_service.dart';
import '../../../widgets/app_palette.dart';
import '../../../widgets/case_card.dart';
import '../widgets/team_header.dart';

/// Legacy member route retained for compatibility.
/// Members may only see cases explicitly assigned to their Firebase UID.
class CasesAllTeamCasesScreen extends StatelessWidget {
  const CasesAllTeamCasesScreen({super.key, required this.team});

  final TeamModel team;

  static const Color _bg = AppPalette.canvas;

  @override
  Widget build(BuildContext context) {
    final uid = TeamService.instance.currentUserId;
    return Scaffold(
      backgroundColor: _bg,
      appBar: TeamHeader(
        title: 'My Assigned Cases',
        subtitle: '${team.lawFirm} · ${team.name}',
      ),
      body: StreamBuilder<List<CaseModel>>(
        stream: uid == null
            ? Stream.value(<CaseModel>[])
            : TeamService.instance.watchTeamCases(team.id, assignedTo: uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data ?? [];
          if (cases.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppPalette.accentGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: AppPalette.accentGold,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Cases Assigned',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTypography.heading,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You do not have any active matters assigned to you right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: cases.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = cases[index];
              return CaseCard(
                caseItem: c,
                actionStyle: CaseCardActionStyle.standard,
              );
            },
          );
        },
      ),
    );
  }
}
