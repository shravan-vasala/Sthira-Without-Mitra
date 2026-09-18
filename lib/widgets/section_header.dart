import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Main section label used on Home / Workout / similar lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.trailing,
    this.countLabel,
    this.horizontalPadding = Spacing.screen,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget? countLabel;
  final double horizontalPadding;

  Widget? _buildTrailing() {
    if (trailing == null) return null;
    Widget child = trailing!;
    if (child is IconButton) {
      child = IconButton(
        key: child.key,
        icon: child.icon,
        onPressed: child.onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        iconSize: child.iconSize,
        color: child.color,
        tooltip: child.tooltip,
        splashRadius: child.splashRadius ?? 16,
        style: child.style,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 24),
      child: IconTheme(
        data: const IconThemeData(size: IconSize.inline),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _buildTrailing();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: context.colors.primary, size: IconSize.inline),
            const SizedBox(width: Spacing.inline),
          ],
          Text(title, style: context.text.sectionLabel),
          if (countLabel != null) ...[
            const SizedBox(width: Spacing.inline),
            countLabel!,
          ],
          const Spacer(),
          if (t != null) t,
        ],
      ),
    );
  }
}
