import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'root_screen.dart';

/// Brand intro shown while the app does its (currently trivial) startup
/// work. Carries the same jade gradient as Home's hero card, so the first
/// thing you see and the first thing you land on belong together.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, _, _) => const RootScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroStart, AppColors.heroEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  PhosphorIconsFill.wallet,
                  size: 44,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .scale(begin: const Offset(0.86, 0.86), end: const Offset(1, 1), duration: 520.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 26),
              Text(
                'SpendTrack',
                style: AppTextStyles.screenTitle.copyWith(color: Colors.white),
              ).animate().fadeIn(delay: 140.ms, duration: 380.ms).slideY(begin: 0.3, end: 0, delay: 140.ms, duration: 420.ms),
              const SizedBox(height: 8),
              Text(
                'Track. Understand. Take Control.',
                style: AppTextStyles.bodySecondary.copyWith(color: AppColors.onInkMuted),
              ).animate().fadeIn(delay: 240.ms, duration: 380.ms),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}
