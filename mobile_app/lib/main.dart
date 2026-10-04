import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Show something readable instead of a bare grey rectangle if a widget
  // fails to build in a release build. A blank screen tells you nothing
  // from a phone you can't attach a debugger to.
  ErrorWidget.builder = (details) => _StartupFailure(
        title: 'Something went wrong drawing this screen',
        detail: details.exceptionAsString(),
      );

  // Render first, initialise second.
  //
  // Notification setup, WorkManager registration and the Keystore-backed
  // credential check all used to be awaited *here*, before runApp(). Any
  // one of them throwing — or simply never completing — meant runApp()
  // was never reached and the app showed nothing but a black window, with
  // no way to tell from the device which step had died. Those now run
  // behind the splash, individually guarded, so a failure is reported
  // rather than fatal. See SplashScreen.
  runApp(const FinTrackApp());
}

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendTrack',
      navigatorKey: NotificationService.instance.navigatorKey,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

/// Full-screen, self-contained error report.
///
/// Deliberately depends on nothing but Flutter itself — it has to be able
/// to render when the rest of the app is in a bad state.
class _StartupFailure extends StatelessWidget {
  final String title;
  final String detail;

  const _StartupFailure({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              Text(
                detail,
                style: AppTextStyles.supporting.copyWith(
                  fontFamily: kIsWeb ? null : 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
