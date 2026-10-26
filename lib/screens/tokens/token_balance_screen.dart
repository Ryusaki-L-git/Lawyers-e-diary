import 'package:flutter/material.dart';

import '../../services/token_service.dart';
import '../../widgets/app_palette.dart';
import '../../widgets/platform_app_bar.dart';
import '../../widgets/windows_desktop_ui.dart';
import '../../templates/animations/loading_effects.dart';

/// Displays the prepaid case-token balance held against the signed-in user.
class TokenBalanceScreen extends StatefulWidget {
  const TokenBalanceScreen({super.key});

  @override
  State<TokenBalanceScreen> createState() => _TokenBalanceScreenState();
}

class _TokenBalanceScreenState extends State<TokenBalanceScreen> {
  final _service = TokenService();
  TokenBalance? _balance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balance = await _service.fetchBalance();
      if (!mounted) {
        return;
      }
      setState(() {
        _balance = balance;
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
        title: 'Case Tokens',
        eyebrow: 'SERVICE ACCOUNT',
        subtitle: 'Prepaid credits available for JURIS case intelligence.',
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.textPrimary,
        actions: [
          IconButton(
            onPressed: _loadBalance,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh balance',
            color: AppPalette.textMuted,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const TemplateLoadingPlaceholder()
              else if (_error != null)
                WindowsMessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load your balance',
                  message: _error!,
                  isError: true,
                  action: FilledButton.icon(
                    onPressed: _loadBalance,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else if (_balance != null) ...[
                WindowsPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available case tokens',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _balance!.caseTokensDisplay,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_balance!.caseTokensMinorUnits} minor units',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/usage_history'),
                  icon: const Icon(Icons.history),
                  label: const Text('View usage history'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                  ),
                ),
              ] else
                const WindowsMessageState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No token balance yet',
                  message: 'A balance appears here once prepaid case tokens are credited to your account.',
                ),
              const Spacer(),
              const Text(
                'Case Tokens are prepaid service credits. They are not withdrawable or transferable.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
