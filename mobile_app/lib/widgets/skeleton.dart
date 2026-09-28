import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A softly pulsing placeholder block.
///
/// Replaces the centred spinner-on-a-blank-screen pattern: a skeleton
/// that mirrors the real layout makes the wait feel shorter, because the
/// page appears to be assembling rather than stalled.
///
/// Driven by its own AnimationController rather than flutter_animate's
/// `repeat`, which schedules a timer the widget tester counts as pending
/// work — an endlessly repeating one then fails any widget test that
/// happens to render a skeleton, at teardown rather than on an assertion.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, required this.height, this.radius = 10});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 1, end: 0.45)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Home's loading state, shaped like Home.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter, 8, AppTheme.gutter, AppTheme.sectionGap),
      children: [
        const Skeleton(width: 90, height: 12),
        const SizedBox(height: 10),
        const Skeleton(width: 160, height: 28),
        const SizedBox(height: AppTheme.sectionGap),
        const Skeleton(height: 232, radius: 28),
        const SizedBox(height: AppTheme.gap),
        const Row(
          children: [
            Expanded(child: Skeleton(height: 86, radius: 22)),
            SizedBox(width: AppTheme.gap),
            Expanded(child: Skeleton(height: 86, radius: 22)),
          ],
        ),
        const SizedBox(height: AppTheme.gap),
        const Skeleton(height: 72, radius: 22),
        const SizedBox(height: AppTheme.sectionGap),
        const Skeleton(height: 260, radius: 22),
      ],
    );
  }
}

/// Loading state for a date-grouped transaction list.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
      children: [
        const Skeleton(height: 40, radius: 999),
        for (var group = 0; group < 3; group++) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
            child: Skeleton(width: 120, height: 11),
          ),
          Skeleton(height: group == 0 ? 68.0 : 136.0, radius: AppTheme.cardRadius),
        ],
      ],
    );
  }
}

/// Loading state for an analytics sub-tab.
class AnalyticsSkeleton extends StatelessWidget {
  const AnalyticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter, 4, AppTheme.gutter, AppTheme.sectionGap),
      children: const [
        Skeleton(height: 120, radius: AppTheme.cardRadius),
        SizedBox(height: AppTheme.gap),
        Row(
          children: [
            Expanded(child: Skeleton(height: 86, radius: AppTheme.cardRadius)),
            SizedBox(width: AppTheme.gap),
            Expanded(child: Skeleton(height: 86, radius: AppTheme.cardRadius)),
          ],
        ),
        SizedBox(height: AppTheme.sectionGap),
        Skeleton(width: 130, height: 14),
        SizedBox(height: 12),
        Skeleton(height: 210, radius: AppTheme.cardRadius),
      ],
    );
  }
}
