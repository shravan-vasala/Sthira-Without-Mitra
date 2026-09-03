import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/layout_insets.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/surface_card.dart';

class GoalSelectionPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const GoalSelectionPage({super.key, required this.onNext});

  @override
  ConsumerState<GoalSelectionPage> createState() => _GoalSelectionPageState();
}

class _GoalSelectionPageState extends ConsumerState<GoalSelectionPage> with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  String? _selectedGoal;
  String? _error;

  final List<Map<String, String>> _goals = [
    {
      'id': 'lose_weight',
      'title': 'Lose Weight',
      'subtitle': 'Burn fat and get leaner',
      'icon': '🔥',
    },
    {
      'id': 'build_muscle',
      'title': 'Build Muscle',
      'subtitle': 'Increase strength and mass',
      'icon': '💪',
    },
    {
      'id': 'stay_healthy',
      'title': 'Stay Healthy',
      'subtitle': 'Maintain weight and feel good',
      'icon': '🥑',
    },
    {
      'id': 'get_stronger',
      'title': 'Get Stronger',
      'subtitle': 'Improve athletic performance',
      'icon': '⚡',
    },
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _contentController, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic));

    final p = ref.read(profileProvider);
    if (p.primaryGoal != null && p.primaryGoal!.isNotEmpty) {
      _selectedGoal = p.primaryGoal;
    }

    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _onSaveAndNext() {
    if (_selectedGoal == null) {
      setState(() {
        _error = 'Please select a goal to continue';
      });
      return;
    }

    // Save
    final profile = ref.read(profileProvider);
    ref.read(profileProvider.notifier).updateProfile(profile.copyWith(primaryGoal: _selectedGoal));
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) {
        return Opacity(
          opacity: _contentFade.value,
          child: SlideTransition(
            position: _contentSlide,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: kSpace4),
            Text(
              'WHAT IS YOUR MAIN GOAL?',
              style: context.text.display.copyWith(color: context.colors.textDark, fontSize: 32, height: 1.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace2),
            Text(
              'This helps your AI Coach personalize recommendations and motivation.',
              style: context.text.body.copyWith(color: context.colors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace5),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: _goals.map((goal) {
                    final isSelected = _selectedGoal == goal['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedGoal = goal['id'];
                            _error = null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? context.colors.cyan : context.colors.card,
                            borderRadius: BorderRadius.circular(kRadiusLg),
                            border: Border.all(
                              color: isSelected ? context.colors.cyan : context.colors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Text(
                                goal['icon']!,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal['title']!,
                                      style: context.text.titleLarge.copyWith(color: isSelected ? context.colors.onPrimary : context.colors.textDark),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      goal['subtitle']!,
                                      style: context.text.bodyBold.copyWith(color: isSelected ? context.colors.onPrimary.withValues(alpha: 0.8) : context.colors.textMedium),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: context.colors.onPrimary, size: 28)
                              else
                                Icon(Icons.radio_button_unchecked_rounded, color: context.colors.border, size: 28),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            if (_error != null) ...[
              const SizedBox(height: kSpace2),
              Text(
                _error!,
                style: context.text.label.copyWith(color: context.colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: kSpace4),
            PrimaryButton(
              label: 'Continue',
              onPressed: _onSaveAndNext,
            ),
            const SizedBox(height: kSpace4),
          ],
        ),
      ),
    );
  }
}
