import 'package:flutter/material.dart';

import 'screen_transitions.dart';

/// Adds restrained press, hover, and keyboard-focus feedback to a card.
/// Keeps the supplied child intact and supports pointer and touch input.
class TemplateInteractiveCard extends StatefulWidget {
  const TemplateInteractiveCard({
    required this.child,
    super.key,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.duration = const Duration(milliseconds: 140),
    this.hoverScale = 1.008,
    this.pressScale = 0.99,
    this.selected = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final Duration duration;
  final double hoverScale;
  final double pressScale;
  final bool selected;
  final FocusNode? focusNode;

  @override
  State<TemplateInteractiveCard> createState() =>
      _TemplateInteractiveCardState();
}

class _TemplateInteractiveCardState extends State<TemplateInteractiveCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : widget.duration;
    final scale = _pressed
        ? widget.pressScale
        : _hovered
        ? widget.hoverScale
        : 1.0;
    final emphasized = widget.selected || _focused;

    return Semantics(
      button: widget.onTap != null,
      selected: widget.selected,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) => setState(() => _focused = value),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onTapDown: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = true),
            onTapUp: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = false),
            onTapCancel: widget.onTap == null
                ? null
                : () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: scale,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: emphasized
                        ? const Color(0xFFCCA046)
                        : const Color(0xFFE5DFD7),
                    width: emphasized ? 1.5 : 1,
                  ),
                  boxShadow: _hovered && !reduceMotion
                      ? const [
                          BoxShadow(
                            color: Color(0x0A1A1A1A),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : const [],
                ),
                child: ClipRRect(
                  borderRadius: widget.borderRadius,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animates a selection mark and optional child changes for tabs or filters.
class TemplateSelectionIndicator extends StatelessWidget {
  const TemplateSelectionIndicator({
    required this.selected,
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 180),
    this.selectedColor = const Color(0xFF1F3D2B),
    this.unselectedColor = const Color(0xFFE5DFD7),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final bool selected;
  final Widget child;
  final Duration duration;
  final Color selectedColor;
  final Color unselectedColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration,
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      color: selected ? selectedColor : unselectedColor,
      borderRadius: borderRadius,
    ),
    child: child,
  );
}

/// Adds a smooth animated expand/collapse for case details and metadata.
class TemplateExpandable extends StatelessWidget {
  const TemplateExpandable({
    required this.expanded,
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeInOutCubic,
    this.alignment = Alignment.topCenter,
  });

  final bool expanded;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      curve: curve,
      alignment: alignment,
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: alignment,
        heightFactor: expanded ? 1 : 0,
        child: child,
      ),
    ),
  );
}

/// Morphs a button label into loading or success feedback without a controller.
class TemplateActionButton extends StatelessWidget {
  const TemplateActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.loading = false,
    this.completed = false,
    this.duration = const Duration(milliseconds: 180),
    this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool completed;
  final Duration duration;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final state = loading
        ? 'loading'
        : completed
        ? 'complete'
        : 'ready';
    final content = switch (state) {
      'loading' => const Row(
        key: ValueKey('loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 9),
          Text('Working…'),
        ],
      ),
      'complete' => const Row(
        key: ValueKey('complete'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded),
          SizedBox(width: 7),
          Text('Complete'),
        ],
      ),
      _ => Row(
        key: const ValueKey('ready'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon), const SizedBox(width: 7)],
          Text(label),
        ],
      ),
    };

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: TemplateAnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : duration,
        style: TemplateTransitionStyle.fade,
        child: content,
      ),
    );
  }
}
