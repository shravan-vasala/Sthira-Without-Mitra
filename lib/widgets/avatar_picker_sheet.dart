import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AvatarPickerSheet extends StatelessWidget {
  const AvatarPickerSheet({super.key});

  static const List<Map<String, String>> avatars = [
    {'name': 'Lion', 'path': 'assets/avatars/lion.png'},
    {'name': 'Rabbit', 'path': 'assets/avatars/rabbit.png'},
    {'name': 'Owl', 'path': 'assets/avatars/owl.png'},
    {'name': 'Fox', 'path': 'assets/avatars/fox.png'},
    {'name': 'Bear', 'path': 'assets/avatars/bear.png'},
    {'name': 'Panda', 'path': 'assets/avatars/panda.png'},
    {'name': 'Tiger', 'path': 'assets/avatars/tiger.png'},
    {'name': 'Koala', 'path': 'assets/avatars/koala.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.textLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Sesireka Spirit',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Cabinet Grotesk',
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your companion',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 32),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
            ),
            itemCount: avatars.length,
            itemBuilder: (context, index) {
              final avatar = avatars[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(avatar['path']),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        avatar['path']!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          
          // Remove Avatar Action
          InkWell(
            onTap: () => Navigator.of(context).pop('DELETE'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Text(
                'Remove Avatar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

