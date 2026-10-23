import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/subscription_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

class WindowsAppSettingsScreen extends StatelessWidget {
  const WindowsAppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WindowsPageHeader(
                    eyebrow: 'PREFERENCES & ACCOUNT',
                    title: 'Application settings',
                    subtitle:
                        'Review account and workspace services without '
                        'changing the existing Android settings flow.',
                  ),
                  const SizedBox(height: 22),
                  StreamBuilder<SubscriptionInfo>(
                    stream: SubscriptionService.instance.watchSubscription(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const WindowsPanel(
                          child: WindowsMessageState(
                            icon: Icons.error_outline_rounded,
                            title: 'Could not load your plan',
                            message: 'Subscription details are temporarily unavailable. Reopen this page to try again.',
                            isError: true,
                          ),
                        );
                      }
                      // The plan must not be stated before the real
                      // subscription record arrives. The free tier is a
                      // fallback, not a finding.
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const WindowsPanel(
                          child: WindowsLoadingPanel(
                            label: 'Loading your plan…',
                          ),
                        );
                      }
                      final sub = snapshot.data ?? SubscriptionInfo.defaultFree;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppPalette.primaryGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0x22FFFFFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_outlined,
                                color: AppPalette.accentGold,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub.isCloud
                                        ? 'Cloud Subscriber'
                                        : 'Free / Local-first',
                                    style: TextStyle(
                                      color: AppPalette.cardBackground,
                                      fontFamily: AppTypography.heading,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    sub.isCloud
                                        ? 'Storage metadata: ${sub.storageUsedFormatted}'
                                        : 'Cloud subscription is not enabled for this account.',
                                    style: const TextStyle(
                                      color: AppPalette.onForestMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/upgrade'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0x66FFFFFF),
                                ),
                              ),
                              child: const Text('View plans'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
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
                          'SIGNED-IN ACCOUNT',
                          style: TextStyle(
                            color: AppPalette.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: AppPalette.accentGold,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName?.trim().isNotEmpty == true
                                        ? user!.displayName!
                                        : 'LED account',
                                    style: const TextStyle(
                                      color: AppPalette.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? 'No email available',
                                    style: const TextStyle(
                                      color: AppPalette.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context)
                                      .pushReplacementNamed('/profile'),
                              child: const Text('Open profile'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SERVICES',
                    style: TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _tile(
                    context,
                    Icons.security_outlined,
                    'Security & access',
                    'Password recovery and account access',
                    '/security',
                  ),
                  _tile(
                    context,
                    Icons.cloud_outlined,
                    'Cloud & storage',
                    'Subscription metadata and sync status',
                    '/cloud_storage',
                  ),
                  _tile(
                    context,
                    Icons.workspace_premium_outlined,
                    'Plans & upgrades',
                    'Review plan information and request an upgrade',
                    '/upgrade',
                  ),
                  _tile(
                    context,
                    Icons.help_outline_rounded,
                    'Help & support',
                    'Knowledge center and your submitted support requests',
                    '/support',
                  ),
                  _tile(
                    context,
                    Icons.notifications_none_rounded,
                    'Notifications',
                    'Open notification status',
                    '/notifications',
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
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
                            'General appearance preferences and device-specific settings are not stored by this desktop page yet; no non-persistent controls are shown as if they were saved.',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: AppPalette.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.statusTile,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppPalette.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
