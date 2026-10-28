import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_palette.dart';

/// Windows-only persistent navigation frame. Existing page widgets remain the
/// content screens, so their data and workflows are reused instead of duplicated.
///
/// The rail adapts to the available width: it shows the full label column on
/// a wide monitor and collapses to an icon rail on a narrow laptop window, so
/// every destination stays reachable without the window ever becoming too
/// small to use. The rail is also keyboard navigable: the arrow keys move
/// between destinations and Enter or Space opens the focused one.
class WindowsDesktopShell extends StatefulWidget {
  const WindowsDesktopShell({
    super.key,
    required this.activeRoute,
    required this.child,
  });

  final String activeRoute;
  final Widget child;

  // Modern Legal Editorial tokens. These are aliases of the canonical
  // AppPalette values so there is exactly one source of truth for the LED
  // design identity; the Windows screens keep using the shell's short names.
  static const canvas = AppPalette.canvas;
  static const forest = AppPalette.primaryGreen;
  static const gold = AppPalette.accentGold;
  static const ink = AppPalette.textPrimary;
  static const muted = AppPalette.textMuted;
  static const border = AppPalette.borderLight;

  // Semantic status tokens, aliased for the same reason.
  static const danger = AppPalette.statusDanger;
  static const success = AppPalette.statusSuccess;
  static const warning = AppPalette.statusWarning;
  static const tile = AppPalette.statusTile;
  static const noteFill = AppPalette.noteFill;
  static const noteBorder = AppPalette.noteBorder;
  static const onForestMuted = AppPalette.onForestMuted;
  static const onForestFaint = AppPalette.onForestFaint;

  /// The width of the navigation rail when the labels are visible.
  static const double expandedRailWidth = 252;

  /// The width of the icon-only rail used on narrow windows.
  static const double compactRailWidth = 74;

  /// Below this total window width the rail collapses to its icon form.
  static const double collapseThreshold = 1080;

  static const _groups = <String>[
    'WORKSPACE',
    'PRACTICE',
    'INTELLIGENCE',
    'ACCOUNT',
  ];

  static const _items = <_DesktopNavItem>[
    _DesktopNavItem(
      'Home',
      Icons.space_dashboard_outlined,
      '/home',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'All cases',
      Icons.folder_open_outlined,
      '/cases',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Case management',
      Icons.view_quilt_outlined,
      '/case_management',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Completed cases',
      Icons.task_alt_rounded,
      '/completed_cases',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Deleted cases',
      Icons.delete_outline_rounded,
      '/deleted_cases',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Starred cases',
      Icons.star_outline_rounded,
      '/starred',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Search cases',
      Icons.manage_search_rounded,
      '/search_cases',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Calendar & hearings',
      Icons.calendar_month_outlined,
      '/calendar',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Cause list',
      Icons.gavel_outlined,
      '/cause_list',
      'WORKSPACE',
    ),
    _DesktopNavItem(
      'Clients',
      Icons.people_outline_rounded,
      '/clients',
      'PRACTICE',
    ),
    _DesktopNavItem(
      'Reminders',
      Icons.notifications_none_rounded,
      '/reminders',
      'PRACTICE',
    ),
    _DesktopNavItem('To-Do list', Icons.checklist_rounded, '/todo', 'PRACTICE'),
    _DesktopNavItem(
      'Notifications',
      Icons.mark_email_unread_outlined,
      '/notifications',
      'PRACTICE',
    ),
    _DesktopNavItem(
      'Fees & transactions',
      Icons.account_balance_wallet_outlined,
      '/fee',
      'PRACTICE',
    ),
    _DesktopNavItem(
      'Team workspace',
      Icons.groups_2_outlined,
      '/team',
      'PRACTICE',
    ),
    _DesktopNavItem(
      'Assign team case',
      Icons.assignment_ind_outlined,
      '/transfer_case',
      'PRACTICE',
    ),
    _DesktopNavItem(
      'JURIS intelligence',
      Icons.auto_awesome_outlined,
      '/juris',
      'INTELLIGENCE',
    ),
    _DesktopNavItem(
      'Case tokens',
      Icons.toll_outlined,
      '/token_balance',
      'INTELLIGENCE',
    ),
    _DesktopNavItem(
      'Profile',
      Icons.person_outline_rounded,
      '/profile',
      'ACCOUNT',
    ),
    _DesktopNavItem(
      'Settings',
      Icons.settings_outlined,
      '/settings',
      'ACCOUNT',
    ),
    _DesktopNavItem(
      'Help & support',
      Icons.help_outline_rounded,
      '/support',
      'ACCOUNT',
    ),
  ];

  @override
  State<WindowsDesktopShell> createState() => _WindowsDesktopShellState();
}

class _WindowsDesktopShellState extends State<WindowsDesktopShell> {
  /// One focus node per destination so the rail can be driven with the
  /// arrow keys.
  final List<FocusNode> _focusNodes = [
    for (final _ in WindowsDesktopShell._items) FocusNode(),
  ];

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusRelative(int from, int delta) {
    if (_focusNodes.isEmpty) return;
    var next = from + delta;
    if (next < 0) next = _focusNodes.length - 1;
    if (next >= _focusNodes.length) next = 0;
    _focusNodes[next].requestFocus();
  }

  void _open(_DesktopNavItem item) {
    if (item.route == widget.activeRoute) return;
    Navigator.of(context).pushReplacementNamed(item.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WindowsDesktopShell.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed =
              constraints.maxWidth < WindowsDesktopShell.collapseThreshold;

          return Row(
            children: [
              SizedBox(
                width: collapsed
                    ? WindowsDesktopShell.compactRailWidth
                    : WindowsDesktopShell.expandedRailWidth,
                child: _buildRail(collapsed: collapsed),
              ),
              Expanded(child: ClipRect(child: widget.child)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRail({required bool collapsed}) {
    return Container(
      color: WindowsDesktopShell.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrand(collapsed: collapsed),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Color(0x33FFFFFF), height: 1),
          ),
          const SizedBox(height: 15),
          Expanded(child: _buildNavigation(collapsed: collapsed)),
          _buildFooter(collapsed: collapsed),
        ],
      ),
    );
  }

  Widget _buildBrand({required bool collapsed}) {
    final mark = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppPalette.brandTile,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x66CCA046)),
      ),
      child: const Icon(Icons.balance_rounded, color: WindowsDesktopShell.gold, size: 24),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
        child: Center(child: mark),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 25, 18, 27),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LAWYER'S",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.15,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'E-DIARY',
                  style: TextStyle(
                    color: WindowsDesktopShell.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation({required bool collapsed}) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _focusRelative(_currentIndex(), 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _focusRelative(_currentIndex(), -1),
      },
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scrollbar(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
            children: [
              for (final group in WindowsDesktopShell._groups) ...[
                if (collapsed)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
                    child: Divider(color: Color(0x22FFFFFF), height: 1),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 13, 8, 8),
                    child: Text(
                      group,
                      style: const TextStyle(
                        color: AppPalette.onForestFaint,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ),
                for (final item in WindowsDesktopShell._items.where(
                  (entry) => entry.group == group,
                )) _buildItem(item, collapsed: collapsed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The index of the destination that currently holds focus, or 0.
  int _currentIndex() {
    for (var i = 0; i < _focusNodes.length; i++) {
      if (_focusNodes[i].hasFocus) return i;
    }
    return 0;
  }

  Widget _buildItem(_DesktopNavItem item, {required bool collapsed}) {
    final index = WindowsDesktopShell._items.indexOf(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _SidebarItem(
        item: item,
        selected: item.route == widget.activeRoute,
        collapsed: collapsed,
        focusNode: _focusNodes[index],
        onTap: () => _open(item),
        onMoveDown: () => _focusRelative(index, 1),
        onMoveUp: () => _focusRelative(index, -1),
      ),
    );
  }

  Widget _buildFooter({required bool collapsed}) {
    if (collapsed) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Icon(
          Icons.shield_outlined,
          color: WindowsDesktopShell.gold,
          size: 19,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: WindowsDesktopShell.gold, size: 19),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private workspace',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Your work, organized',
                    style: TextStyle(
                      color: AppPalette.onForestFaint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.focusNode,
    required this.onTap,
    required this.onMoveDown,
    required this.onMoveUp,
  });

  final _DesktopNavItem item;
  final bool selected;
  final bool collapsed;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveUp;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: selected ? Colors.white : AppPalette.onForestText,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    final icon = Icon(
      item.icon,
      size: 19,
      color: selected
          ? WindowsDesktopShell.gold
          : AppPalette.onForestFaint,
    );

    final row = Row(
      children: [
        icon,
        if (!collapsed) ...[
          const SizedBox(width: 11),
          Expanded(child: label),
          if (selected)
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: WindowsDesktopShell.gold,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ],
    );

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowDown:
              onMoveDown();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowUp:
              onMoveUp();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.enter:
            case LogicalKeyboardKey.space:
              onTap();
              return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final focused = focusNode.hasFocus;
            return Tooltip(
              message: collapsed ? item.label : '',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(11),
                  hoverColor: const Color(0x1AFFFFFF),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 43,
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 0 : 12,
                    ),
                    alignment: collapsed ? Alignment.center : null,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppPalette.navSelected
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: focused
                            ? WindowsDesktopShell.gold
                            : selected
                            ? const Color(0x55CCA046)
                            : Colors.transparent,
                        width: focused ? 1.5 : 1,
                      ),
                    ),
                    child: row,
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

class _DesktopNavItem {
  const _DesktopNavItem(this.label, this.icon, this.route, this.group);
  final String label;
  final IconData icon;
  final String route;
  final String group;
}
