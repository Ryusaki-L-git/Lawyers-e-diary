import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/subscription_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

class WindowsCloudStorageScreen extends StatefulWidget {
  const WindowsCloudStorageScreen({super.key});

  @override
  State<WindowsCloudStorageScreen> createState() =>
      _WindowsCloudStorageScreenState();
}

class _WindowsCloudStorageScreenState extends State<WindowsCloudStorageScreen> {
  bool _recording = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
        child: StreamBuilder<SubscriptionInfo>(
          stream: SubscriptionService.instance.watchSubscription(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const WindowsMessageState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load your storage plan',
                message: 'Your subscription details are temporarily unavailable. Reopen this page to try again.',
                isError: true,
              );
            }
            // The plan must not be shown before the real subscription record
            // arrives: the free tier is a fallback, not a finding, and
            // rendering it while loading states a plan the account may not be
            // on.
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const WindowsLoadingPanel(
                label: 'Loading your storage plan…',
              );
            }
            final sub = snapshot.data ?? SubscriptionInfo.defaultFree;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WindowsPageHeader(
                    eyebrow: 'ACCOUNT & DATA',
                    title: 'Cloud & storage',
                    subtitle:
                        'Review the subscription information currently stored '
                        'for your account.',
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppPalette.primaryGreen,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            sub.isCloud
                                ? Icons.cloud_done_outlined
                                : Icons.devices_outlined,
                            color: AppPalette.accentGold,
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.isCloud
                                    ? 'Cloud Subscriber'
                                    : 'Free / local-first plan',
                                style: TextStyle(
                                  color: AppPalette.cardBackground,
                                  fontFamily: AppTypography.heading,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sub.isCloud
                                    ? 'Cloud subscription metadata is present.'
                                    : 'Your account currently reports the free tier.',
                                style: const TextStyle(
                                  color: AppPalette.onForestMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (sub.isFree)
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/upgrade'),
                            style: WindowsButtonStyles.onForest(),
                            child: const Text('View plans'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 760;

                      final cards = [
                        _InfoCard(
                          icon: Icons.storage_outlined,
                          label: 'STORAGE USAGE',
                          value: sub.storageUsedFormatted,
                          detail: 'Value recorded in subscription metadata',
                        ),
                        _InfoCard(
                          icon: Icons.sync_outlined,
                          label: 'LAST SYNC MARKER',
                          value: sub.lastSyncedAt == null
                              ? 'Not recorded'
                              : DateFormat('dd MMM yyyy, HH:mm')
                                    .format(sub.lastSyncedAt!.toLocal()),
                          detail: 'Timestamp only; not proof that all records synced',
                        ),
                      ];

                      return Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < cards.length; i++)
                            ExpandedOrBox(
                              wide: wide,
                              gapAfter: i == 0,
                              child: cards[i],
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppPalette.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sync status',
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The current subscription service records a timestamp only. It does not run a full case/client/document synchronization job. This screen therefore does not claim that a backup has completed.',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _recording ? null : _recordMarker,
                          icon: const Icon(Icons.history_toggle_off_rounded),
                          label: Text(
                            _recording ? 'Recording…' : 'Record a status check',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppPalette.primaryGreen,
                            side: const BorderSide(
                              color: AppPalette.borderLight,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 13,
                            ),
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
  );

  Future<void> _recordMarker() async {
    setState(() => _recording = true);

    try {
      await SubscriptionService.instance.recordSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Status timestamp recorded. No data synchronization was run.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not record the status timestamp.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _recording = false);
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: AppPalette.cardBackground,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppPalette.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppPalette.accentGold, size: 23),
        const SizedBox(height: 13),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppPalette.primaryGreen,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class ExpandedOrBox extends StatelessWidget {
  const ExpandedOrBox({
    super.key,
    required this.wide,
    required this.child,
    required this.gapAfter,
  });

  final bool wide;
  final Widget child;
  final bool gapAfter;

  @override
  Widget build(BuildContext context) => wide
      ? Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: gapAfter ? 12 : 0),
            child: child,
          ),
        )
      : Padding(
          padding: EdgeInsets.only(bottom: gapAfter ? 12 : 0),
          child: child,
        );
}
