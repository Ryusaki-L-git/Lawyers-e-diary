import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'custom_plan_builder_dialog.dart';

enum _PlanAudience { individual, team }

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    required this.subtitle,
    required this.storage,
    required this.caseTokens,
    required this.jurisCredits,
    required this.included,
    required this.excluded,
    this.seats,
    this.featured = false,
    this.custom = false,
  });

  final String name;
  final int price;
  final String subtitle;
  final String storage;
  final String caseTokens;
  final String jurisCredits;
  final int? seats;
  final List<String> included;
  final List<String> excluded;
  final bool featured;
  final bool custom;
}

const _individualPlans = <_Plan>[
  _Plan(
    name: 'Free',
    price: 0,
    subtitle: 'Start with the essentials',
    storage: 'No included cloud storage',
    caseTokens: 'No monthly Case Token bundle',
    jurisCredits: 'No monthly JURIS Credit bundle',
    included: [
      'Core local case register',
      'Case search and hearing views',
      'Calendar and reminders',
      'Fee and practice workflows available in the app',
    ],
    excluded: [
      'Included monthly Case Tokens and JURIS Credits',
      'Paid cloud-storage allowance',
      'Shared team pool and leader allocation controls',
    ],
  ),
  _Plan(
    name: 'Starter',
    price: 299,
    subtitle: 'For an independent practice',
    storage: '10 GB proposed allowance',
    caseTokens: '100 / month',
    jurisCredits: '50 / month',
    included: [
      'Core LED case-management workflows',
      'Personal Case Token allowance',
      'Personal JURIS Credit allowance',
      'Entry-level cloud quota shown for planning',
    ],
    excluded: [
      'Team seats and shared team wallets',
      'Owner controls for member allocations',
      'Extra usage beyond included allowances',
      'Actual cloud document storage is not active yet',
    ],
  ),
  _Plan(
    name: 'Professional',
    price: 599,
    subtitle: 'More room for a growing docket',
    storage: '20 GB proposed allowance',
    caseTokens: '250 / month',
    jurisCredits: '100 / month',
    included: [
      'Core LED case-management workflows',
      'Larger personal Case Token allowance',
      'Larger personal JURIS Credit allowance',
      'Higher planned storage quota than Starter',
    ],
    excluded: [
      'Team seats and shared team wallets',
      'Owner controls for member allocations',
      'Extra usage beyond included allowances',
      'Actual cloud document storage is not active yet',
    ],
  ),
  _Plan(
    name: 'Advocate Pro',
    price: 999,
    subtitle: 'For a busy individual practice',
    storage: '50 GB proposed allowance',
    caseTokens: '500 / month',
    jurisCredits: '200 / month',
    included: [
      'Core LED case-management workflows',
      'Higher personal Case Token allowance',
      'Higher personal JURIS Credit allowance',
      'Larger planned storage quota',
    ],
    excluded: [
      'Team seats and shared team wallets',
      'Owner controls for member allocations',
      'Extra usage beyond included allowances',
      'Actual cloud document storage is not active yet',
    ],
    featured: true,
  ),
  _Plan(
    name: 'LEGEND',
    price: 1499,
    subtitle: 'The highest individual allowance',
    storage: '100 GB proposed allowance',
    caseTokens: '800 / month',
    jurisCredits: '350 / month',
    included: [
      'Core LED case-management workflows',
      'Highest individual Case Token bundle',
      'Highest individual JURIS Credit bundle',
      'Largest planned individual storage quota',
    ],
    excluded: [
      'Team seats and shared team wallets',
      'Owner controls for member allocations',
      'Extra usage beyond included allowances',
      'Actual cloud document storage is not active yet',
    ],
  ),
  _Plan(
    name: 'Custom Individual',
    price: 0,
    subtitle: 'Tailored for a specialist practice',
    storage: 'Configured by quotation',
    caseTokens: 'Custom allocation',
    jurisCredits: 'Custom allocation',
    included: [
      'Custom monthly Case Token allowance',
      'Custom monthly JURIS Credit allowance',
      'Storage quota planned around your needs',
      'Review before any commercial commitment',
    ],
    excluded: [
      'Team seats and shared team wallets',
      'Instant activation or self-service checkout',
      'Any feature not confirmed in the final plan',
      'Actual cloud document storage is not active yet',
    ],
    custom: true,
  ),
];

const _teamPlans = <_Plan>[
  _Plan(
    name: 'Chamber Mini',
    price: 999,
    subtitle: 'A small chamber getting organised',
    seats: 3,
    storage: '30 GB proposed shared allowance',
    caseTokens: '300 shared / month',
    jurisCredits: '100 shared / month',
    included: [
      'Up to 3 team members',
      'Proposed shared Case Token pool',
      'Proposed shared JURIS Credit pool',
      'Leader-set monthly member limits',
      'Shared storage quota planning',
    ],
    excluded: [
      'Members above the 3-seat limit',
      'Usage beyond the included monthly pools',
      'Live top-ups and payment checkout',
      'Actual shared file upload/download is not active yet',
    ],
  ),
  _Plan(
    name: 'Chamber Plus',
    price: 1999,
    subtitle: 'For a growing team',
    seats: 5,
    storage: '100 GB proposed shared allowance',
    caseTokens: '750 shared / month',
    jurisCredits: '250 shared / month',
    included: [
      'Up to 5 team members',
      'Proposed shared Case Token pool',
      'Proposed shared JURIS Credit pool',
      'Leader-set monthly member limits',
      'Higher planned shared storage quota',
    ],
    excluded: [
      'Members above the 5-seat limit',
      'Usage beyond the included monthly pools',
      'Live top-ups and payment checkout',
      'Actual shared file upload/download is not active yet',
    ],
  ),
  _Plan(
    name: 'Chamber Growth',
    price: 3999,
    subtitle: 'For an expanding practice',
    seats: 10,
    storage: '250 GB proposed shared allowance',
    caseTokens: '1,500 shared / month',
    jurisCredits: '500 shared / month',
    included: [
      'Up to 10 team members',
      'Proposed shared Case Token pool',
      'Proposed shared JURIS Credit pool',
      'Leader-set monthly member limits',
      'Expanded planned shared storage quota',
    ],
    excluded: [
      'Members above the 10-seat limit',
      'Usage beyond the included monthly pools',
      'Live top-ups and payment checkout',
      'Actual shared file upload/download is not active yet',
    ],
  ),
  _Plan(
    name: 'Chamber Max',
    price: 7999,
    subtitle: 'For a larger team',
    seats: 25,
    storage: '500 GB proposed shared allowance',
    caseTokens: '3,500 shared / month',
    jurisCredits: '1,000 shared / month',
    included: [
      'Up to 25 team members',
      'Proposed shared Case Token pool',
      'Proposed shared JURIS Credit pool',
      'Leader-set monthly member limits',
      'Large planned shared storage quota',
    ],
    excluded: [
      'Members above the 25-seat limit',
      'Usage beyond the included monthly pools',
      'Live top-ups and payment checkout',
      'Actual shared file upload/download is not active yet',
    ],
  ),
  _Plan(
    name: 'Chamber LEGION',
    price: 15999,
    subtitle: 'For large chambers and firms',
    seats: 50,
    storage: '1 TB proposed shared allowance',
    caseTokens: '7,500 shared / month',
    jurisCredits: '2,000 shared / month',
    included: [
      'Up to 50 team members',
      'Proposed shared Case Token pool',
      'Proposed shared JURIS Credit pool',
      'Leader-set monthly member limits',
      'Largest planned shared storage quota',
    ],
    excluded: [
      'Members above the 50-seat limit',
      'Usage beyond the included monthly pools',
      'Live top-ups and payment checkout',
      'Actual shared file upload/download is not active yet',
    ],
    featured: true,
  ),
  _Plan(
    name: 'Custom Chamber',
    price: 0,
    subtitle: 'Custom seats, limits and allowances',
    storage: 'Configured by quotation',
    caseTokens: 'Custom allocation',
    jurisCredits: 'Custom allocation',
    included: [
      'Custom team size and member limits',
      'Custom Case Token and JURIS Credit allowances',
      'Storage quota planned around the team',
      'Sales review before any commitment',
    ],
    excluded: [
      'Instant activation or self-service checkout',
      'Any guaranteed feature not confirmed in writing',
      'Actual shared file upload/download is not active yet',
    ],
    custom: true,
  ),
];

/// Shared catalogue used by the mobile and Windows upgrade screens.
///
/// Prices and monthly quotas are the current proposed catalogue, not live
/// billing. The widget deliberately never changes a user's entitlement.
class PlanCatalogue extends StatefulWidget {
  const PlanCatalogue({super.key, this.showIntro = true});

  final bool showIntro;

  @override
  State<PlanCatalogue> createState() => _PlanCatalogueState();
}

class _PlanCatalogueState extends State<PlanCatalogue> {
  _PlanAudience _audience = _PlanAudience.individual;

  List<_Plan> get _plans =>
      _audience == _PlanAudience.individual ? _individualPlans : _teamPlans;

  Future<void> _requestPlan(_Plan plan) async {
    if (plan.custom) {
      final isTeam = _audience == _PlanAudience.team;
      await showDialog<void>(
        context: context,
        builder: (_) => CustomPlanBuilderDialog(
          isTeam: isTeam,
          planName: plan.name,
        ),
      );
      return;
    }
    final audience = _audience == _PlanAudience.individual
        ? 'Individual'
        : 'Team / chamber';
    final price = plan.custom
        ? 'Custom quotation'
        : plan.price == 0
        ? 'Free'
        : '₹${plan.price.toString()} per month';
    final details = [
      'Lawyer\'s E-Diary plan request',
      'Plan: ${plan.name}',
      'Category: $audience',
      'Price: $price',
      if (plan.seats != null) 'Seats: up to ${plan.seats}',
      'Storage: ${plan.storage}',
      'Case Tokens: ${plan.caseTokens}',
      'JURIS Credits: ${plan.jurisCredits}',
      'Request status: not submitted; checkout and activation are not connected.',
    ].join('\n');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(plan.custom ? 'Request a custom plan' : 'Plan details'),
        content: SingleChildScrollView(
          child: Text(
            '${plan.name} — $price\n\n'
            'This catalogue is informational. Checkout, payment processing, '
            'and server-side subscription activation are not connected yet, '
            'so this selection will not change your current plan.\n\n'
            'You can copy the plan details to discuss the request with your '
            'administrator or sales contact.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: details));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Plan request details copied. Nothing was purchased.'),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy request details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showIntro) ...[
          Text(
            'Upgrade your practice, your way',
            style: TextStyle(
              color: AppPalette.primaryGreen,
              fontFamily: AppTypography.heading,
              fontSize: isDesktop ? 30 : 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Compare every individual and chamber tier. Each plan shows its '
            'monthly allowances, what is included, and what is not included.',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFECE8E1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SegmentedButton<_PlanAudience>(
            segments: const [
              ButtonSegment(
                value: _PlanAudience.individual,
                icon: Icon(Icons.person_outline_rounded),
                label: Text('Individuals'),
              ),
              ButtonSegment(
                value: _PlanAudience.team,
                icon: Icon(Icons.groups_2_outlined),
                label: Text('Chambers & firms'),
              ),
            ],
            selected: {_audience},
            onSelectionChanged: (selection) =>
                setState(() => _audience = selection.first),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1050 ? 3 : width >= 650 ? 2 : 1;
            final gap = 14.0;
            final cardWidth = (width - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final plan in _plans)
                  SizedBox(
                    width: cardWidth,
                    child: _PlanCard(
                      plan: plan,
                      audience: _audience,
                      onSelect: () => _requestPlan(plan),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _CatalogueNotice(
          icon: Icons.info_outline_rounded,
          title: 'Important before upgrading',
          message: 'These are proposed monthly plan prices and allocations. '
              'Payment checkout and subscription activation are not connected. '
              'The storage figures are planned quotas only: actual shared '
              'document upload/download and quota enforcement are not live. '
              'Do not treat a displayed allowance as active storage until '
              'the feature is released.',
        ),
        const SizedBox(height: 10),
        _CatalogueNotice(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Keep the balances separate',
          message: 'Case Tokens are for LED paid services such as Smart Refresh. '
              'JURIS Credits are for AI usage. Their allowances are separate '
              'and must not be treated as interchangeable cash balances.',
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.audience,
    required this.onSelect,
  });

  final _Plan plan;
  final _PlanAudience audience;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isTeam = audience == _PlanAudience.team;
    final priceLabel = plan.custom
        ? 'Custom'
        : plan.price == 0
        ? '₹0'
        : '₹${plan.price}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.featured
              ? AppPalette.accentGold
              : const Color(0xFFE4DED5),
          width: plan.featured ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (plan.featured)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FEATURED TIER',
                    style: TextStyle(
                      color: Color(0xFF7A4E00),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            if (plan.featured) const SizedBox(height: 10),
            Text(
              plan.name,
              style: TextStyle(
                color: AppPalette.primaryGreen,
                fontFamily: AppTypography.heading,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              plan.subtitle,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceLabel,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!plan.custom && plan.price > 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      '/ month',
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            if (isTeam && plan.seats != null) ...[
              const SizedBox(height: 8),
              _MetricLine(
                icon: Icons.people_alt_outlined,
                label: 'Seats',
                value: 'Up to ${plan.seats} members',
              ),
            ],
            const SizedBox(height: 12),
            _MetricLine(
              icon: Icons.cloud_outlined,
              label: 'Storage',
              value: plan.storage,
            ),
            _MetricLine(
              icon: Icons.bolt_outlined,
              label: 'Case Tokens',
              value: plan.caseTokens,
            ),
            _MetricLine(
              icon: Icons.auto_awesome_outlined,
              label: 'JURIS Credits',
              value: plan.jurisCredits,
            ),
            const SizedBox(height: 16),
            const _SectionHeading(title: 'What you get', positive: true),
            const SizedBox(height: 8),
            for (final feature in plan.included)
              _FeatureLine(text: feature, positive: true),
            const SizedBox(height: 12),
            const _SectionHeading(title: 'What you do not get', positive: false),
            const SizedBox(height: 8),
            for (final feature in plan.excluded)
              _FeatureLine(text: feature, positive: false),
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              child: plan.price == 0 && !plan.custom
                  ? OutlinedButton(
                      onPressed: onSelect,
                      child: const Text('Review free tier'),
                    )
                  : FilledButton(
                      onPressed: onSelect,
                      style: FilledButton.styleFrom(
                        backgroundColor: plan.featured
                            ? AppPalette.primaryGreen
                            : const Color(0xFF2B5540),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        plan.custom ? 'Request custom quote' : 'Review this plan',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppPalette.primaryGreen),
        const SizedBox(width: 7),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.positive});

  final String title;
  final bool positive;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        positive ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded,
        size: 15,
        color: positive ? AppPalette.primaryGreen : const Color(0xFF9A5A46),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: positive ? AppPalette.primaryGreen : const Color(0xFF8D4938),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          positive ? Icons.check_rounded : Icons.close_rounded,
          size: 15,
          color: positive ? AppPalette.primaryGreen : const Color(0xFF9A5A46),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CatalogueNotice extends StatelessWidget {
  const _CatalogueNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFCFAF6),
      border: Border.all(color: const Color(0xFFE4DED5)),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppPalette.accentGold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
