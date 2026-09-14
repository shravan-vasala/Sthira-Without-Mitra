import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _monthKeys = List.generate(12, (_) => GlobalKey());
  bool _hasScrolledInitially = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMonth() {
    if (!mounted) return;
    final year = ref.read(selectedYearProvider);
    final now = DateTime.now();
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (year == now.year && _scrollController.hasClients) {
      if (!_hasScrolledInitially) {
        final monthKey = _monthKeys[now.month - 1];
        if (monthKey.currentContext != null) {
          if (disableAnimations) {
            Scrollable.ensureVisible(monthKey.currentContext!);
          } else {
            Scrollable.ensureVisible(
              monthKey.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
          _hasScrolledInitially = true;
        }
      }
    } else if (_scrollController.hasClients) {
      if (disableAnimations) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Color _getColorForScore(BuildContext context, int score) {
    if (score == -1) return Colors.transparent;
    if (score == -2) return context.colors.inputFill;
    if (score == 0) {
      return context.colors.border;
    }
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
      _hasScrolledInitially = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentMonth();
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
                        style: AppTheme.numeric(
                          TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 500;
                  final int crossAxisCount = isWide ? 2 : 1;
                  final double cardWidth = (constraints.maxWidth - 40 - (16 * (crossAxisCount - 1))) / crossAxisCount;
                  
                  final innerPadding = 12.0;
                  final availableGridWidth = cardWidth - (innerPadding * 2);
                  final double cellSize = (availableGridWidth / 8.2).floorToDouble();
                  final estimatedHeight = 20.0 + 16.0 + 12.0 + 8.0 + (6 * (cellSize + 3.0)) + 24.0;
                  final aspectRatio = cardWidth / estimatedHeight;
                  
                  final int monthsToShow;
                  if (year == DateTime.now().year) {
                    monthsToShow = DateTime.now().month;
                  } else if (year < DateTime.now().year) {
                    monthsToShow = 12;
                  } else {
                    monthsToShow = 0;
                  }
                  
                  if (monthsToShow == 0) {
                    return Center(
                      child: Text(
                        'No activity yet for this year.',
                        style: TextStyle(color: context.colors.textMedium),
                      ),
                    );
                  }

                  return GridView.builder(
                    key: const PageStorageKey('heatmap_grid'),
                    controller: _scrollController,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: monthsToShow,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: aspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final month = index + 1;
                      return _buildMonthCard(context, year, month, heatmapData, cardWidth, _monthKeys[index]);
                    },
                  );
                }
              ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: context.colors.red.withValues(alpha: 0.8), size: 32),
            const SizedBox(height: 12),
            Text('Failed to load activity.', style: TextStyle(color: context.colors.textMedium)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(yearlyActivityHeatmapProvider),
              icon: Icon(Icons.refresh_rounded, color: context.colors.primary),
              label: Text('Retry', style: TextStyle(color: context.colors.primary)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCard(BuildContext context, int year, int month, Map<DateTime, int> heatmapData, double width, GlobalKey key) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    
    // Monday-anchored start of week
    // DateTime.monday == 1 ... DateTime.sunday == 7
    final startWeekday = (firstDayOfMonth.weekday - DateTime.monday) % 7;
    
    final totalCells = daysInMonth + startWeekday;
    final totalRows = (totalCells / 7).ceil();

    final monthName = DateFormat('MMM').format(firstDayOfMonth).toLowerCase();
    
    // Calculate cell size organically
    final innerPadding = 12.0;
    final availableGridWidth = width - (innerPadding * 2);
    final double cellSize = (availableGridWidth / 8.2).floorToDouble();

    return Container(
      key: key,
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
              Expanded(
                child: Text(
                  monthName,
                  style: TextStyle(
                    fontFamily: 'Cabinet Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
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
                  
                  String tooltipMsg;
                  if (score == -1) {
                    tooltipMsg = '${DateFormat('MMM dd, yyyy').format(currentDate)}\nFuture';
                  } else if (score == -2) {
                    tooltipMsg = '${DateFormat('MMM dd, yyyy').format(currentDate)}\nNo activity recorded';
                  } else if (score == 0) {
                    tooltipMsg = '${DateFormat('MMM dd, yyyy').format(currentDate)}\n0% (Missed goals)';
                  } else {
                    tooltipMsg = '${DateFormat('MMM dd, yyyy').format(currentDate)}\nScore: $score%';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: GestureDetector(
                      onTap: score == -1 ? null : () {
                        ref.read(selectedDateProvider.notifier).state = currentDate;
                        context.go('/home');
                      },
                      child: Semantics(
                        label: tooltipMsg,
                        button: score != -1,
                        child: Tooltip(
                          message: tooltipMsg,
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: _getColorForScore(context, score),
                              borderRadius: BorderRadius.circular(4),
                              border: score == 0 
                                  ? Border.all(color: context.colors.red.withValues(alpha: 0.3), width: 1)
                                  : null,
                            ),
                          ),
                        ),
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
        border: score == 0 
            ? Border.all(color: context.colors.red.withValues(alpha: 0.3), width: 1)
            : null,
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
