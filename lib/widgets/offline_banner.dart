import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class OfflineBanner extends StatelessWidget {
  final String message;

  const OfflineBanner({
    super.key,
    this.message = 'You are currently offline. AI features are unavailable.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.colors.orange.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: context.colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.text.caption.copyWith(
                color: context.colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
