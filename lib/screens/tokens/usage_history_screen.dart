import 'package:flutter/material.dart';

import '../../services/token_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/platform_app_bar.dart';
import '../../widgets/windows_desktop_ui.dart';
import '../../templates/animations/loading_effects.dart';

/// Lists the token consumption recorded against the signed-in user.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: PlatformAppBar(
        title: 'Usage history',
        eyebrow: 'SERVICE ACCOUNT',
        subtitle: 'A running record of case-token consumption.',
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
            ? const TemplateLoadingPlaceholder()
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
                message: 'Token consumption appears here once JURIS case intelligence is used.',
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
                        '${entry.createdAt}\n${entry.amountTokens.toStringAsFixed(2)} tokens',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      trailing: Text(
                        entry.balanceAfterTokens.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primaryGreen,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
