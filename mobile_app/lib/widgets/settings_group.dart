import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';

/// A titled group of settings rows — an overline label above one card
/// holding hairline-separated rows. The grouped-list idiom, so Settings
/// scans as a list of destinations rather than a stack of panels.
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title.toUpperCase(), style: AppTextStyles.overline),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 66, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in a [SettingsGroup]: a tinted icon tile, label, optional
/// supporting line, and a chevron. [trailingText] is for a value the row
/// reports (e.g. a version number) rather than one it explains.
///
/// The icon tile matches the category tiles used on Home and in the
/// transaction list, so one shape language runs through the whole app
/// instead of Settings having bare grey glyphs of its own.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? supporting;
  final String? trailingText;
  final VoidCallback? onTap;

  /// Tints icon and supporting text — used to mark a row that needs
  /// attention, e.g. an account that isn't connected yet.
  final Color? accent;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.supporting,
    this.trailingText,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _IconTile(icon: icon, color: accent ?? AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  if (supporting != null && supporting!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      supporting!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: accent == null
                          ? AppTextStyles.supporting
                          : AppTextStyles.supporting.copyWith(color: accent),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 12),
              Text(trailingText!, style: AppTextStyles.supporting),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 10),
              const Icon(PhosphorIconsBold.caretRight, size: 12, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconTile({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// A labelled statistic inside a sub-screen — the read-only counterpart to
/// [SettingsRow], for things like "Transactions: 248".
class SettingsStatRow extends StatelessWidget {
  final String label;
  final String value;

  const SettingsStatRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          const SizedBox(width: 12),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
