import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'widgets/activity_heatmap.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class YearlyActivityScreen extends ConsumerWidget {
  const YearlyActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Yearly Activity',
          style: context.text.screenTitle.copyWith(
            color: context.colors.textDark,
          ),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screen,
            vertical: Spacing.section,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Display the heatmap
              const Expanded(child: ActivityHeatmap()),

              const SizedBox(height: Spacing.major),

              Container(
                padding: const EdgeInsets.all(Spacing.cardPad),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        color: context.colors.primary,
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Consistency is key. Track habits, workouts, and nutrition to brighten your heatmap. Unrecorded days are lightly shaded, while missed goals are outlined.',
                          style: context.text.body.copyWith(
                            color: context.colors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
