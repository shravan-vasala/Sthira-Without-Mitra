import 'package:flutter/material.dart';

class SthiraAuraBackground extends StatefulWidget {
  final int currentPage;

  const SthiraAuraBackground({super.key, required this.currentPage});

  @override
  State<SthiraAuraBackground> createState() => _SthiraAuraBackgroundState();
}

class _SthiraAuraBackgroundState extends State<SthiraAuraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine aura colors based on the current page to give a sense of progression
    Color primaryAura;
    Color secondaryAura;

    if (widget.currentPage <= 1) {
      primaryAura = const Color(0xFFE29B65); // Sandy Peach
      secondaryAura = const Color(0xFF171F1B); // Dark Surface
    } else if (widget.currentPage == 2) {
      primaryAura = const Color(0xFFE29B65); // Sandy Peach
      secondaryAura = const Color(0xFFB5A5AA); // Muted Sage
    } else {
      primaryAura = const Color(0xFFB5A5AA); // Muted Sage
      secondaryAura = const Color(0xFF171F1B); // Dark Surface
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1513), // Deep Forest Black base
            gradient: RadialGradient(
              center: const Alignment(0, 0.2),
              radius: 1.2 * _scaleAnimation.value,
              colors: [
                primaryAura.withValues(alpha: 0.15),
                secondaryAura.withValues(alpha: 0.05),
                const Color(0xFF0F1513),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -150,
                right: -50,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryAura.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
