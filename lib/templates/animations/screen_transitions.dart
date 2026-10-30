import 'package:flutter/material.dart';

/// Native transition styles for selected LED routes and changing content.
enum TemplateTransitionStyle {
  fade,
  fadeSlide,
  horizontalSlide,
  verticalSlide,
  scaleFade,
}

/// Builds a configurable page route with a restrained LED screen transition.
/// Use this for individual routes when a screen-specific transition is desired.
class TemplatePageRoute<T> extends PageRouteBuilder<T> {
  TemplatePageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.style = TemplateTransitionStyle.fadeSlide,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             buildTemplateTransition(
               animation: animation,
               child: child,
               style: style,
               curve: curve,
             ),
       );

  final TemplateTransitionStyle style;
  final Duration duration;
  final Curve curve;
}

/// Applies one LED transition to a child using Flutter's native transitions.
/// The same builder can be supplied to [AnimatedSwitcher.transitionBuilder].
Widget buildTemplateTransition({
  required Animation<double> animation,
  required Widget child,
  TemplateTransitionStyle style = TemplateTransitionStyle.fadeSlide,
  Curve curve = Curves.easeOutCubic,
  double slideDistance = 0.045,
  double scaleBegin = 0.96,
}) {
  final curved = CurvedAnimation(parent: animation, curve: curve);
  switch (style) {
    case TemplateTransitionStyle.fade:
      return FadeTransition(opacity: curved, child: child);
    case TemplateTransitionStyle.fadeSlide:
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, slideDistance),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    case TemplateTransitionStyle.horizontalSlide:
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(slideDistance, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    case TemplateTransitionStyle.verticalSlide:
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, slideDistance),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    case TemplateTransitionStyle.scaleFade:
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: scaleBegin, end: 1).animate(curved),
          child: child,
        ),
      );
  }
}

/// Switches keyed content with a selected transition and reversible duration.
class TemplateAnimatedSwitcher extends StatelessWidget {
  const TemplateAnimatedSwitcher({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 220),
    this.style = TemplateTransitionStyle.fade,
    this.curve = Curves.easeOutCubic,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  final Widget child;
  final Duration duration;
  final TemplateTransitionStyle style;
  final Curve curve;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration,
    reverseDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration,
    switchInCurve: curve,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: layoutBuilder,
    transitionBuilder: (child, animation) => buildTemplateTransition(
      animation: animation,
      child: child,
      style: style,
      curve: curve,
    ),
    child: child,
  );
}


/// Shared transition builder for normal MaterialApp route navigation.
class TemplatePlatformPageTransitionsBuilder extends PageTransitionsBuilder {
  const TemplatePlatformPageTransitionsBuilder({this.style = TemplateTransitionStyle.fadeSlide});
  final TemplateTransitionStyle style;
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return buildTemplateTransition(animation: animation, child: child, style: style, curve: Curves.easeOutCubic);
  }
}
