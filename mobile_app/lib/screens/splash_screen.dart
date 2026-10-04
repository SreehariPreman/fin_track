import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/background_sync_service.dart';
import '../services/credentials_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'root_screen.dart';

/// Brand intro, and the place the app's startup work actually happens.
///
/// Each step is guarded *and* timed out. A throw and a step that simply
/// never completes both used to produce the same thing — an app stuck
/// before its first frame, with nothing on screen to say why — so neither
/// is allowed to block the UI any more. Whatever fails, the app still
/// reaches Home; the failures are just reported on the way past.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// No single startup step has any business taking this long. Exceeding
  /// it is treated as a failure of that step rather than of the app.
  static const _stepTimeout = Duration(seconds: 8);

  /// Keep the brand moment on screen briefly even when startup is instant.
  static const _minimumVisible = Duration(milliseconds: 1100);

  final _failures = <String>[];
  bool _showFailures = false;

  @override
  void initState() {
    super.initState();
    _startUp();
  }

  Future<void> _step(String label, Future<void> Function() body) async {
    try {
      await body().timeout(_stepTimeout);
    } catch (error) {
      _failures.add('$label — $error');
    }
  }

  Future<void> _startUp() async {
    final started = DateTime.now();

    await _step('Notifications', () => NotificationService.instance.init());
    await _step('Background sync', () => BackgroundSyncService.initialize());
    await _step('Saved credentials', () async {
      // Reading these touches the Android Keystore, which can refuse to
      // decrypt after a restore from backup or an OS upgrade.
      if (await CredentialsService().hasCredentials()) {
        await BackgroundSyncService.register();
      }
    });

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minimumVisible) {
      await Future.delayed(_minimumVisible - elapsed);
    }
    if (!mounted) return;

    if (_failures.isEmpty) {
      _goHome();
    } else {
      // Don't silently swallow it: a build that half-works should say so,
      // because this screen may be the only diagnostic available on a
      // device that can't be attached to.
      setState(() => _showFailures = true);
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const RootScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
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
          child: _showFailures ? _buildFailures() : _buildBrand(),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        const Spacer(flex: 3),
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(PhosphorIconsFill.wallet, size: 44, color: Colors.white),
        )
            .animate()
            .fadeIn(duration: 420.ms)
            .scale(
              begin: const Offset(0.86, 0.86),
              end: const Offset(1, 1),
              duration: 520.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 26),
        Text(
          'SpendTrack',
          style: AppTextStyles.screenTitle.copyWith(color: Colors.white),
        ).animate().fadeIn(delay: 140.ms, duration: 380.ms).slideY(
              begin: 0.3,
              end: 0,
              delay: 140.ms,
              duration: 420.ms,
            ),
        const SizedBox(height: 8),
        Text(
          'Track. Understand. Take Control.',
          style: AppTextStyles.bodySecondary.copyWith(color: AppColors.onInkMuted),
        ).animate().fadeIn(delay: 240.ms, duration: 380.ms),
        const Spacer(flex: 4),
      ],
    );
  }

  Widget _buildFailures() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Started with problems',
            style: AppTextStyles.screenTitle.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'The app will still open. These parts did not start correctly:',
            style: AppTextStyles.bodySecondary.copyWith(color: AppColors.onInkMuted),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final failure in _failures)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        failure,
                        style: AppTextStyles.supporting.copyWith(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _goHome,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.heroEnd,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
