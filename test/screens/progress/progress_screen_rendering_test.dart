import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/screens/progress/progress_screen.dart';
import 'package:trufit_bodamma/providers/progress_chart_provider.dart';
import 'package:trufit_bodamma/providers/profile_providers.dart';
import 'package:trufit_bodamma/services/progress_aggregation_service.dart';
import 'package:trufit_bodamma/models/user_profile.dart';

class MockProfileNotifier extends ProfileNotifier {
  @override
  UserProfile build() {
    return UserProfile(useKg: true, height: 180);
  }
}

void main() {
  testWidgets('ProgressScreen renders safely with all-null data (No recorded data)', (WidgetTester tester) async {
    final mockBuckets = [
      ChartBucket(startDate: DateTime(2023, 1, 1), endDate: DateTime(2023, 1, 1), validDaysCount: 0, eligibleDaysCount: 1, average: null),
      ChartBucket(startDate: DateTime(2023, 1, 2), endDate: DateTime(2023, 1, 2), validDaysCount: 0, eligibleDaysCount: 1, average: null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => MockProfileNotifier()),
          aggregatedChartProvider.overrideWith((ref, param) => mockBuckets),
        ],
        child: const MaterialApp(home: ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recorded data for this period.'), findsOneWidget);
  });

  testWidgets('ProgressScreen handles gaps and sparse datasets (Null endpoints, one valid point, zeros)', (WidgetTester tester) async {
    final mockBuckets = [
      ChartBucket(startDate: DateTime(2023, 1, 1), endDate: DateTime(2023, 1, 1), validDaysCount: 0, eligibleDaysCount: 1, average: null),
      ChartBucket(startDate: DateTime(2023, 1, 2), endDate: DateTime(2023, 1, 2), validDaysCount: 1, eligibleDaysCount: 1, average: 0.0), // zero
      ChartBucket(startDate: DateTime(2023, 1, 3), endDate: DateTime(2023, 1, 3), validDaysCount: 0, eligibleDaysCount: 1, average: null),
      ChartBucket(startDate: DateTime(2023, 1, 4), endDate: DateTime(2023, 1, 4), validDaysCount: 1, eligibleDaysCount: 1, average: 80.5),
      ChartBucket(startDate: DateTime(2023, 1, 5), endDate: DateTime(2023, 1, 5), validDaysCount: 0, eligibleDaysCount: 1, average: null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => MockProfileNotifier()),
          aggregatedChartProvider.overrideWith((ref, param) => mockBuckets),
        ],
        child: const MaterialApp(home: ProgressScreen(initialMetric: MetricType.weight)),
      ),
    );
    await tester.pumpAndSettle();

    // Verify it doesn't crash
    final ex = tester.takeException();
    if (ex != null) {
      print('Exception: $ex');
      if (ex is Error) {
        print('StackTrace: ${ex.stackTrace}');
      }
    }
    expect(ex, isNull);
  });
}
