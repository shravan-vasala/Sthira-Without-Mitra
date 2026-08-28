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
              // Day Headers (Fixed at top)
              Row(
                children: [
                  const SizedBox(width: 40), // Space for month labels
                  ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) => 
                    Container(
                      width: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      alignment: Alignment.center,
                      child: Text(
                        day, 
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: context.colors.textMedium
                        ),
                      ),
                    )
                  )
                ]
              ),
              const SizedBox(height: 8),
              
              // Scrollable Vertical Heatmap
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(totalColumns, (rowIndex) {
                      // Check if a new month starts in this row
                      String monthLabel = '';
                      for (int colIndex = 0; colIndex < 7; colIndex++) {
                        final cellIndex = rowIndex * 7 + colIndex;
                        final dayOffset = cellIndex - startWeekday;
                        if (dayOffset >= 0 && dayOffset < 365) {
                          final currentDate = startDate.add(Duration(days: dayOffset));
                          if (currentDate.month != lastMonth) {
                            monthLabel = DateFormat('MMM').format(currentDate);
                            lastMonth = currentDate.month;
                            break; // found the first month boundary in this row
                          }
                        }
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Minimal Month Hinting
                          SizedBox(
                            width: 32,
                            child: monthLabel.isNotEmpty 
                              ? Text(
                                  monthLabel,
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textLight
                                  ),
                                  textAlign: TextAlign.right,
                                ) 
                              : null,
                          ),
                          const SizedBox(width: 8),
                          
                          // Grid Row (1 Week)
                          ...List.generate(7, (colIndex) {
                            final cellIndex = rowIndex * 7 + colIndex;
                            final dayOffset = cellIndex - startWeekday;
                            
                            if (dayOffset < 0 || dayOffset >= daysInYear) {
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
                              message: '$dateStr\nScore: $score',
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
                        ],
                      );
                    }),
                  ),
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

