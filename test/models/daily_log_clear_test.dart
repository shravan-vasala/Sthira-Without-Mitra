import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/daily_log.dart';

void main() {
  group('DailyLog Clear Methods', () {
    test('clearWeight retains other fields', () {
      final log = DailyLog(
        date: '2023-10-01',
        weight: 70.0,
        steps: 5000,
        waterMl: 1000,
        screenTimeMinutes: 120,
      );

      final cleared = log.clearWeight();

      expect(cleared.weight, isNull);
      expect(cleared.steps, 5000);
      expect(cleared.waterMl, 1000);
      expect(cleared.screenTimeMinutes, 120);
    });

    test('clearSteps retains other fields', () {
      final log = DailyLog(
        date: '2023-10-01',
        weight: 70.0,
        steps: 5000,
        stepsSource: 'health_connect',
        waterMl: 1000,
      );

      final cleared = log.clearSteps();

      expect(cleared.steps, isNull);
      expect(cleared.stepsSource, isNull);
      expect(cleared.weight, 70.0);
      expect(cleared.waterMl, 1000);
    });
  });
}

