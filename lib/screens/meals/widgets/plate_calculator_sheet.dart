import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bottom_sheet.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

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
    return AppSheet(
      title: 'Visual Plate Calculator',
      subtitle:
          'Values are rough educational examples for a standard 500g plate. For accurate meal tracking and precise nutrition, please log your actual food.',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            title: 'Added Fats & Oils (Highly Caloric)',
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
              // Sthira: No borders!
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroItem(
                  'Calories',
                  "${macros['calories']!.toInt()}",
                  isGiant: true,
                ),
                _macroItem('Protein', "${macros['protein']!.toInt()}g"),
                _macroItem('Carbs', "${macros['carbs']!.toInt()}g"),
                _macroItem('Fat', "${macros['fat']!.toInt()}g"),
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
    for (int i = 0; i < 5; i++) {
      final double total =
          proteinPercent + carbsPercent + vegPercent + fatPercent;
      final double diff = 100.0 - total;

      if (diff.abs() < 0.1) break;

      int absorbCount = 0;
      if (!protein && (diff > 0 ? proteinPercent < 100 : proteinPercent > 0))
        absorbCount++;
      if (!carbs && (diff > 0 ? carbsPercent < 100 : carbsPercent > 0))
        absorbCount++;
      if (!veg && (diff > 0 ? vegPercent < 100 : vegPercent > 0)) absorbCount++;
      if (!fat && (diff > 0 ? fatPercent < 100 : fatPercent > 0)) absorbCount++;

      if (absorbCount == 0) {
        // If no other slider can absorb the diff, force the active slider to give up its value
        if (protein) proteinPercent = (proteinPercent + diff).clamp(0, 100);
        if (carbs) carbsPercent = (carbsPercent + diff).clamp(0, 100);
        if (veg) vegPercent = (vegPercent + diff).clamp(0, 100);
        if (fat) fatPercent = (fatPercent + diff).clamp(0, 100);
        break;
      }

      final double addPerOther = diff / absorbCount;
      if (!protein && (diff > 0 ? proteinPercent < 100 : proteinPercent > 0)) {
        proteinPercent = (proteinPercent + addPerOther).clamp(0, 100);
      }
      if (!carbs && (diff > 0 ? carbsPercent < 100 : carbsPercent > 0)) {
        carbsPercent = (carbsPercent + addPerOther).clamp(0, 100);
      }
      if (!veg && (diff > 0 ? vegPercent < 100 : vegPercent > 0)) {
        vegPercent = (vegPercent + addPerOther).clamp(0, 100);
      }
      if (!fat && (diff > 0 ? fatPercent < 100 : fatPercent > 0)) {
        fatPercent = (fatPercent + addPerOther).clamp(0, 100);
      }
    }
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
                style: context.text.body.copyWith(
                  color: context.colors.textDark,
                ),
              ),
              Text(
                '${value.toInt()}%',
                style: context.text.body.copyWith(color: color),
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

  Widget _macroItem(String title, String value, {bool isGiant = false}) {
    return Column(
      children: [
        Text(
          title,
          style: context.text.micro.copyWith(color: context.colors.textLight),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (isGiant)
              Text(
                '~',
                style: AppTheme.numeric(
                  context.text.screenTitle.copyWith(
                    color: context.colors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            Text(
              value,
              style: AppTheme.numeric(
                context.text.body.copyWith(
                  color: isGiant
                      ? context.colors.primary
                      : context.colors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Example',
          style: context.text.micro.copyWith(color: context.colors.textMedium),
        ),
      ],
    );
  }
}
