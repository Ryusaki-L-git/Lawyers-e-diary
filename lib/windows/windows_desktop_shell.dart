import 'package:flutter/material.dart';

/// Native Windows navigation frame for Lawyer's E-Diary.
/// Existing route screens are embedded so their business logic remains intact.
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
    _DesktopNavItem('Home', Icons.space_dashboard_outlined, '/home', group: 'WORKSPACE'),
    _DesktopNavItem('All cases', Icons.folder_open_outlined, '/cases', group: 'WORKSPACE'),
    _DesktopNavItem('Search cases', Icons.manage_search_rounded, '/search_cases', group: 'WORKSPACE'),
    _DesktopNavItem('Calendar & hearings', Icons.calendar_month_outlined, '/calendar', group: 'WORKSPACE'),
    _DesktopNavItem('Cause list', Icons.gavel_outlined, '/cause_list', group: 'WORKSPACE'),
    _DesktopNavItem('Clients', Icons.people_outline_rounded, '/clients', group: 'PRACTICE'),
    _DesktopNavItem('Reminders', Icons.notifications_none_rounded, '/reminders', group: 'PRACTICE'),
    _DesktopNavItem('Fees & transactions', Icons.account_balance_wallet_outlined, '/fee', group: 'PRACTICE'),
    _DesktopNavItem('Team workspace', Icons.groups_2_outlined, '/team', group: 'PRACTICE'),
    _DesktopNavItem('JURIS intelligence', Icons.auto_awesome_outlined, '/juris', group: 'INTELLIGENCE'),
    _DesktopNavItem('Profile', Icons.person_outline_rounded, '/profile', group: 'ACCOUNT'),
    _DesktopNavItem('Settings', Icons.settings_outlined, '/settings', group: 'ACCOUNT'),
  ];

  String get _pageTitle {
    for (final item in _items) {
      if (item.route == activeRoute) return item.label;
    }
    const titles = {
      '/add_case': 'Create a case',
      '/case_management': 'Case management',
      '/completed_cases': 'Completed cases',
      '/deleted_cases': 'Deleted cases',
      '/starred': 'Starred cases',
      '/full_calendar': 'Full calendar',
      '/notifications': 'Notifications',
      '/cloud_storage': 'Cloud storage',
      '/upgrade': 'Plan & billing',
      '/support': 'Help & support',
      '/todo': 'To-do',
      '/transfer_case': 'Transfer case',
    };
    return titles[activeRoute] ?? 'Legal workspace';
  }

  void _navigate(BuildContext context, String route) {
    if (route == activeRoute) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: Row(
        children: [
          SizedBox(
            width: 252,
            child: _DesktopSidebar(activeRoute: activeRoute, items: _items, onNavigate: (route) => _navigate(context, route)),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: border))),
                  child: Row(
                    children: [
                      Text(_pageTitle, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.35)),
                      const SizedBox(width: 24),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              textInputAction: TextInputAction.search,
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  Navigator.of(context).pushReplacementNamed('/search_cases', arguments: value.trim());
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Search cases by title, client or number',
                                hintStyle: const TextStyle(color: muted, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, size: 19, color: muted),
                                filled: true,
                                fillColor: canvas,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: forest, width: 1.2)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _TopAction(tooltip: 'Notifications', icon: Icons.notifications_none_rounded, onTap: () => _navigate(context, '/notifications')),
                      const SizedBox(width: 10),
                      _TopAction(tooltip: 'Profile', icon: Icons.person_outline_rounded, onTap: () => _navigate(context, '/profile')),
                      const SizedBox(width: 14),
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: forest, borderRadius: BorderRadius.circular(12)),
                        child: const Text('LED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                      ),
                    ],
                  ),
                ),
                Expanded(child: ClipRect(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.activeRoute, required this.items, required this.onNavigate});
  final String activeRoute;
  final List<_DesktopNavItem> items;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    const groups = ['WORKSPACE', 'PRACTICE', 'INTELLIGENCE', 'ACCOUNT'];
    return Container(
      color: WindowsDesktopShell.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 25, 18, 27),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: const Color(0xFF2D513B), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0x66CCA046))),
                  child: const Icon(Icons.balance_rounded, color: WindowsDesktopShell.gold, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("LAWYER'S", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.15)),
                  SizedBox(height: 3),
                  Text('E-DIARY', style: TextStyle(color: WindowsDesktopShell.gold, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2.4)),
                ])),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(color: Color(0x334FFFFFFF), height: 1)),
          const SizedBox(height: 15),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 13, 8, 8),
                    child: Text(group, style: const TextStyle(color: Color(0xFFB9C7BD), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.25)),
                  ),
                  for (final item in items.where((entry) => entry.group == group))
                    _SidebarItem(item: item, selected: item.route == activeRoute || (activeRoute == '/calendar_list' && item.route == '/calendar'), onTap: () => onNavigate(item.route)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x22FFFFFF))),
              child: const Row(children: [
                Icon(Icons.shield_outlined, color: WindowsDesktopShell.gold, size: 19),
                SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Private workspace', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('Your work, organized', style: TextStyle(color: Color(0xFFB9C7BD), fontSize: 10)),
                ])),
              ]),
            ),
          ),
        ],
      ),
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

class _TopAction extends StatelessWidget {
  const _TopAction({required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: WindowsDesktopShell.canvas,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: WindowsDesktopShell.border)),
            child: Icon(icon, size: 20, color: WindowsDesktopShell.forest),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem {
  const _DesktopNavItem(this.label, this.icon, this.route, {required this.group});
  final String label;
  final IconData icon;
  final String route;
  final String group;
}
