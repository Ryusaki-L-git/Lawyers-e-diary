/// Shared desktop presentation components for the LED Windows application.
///
/// The Windows screens previously each hand-rolled their own page header,
/// panel, empty state and form label. That duplication is the reason small
/// visual differences accumulated across the workspace. These components
/// establish one house style that every Windows surface can rely on.
///
/// Every component takes its colours from the canonical [AppPalette] tokens
/// so the Modern Legal Editorial identity stays in one place.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../templates/animations/loading_effects.dart';
import 'app_palette.dart';

/// The standard page header for a Windows desktop surface.
///
/// Consists of a small uppercase eyebrow, a serif title and a muted
/// subtitle, matching the editorial character of the design system.
class WindowsPageHeader extends StatelessWidget {
  const WindowsPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  /// Optional leading widget, typically a back button.
  final Widget? leading;

  /// Optional trailing actions, typically the primary page action.
  final Widget? actions;

  /// Optional secondary content rendered below the title block.
  ///
  /// Used for toolbars that belong to the page identity rather than to the
  /// action cluster on the right.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppPalette.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.heading,
            color: AppPalette.primaryGreen,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 13),
          ),
        ],
      ],
    );

    if (leading == null && actions == null && trailing == null) {
      return titleBlock;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final header = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: titleBlock),
                    ],
                  ),
                  if (actions != null) ...[
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: actions!),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Expanded(child: titleBlock),
                  if (actions != null) ...[const SizedBox(width: 14), actions!],
                ],
              );

        if (trailing == null) return header;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: 16), trailing!],
        );
      },
    );
  }
}

/// A white content panel with a hairline border, used for every discrete
/// block of content on a Windows surface.
class WindowsPanel extends StatelessWidget {
  const WindowsPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  final Widget child;

  /// Optional panel heading rendered above the content.
  final String? title;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x071A1A1A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// The consistent empty, error and informational state for a Windows screen.
class WindowsMessageState extends StatelessWidget {
  const WindowsMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Renders the state in the destructive colour when true.
  final bool isError;

  /// Optional call to action, such as a retry button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? AppPalette.statusDanger : AppPalette.accentGold;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: accent),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// A small uppercase label used above form fields on Windows surfaces.
class WindowsFieldLabel extends StatelessWidget {
  const WindowsFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppPalette.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// A compact status chip, used for fee status, task priority and similar
/// short state labels.
class WindowsStatusChip extends StatelessWidget {
  const WindowsStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;

  /// Renders the chip with a solid fill instead of a tinted outline.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled ? color : color.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The standard input decoration for a Windows form field.
class WindowsFieldDecoration {
  const WindowsFieldDecoration({required this.hint, this.errorText});

  final String hint;
  final String? errorText;

  InputDecoration build() {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 13),
      errorText: errorText,
      filled: true,
      fillColor: AppPalette.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.accentGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.statusDanger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppPalette.statusDanger,
          width: 1.5,
        ),
      ),
    );
  }
}

/// The standard page scaffold for a Windows desktop surface.
///
/// It supplies the ivory canvas, the desktop gutters and a centred content
/// column, and it can optionally own the scrolling so that a page never
/// overflows a short window.
class WindowsPage extends StatelessWidget {
  const WindowsPage({
    super.key,
    required this.child,
    this.maxWidth = 1240,
    this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 28),
    this.scrollable = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  /// When true the content scrolls vertically inside the page.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }

    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout scale
// ---------------------------------------------------------------------------

/// The desktop breakpoints used across the Windows workspace.
///
/// A Windows application has to stay usable on a 13-inch laptop and on a
/// 27-inch desktop monitor, so every multi-column surface picks its column
/// count from one of these three bands rather than from a hard-coded width
/// at each call site.
enum WindowsBreakpoint {
  /// Narrow windows and side-by-side layouts. One column, no sidebar.
  compact,

  /// Standard laptop widths. Two columns where the content warrants it.
  medium,

  /// Wide desktop monitors. Three or more columns.
  expanded;

  /// True when the layout should stack into a single column.
  bool get isCompact => this == WindowsBreakpoint.compact;

  /// True when the layout may use side-by-side columns.
  bool get isMultiColumn => this != WindowsBreakpoint.compact;
}

/// Resolves the [WindowsBreakpoint] for a given available width.
abstract final class WindowsLayout {
  /// Upper bound of the compact band.
  static const double compactMax = 820;

  /// Upper bound of the medium band.
  static const double mediumMax = 1180;

  /// The breakpoint that applies to [width].
  static WindowsBreakpoint breakpointOf(double width) {
    if (width >= mediumMax) return WindowsBreakpoint.expanded;
    if (width >= compactMax) return WindowsBreakpoint.medium;
    return WindowsBreakpoint.compact;
  }

  /// The number of columns a stat tile row should use at [width].
  static int statColumnsOf(double width) {
    if (width >= mediumMax) return 4;
    if (width >= compactMax) return 2;
    return 1;
  }
}

// ---------------------------------------------------------------------------
// Action styling
// ---------------------------------------------------------------------------

/// The house button styles for Windows surfaces.
///
/// Every desktop screen routes its controls through these helpers so that
/// the primary, secondary and destructive actions stay visually distinct
/// across the whole workspace.
abstract final class WindowsButtonStyles {
  /// The single primary action of a page: solid forest green.
  static ButtonStyle primary({double height = 40}) {
    return FilledButton.styleFrom(
      backgroundColor: AppPalette.primaryGreen,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppPalette.primaryGreen.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  /// A secondary action: white surface, forest green label, hairline border.
  static ButtonStyle secondary({double height = 40}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppPalette.primaryGreen,
      backgroundColor: AppPalette.cardBackground,
      side: const BorderSide(color: AppPalette.borderLight),
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  /// A low-emphasis action used for tertiary links inside a panel.
  static ButtonStyle ghost() {
    return TextButton.styleFrom(
      foregroundColor: AppPalette.primaryGreen,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    );
  }

  /// A destructive action, kept visually distinct from the primary action.
  static ButtonStyle danger({double height = 40}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppPalette.statusDanger,
      backgroundColor: AppPalette.cardBackground,
      side: BorderSide(
        color: AppPalette.statusDanger.withValues(alpha: 0.45),
      ),
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  /// An action rendered on top of a forest green panel.
  static ButtonStyle onForest({bool filled = false}) {
    if (filled) {
      return FilledButton.styleFrom(
        backgroundColor: AppPalette.accentGold,
        foregroundColor: AppPalette.primaryGreen,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      );
    }
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0x66FFFFFF)),
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

/// The standard search input used by the Windows workspace.
///
/// Provides the search glyph, a clear affordance and the shared field
/// decoration so search behaves identically on every desktop surface.
class WindowsSearchField extends StatelessWidget {
  const WindowsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.width = 340,
    this.onDark = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// The fixed width of the field. Desktop toolbars keep search at a
  /// predictable size rather than letting it stretch across the window.
  final double width;

  /// Renders the field for use on a forest green panel.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final hintColor = onDark
        ? AppPalette.onForestFaint
        : AppPalette.textMuted;
    final fieldFill = onDark ? const Color(0x1AFFFFFF) : AppPalette.canvas;
    final fieldBorder = onDark
        ? const Color(0x3DFFFFFF)
        : AppPalette.borderLight;

    return SizedBox(
      width: width,
      height: 44,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: TextStyle(
              color: onDark ? Colors.white : AppPalette.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor, fontSize: 13),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 19,
                color: onDark ? AppPalette.accentGold : AppPalette.textMuted,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 17),
                      color: onDark
                          ? AppPalette.onForestFaint
                          : AppPalette.textMuted,
                      tooltip: 'Clear search',
                    ),
              filled: true,
              fillColor: fieldFill,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: AppPalette.accentGold,
                  width: 1.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A segmented filter control for the Windows workspace.
///
/// Replaces the loose rows of [ChoiceChip] that each screen used to build on
/// its own, so filtering looks and behaves the same everywhere.
class WindowsFilterBar extends StatelessWidget {
  const WindowsFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  /// The available filters as `(value, label)` pairs.
  final List<(String, String)> options;

  /// The currently selected value.
  final String selected;

  final ValueChanged<String> onChanged;

  /// Optional caption rendered before the segments.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final option in options)
                _FilterSegment(
                  label: option.$2,
                  selected: option.$1 == selected,
                  onTap: () => onChanged(option.$1),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.primaryGreen : AppPalette.cardBackground,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? AppPalette.primaryGreen : AppPalette.borderLight,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppPalette.textMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data display
// ---------------------------------------------------------------------------

/// A small uppercase section label used to break a page into groups.
class WindowsSectionHeading extends StatelessWidget {
  const WindowsSectionHeading(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppPalette.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.7,
      ),
    );

    if (trailing == null) return heading;

    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: 12),
        trailing!,
      ],
    );
  }
}

/// A single headline figure with a caption, used for workspace summaries.
///
/// Every figure comes from the same repository-backed data the screen
/// already loads; the tile only presents it.
class WindowsStatTile extends StatelessWidget {
  const WindowsStatTile({
    super.key,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.onTap,
    this.width,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  /// Optional action. When supplied the tile becomes a button.
  final VoidCallback? onTap;

  /// An explicit width, used when the tile sits in a Wrap.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return width == null ? content : SizedBox(width: width, child: content);
    }

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: content,
        ),
      ),
    );
  }
}

/// The consistent loading treatment for a Windows panel.
class WindowsLoadingPanel extends StatelessWidget {
  const WindowsLoadingPanel({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: const TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
            ],
            for (var index = 0; index < 3; index++) ...[
              WindowsPanel(
                padding: const EdgeInsets.all(16),
                child: TemplateSkeletonLines(
                  lineCount: index == 0 ? 3 : 2,
                  lineHeight: index == 0 ? 11 : 9,
                  spacing: 9,
                  lastLineFraction: index == 0 ? 0.48 : 0.68,
                ),
              ),
              if (index < 2) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// A structured row used by the desktop list surfaces.
///
/// Provides the hairline separation, the hover treatment and a consistent
/// text rhythm so a list of matters reads like a register rather than a
/// stack of cards.
class WindowsListRow extends StatelessWidget {
  const WindowsListRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    this.showDivider = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppPalette.cardBackground,
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: AppPalette.borderLight),
              )
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: AppPalette.cardBackground,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppPalette.canvas.withValues(alpha: 0.6),
        child: content,
      ),
    );
  }
}

/// The column headings of a structured desktop list.
class WindowsListHeader extends StatelessWidget {
  const WindowsListHeader({
    super.key,
    required this.columns,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
  });

  /// The headings, each already carrying the width or flex it needs.
  final List<Widget> columns;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AppPalette.canvas,
        border: Border(bottom: BorderSide(color: AppPalette.borderLight)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            columns[i],
          ],
        ],
      ),
    );
  }
}

/// A column heading label for [WindowsListHeader].
class WindowsColumnLabel extends StatelessWidget {
  const WindowsColumnLabel(this.label, {super.key, this.flex, this.width});

  final String label;
  final int? flex;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppPalette.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );

    if (flex != null) return Expanded(flex: flex!, child: text);
    if (width != null) return SizedBox(width: width, child: text);
    return text;
  }
}

/// A desktop scroll behaviour that supports click-and-drag scrolling.
///
/// Flutter's default desktop behaviour only drags with a touch device, which
/// leaves a mouse-driven user without the scrollbar-free drag gesture they
/// expect from a native Windows application.
class WindowsDesktopScrollBehavior extends MaterialScrollBehavior {
  const WindowsDesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}
