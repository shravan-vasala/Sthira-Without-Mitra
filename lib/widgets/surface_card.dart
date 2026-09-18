import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_motion.dart';


enum SurfaceCardElevation { home, nested }

/// Standard app surface card — Home cockpit chrome by default.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    /// The container owns the horizontal inset. Cards inside a padded scrollable pass `margin: EdgeInsets.zero`.
    this.margin = const EdgeInsets.symmetric(horizontal: Spacing.screen),
    this.padding,
    this.dense = false,
    this.onTap,
    this.border,
    this.color,
    this.elevation = SurfaceCardElevation.home,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool dense;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final Color? color;
  final SurfaceCardElevation elevation;
  final double? borderRadius;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? Radii.card;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final List<BoxShadow> shadows;
    switch (widget.elevation) {
      case SurfaceCardElevation.home:
        shadows = [
          BoxShadow(
            color: context.colors.textDark.withValues(
              alpha: isLight ? 0.05 : 0.0,
            ),
            blurRadius: isLight ? 12 : 16,
            offset: Offset(0, isLight ? 4 : 6),
          ),
        ];
      case SurfaceCardElevation.nested:
        shadows = [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ];
    }

    final card = Container(
      margin: widget.margin,
      padding:
          widget.padding ??
          EdgeInsets.all(widget.dense ? Spacing.cardPadTight : Spacing.cardPad),
      decoration: BoxDecoration(
        color: widget.color ?? context.colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: widget.border,
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: Motion.instant,
        curve: Motion.enter,
        child: card,
      ),
    );
  }
}
