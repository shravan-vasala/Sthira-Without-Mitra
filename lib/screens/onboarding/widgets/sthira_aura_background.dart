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
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We enforce the strict monochromatic aura requested, completely overriding the previous colored gradient logic.
    const Color primaryAura = Color(0xFF171F1B); // Dark Surface
    const Color secondaryAura = Color(0xFF171F1B); // Monolithic

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
                primaryAura.withValues(alpha: 0.8),
                secondaryAura.withValues(alpha: 0.3),
                const Color(0xFF0F1513),
              ],
              stops: const [0.0, 0.5, 1.0],
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
                          primaryAura.withValues(alpha: 0.5),
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
