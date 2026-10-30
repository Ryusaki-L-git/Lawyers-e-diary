import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_palette.dart';

/// An application bar that adapts to the host platform.
///
/// The LED Windows application presents its screens inside the persistent
/// [WindowsDesktopShell], which already supplies the navigation rail and the
/// page chrome. A stock mobile [AppBar] inside that shell produced a second,
/// conflicting header band, so this widget renders a desktop header on
/// Windows and the familiar mobile app bar everywhere else.
///
/// Using it keeps a single screen implementation for both platforms without
/// forking the layout, and it guarantees every embedded flow gets the same
/// desktop treatment.
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
    if (!_isWindows) return const Size.fromHeight(kToolbarHeight);
    // The desktop header carries an eyebrow, a serif title and an optional
    // subtitle, so it needs more vertical room than a mobile toolbar.
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Size.fromHeight(hasSubtitle ? 84 : 62);
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

    final ink = foregroundColor ?? AppPalette.textPrimary;

    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        color: backgroundColor ?? AppPalette.canvas,
        padding: const EdgeInsets.fromLTRB(30, 10, 30, 10),
        child: Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: ink,
                tooltip: 'Back',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
            ] else if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                    Text(
                      eyebrow!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.heading,
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (actions != null) ...[const SizedBox(width: 12), ...actions!],
          ],
        ),
      ),
    );
  }
}
