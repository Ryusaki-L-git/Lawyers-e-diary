import 'package:flutter/material.dart';

/// Marks a selected child as a Hero source or destination in its route pair.
/// Use the same stable [tag] on both routes; do not reuse tags in one route.
class TemplateSharedElement extends StatelessWidget {
  const TemplateSharedElement({
    required this.tag,
    required this.child,
    super.key,
    this.flightShuttleBuilder,
  });

  final Object tag;
  final Widget child;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  @override
  Widget build(BuildContext context) =>
      Hero(tag: tag, flightShuttleBuilder: flightShuttleBuilder, child: child);
}
