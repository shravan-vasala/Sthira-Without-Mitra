import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/layout_insets.dart';
import '../theme/app_typography.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_motion.dart';


/// Full-width primary save CTA (52dp, flat primary).
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final bool isLoading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.colors.onPrimary,
            ),
          )
        : (widget.icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 20,
                      color: widget.iconColor ?? context.colors.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: context.text.bodyStrong.copyWith(
                        color: context.colors.onPrimary,
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.label,
                  style: context.text.bodyStrong.copyWith(
                    color: context.colors.onPrimary,
                  ),
                ));

    final btn = SizedBox(
      width: double.infinity,
      height: kPrimaryButtonHeight,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.primary,
          foregroundColor: context.colors.onPrimary,
          disabledBackgroundColor: context.colors.card,
          disabledForegroundColor: context.colors.textMedium,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kButtonRadius),
          ),
          splashFactory: NoSplash.splashFactory, // Handled by scale
        ),
        child: child,
      ),
    );

    return GestureDetector(
      onTapDown: widget.isLoading || widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Motion.instant,
        curve: Motion.enter,
        child: widget.isLoading && !MediaQuery.disableAnimationsOf(context)
            ? btn
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: Motion.deliberate,
                    color: Colors.white.withValues(alpha: 0.2),
                  )
            : btn,
      ),
    );
  }
}

/// Compact row action (Photo / Describe / Adjust) — 40dp min height.
class CompactButton extends StatefulWidget {
  const CompactButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;

  @override
  State<CompactButton> createState() => _CompactButtonState();
}

class _CompactButtonState extends State<CompactButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.text.caption.copyWith(
      fontWeight: FontWeight.w700,
    );

    final child = widget.icon != null
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          )
        : Text(widget.label, style: textStyle);

    final btn = SizedBox(
      height: kCompactButtonHeight,
      width: double.infinity,
      child: widget.filled
          ? ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: textStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kOutlinedButtonRadius),
                ),
                splashFactory: NoSplash.splashFactory,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: widget.onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: textStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kOutlinedButtonRadius),
                ),
                splashFactory: NoSplash.splashFactory,
              ),
              child: child,
            ),
    );

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Motion.instant,
        curve: Motion.enter,
        child: btn,
      ),
    );
  }
}
