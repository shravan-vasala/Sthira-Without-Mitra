import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  double proteinPercent = 25.0;
  double carbsPercent = 25.0;
  double vegPercent = 50.0;
  double fatPercent = 0.0; // Added fat/oils optionally

  // Generic macros total for a standard 500g meal
  final double baseWeightGrams = 500.0;

  Map<String, double> get _calculatedMacros {
    // Very rough estimations for educational purposes
    // protein is usually 25g per 100g of protein source
    // carbs are usually 30g per 100g of carb source
    // veg is usually 5g carbs per 100g
    // fat is directly 1g fat per 1g

    final proteinWeight = (proteinPercent / 100) * baseWeightGrams;
    final carbsWeight = (carbsPercent / 100) * baseWeightGrams;
    final vegWeight = (vegPercent / 100) * baseWeightGrams;
    final fatWeight = (fatPercent / 100) * baseWeightGrams;

    final proteinG = (proteinWeight * 0.25) + (vegWeight * 0.02);
    final carbsG = (carbsWeight * 0.30) + (vegWeight * 0.05);
    final fatG =
        (proteinWeight * 0.10) +
        (carbsWeight * 0.05) +
        fatWeight; // some incidental fats

    final calories = (proteinG * 4) + (carbsG * 4) + (fatG * 9);

    return {
      'protein': proteinG,
      'carbs': carbsG,
      'fat': fatG,
      'calories': calories,
    };
  }

  @override
  Widget build(BuildContext context) {
    final macros = _calculatedMacros;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 20,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Visual Plate Calculator',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust the sliders to roughly estimate a standard 500g meal based on plate proportions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.colors.textMedium),
          ),
          const SizedBox(height: 24),

          _buildSlider(
            title: 'Protein (Meat, Eggs, Dal)',
            color: context.colors.primary,
            value: proteinPercent,
            onChanged: (v) {
              setState(() {
                proteinPercent = v;
                _balance(protein: true);
              });
            },
          ),
          _buildSlider(
            title: 'Carbs (Rice, Roti, Potato)',
            color: context.colors.orange,
            value: carbsPercent,
            onChanged: (v) {
              setState(() {
                carbsPercent = v;
                _balance(carbs: true);
              });
            },
          ),
          _buildSlider(
            title: 'Veggies & Greens',
            color: context.colors.green,
            value: vegPercent,
            onChanged: (v) {
              setState(() {
                vegPercent = v;
                _balance(veg: true);
              });
            },
          ),
          _buildSlider(
            title: 'Added Fats & Oils',
            color: context.colors.red,
            value: fatPercent,
            onChanged: (v) {
              setState(() {
                fatPercent = v;
                _balance(fat: true);
              });
            },
          ),

          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.scaffoldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroItem('Calories', "${macros['calories']!.toInt()}"),
                _macroItem(
                  'Protein',
                  "${macros['protein']!.toStringAsFixed(1)}g",
                ),
                _macroItem('Carbs', "${macros['carbs']!.toStringAsFixed(1)}g"),
                _macroItem('Fat', "${macros['fat']!.toStringAsFixed(1)}g"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _balance({
    bool protein = false,
    bool carbs = false,
    bool veg = false,
    bool fat = false,
  }) {
    final double total =
        proteinPercent + carbsPercent + vegPercent + fatPercent;
    if (total == 100.0) return;

    final double diff = 100.0 - total;

    // Distribute diff to others
    final int othersCount =
        (protein ? 0 : 1) + (carbs ? 0 : 1) + (veg ? 0 : 1) + (fat ? 0 : 1);
    final double addPerOther = diff / othersCount;

    if (!protein) proteinPercent = (proteinPercent + addPerOther).clamp(0, 100);
    if (!carbs) carbsPercent = (carbsPercent + addPerOther).clamp(0, 100);
    if (!veg) vegPercent = (vegPercent + addPerOther).clamp(0, 100);
    if (!fat) fatPercent = (fatPercent + addPerOther).clamp(0, 100);
  }

  Widget _buildSlider({
    required String title,
    required Color color,
    required double value,
    required Function(double) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDark,
                ),
              ),
              Text(
                '${value.toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color.withValues(alpha: 0.8),
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: context.colors.textLight),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.textDark,
          ),
        ),
      ],
    );
  }
}
