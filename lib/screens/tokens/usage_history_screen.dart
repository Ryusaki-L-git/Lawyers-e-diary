import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/token_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/platform_app_bar.dart';
import '../../widgets/windows_desktop_ui.dart';

/// Lists JURIS Credit and eCourts Case Token usage recorded for the signed-in user.
class UsageHistoryScreen extends StatefulWidget {
  const UsageHistoryScreen({super.key});

  @override
  State<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends State<UsageHistoryScreen> {
  final _service = TokenService();
  List<UsageEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.fetchUsageHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildWindowsHistory() {
    final creditEntries = _entries
        .where((entry) => entry.unitLabel.toLowerCase().contains('credit'))
        .length;
    final caseTokenEntries = _entries.length - creditEntries;
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WindowsPageHeader(
                eyebrow: 'SERVICE ACCOUNT',
                title: 'Usage history',
                subtitle: 'A clear record of JURIS Credits and eCourts Case Tokens.',
                actions: OutlinedButton.icon(
                  onPressed: _loading ? null : _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Refresh'),
                  style: WindowsButtonStyles.secondary(),
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final tiles = [
                    _usageMetric('All transactions', _entries.length.toString(),
                        Icons.receipt_long_outlined),
                    _usageMetric('JURIS Credit entries', creditEntries.toString(),
                        Icons.psychology_alt_outlined),
                    _usageMetric('Case Token entries', caseTokenEntries.toString(),
                        Icons.account_balance_outlined),
                  ];
                  if (compact) {
                    return Column(
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          tiles[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: tiles[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const WindowsLoadingPanel(label: 'Loading service ledger')
                    : _error != null
                        ? WindowsMessageState(
                            icon: Icons.error_outline_rounded,
                            title: 'Could not load usage history',
                            message: _error!,
                            isError: true,
                            action: FilledButton.icon(
                              onPressed: _loadHistory,
                              icon: const Icon(Icons.refresh_rounded, size: 17),
                              label: const Text('Try again'),
                              style: WindowsButtonStyles.primary(),
                            ),
                          )
                        : _entries.isEmpty
                            ? const WindowsMessageState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No usage records yet',
                                message: 'Transactions will appear here when JURIS or eCourts services are used.',
                              )
                            : Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1240),
                                  child: ListView.separated(
                                    itemCount: _entries.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final entry = _entries[index];
                                      final isCredit = entry.unitLabel
                                          .toLowerCase()
                                          .contains('credit');
                                      return WindowsPanel(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: AppPalette.primaryGreen
                                                    .withValues(alpha: .08),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                isCredit
                                                    ? Icons.psychology_alt_outlined
                                                    : Icons.account_balance_outlined,
                                                color: AppPalette.primaryGreen,
                                                size: 21,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.reason,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: AppPalette.textPrimary,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    entry.createdAt.toString(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: AppPalette.textMuted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    entry.amountTokens
                                                        .toStringAsFixed(2),
                                                    style: const TextStyle(
                                                      color: AppPalette.textPrimary,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  Text(
                                                    entry.unitLabel,
                                                    style: const TextStyle(
                                                      color: AppPalette.textMuted,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    entry.balanceAfterTokens
                                                        .toStringAsFixed(2),
                                                    style: const TextStyle(
                                                      color: AppPalette.primaryGreen,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const Text(
                                                    'Balance after',
                                                    style: TextStyle(
                                                      color: AppPalette.textMuted,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _usageMetric(String label, String value, IconData icon) {
    return WindowsPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppPalette.statusTile,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppPalette.primaryGreen, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                  color: AppPalette.textMuted, fontSize: 11,
                )),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(
                  color: AppPalette.textPrimary, fontSize: 20,
                  fontWeight: FontWeight.w800,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _buildWindowsHistory();
    }
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: PlatformAppBar(
        title: 'Usage history',
        eyebrow: 'SERVICE ACCOUNT',
        subtitle: 'Separate ledger entries for JURIS Credits and eCourts Case Tokens.',
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh history',
            color: AppPalette.textMuted,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppPalette.primaryGreen,
                ),
              )
            : _error != null
            ? WindowsMessageState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load usage history',
                message: _error!,
                isError: true,
                action: FilledButton.icon(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            : _entries.isEmpty
            ? const WindowsMessageState(
                icon: Icons.receipt_long_outlined,
                title: 'No usage records yet',
                message: 'Usage appears here when JURIS AI or eCourts services are used.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    decoration: BoxDecoration(
                      color: AppPalette.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.borderLight),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: Text(
                        entry.reason,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${entry.createdAt}\n${entry.amountTokens.toStringAsFixed(2)} ${entry.unitLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            entry.balanceAfterTokens.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppPalette.primaryGreen,
                            ),
                          ),
                          Text(
                            entry.unitLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
