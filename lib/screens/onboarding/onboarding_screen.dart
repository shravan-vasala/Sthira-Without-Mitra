import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/habit.dart';
import '../../utils/target_calculator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'widgets/sthira_aura_background.dart';

import 'pages/welcome_page.dart';
import 'pages/about_you_page.dart';
import 'pages/your_plan_page.dart';
import 'pages/connect_page.dart';

String kOnboardingCompletedKey = 'onboarding_completed';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  bool _showCompletion = false;
  bool _isSaving = false;
  bool _showErrors = false;

  final _nameController = TextEditingController();
  final _coachNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _useKg = true;

  double _targetCalories = 1250;
  bool _isCaloriesManuallyEdited = false;
  TargetMacros? _targetMacros;
  final List<String> _selectedHabitIds = ['sleep', 'walk', 'water'];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_triggerRebuild);
    _heightController.addListener(_triggerRebuild);
    _weightController.addListener(_triggerRebuild);
  }

  void _triggerRebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_triggerRebuild);
    _heightController.removeListener(_triggerRebuild);
    _weightController.removeListener(_triggerRebuild);
    _pageController.dispose();
    _nameController.dispose();
    _coachNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _completeRoute() {
    ref.read(onboardingCompletedProvider.notifier).completeRoute();
  }

  Future<void> _goNext() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_currentPage == 1) {
        setState(() => _showErrors = true);
        if (!await _saveProfile()) return;
      }
      if (_currentPage == 2) {
        if (_selectedHabitIds.isEmpty) return; // Must have 1
        await _saveGoals();
      }
      
      if (_currentPage < _totalPages - 1) {
        HapticFeedback.selectionClick();
        _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else {
        // Connect screen complete!
        await ref.read(onboardingCompletedProvider.notifier).commitLocalSetup();
        
        HapticFeedback.lightImpact();
        setState(() {
          _showCompletion = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<bool> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    
    final hText = _heightController.text;
    if (hText.isEmpty) return false;
    final height = double.tryParse(hText);
    if (height == null || height < 100 || height > 230) return false;

    double? finalWeight;
    final wText = _weightController.text;
    if (wText.isNotEmpty) {
      final w = double.tryParse(wText);
      if (w != null) {
        final double wKg = _useKg ? w : w / 2.20462;
        if (wKg < 30 || wKg > 200) return false;
        finalWeight = wKg;
      } else {
        return false;
      }
    }

    final current = ref.read(profileProvider);
    await ref.read(profileProvider.notifier).updateProfile(
      current.copyWith(
        name: name,
        coachName: _coachNameController.text.trim(),
        height: height,
        currentWeight: finalWeight,
        clearCurrentWeight: wText.isEmpty,
        useKg: _useKg,
      ),
    );
    return true;
  }

  Future<void> _saveGoals() async {
    final current = ref.read(profileProvider);
    await ref.read(profileProvider.notifier).updateProfile(
      current.copyWith(
        targetCalories: _targetCalories.round(),
        targetProteinG: _targetMacros?.proteinG,
        targetCarbsG: _targetMacros?.carbsG,
        targetFatG: _targetMacros?.fatG,
      ),
    );
    final habitRepo = ref.read(habitRepoProvider);

    final currentHabits = habitRepo.getHabits();
    for (final habit in currentHabits) {
      if (!_selectedHabitIds.contains(habit.id)) {
        await habitRepo.deleteHabit(habit.id);
      }
    }

    final selected = Habit.defaults
        .where((h) => _selectedHabitIds.contains(h.id))
        .toList();
    for (final habit in selected) {
      await habitRepo.saveHabit(habit);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showCompletion) {
      return CompletionScreen(
        name: _nameController.text.trim(),
        onComplete: _completeRoute,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1513),
      body: Stack(
        children: [
          SthiraAuraBackground(currentPage: _currentPage),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      const WelcomePage(),
                      AboutYouPage(
                        nameController: _nameController,
                        coachController: _coachNameController,
                        heightController: _heightController,
                        weightController: _weightController,
                        useKg: _useKg,
                        showErrors: _showErrors,
                        onToggleUnit: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _useKg = !_useKg;
                          });
                        },
                      ),
                      YourPlanPage(
                        initialCalories: _targetCalories,
                        heightCm: double.tryParse(_heightController.text) ?? 160.0,
                        weightKg: double.tryParse(_weightController.text) != null
                            ? (_useKg
                                ? double.parse(_weightController.text)
                                : double.parse(_weightController.text) / 2.20462)
                            : null,
                        selectedHabitIds: _selectedHabitIds,
                        isManuallyEdited: _isCaloriesManuallyEdited,
                        onCaloriesChanged: (v, manual) {
                          _targetCalories = v;
                          _isCaloriesManuallyEdited = manual;
                        },
                        onMacrosChanged: (m) => _targetMacros = m,
                        onHabitToggled: (id, selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (selected) {
                              if (!_selectedHabitIds.contains(id)) _selectedHabitIds.add(id);
                            } else {
                              if (_selectedHabitIds.length > 1) {
                                _selectedHabitIds.remove(id);
                              }
                            }
                          });
                        },
                      ),
                      const ConnectPage(),
                    ],
                  ),
                ),
                _NavButtons(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  canGoNext: _canGoNext(), // dynamic calculation based on current fields
                  onNext: _goNext,
                  onBack: _goBack,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canGoNext() {
    if (_currentPage == 1) {
      return true; // Allow attempting Next to surface validation errors
    }
    if (_currentPage == 2) {
      if (_selectedHabitIds.isEmpty) return false;
    }
    return true;
  }
}

class _NavButtons extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool canGoNext;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _NavButtons({
    required this.currentPage,
    required this.totalPages,
    required this.canGoNext,
    required this.onNext,
    required this.onBack,
  });

  bool get _isLastPage => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
      child: Column(
        children: [
          Row(
            // Progress dots
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              final active = index == currentPage;
              final completed = index < currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active || completed ? context.colors.primary : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentPage > 0)
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white.withOpacity(0.7)),
                  ),
                )
              else
                const SizedBox(width: 48), // spacer placeholder for first page
                
              GestureDetector(
                onTap: canGoNext ? onNext : null,
                child: Builder(
                  builder: (context) {
                    Widget btn = AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: canGoNext ? context.colors.primary : context.colors.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isLastPage ? 'Start my journey' : 'Next',
                        style: TextStyle(
                          fontFamily: 'General Sans',
                          color: canGoNext ? context.colors.onPrimary : Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    );
                    
                    if (!MediaQuery.disableAnimationsOf(context)) {
                      btn = btn.animate(
                        target: canGoNext ? 1 : 0, 
                        onPlay: (controller) => controller.repeat(),
                      ).shimmer(
                        duration: 2000.ms,
                        color: Colors.white.withValues(alpha: 0.15),
                      );
                    }
                    
                    return btn;
                  }
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
