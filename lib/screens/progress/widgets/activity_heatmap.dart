import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';

class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });
  }

  void _scrollToCurrentMonth() {
    final year = ref.read(selectedYearProvider);
    final now = DateTime.now();
    if (year == now.year && _scrollController.hasClients) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final cardWidth = (screenWidth - 40 - 16) / 2;
      final clampedWidth = cardWidth.clamp(160.0, 240.0);
      final offset = (now.month - 1) * (clampedWidth + 16.0);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Color _getColorForScore(BuildContext context, int score) {
    if (score == 0) return context.colors.inputFill;
    if (score < 25) return context.colors.primary.withValues(alpha: 0.25);
    if (score < 50) return context.colors.primary.withValues(alpha: 0.50);
    if (score < 75) return context.colors.primary.withValues(alpha: 0.75);
    return context.colors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(selectedYearProvider);
    final heatmapAsync = ref.watch(yearlyActivityHeatmapProvider(year));

    ref.listen(selectedYearProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentMonth();
      });
    });

    return heatmapAsync.when(
      data: (heatmapData) {
        int activeDays = 0;
        int currentStreak = 0;
        int maxStreak = 0;

        final startDate = DateTime(year, 1, 1);
        final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        final daysInYear = isLeapYear ? 366 : 365;

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
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
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: year < DateTime.now().year
                              ? context.colors.textDark
                              : context.colors.textLight,
                        ),
                        onPressed: year < DateTime.now().year
                            ? () => ref.read(selectedYearProvider.notifier).state++
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = (constraints.maxWidth - 40 - 16) / 2; // Taking outer padding and gap into account
                final double clampedWidth = cardWidth.clamp(160.0, 240.0);
                
                return SizedBox(
                  height: 215, // Reduced height for the tighter side-by-side squares
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 12,
                    separatorBuilder: (context, index) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      return _buildMonthCard(context, year, month, heatmapData, clampedWidth);
                    },
                  ),
                );
              }
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
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
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            const SizedBox(height: 20),
          ],
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
        child: Text('Error: $e', style: TextStyle(color: context.colors.red)),
      ),
    );
  }

  Widget _buildMonthCard(BuildContext context, int year, int month, Map<DateTime, int> heatmapData, double width) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    
    // We want Sunday to be 0 for standard layout
    final startWeekday = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    
    final totalCells = daysInMonth + startWeekday;
    final totalRows = (totalCells / 7).ceil();

    final monthName = DateFormat('MMM').format(firstDayOfMonth).toLowerCase();
    
    // Calculate cell size organically
    final innerPadding = 12.0;
    final availableGridWidth = width - (innerPadding * 2);
    // 7 days in a week. Need to account for small spacing. If cell is W, spacing is roughly W/5.
    // 7 * W + 6 * (W/5) = availableGridWidth => W = availableGridWidth / 8.2
    final double cellSize = (availableGridWidth / 8.2).floorToDouble();

    return Container(
      width: width, 
      padding: EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(
        color: context.colors.card, 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_month_rounded, size: 16, color: context.colors.textDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthName,
                  style: TextStyle(
                    fontFamily: 'Cabinet Grotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return SizedBox(
                width: cellSize,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMedium,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(totalRows, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayOffset = cellIndex - startWeekday;

                    if (dayOffset < 0 || dayOffset >= daysInMonth) {
                      return SizedBox(width: cellSize, height: cellSize);
                    }

                    final currentDate = DateTime(year, month, dayOffset + 1);
                    final score = heatmapData[currentDate] ?? 0;
                    
                    String tooltipMsg = '${DateFormat('MMM dd, yyyy').format(currentDate)}\nScore: $score';

                    return Tooltip(
                      message: tooltipMsg,
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: _getColorForScore(context, score),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
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
              fontFamily: 'Cabinet Grotesk',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: context.colors.primary,
              height: 1.0,
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
