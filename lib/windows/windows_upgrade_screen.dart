import 'package:flutter/material.dart';

import '../widgets/app_palette.dart';
import '../widgets/plan_catalogue.dart';
import '../widgets/windows_desktop_ui.dart';

/// Windows upgrade catalogue. This is a plan comparison/request screen only:
/// it never grants an entitlement or reports a payment as successful.
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
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                WindowsPageHeader(
                  eyebrow: 'PLANS & WORKSPACE CAPABILITIES',
                  title: 'Plans & upgrades',
                  subtitle:
                      'Compare every individual and chamber tier, including monthly allowances, included benefits, and exclusions.',
                ),
                SizedBox(height: 22),
                PlanCatalogue(showIntro: false),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
