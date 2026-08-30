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
    final year = ref.watch(selectedYearProvider);
    final heatmapAsync = ref.watch(yearlyActivityHeatmapProvider(year));
    
    return heatmapAsync.when(
      data: (heatmapData) {
        final startDate = DateTime(year, 1, 1);
        final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        final daysInYear = isLeapYear ? 366 : 365;
        
        // DateTime.weekday is 1 (Monday) to 7 (Sunday). Let's make Monday = 0, Sunday = 6.
        final startWeekday = startDate.weekday - 1; 
        
        final totalCells = daysInYear + startWeekday;
        final totalColumns = (totalCells / 7).ceil();
        
        int lastMonth = -1;
        
        // Calculate some basic stats
        int activeDays = 0;
        int currentStreak = 0;
        int maxStreak = 0;
        
        for (int i = 0; i < daysInYear; i++) {
          final date = startDate.add(Duration(days: i));
          if ((heatmapData[date] ?? 0) > 0) {
            activeDays++;
            currentStreak++;
            if (currentStreak > maxStreak) {
              maxStreak = currentStreak;
            }
          } else {
            currentStreak = 0;
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
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded, color: context.colors.textDark),
                        onPressed: () => ref.read(selectedYearProvider.notifier).state--,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        year.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded, color: year < DateTime.now().year ? context.colors.textDark : context.colors.textLight),
                        onPressed: year < DateTime.now().year 
                            ? () => ref.read(selectedYearProvider.notifier).state++ 
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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
              // Scrollable Horizontal Heatmap
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Height is distributed among 7 rows + 1 row for month labels
                    // Available height for the 7 rows = maxHeight - 20 (for months)
                    final availableHeight = constraints.maxHeight - 20;
                    // Divide by 7, subtract 2 for margins (1px each side)
                    final double calculatedCellSize = (availableHeight / 7) - 2;
                    // Clamp the size to avoid it being ridiculously large or too small
                    final double cellSize = calculatedCellSize.clamp(12.0, 40.0);
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left labels for days of week
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20), // Spacer for month row
                            ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) => 
                              Container(
                                height: cellSize + 2, // Include margin to align with cells
                                alignment: Alignment.center,
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  day, 
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.textMedium
                                  ),
                                ),
                              )
                            ),
                          ],
                        ),
                        // Horizontal scrollable heatmap
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(totalColumns, (colIndex) {
                                // Check if a new month starts in this column
                                String monthLabel = '';
                                for (int rowIndex = 0; rowIndex < 7; rowIndex++) {
                                  final cellIndex = colIndex * 7 + rowIndex;
                                  final dayOffset = cellIndex - startWeekday;
                                  if (dayOffset >= 0 && dayOffset < 365) {
                                    final currentDate = startDate.add(Duration(days: dayOffset));
                                    if (currentDate.month != lastMonth) {
                                      monthLabel = DateFormat('MMM').format(currentDate);
                                      lastMonth = currentDate.month;
                                      break; // found the first month boundary in this column
                                    }
                                  }
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Month Label
                                    Container(
                                      height: 20,
                                      width: cellSize + 2, // Match column width
                                      alignment: Alignment.bottomLeft,
                                      // Ensure the text doesn't get clipped or force column width expansion
                                      child: monthLabel.isNotEmpty 
                                        ? OverflowBox(
                                            maxWidth: double.infinity,
                                            alignment: Alignment.bottomLeft,
                                            child: Text(
                                              monthLabel,
                                              style: TextStyle(
                                                fontSize: 10, 
                                                fontWeight: FontWeight.w600,
                                                color: context.colors.textLight
                                              ),
                                            ),
                                          ) 
                                        : null,
                                    ),
                                    
                                    // Column of 7 days
                                    ...List.generate(7, (rowIndex) {
                                      final cellIndex = colIndex * 7 + rowIndex;
                                      final dayOffset = cellIndex - startWeekday;
                                      
                                      if (dayOffset < 0 || dayOffset >= daysInYear) {
                                        return Container(
                                          width: cellSize,
                                          height: cellSize,
                                          margin: const EdgeInsets.all(1),
                                        );
                                      }
                                      
                                      final currentDate = startDate.add(Duration(days: dayOffset));
                                      final score = heatmapData[currentDate] ?? 0;
                                      final dateStr = DateFormat('MMM dd, yyyy').format(currentDate);
                                      
                                      return Tooltip(
                                        message: '$dateStr\nScore: $score',
                                        child: Container(
                                          width: cellSize,
                                          height: cellSize,
                                          margin: const EdgeInsets.all(1),
                                          decoration: BoxDecoration(
                                            color: _getColorForScore(context, score),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(context, 'Active Days', '$activeDays'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(context, 'Longest Streak', '$maxStreak'),
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

  Widget _buildStatCard(BuildContext context, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

