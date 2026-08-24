import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';

class ActivityHeatmap extends ConsumerWidget {
  const ActivityHeatmap({super.key});

  Color _getColorForScore(BuildContext context, int score) {
    if (score == 0) return context.colors.inputFill;
    if (score < 25) return context.colors.primary.withValues(alpha: 0.25);
    if (score < 50) return context.colors.primary.withValues(alpha: 0.50);
    if (score < 75) return context.colors.primary.withValues(alpha: 0.75);
    return context.colors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(yearlyActivityHeatmapProvider);
    
    return heatmapAsync.when(
      data: (heatmapData) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = todayDate.subtract(const Duration(days: 364));
        
        // DateTime.weekday is 1 (Monday) to 7 (Sunday). Let's make Monday = 0, Sunday = 6.
        final startWeekday = startDate.weekday - 1; 
        
        final totalCells = 365 + startWeekday;
        final totalColumns = (totalCells / 7).ceil();
        
        // Pre-calculate month labels
        final monthLabels = <Widget>[];
        int lastMonth = -1;
        for (int col = 0; col < totalColumns; col++) {
          final dayOffset = (col * 7) - startWeekday;
          final d = startDate.add(Duration(days: dayOffset >= 0 ? dayOffset : 0));
          if (d.month != lastMonth) {
            monthLabels.add(
              Container(
                width: 14.0 * 4, // Approx 4 columns width to prevent overlap
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  DateFormat('MMM').format(d),
                  style: TextStyle(fontSize: 10, color: context.colors.textLight),
                ),
              )
            );
            lastMonth = d.month;
          } else {
            monthLabels.add(const SizedBox(width: 14));
          }
        }
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fix for bottom sheet expanding too much
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Yearly Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      Text('Less', style: TextStyle(fontSize: 10, color: context.colors.textLight)),
                      const SizedBox(width: 4),
                      _buildLegendSquare(context, 0),
                      _buildLegendSquare(context, 20),
                      _buildLegendSquare(context, 45),
                      _buildLegendSquare(context, 70),
                      _buildLegendSquare(context, 100),
                      const SizedBox(width: 4),
                      Text('More', style: TextStyle(fontSize: 10, color: context.colors.textLight)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Day Labels (Fixed on left)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 16.0), // top padding to align with grid below month labels
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 14), // Mon
                        Text('Mon', style: TextStyle(fontSize: 10, color: context.colors.textLight, height: 1.4)),
                        const SizedBox(height: 14), // Tue
                        const SizedBox(height: 14), // Wed
                        Text('Wed', style: TextStyle(fontSize: 10, color: context.colors.textLight, height: 1.4)),
                        const SizedBox(height: 14), // Thu
                        const SizedBox(height: 14), // Fri
                        Text('Fri', style: TextStyle(fontSize: 10, color: context.colors.textLight, height: 1.4)),
                        const SizedBox(height: 14), // Sat
                        const SizedBox(height: 14), // Sun
                      ],
                    ),
                  ),
                  
                  // Scrollable Heatmap
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // Scroll to the end (today) by default
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month Labels
                          Row(
                            children: monthLabels,
                          ),
                          const SizedBox(height: 4),
                          // Grid
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(totalColumns, (colIndex) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(7, (rowIndex) {
                                  final cellIndex = colIndex * 7 + rowIndex;
                                  final dayOffset = cellIndex - startWeekday;
                                  
                                  if (dayOffset < 0 || dayOffset >= 365) {
                                    return Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.all(1),
                                    );
                                  }
                                  
                                  final currentDate = startDate.add(Duration(days: dayOffset));
                                  final score = heatmapData[currentDate] ?? 0;
                                  final dateStr = DateFormat('MMM dd, yyyy').format(currentDate);
                                  
                                  return Tooltip(
                                    message: '\$dateStr\nScore: \$score',
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: _getColorForScore(context, score),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 150,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      error: (e, st) => Container(
        height: 150,
        alignment: Alignment.center,
        child: Text('Error: \$e', style: TextStyle(color: context.colors.red)),
      ),
    );
  }

  Widget _buildLegendSquare(BuildContext context, int score) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _getColorForScore(context, score),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

