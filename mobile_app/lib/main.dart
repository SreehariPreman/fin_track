import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/background_sync_service.dart';
import 'services/credentials_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Order matters: notification channel + cold-start tap detection before
  // the UI builds, so a tap that launched the app is ready to route as
  // soon as RootScreen mounts.
  await NotificationService.instance.init();

  await BackgroundSyncService.initialize();
  if (await CredentialsService().hasCredentials()) {
    // Re-assert scheduling on every app start (e.g. after a reinstall) —
    // registerPeriodicTask + ExistingWorkPolicy.keep is a no-op if it's
    // already scheduled.
    await BackgroundSyncService.register();
  }

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
      home: const SplashScreen(),
    );
  }
}
