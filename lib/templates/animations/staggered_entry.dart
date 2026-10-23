import 'package:flutter/material.dart';

/// Fades and gently raises one child using an externally managed animation.
/// Pair it with [StaggeredEntryController] to sequence a group of entries.
class StaggeredEntry extends StatelessWidget {
  const StaggeredEntry({
    super.key,
    required this.animation,
    required this.child,
    this.offset = const Offset(0, 0.06),
  });

  final Animation<double> animation;
  final Widget child;

  /// The normalized starting offset; keep it small for restrained motion.
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: offset,
      end: Offset.zero,
    ).animate(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Owns the controller and per-item intervals for a staggered entrance.
/// Call [dispose] from the owning State's `dispose` method.
class StaggeredEntryController {
  StaggeredEntryController({
    required TickerProvider vsync,
    int itemCount = 9,
    Duration duration = const Duration(milliseconds: 1000),
    double initialDelay = 0.04,
    double itemGap = 0.07,
    double itemDuration = 0.34,
    Curve curve = Curves.easeOutCubic,
  }) {
    if (itemCount < 0) {
      throw ArgumentError.value(
        itemCount,
        'itemCount',
        'Must not be negative.',
      );
    }
    if (initialDelay < 0 || itemGap < 0 || itemDuration <= 0) {
      throw ArgumentError(
        'Stagger intervals must be non-negative and non-zero.',
      );
    }
    if (itemCount > 0 &&
        initialDelay + ((itemCount - 1) * itemGap) + itemDuration > 1) {
      throw ArgumentError('Stagger intervals must end at or before 1.0.');
    }
    controller = AnimationController(vsync: vsync, duration: duration);
    animations = <Animation<double>>[];
    animations.addAll(
      List<Animation<double>>.generate(itemCount, (index) {
        final start = initialDelay + (index * itemGap);
        return CurvedAnimation(
          parent: controller,
          curve: Interval(start, start + itemDuration, curve: curve),
        );
      }),
    );
  }

  late final AnimationController controller;
  late final List<Animation<double>> animations;

  void dispose() => controller.dispose();
}
