import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The app's one card style: white, generously rounded, and lifted by a
/// two-layer shadow (tight contact + wide ambient) rather than a single
/// blur — that's the difference between a card that sits on the page and
/// one that looks stickered on top of it.
///
/// Use this for any card-like section instead of hand-rolling a Container.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Drops the shadow for cards nested inside another surface, where a
  /// second shadow just reads as grime.
  final bool flat;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.cardRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: radius,
        border: flat ? Border.all(color: AppColors.border) : null,
        boxShadow: flat ? null : AppColors.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          // A null onTap still goes through InkWell so the clip and radius
          // are identical whether or not the card is interactive.
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A tinted, borderless surface used for inline notices (e.g. the
/// unlabelled nudge). Reads as part of the page rather than a card
/// floating above it, which is right for something advisory.
class TintedPanel extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TintedPanel({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.cardRadius);
    return Material(
      color: color,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
