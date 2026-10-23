import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../data/local/app_database.dart';
import '../models/case_model.dart';
import '../repositories/case_repository.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';
import 'windows_case_detail_screen.dart';
import 'windows_desktop_shell.dart';

class WindowsDeletedCasesScreen extends StatelessWidget {
  const WindowsDeletedCasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final database = AppDatabase.instance;
    final repository = CaseRepository(database: database);

    // The local repository refuses to resolve an owner without an
    // authenticated identity, so the signed-out case is handled before the
    // query is built instead of throwing during the build.
    String? uid;
    try {
      uid = repository.currentUserId;
    } catch (_) {
      uid = null;
    }

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppPalette.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WindowsPageHeader(
                  eyebrow: 'CASE LIFECYCLE',
                  title: 'Deleted cases',
                  subtitle:
                      'Review archived matters and restore them when '
                      'appropriate.',
                ),
                Expanded(
                  child: WindowsMessageState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sign in to review archived matters',
                    message:
                        'Archived cases are scoped to your account, so they '
                        'are only available while you are signed in.',
                    action: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/login'),
                      style: WindowsButtonStyles.secondary(),
                      child: const Text('Sign in'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ownerUid = uid;
    final stream =
        (database.select(database.localCases)
              ..where((row) => row.ownerUid.equals(ownerUid))
              ..where((row) => row.isDeleted.equals(true))
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .watch()
            .map(
              (rows) => rows
                  .map((row) => LocalCaseRecord.fromRow(row).toCaseModel())
                  .toList(),
            );

    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WindowsPageHeader(
                eyebrow: 'CASE LIFECYCLE',
                title: 'Deleted cases',
                subtitle:
                    'Review archived matters and restore them when '
                    'appropriate.',
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<CaseModel>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return WindowsMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load deleted cases',
                        message: '${snapshot.error}',
                        isError: true,
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const WindowsLoadingPanel();
                    }
                    final cases = snapshot.data ?? const <CaseModel>[];
                    if (cases.isEmpty) {
                      return const WindowsMessageState(
                        icon: Icons.delete_outline_rounded,
                        title: 'No deleted cases',
                        message:
                            'Cases moved to deleted status will appear here.',
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppPalette.cardBackground,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: ListView.separated(
                        itemCount: cases.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppPalette.borderLight,
                        ),
                        itemBuilder: (context, index) {
                          final c = cases[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppPalette.statusDangerTile,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.archive_outlined,
                                    color: AppPalette.statusDanger,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.caseTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppPalette.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${c.caseNumber} · ${c.clientName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppPalette.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => WindowsDesktopShell(
                                        activeRoute: '/deleted_cases',
                                        child: WindowsCaseDetailScreen(
                                          caseItem: c,
                                        ),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Review'),
                                  style: WindowsButtonStyles.secondary(),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () async {
                                    try {
                                      await repository.restoreCase(c.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Case restored to active status.',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Could not restore case: $e',
                                                ),
                                              ),
                                            );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.restore_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Restore'),
                                  style: WindowsButtonStyles.primary(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
}
