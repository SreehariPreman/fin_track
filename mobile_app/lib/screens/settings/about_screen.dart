import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/app_text_styles.dart';
import '../../widgets/settings_group.dart';

/// Version and build identity, read from the installed package rather
/// than hardcoded — see the note at the bottom of the screen.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: info == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                SettingsGroup(
                  title: 'Application',
                  children: [
                    SettingsStatRow(label: 'Name', value: info.appName),
                    SettingsStatRow(label: 'Version', value: info.version),
                    SettingsStatRow(label: 'Build', value: info.buildNumber),
                  ],
                ),
                const SizedBox(height: 22),
                SettingsGroup(
                  title: 'Package',
                  children: [
                    SettingsStatRow(label: 'Identifier', value: info.packageName),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Read from the installed app, which takes it from '
                    '`version: <version>+<build>` in pubspec.yaml. Bump the '
                    'version for a release people would notice, and the build '
                    'number for every build you install anywhere.',
                    style: AppTextStyles.supporting,
                  ),
                ),
              ],
            ),
    );
  }
}
