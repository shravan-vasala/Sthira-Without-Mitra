import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/habit.dart';
import '../../utils/habit_icons.dart';
import 'widgets/sthira_aura_background.dart';

String kOnboardingCompletedKey = 'onboarding_completed';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  final _nameController = TextEditingController();
  final _coachNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _useKg = true;

  double _targetCalories = 1397;
  final List<String> _selectedHabitIds = ['sleep', 'walk', 'water'];

  bool _hcConnecting = false;
  bool _hcConnected = false;
  String _hcStatus = '';

  final _geminiKeyController = TextEditingController();
  bool _geminiKeySaved = false;
  bool _geminiKeyVerifying = false;
  String _geminiKeyError = '';
  bool _obscureKey = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _coachNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_currentPage < _totalPages - 1) {
      if (_currentPage == 1) {
        if (!_saveProfile()) return;
      }
      if (_currentPage == 2) {
        _saveGoals();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _saveGeminiKey();
      _complete();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _saveProfile() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your name'),
          backgroundColor: context.colors.red,
        ),
      );
      return false;
    }
    final height = double.tryParse(_heightController.text) ?? 160.0;
    final weight = double.tryParse(_weightController.text);
    final current = ref.read(profileProvider);
    ref.read(profileProvider.notifier).updateProfile(
          current.copyWith(
            name: name,
            coachName: _coachNameController.text.trim(),
            height: height,
            targetWeight: weight,
            useKg: _useKg,
          ),
        );
    return true;
  }

  void _saveGoals() {
    final current = ref.read(profileProvider);
    ref.read(profileProvider.notifier).updateProfile(
          current.copyWith(targetCalories: _targetCalories.round()),
        );
    final habitRepo = ref.read(habitRepoProvider);
    
    final currentHabits = habitRepo.getHabits();
    for (final habit in currentHabits) {
      if (!_selectedHabitIds.contains(habit.id)) {
        habitRepo.deleteHabit(habit.id);
      }
    }

    final selected = Habit.defaults
        .where((h) => _selectedHabitIds.contains(h.id))
        .toList();
    for (final habit in selected) {
      habitRepo.saveHabit(habit);
    }
  }

  Future<void> _connectHealthConnect() async {
    setState(() {
      _hcConnecting = true;
      _hcStatus = '';
    });
    try {
      final hcService = ref.read(healthConnectServiceProvider);
      final granted = await hcService.requestPermission();
      setState(() {
        _hcConnected = granted;
        _hcStatus = granted
            ? 'Connected! Data will sync automatically.'
            : 'Permission denied.';
      });
    } catch (e) {
      setState(() {
        _hcStatus = 'Health Connect not available.';
      });
    } finally {
      setState(() => _hcConnecting = false);
    }
  }

  Future<void> _saveGeminiKey() async {
    final key = _geminiKeyController.text.trim();
    if (key.isNotEmpty) {
      setState(() {
        _geminiKeyVerifying = true;
        _geminiKeyError = '';
      });
      try {
        await ref.read(geminiFoodServiceProvider).verifyApiKey(key);
      } catch (e) {
        if (mounted) {
          setState(() {
            _geminiKeyVerifying = false;
            _geminiKeyError = e.toString().replaceAll('Exception: ', '');
          });
        }
        return; 
      }
      await ref.read(profileProvider.notifier).updateGeminiKey(key);
      setState(() {
        _geminiKeySaved = true;
        _geminiKeyVerifying = false;
      });
    }
  }

  Future<void> _complete() async {
    await ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E1D2F),
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
                      _WelcomePage(),
                      _ProfilePage(
                        nameController: _nameController,
                        coachNameController: _coachNameController,
                        heightController: _heightController,
                        weightController: _weightController,
                        useKg: _useKg,
                        onToggleUnit: () => setState(() => _useKg = !_useKg),
                      ),
                      _GoalsPage(
                        targetCalories: _targetCalories,
                        selectedHabitIds: _selectedHabitIds,
                        onCaloriesChanged: (v) =>
                            setState(() => _targetCalories = v),
                        onHabitToggled: (id, selected) {
                          setState(() {
                            if (selected) {
                              _selectedHabitIds.add(id);
                            } else {
                              _selectedHabitIds.remove(id);
                            }
                          });
                        },
                      ),
                      _HealthConnectPage(
                        connecting: _hcConnecting,
                        connected: _hcConnected,
                        status: _hcStatus,
                        onConnect: _connectHealthConnect,
                      ),
                      _AiSetupPage(
                        controller: _geminiKeyController,
                        keySaved: _geminiKeySaved,
                        isVerifying: _geminiKeyVerifying,
                        errorMessage: _geminiKeyError,
                        obscure: _obscureKey,
                        onToggleObscure: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        onSaveKey: _saveGeminiKey,
                      ),
                      _CloudSyncPage(),
                    ],
                  ),
                ),
                _NavButtons(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onNext: _goNext,
                  onSkip: _goNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _NavButtons({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onSkip,
  });

  bool get _isLastPage => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isLastPage)
            GestureDetector(
              onTap: onNext,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A163),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    color: Color(0xFF2E1D2F),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onNext,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A163),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF2E1D2F),
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatefulWidget {
  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> {
  bool _showSloka = false;

  @override
  Widget build(BuildContext context) {
    final fontFamily = Theme.of(context).textTheme.headlineLarge?.fontFamily;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: Image.asset(
              'assets/icon/app_icon.jpg',
              width: 140,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Sthira',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'स्थिर',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 22,
                  color: const Color(0xFFE8A163),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '•',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'steady, every day',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 64),
          GestureDetector(
            onTap: () => setState(() => _showSloka = !_showSloka),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  'Bhagavad Gita 2:47',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 16,
                    color: const Color(0xFFE8A163),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showSloka
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'కర్మణ్యేవాధికారస్తే మా ఫలేషు కదాచన ।\nమా కర్మఫలహేతుర్భూర్మా తే సఙ్గోయస్త్వకర్మణి ॥',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 14,
                              height: 1.8,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made with ',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.favorite_rounded, color: Color(0xFFE8A163), size: 14),
              Text(
                ' for Bodamma',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController coachNameController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final bool useKg;
  final VoidCallback onToggleUnit;

  const _ProfilePage({
    required this.nameController,
    required this.coachNameController,
    required this.heightController,
    required this.weightController,
    required this.useKg,
    required this.onToggleUnit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.person_outline_rounded, size: 48, color: Color(0xFFE8A163)),
          const SizedBox(height: 24),
          const Text(
            'Who is\nthis?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 64),
          _MinimalInputField(
            controller: nameController,
            hint: 'Eg. Bodamma',
            capitalization: TextCapitalization.words,
            centerText: true,
          ),
          const SizedBox(height: 32),
          _MinimalInputField(
            controller: coachNameController,
            hint: 'Eg. Shravan (Coach)',
            capitalization: TextCapitalization.words,
            centerText: true,
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: _MinimalInputField(
                  controller: heightController,
                  hint: '175 cm',
                  keyboardType: TextInputType.number,
                  centerText: true,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _MinimalInputField(
                  controller: weightController,
                  hint: useKg ? '70 kg' : '154 lb',
                  keyboardType: TextInputType.number,
                  centerText: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onToggleUnit,
            child: Text(
              'Switch to ${useKg ? 'Pounds' : 'Kilograms'}',
              style: const TextStyle(
                color: Color(0xFF8FB896),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MinimalInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final bool centerText;

  const _MinimalInputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.centerText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textAlign: centerText ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE8A163), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _GoalsPage extends StatelessWidget {
  final double targetCalories;
  final List<String> selectedHabitIds;
  final ValueChanged<double> onCaloriesChanged;
  final void Function(String id, bool selected) onHabitToggled;

  const _GoalsPage({
    required this.targetCalories,
    required this.selectedHabitIds,
    required this.onCaloriesChanged,
    required this.onHabitToggled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.track_changes_outlined, size: 48, color: Color(0xFF8FB896)),
          const SizedBox(height: 24),
          const Text(
            'Daily\nGoals',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 64),
          Text(
            '${targetCalories.round()} kcal',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8A163),
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFE8A163),
              thumbColor: const Color(0xFFE8A163),
              inactiveTrackColor: Colors.white.withOpacity(0.2),
              trackHeight: 2,
            ),
            child: Slider(
              value: targetCalories,
              min: 1200,
              max: 2500,
              divisions: 130,
              onChanged: onCaloriesChanged,
            ),
          ),
          const SizedBox(height: 48),
          ...Habit.defaults.map((habit) {
            final selected = selectedHabitIds.contains(habit.id);
            return GestureDetector(
              onTap: () => onHabitToggled(habit.id, !selected),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? const Color(0xFF8FB896) : Colors.white.withOpacity(0.2),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      HabitIcons.resolve(habit.icon),
                      size: 24,
                      color: selected ? const Color(0xFF8FB896) : Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HealthConnectPage extends StatelessWidget {
  final bool connecting;
  final bool connected;
  final String status;
  final VoidCallback onConnect;

  const _HealthConnectPage({
    required this.connecting,
    required this.connected,
    required this.status,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border_rounded, size: 64, color: Color(0xFF8FB896)),
          const SizedBox(height: 32),
          const Text(
            'Sync Health\nData',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Automatically sync steps and sleep from Health Connect.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 64),
          if (connecting)
            const CircularProgressIndicator(color: Color(0xFF8FB896))
          else if (connected)
            const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF8FB896))
          else
            GestureDetector(
              onTap: onConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8FB896), width: 2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Text(
                  'Connect Now',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8FB896),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE8A163), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AiSetupPage extends StatelessWidget {
  final TextEditingController controller;
  final bool keySaved;
  final bool isVerifying;
  final String errorMessage;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSaveKey;

  const _AiSetupPage({
    required this.controller,
    required this.keySaved,
    required this.isVerifying,
    required this.errorMessage,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSaveKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 64, color: Color(0xFFE8A163)),
          const SizedBox(height: 32),
          const Text(
            'Smart\nLogging',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Provide a Gemini API key to enable AI-powered photo food logging.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 64),
          if (keySaved)
            const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF8FB896))
          else
            Column(
              children: [
                _MinimalInputField(
                  controller: controller,
                  hint: 'Paste API Key',
                  centerText: true,
                ),
                const SizedBox(height: 32),
                if (isVerifying)
                  const CircularProgressIndicator(color: Color(0xFFE8A163))
                else
                  GestureDetector(
                    onTap: onSaveKey,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8A163),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Text(
                        'Verify Key',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E1D2F),
                        ),
                      ),
                    ),
                  ),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CloudSyncPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<_CloudSyncPage> {
  bool _isSyncing = false;
  String _syncStatus = '';

  Future<void> _handleSignIn() async {
    setState(() { _isSyncing = true; _syncStatus = 'Signing in...'; });
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null && mounted) {
        setState(() { _syncStatus = 'Syncing data...'; });
        final syncService = ref.read(firestoreSyncServiceProvider);
        
        final hasCloudData = await syncService.hasCloudData();
        if (hasCloudData) {
          final profile = await syncService.pullProfile();
          await ref.read(profileRepoProvider).importProfileFromCloud(profile);
          final dailyLogs = await syncService.pullCollection('daily_logs');
          await ref.read(dailyLogRepoProvider).importFromCloud(dailyLogs);
          final mealLogs = await syncService.pullCollection('meal_logs');
          await ref.read(mealRepoProvider).importLogsFromCloud(mealLogs);
          final stats = await syncService.pullCollection('body_stats');
          await ref.read(bodyStatsRepoProvider).importStatsFromCloud(stats);
          
          final workoutPlans = await syncService.pullCollection('workout_plans');
          await ref.read(workoutRepoProvider).importPlansFromCloud(workoutPlans);
          
          final mealPlans = await syncService.pullCollection('meal_plans');
          await ref.read(mealRepoProvider).importPlansFromCloud(mealPlans);
          
          ref.invalidate(profileProvider);
          ref.invalidate(dailyLogProvider);
          ref.invalidate(dailyMealLogProvider);
          ref.invalidate(latestBodyStatsProvider);
        } else {
          syncService.syncProfile(ref.read(profileRepoProvider).exportProfileForCloud());
          await syncService.bulkSync('habit_config', ref.read(habitRepoProvider).exportConfigForCloud());
          await syncService.bulkSync('workout_plans', ref.read(workoutRepoProvider).exportPlansForCloud());
          await syncService.bulkSync('meal_plans', ref.read(mealRepoProvider).exportPlansForCloud());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully signed in & synced!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isSyncing = false; _syncStatus = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final userEmail = ref.watch(userEmailProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_outlined, size: 64, color: Color(0xFF8FB896)),
          const SizedBox(height: 32),
          const Text(
            'Cloud Sync',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Keep your data safe across devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 64),
          if (_isSyncing)
            Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF8FB896)),
                const SizedBox(height: 16),
                Text(_syncStatus, style: const TextStyle(color: Color(0xFF8FB896), fontWeight: FontWeight.bold)),
              ],
            )
          else if (!isSignedIn)
            GestureDetector(
              onTap: _handleSignIn,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8FB896), width: 2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8FB896),
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF8FB896)),
                const SizedBox(height: 12),
                Text(userEmail ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              ],
            ),
          const SizedBox(height: 64),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made with ',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              const Icon(Icons.favorite, color: Colors.white54, size: 12),
              Text(
                ' bodamma',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          )
        ],
      ),
    );
  }
}
