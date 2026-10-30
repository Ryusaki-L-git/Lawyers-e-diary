import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Mobile application bar. On Windows the persistent [WindowsDesktopShell]
/// owns the global workspace bar and individual desktop pages own their page
/// heading, so this widget deliberately occupies no vertical space there.

class PlatformAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PlatformAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle,
  });

  /// The screen title.
  final String title;

  /// Optional small uppercase eyebrow shown above the title on Windows.
  final String? eyebrow;

  /// Optional muted subtitle shown under the title on Windows.
  final String? subtitle;

  /// Invoked when the desktop back affordance is used. When null no back
  /// affordance is rendered on Windows.
  final VoidCallback? onBack;

  /// Trailing actions, shared by both presentations.
  final List<Widget>? actions;

  /// Replaces the default back affordance on Windows.
  final Widget? leading;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? centerTitle;

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  @override
  Size get preferredSize {
    if (_isWindows) return Size.zero;
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWindows) {
      return AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        centerTitle: centerTitle,
        elevation: 0,
        scrolledUnderElevation: 0,
      );
    }

    return const SizedBox.shrink();
  }
}
