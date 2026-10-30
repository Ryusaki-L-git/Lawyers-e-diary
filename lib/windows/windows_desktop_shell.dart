import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_palette.dart';

/// Persistent Windows navigation frame for the Modern Legal Editorial workspace.
class WindowsDesktopShell extends StatefulWidget {
  const WindowsDesktopShell({
    super.key,
    required this.activeRoute,
    required this.child,
  });

  final String activeRoute;
  final Widget child;

  static const canvas = AppPalette.canvas;
  static const forest = Color(0xFF09251B);
  static const gold = AppPalette.accentGold;
  static const expandedRailWidth = 236.0;
  static const compactRailWidth = 72.0;
  static const collapseThreshold = 1080.0;

  static const _items = <_DesktopNavItem>[
    _DesktopNavItem('Home', Icons.home_filled, '/home'),
    _DesktopNavItem('Cases', Icons.folder_open_outlined, '/cases'),
    _DesktopNavItem('Calendar', Icons.calendar_month_outlined, '/calendar'),
    _DesktopNavItem('Reminders', Icons.notifications_none_rounded, '/reminders'),
    _DesktopNavItem('Fees', Icons.request_quote_outlined, '/fee'),
    _DesktopNavItem('Clients', Icons.person_outline_rounded, '/clients'),
    _DesktopNavItem('Team', Icons.groups_2_outlined, '/team'),
    _DesktopNavItem('JURIS', Icons.psychology_alt_outlined, '/juris'),
    _DesktopNavItem('To-Do list', Icons.checklist_rounded, '/todo'),
    _DesktopNavItem('Services', Icons.grid_view_rounded, '/services'),
    _DesktopNavItem('Reports', Icons.description_outlined, '/usage_history'),
    _DesktopNavItem('Settings', Icons.settings_outlined, '/settings'),
  ];

  @override
  State<WindowsDesktopShell> createState() => _WindowsDesktopShellState();
}

class _WindowsDesktopShellState extends State<WindowsDesktopShell> {
  final List<FocusNode> _focusNodes = [
    for (final _ in WindowsDesktopShell._items) FocusNode(),
  ];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _focusRelative(int from, int delta) {
    var next = from + delta;
    if (next < 0) next = _focusNodes.length - 1;
    if (next >= _focusNodes.length) next = 0;
    _focusNodes[next].requestFocus();
  }

  int _currentIndex() {
    for (var i = 0; i < _focusNodes.length; i++) {
      if (_focusNodes[i].hasFocus) return i;
    }
    return 0;
  }

  bool _isSelected(_DesktopNavItem item) {
    final route = widget.activeRoute;
    if (item.route == route) return true;
    if (item.route == '/cases') {
      return const {
        '/add_case',
        '/search_cases',
        '/case_management',
        '/completed_cases',
        '/deleted_cases',
        '/starred',
      }.contains(route);
    }
    if (item.route == '/calendar') {
      return const {'/calendar_list', '/full_calendar', '/cause_list'}
          .contains(route);
    }
    if (item.route == '/fee') return route == '/record_payment';
    if (item.route == '/team') return route == '/transfer_case';
    if (item.route == '/settings') {
      return const {
        '/security',
        '/settings_native',
        '/cloud_storage',
        '/upgrade',
      }.contains(route);
    }
    return false;
  }

  void _open(_DesktopNavItem item) {
    if (_isSelected(item)) return;
    Navigator.of(context).pushReplacementNamed(item.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WindowsDesktopShell.canvas,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _searchFocus.requestFocus(),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final collapsed =
                constraints.maxWidth < WindowsDesktopShell.collapseThreshold;
            return Row(
              children: [
                SizedBox(
                  width: collapsed
                      ? WindowsDesktopShell.compactRailWidth
                      : WindowsDesktopShell.expandedRailWidth,
                  child: _buildRail(collapsed),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.activeRoute != '/home') _buildWorkspaceBar(),
                      Expanded(child: ClipRect(child: widget.child)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkspaceBar() {
    final user = (() {
      try {
        return FirebaseAuth.instance.currentUser;
      } catch (_) {
        return null;
      }
    })();
    final displayName = (user?.displayName ?? '').trim().isNotEmpty
        ? user!.displayName!.trim()
        : (user?.email ?? 'Advocate').split('@').first;
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF7),
        border: Border(bottom: BorderSide(color: Color(0xFFE5DFD7))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: (MediaQuery.sizeOf(context).width -
                    (MediaQuery.sizeOf(context).width < 1080 ? 72 : 236) -
                    380)
                .clamp(180.0, 720.0),
            height: 40,
            child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  final query = value.trim();
                  if (query.isNotEmpty) {
                    Navigator.of(context).pushNamed(
                      '/search_cases',
                      arguments: query,
                    );
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search cases, clients, matters…',
                  hintStyle: const TextStyle(
                    color: Color(0xFF8A8984),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixText: 'Ctrl + K',
                  suffixStyle: const TextStyle(
                    color: Color(0xFF88847D),
                    fontSize: 10,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2DED7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2DED7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: WindowsDesktopShell.gold,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).pushNamed('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
            color: WindowsDesktopShell.forest,
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 34,
            color: const Color(0xFFDCD7CE),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFE8E2D5),
            backgroundImage: user?.photoURL == null
                ? null
                : NetworkImage(user!.photoURL!),
            child: user?.photoURL != null
                ? null
                : Text(
              initials.isEmpty ? 'A' : initials,
              style: const TextStyle(
                color: WindowsDesktopShell.forest,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17221B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Advocate workspace',
                  style: TextStyle(
                    color: Color(0xFF77766F),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: WindowsDesktopShell.forest,
          ),
        ],
      ),
    );
  }

  Widget _buildRail(bool collapsed) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: WindowsDesktopShell.forest),
        Positioned.fill(
          child: Image.asset(
            'assets/images/led_pillar_sidebar.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(color: WindowsDesktopShell.forest.withValues(alpha: .82)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrand(collapsed),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0x25FFFFFF)),
            const SizedBox(height: 15),
            Expanded(child: _buildNavigation(collapsed)),
            if (!collapsed) _buildQuote(),
            if (collapsed)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Icon(Icons.balance_rounded, color: WindowsDesktopShell.gold, size: 20),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrand(bool collapsed) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(13, 22, 13, 22),
        child: Image.asset(
          'assets/images/master logo.png',
          height: 42,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.balance_rounded, color: WindowsDesktopShell.gold, size: 30),
        ),
      );
    }
    return SizedBox(
      height: 95,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 17, 14, 14),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 48,
              child: Image.asset(
                'assets/images/master logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.balance_rounded, color: WindowsDesktopShell.gold, size: 34),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LED', style: TextStyle(fontFamily: 'Palatino Linotype', fontSize: 25, height: 1, color: Colors.white)),
                  SizedBox(height: 4),
                  Text("Lawyer’s E-Diary", maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFFE7E8E1), letterSpacing: .15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(bool collapsed) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _focusRelative(_currentIndex(), 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _focusRelative(_currentIndex(), -1),
      },
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(collapsed ? 9 : 14, 0, collapsed ? 9 : 12, 12),
          itemCount: WindowsDesktopShell._items.length,
          itemBuilder: (context, index) {
            final item = WindowsDesktopShell._items[index];
            final selected = _isSelected(item);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _SidebarItem(
                item: item,
                selected: selected,
                collapsed: collapsed,
                focusNode: _focusNodes[index],
                onTap: () => _open(item),
                onMoveDown: () => _focusRelative(index, 1),
                onMoveUp: () => _focusRelative(index, -1),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuote() {
    return const SizedBox(
      height: 255,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 18, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“Justice is not\njust a word,\nit’s a commitment.”',
                style: TextStyle(fontFamily: 'Palatino Linotype', fontStyle: FontStyle.italic,
                  color: Colors.white, fontSize: 17, height: 1.35)),
              SizedBox(height: 10),
              SizedBox(width: 30, child: Divider(color: WindowsDesktopShell.gold, thickness: 2)),
            ],
          ),
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
    return Focus(
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
      child: Tooltip(
        message: collapsed ? item.label : '',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            hoverColor: const Color(0x17FFFFFF),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              height: 42,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14),
              alignment: collapsed ? Alignment.center : null,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF665A35) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focusNode.hasFocus ? WindowsDesktopShell.gold : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(item.icon, size: 20, color: selected ? const Color(0xFFFFE6A8) : const Color(0xFFE2E9E3)),
                  if (!collapsed) ...[
                    const SizedBox(width: 13),
                    Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? const Color(0xFFFFE9B4) : Colors.white))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem {
  const _DesktopNavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
