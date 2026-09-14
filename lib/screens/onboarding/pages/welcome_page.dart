import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _staggerController.value = 1.0;
    } else if (!_staggerController.isAnimating && _staggerController.value == 0) {
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _showGitaSheet(BuildContext context) {
    showAppBottomSheet(
      context: context,
      builder: (ctx) => AppSheet(
        scrollable: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '2:47',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cabinet Grotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'కర్మణ్యేవాధికారస్తే మా ఫలేషు కదాచన ।\nమా కర్మఫలహేతుర్భూర్మా తే సఙ్గోయస్త్వకర్మణి ॥',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  fontSize: 15,
                  height: 1.5,
                  color: context.colors.textMedium,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "\"Krishna does not ask Arjuna to chase results - He asks him to master his focus. You can't control outcomes, but you can control the integrity of your effort. Do your karma, then let go.\"",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 22,
                    color: context.colors.textDark.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // Logo Entrance
          AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              final scale = CurvedAnimation(
                parent: _staggerController,
                curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
              ).value;
              final fade = CurvedAnimation(
                parent: _staggerController,
                curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
              ).value;
              Widget logo = ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.asset(
                  'assets/icon/logo.jpeg',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              );
              if (!MediaQuery.disableAnimationsOf(context)) {
                logo = logo.animate(onPlay: (controller) => controller.repeat()).shimmer(
                  duration: 4.seconds,
                  color: Colors.white.withValues(alpha: 0.1),
                );
              }
              return Opacity(
                opacity: fade,
                child: Transform.scale(
                  scale: scale,
                  child: logo,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Title
          AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              final fade = CurvedAnimation(
                parent: _staggerController,
                curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
              ).value;
              return Opacity(
                opacity: fade,
                child: Column(
                  children: [
                    Text(
                      'Sthira',
                      style: TextStyle(
                        fontFamily: 'Cabinet Grotesk',
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
                            fontFamily: 'General Sans',
                            fontSize: 20,
                            color: const Color(0xFFE29B65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          'steady, every day',
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          
          // Pillars
          _buildAnimPill(
            delayIdx: 0,
            icon: Icons.offline_bolt_rounded,
            title: 'Local-first',
            subtitle: 'Everything works perfectly offline.',
          ),
          _buildAnimPill(
            delayIdx: 1,
            icon: Icons.camera_alt_rounded,
            title: 'AI Food Scanning',
            subtitle: 'A photo becomes macro data.',
          ),
          _buildAnimPill(
            delayIdx: 2,
            icon: Icons.security_rounded,
            title: 'Your data, yours',
            subtitle: 'Export or encrypted backup anytime.',
          ),

          const Spacer(),
          
          // 2:47 Easter Egg
          AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              final fade = CurvedAnimation(
                parent: _staggerController,
                curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
              ).value;
              return Opacity(
                opacity: fade,
                child: GestureDetector(
                  onTap: () => _showGitaSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '2:47',
                      style: TextStyle(
                        fontFamily: 'Cabinet Grotesk',
                        fontSize: 16,
                        color: const Color(0xFFE29B65).withOpacity(0.8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          // Dedication
          AnimatedBuilder(
            animation: _staggerController,
            builder: (context, child) {
              final fade = CurvedAnimation(
                parent: _staggerController,
                curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
              ).value;
              return Opacity(
                opacity: fade,
                child: const _DedicationLine(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAnimPill({
    required int delayIdx,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final start = 0.4 + (delayIdx * 0.1);
    final end = start + 0.3;
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final slide = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ).value;
        final fade = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end - 0.1, curve: Curves.easeIn),
        ).value;
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - slide)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Builder(
                builder: (context) {
                  Widget card = SurfaceCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: context.colors.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'General Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontFamily: 'General Sans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  if (!MediaQuery.disableAnimationsOf(context)) {
                    card = card.animate(
                      delay: (start * 1000 + 1000).ms, 
                      onPlay: (controller) => controller.repeat(reverse: false),
                    ).shimmer(
                      duration: 3.seconds,
                      color: Colors.white.withValues(alpha: 0.05),
                    );
                  }
                  return card;
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DedicationLine extends StatelessWidget {
  const _DedicationLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Made with ',
          style: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 12,
            color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        Icon(
          Icons.favorite_rounded,
          color: context.colors.primary.withOpacity(0.8),
          size: 11,
        ),
        Text(
          ' for Bodamma',
          style: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 12,
            color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class CompletionScreen extends StatefulWidget {
  final String name;
  final VoidCallback onComplete;

  const CompletionScreen({super.key, required this.name, required this.onComplete});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  bool _sequenceStarted = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sequenceStarted) {
      _sequenceStarted = true;
      _playSequence(MediaQuery.disableAnimationsOf(context));
    }
  }

  Future<void> _playSequence(bool disableAnim) async {
    if (disableAnim) {
      _fadeController.value = 1.0;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      widget.onComplete();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _fadeController.forward();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1513),
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: CurvedAnimation(
                    parent: _fadeController,
                    curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
                  ).value,
                  child: Text(
                    widget.name.isEmpty
                        ? 'Your journey starts now.'
                        : 'Your journey starts now,\n${widget.name}.',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cabinet Grotesk',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Opacity(
                  opacity: CurvedAnimation(
                    parent: _fadeController,
                    curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
                  ).value,
                  child: const _DedicationLine(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
