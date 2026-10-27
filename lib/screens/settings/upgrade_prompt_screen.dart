import 'package:flutter/material.dart';

import '../../widgets/app_palette.dart';
import '../../widgets/plan_catalogue.dart';

/// Mobile upgrade catalogue. Plan selection is informational until checkout
/// and server-side subscription activation are implemented.
class UpgradePromptScreen extends StatelessWidget {
  const UpgradePromptScreen({super.key});

  static const Color _bg = Color(0xFFF7F5F2);
  static const Color _dark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _dark),
        ),
        title: Text(
          'Plans & upgrades',
          style: TextStyle(
            color: _dark,
            fontFamily: AppTypography.heading,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: const [
            PlanCatalogue(showIntro: true),
          ],
        ),
      ),
    );
  }
}
