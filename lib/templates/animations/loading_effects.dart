import 'package:flutter/material.dart';

/// Renders a low-cost, clipped shimmer over a loading placeholder.
/// The animation pauses when animations are disabled in the platform settings.
class TemplateShimmer extends StatefulWidget {
  const TemplateShimmer({
    required this.child,
    super.key,
    this.baseColor = const Color(0xFFE9E5DF),
    this.highlightColor = const Color(0xFFF7F5F2),
    this.duration = const Duration(milliseconds: 1250),
    this.enabled = true,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;
  final bool enabled;

  @override
  State<TemplateShimmer> createState() => _TemplateShimmerState();
}

class _TemplateShimmerState extends State<TemplateShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant TemplateShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.enabled && !_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reduceMotion) {
      return ColoredBox(color: widget.baseColor, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.2 + 2.4 * _controller.value, 0),
          end: Alignment(-.2 + 2.4 * _controller.value, 0),
          colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
          stops: const [0.25, 0.5, 0.75],
        ).createShader(bounds),
        child: ColoredBox(color: widget.baseColor, child: child),
      ),
    );
  }
}

/// Displays a static group of skeleton bars, optionally with a clipped shimmer.
class TemplateSkeletonLines extends StatelessWidget {
  const TemplateSkeletonLines({
    super.key,
    this.lineCount = 3,
    this.lineHeight = 10,
    this.spacing = 8,
    this.lastLineFraction = 0.62,
    this.shimmer = true,
    this.baseColor = const Color(0xFFE9E5DF),
    this.highlightColor = const Color(0xFFF7F5F2),
  });

  final int lineCount;
  final double lineHeight;
  final double spacing;
  final double lastLineFraction;
  final bool shimmer;
  final Color baseColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    assert(lineCount >= 0);
    final skeleton = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lineCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == lineCount - 1 ? 0 : spacing,
          ),
          child: FractionallySizedBox(
            widthFactor: index == lineCount - 1 ? lastLineFraction : 1,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: lineHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(lineHeight),
                ),
              ),
            ),
          ),
        );
      }),
    );
    if (!shimmer) return skeleton;
    return TemplateShimmer(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: skeleton,
    );
  }
}

/// Animates a determinate progress value and announces it to accessibility.
class TemplateAnimatedProgress extends StatelessWidget {
  const TemplateAnimatedProgress({
    required this.value,
    super.key,
    this.duration = const Duration(milliseconds: 260),
    this.color = const Color(0xFF1F3D2B),
    this.backgroundColor = const Color(0xFFE5DFD7),
    this.minHeight = 4,
  });

  final double value;
  final Duration duration;
  final Color color;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0);
    final effectiveDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    return Semantics(
      value: '${(normalized * 100).round()} percent',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: normalized),
        duration: effectiveDuration,
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) => ClipRRect(
          borderRadius: BorderRadius.circular(minHeight),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            color: color,
            backgroundColor: backgroundColor,
          ),
        ),
      ),
    );
  }
}

/// Crossfades between pending and successful task icons with compact feedback.
class TemplateCompletionIcon extends StatelessWidget {
  const TemplateCompletionIcon({
    required this.completed,
    super.key,
    this.pendingIcon = Icons.radio_button_unchecked_rounded,
    this.completedIcon = Icons.check_circle_rounded,
    this.size = 22,
    this.duration = const Duration(milliseconds: 220),
    this.color = const Color(0xFF536D5A),
    this.semanticLabel,
  });

  final bool completed;
  final IconData pendingIcon;
  final IconData completedIcon;
  final double size;
  final Duration duration;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? (completed ? 'Completed' : 'Pending'),
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : duration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .82, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Icon(
        completed ? completedIcon : pendingIcon,
        key: ValueKey(completed),
        size: size,
        color: color,
      ),
    ),
  );
}
