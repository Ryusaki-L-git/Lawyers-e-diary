import 'package:flutter/material.dart';

import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// Desktop plan catalogue.
///
/// This surface only presents the product catalogue and an honest request
/// notice. No payment provider, entitlement or subscription approval is
/// connected, and nothing here claims otherwise.
class WindowsUpgradeScreen extends StatelessWidget {
  const WindowsUpgradeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WindowsPageHeader(
                  eyebrow: 'PLANS & WORKSPACE CAPABILITIES',
                  title: 'Choose how you work',
                  subtitle:
                      'Review the current LED plan options. Subscription changes are not made automatically from this screen.',
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 700;
                    final cards = [
                      _PlanCard(
                        title: 'Free / Local-first',
                        subtitle: 'For individual practice on this device',
                        featured: false,
                        features: const [
                          'Local case register',
                          'Case search and hearing views',
                          'Core practice workflows',
                          'Internet not required for all local workflows',
                        ],
                        action: () =>
                            Navigator.of(context).pushNamed('/cloud_storage'),
                      ),
                      _PlanCard(
                        title: 'Cloud Subscriber',
                        subtitle: 'For cloud-backed workflows where enabled',
                        featured: true,
                        features: const [
                          'Subscription metadata and status',
                          'Cloud-oriented workflow options',
                          'Multi-device features only where configured',
                          'Actual sync capabilities depend on backend setup',
                        ],
                        action: () => _requestUpgrade(context),
                      ),
                    ];
                    if (wide) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < cards.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == 0 ? 12 : 0,
                                  ),
                                  child: cards[i],
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == 0 ? 14 : 0,
                            ),
                            child: cards[i],
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                WindowsPanel(
                  padding: const EdgeInsets.all(17),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppPalette.accentGold,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is an information and request screen, not a payment checkout. No price, subscription entitlement, or successful upgrade is invented here.',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  void _requestUpgrade(BuildContext context) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Request a cloud upgrade'),
      content: const Text(
        'The current LED project does not include a connected payment or subscription-approval workflow. Please contact your workspace administrator to request an upgrade.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: WindowsButtonStyles.ghost(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.featured,
    required this.action,
  });
  final String title, subtitle;
  final List<String> features;
  final bool featured;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => WindowsPanel(
    padding: const EdgeInsets.all(23),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured)
          const WindowsStatusChip(
            label: 'CLOUD-ENABLED PLAN',
            color: AppPalette.accentGold,
          ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: AppPalette.primaryGreen,
            fontFamily: AppTypography.heading,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppPalette.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: featured
              ? FilledButton(
                  onPressed: action,
                  style: WindowsButtonStyles.primary(),
                  child: const Text('Request upgrade'),
                )
              : OutlinedButton(
                  onPressed: action,
                  style: WindowsButtonStyles.secondary(),
                  child: const Text('Review storage status'),
                ),
        ),
      ],
    ),
  );
}
