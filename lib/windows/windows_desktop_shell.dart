import 'package:flutter/material.dart';

/// Windows-only persistent navigation frame. Existing page widgets remain the
/// content screens, so their data and workflows are reused instead of duplicated.
class WindowsDesktopShell extends StatelessWidget {
  const WindowsDesktopShell({super.key, required this.activeRoute, required this.child});
  final String activeRoute;
  final Widget child;

  static const canvas = Color(0xFFF7F5F2);
  static const forest = Color(0xFF1F3D2B);
  static const gold = Color(0xFFCCA046);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B665E);
  static const border = Color(0xFFE5DFD7);

  static const _items = <_DesktopNavItem>[
    _DesktopNavItem('Home', Icons.space_dashboard_outlined, '/home', 'WORKSPACE'),
    _DesktopNavItem('All cases', Icons.folder_open_outlined, '/cases', 'WORKSPACE'),
    _DesktopNavItem('Case management', Icons.view_quilt_outlined, '/case_management', 'WORKSPACE'),
    _DesktopNavItem('Search cases', Icons.manage_search_rounded, '/search_cases', 'WORKSPACE'),
    _DesktopNavItem('Calendar & hearings', Icons.calendar_month_outlined, '/calendar', 'WORKSPACE'),
    _DesktopNavItem('Cause list', Icons.gavel_outlined, '/cause_list', 'WORKSPACE'),
    _DesktopNavItem('Clients', Icons.people_outline_rounded, '/clients', 'PRACTICE'),
    _DesktopNavItem('Reminders', Icons.notifications_none_rounded, '/reminders', 'PRACTICE'),
    _DesktopNavItem('Notifications', Icons.mark_email_unread_outlined, '/notifications', 'PRACTICE'),
    _DesktopNavItem('Fees & transactions', Icons.account_balance_wallet_outlined, '/fee', 'PRACTICE'),
    _DesktopNavItem('Team workspace', Icons.groups_2_outlined, '/team', 'PRACTICE'),
    _DesktopNavItem('JURIS intelligence', Icons.auto_awesome_outlined, '/juris', 'INTELLIGENCE'),
    _DesktopNavItem('Profile', Icons.person_outline_rounded, '/profile', 'ACCOUNT'),
    _DesktopNavItem('Settings', Icons.settings_outlined, '/settings', 'ACCOUNT'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Row(children: [
        SizedBox(
          width: 252,
          child: Container(
            color: forest,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 25, 18, 27),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF2D513B), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0x66CCA046))), child: const Icon(Icons.balance_rounded, color: gold, size: 24)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("LAWYER'S", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.15)),
                    SizedBox(height: 3),
                    Text('E-DIARY', style: TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2.4)),
                  ])),
                ]),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(color: Color(0x334FFFFFFF), height: 1)),
              const SizedBox(height: 15),
              Expanded(child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                children: [
                  for (final group in ['WORKSPACE', 'PRACTICE', 'INTELLIGENCE', 'ACCOUNT']) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(11, 13, 8, 8), child: Text(group, style: const TextStyle(color: Color(0xFFB9C7BD), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.25))),
                    for (final item in _items.where((entry) => entry.group == group))
                      _SidebarItem(item: item, selected: item.route == activeRoute || (activeRoute == '/calendar_list' && item.route == '/calendar'), onTap: () {
                        if (item.route != activeRoute) Navigator.of(context).pushReplacementNamed(item.route);
                      }),
                  ],
                ],
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x22FFFFFF))),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined, color: gold, size: 19),
                    SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Private workspace', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text('Your work, organized', style: TextStyle(color: Color(0xFFB9C7BD), fontSize: 10)),
                    ])),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Expanded(child: ClipRect(child: child)),
      ]),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.selected, required this.onTap});
  final _DesktopNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF31543D) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: 43,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: selected ? Border.all(color: const Color(0x55CCA046)) : null),
            child: Row(children: [
              Icon(item.icon, size: 19, color: selected ? WindowsDesktopShell.gold : const Color(0xFFB9C7BD)),
              const SizedBox(width: 11),
              Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : const Color(0xFFE3EAE5), fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
              if (selected) Container(width: 5, height: 5, decoration: const BoxDecoration(color: WindowsDesktopShell.gold, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem {
  const _DesktopNavItem(this.label, this.icon, this.route, this.group);
  final String label;
  final IconData icon;
  final String route;
  final String group;
}
