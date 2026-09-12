import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/primary_button.dart';
import '../../../providers/app_providers.dart';

class AIMealSuggestionCard extends ConsumerStatefulWidget {
  final int remainingCalories;
  final double remainingProtein;
  final double remainingCarbs;
  final double remainingFat;
  final String? mealName;
  final int mealsLeft;

  const AIMealSuggestionCard({
    super.key,
    required this.remainingCalories,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFat,
    this.mealName,
    this.mealsLeft = 1,
  });

  @override
  ConsumerState<AIMealSuggestionCard> createState() =>
      _AIMealSuggestionCardState();
}

class _AIMealSuggestionCardState extends ConsumerState<AIMealSuggestionCard> {
  bool _isLoading = false;
  bool _isStreaming = false;
  String? _suggestionText;
  String? _error;

  @override
  void didUpdateWidget(AIMealSuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remainingCalories != widget.remainingCalories ||
        oldWidget.remainingProtein != widget.remainingProtein ||
        oldWidget.remainingCarbs != widget.remainingCarbs ||
        oldWidget.remainingFat != widget.remainingFat ||
        oldWidget.mealName != widget.mealName) {
      if (_suggestionText != null || _error != null || _isLoading || _isStreaming) {
        setState(() {
          _suggestionText = null;
          _error = null;
          _isLoading = false;
          _isStreaming = false;
        });
      }
    }
  }

  Future<void> _fetchSuggestion() async {
    setState(() {
      _isLoading = true;
      _isStreaming = false;
      _error = null;
      _suggestionText = null;
    });

    try {
      final service = ref.read(geminiFoodServiceProvider);

      final dateStr = ref.read(dateStringProvider);
      final mealRepo = ref.read(mealRepoProvider);
      final todayLogs = mealRepo.getLogsInRange(dateStr, dateStr);
      final previousMeals = todayLogs
          .expand((l) => l.customSlots.values)
          .expand((slot) => slot.items)
          .map((i) => i.name ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final stream = service.suggestMealStream(
        remainingCalories: widget.remainingCalories,
        remainingProtein: widget.remainingProtein,
        remainingCarbs: widget.remainingCarbs,
        remainingFat: widget.remainingFat,
        mealName: widget.mealName,
        mealsLeft: widget.mealsLeft,
        previousMeals: previousMeals,
      );

      bool isFirstChunk = true;
      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            if (isFirstChunk) {
              _isLoading = false;
              _isStreaming = true;
              _suggestionText = '';
              isFirstChunk = false;
            }
            _suggestionText = (_suggestionText ?? '') + chunk;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isStreaming = false;
        });
      }

      if (isFirstChunk && mounted) {
        // Stream completed without yielding anything
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          _error = 'Failed to generate a suggestion. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isStreaming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dateStringProvider, (previous, next) {
      if (previous != next && mounted) {
        setState(() {
          _suggestionText = null;
          _error = null;
          _isLoading = false;
          _isStreaming = false;
        });
      }
    });

    if (widget.remainingCalories <= 0) {
      return SurfaceCard(
        elevation: SurfaceCardElevation.nested,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: context.colors.green,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Calorie Goal Reached!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You hit your target for today. Great job!',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SurfaceCard(
      elevation: SurfaceCardElevation.nested,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: context.colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart Meal Suggestion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: MediaQuery.disableAnimationsOf(context) ? (c) => c.stop() : (c) => c.repeat()).shimmer(
                    duration: MediaQuery.disableAnimationsOf(context) ? 0.ms : 1200.ms,
                    color: context.colors.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: MediaQuery.disableAnimationsOf(context) ? (c) => c.stop() : (c) => c.repeat()).shimmer(
                    duration: MediaQuery.disableAnimationsOf(context) ? 0.ms : 1200.ms,
                    color: context.colors.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: MediaQuery.of(context).size.width * 0.4,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: MediaQuery.disableAnimationsOf(context) ? (c) => c.stop() : (c) => c.repeat()).shimmer(
                    duration: MediaQuery.disableAnimationsOf(context) ? 0.ms : 1200.ms,
                    color: context.colors.primary.withValues(alpha: 0.4),
                  ),
                ],
              )
            else if (_suggestionText != null) ...[
              Wrap(
                children: [
                   Text(
                    _suggestionText!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textDark,
                      height: 1.4,
                    ),
                  ),
                  if (_isStreaming)
                    Text(
                      '▍',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.colors.primary,
                        height: 1.4,
                      ),
                    ).animate(onPlay: (c) => c.repeat()).fade(duration: 400.ms),
                ]
              ),
              const SizedBox(height: 16),
              if (!_isStreaming)
                CompactButton(
                  label: 'Suggest something else',
                  icon: Icons.refresh_rounded,
                  filled: false,
                  onPressed: _fetchSuggestion,
                ),
            ] else ...[
              Text(
                'Need ideas for your next meal? I can suggest a dish that perfectly fits your remaining macros (${widget.remainingCalories} kcal left).',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                  height: 1.4,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: context.colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: _fetchSuggestion,
                label: 'Suggest a Meal',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
