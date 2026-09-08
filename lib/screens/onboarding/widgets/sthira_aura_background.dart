import 'package:flutter/material.dart';

class SthiraAuraBackground extends StatelessWidget {
  final int currentPage;

  const SthiraAuraBackground({super.key, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    const Color primaryAura = Color(0xFF171F1B); // Dark Surface
    const Color secondaryAura = Color(0xFF171F1B); // Monolithic

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1513), // Deep Forest Black base
        gradient: RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 1.2,
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
        ],
      ),
    );
  }
}
