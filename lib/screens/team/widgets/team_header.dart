import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/team_model.dart';
import '../../../widgets/app_palette.dart';
import '../../../widgets/platform_app_bar.dart';

/// Top bar used across Team screens.
/// Shows team name, firm name, role badge, and actions.
class TeamHeader extends StatelessWidget implements PreferredSizeWidget {
  const TeamHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.role,
    this.actions,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final TeamRole? role;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => defaultTargetPlatform == TargetPlatform.windows
      ? Size.fromHeight(subtitle == null || subtitle!.isEmpty ? 62 : 84)
      : const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return PlatformAppBar(
        title: title,
        eyebrow: 'TEAM WORKSPACE',
        subtitle: subtitle,
        onBack: showBack
            ? (onBack ?? () => Navigator.of(context).maybePop())
            : null,
        actions: actions,
        backgroundColor: AppPalette.cardBackground,
        foregroundColor: AppPalette.textPrimary,
      );
    }
    return AppBar(
      backgroundColor: AppPalette.cardBackground,
      foregroundColor: AppPalette.primaryGreen,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: AppPalette.borderLight)),
      leading: showBack
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppPalette.primaryGreen,
                size: 22,
              ),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontFamily: AppTypography.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (role != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _roleBadgeColor(role!).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _roleBadgeColor(role!).withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    role!.label.toUpperCase(),
                    style: TextStyle(
                      color: _roleBadgeColor(role!),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions,
    );
  }

  Color _roleBadgeColor(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
        return AppPalette.accentGold;
      case TeamRole.leader:
        return AppPalette.primaryGreen;
      case TeamRole.member:
        return AppPalette.deepGreen;
    }
  }
}
