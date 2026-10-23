import 'package:flutter/material.dart';

import '../../widgets/app_palette.dart';

/// Primary action button used by the authentication and registration flows.
///
/// The visual identity is resolved from the active [ThemeData] through
/// [EditorialComponentTheme], so the Android build keeps its existing
/// legacy-gold appearance while the Windows build uses the Modern Legal
/// Editorial forest green.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.child,
    this.loadingColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final Widget? child;

  /// Overrides the spinner colour. When null the spinner follows the
  /// button's own foreground colour.
  final Color? loadingColor;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<EditorialComponentTheme>() ??
        EditorialComponentTheme.legacy;

    final buttonChild = child ?? Text(label);
    final loadingChild = SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color:
            loadingColor ??
            (outlined ? tokens.onOutlineAction : tokens.onPrimaryAction),
      ),
    );

    return SizedBox(
      height: 52,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.onOutlineAction,
                disabledForegroundColor: tokens.onOutlineAction.withValues(
                  alpha: 0.45,
                ),
                side: BorderSide(color: tokens.outlineActionBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading ? loadingChild : buttonChild,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primaryAction,
                disabledBackgroundColor: tokens.primaryActionDisabled,
                foregroundColor: tokens.onPrimaryAction,
                disabledForegroundColor: tokens.onPrimaryActionDisabled,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading ? loadingChild : buttonChild,
            ),
    );
  }
}
