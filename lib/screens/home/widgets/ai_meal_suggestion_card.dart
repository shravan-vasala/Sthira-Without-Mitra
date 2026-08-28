import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/primary_button.dart';
import '../../../services/gemini_food_service.dart';
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
  ConsumerState<AIMealSuggestionCard> createState() => _AIMealSuggestionCardState();
}

class _AIMealSuggestionCardState extends ConsumerState<AIMealSuggestionCard> {
  bool _isLoading = false;
  String? _suggestionText;
  String? _error;

  Future<void> _fetchSuggestion() async {
    setState(() {
      _isLoading = true;
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

      
      setState(() {
        _suggestionText = '';
        _isLoading = false;
      });

      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            _suggestionText = (_suggestionText ?? '') + chunk;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.remainingCalories <= 0) {
      return SurfaceCard(
        elevation: SurfaceCardElevation.nested,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(Icons.check_circle_rounded, color: context.colors.green, size: 40),
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
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: context.colors.primary, size: 20),
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_suggestionText != null) ...[
              Text(
                _suggestionText!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textDark,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _fetchSuggestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    side: BorderSide(color: context.colors.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Suggest Something Else'),
                ),
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
