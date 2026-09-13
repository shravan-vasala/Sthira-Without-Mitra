import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/services/screen_time_service.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenTimeResult parsing', () {
    test('Parses successful payload correctly', () {
      final json = {
        'status': 'success',
        'minutes': 142,
        'measuredDate': '2023-11-05',
        'timestamp': 1699142400000,
      };

      final result = ScreenTimeResult.fromJson(json);

      expect(result.status, 'success');
      expect(result.minutes, 142);
      expect(result.measuredDate, '2023-11-05');
      expect(result.timestamp, 1699142400000);
      expect(result.error, null);
    });

    test('Parses unavailable payload correctly', () {
      final json = {
        'status': 'unavailable',
      };

      final result = ScreenTimeResult.fromJson(json);

      expect(result.status, 'unavailable');
      expect(result.minutes, null);
      expect(result.measuredDate, null);
      expect(result.error, null);
    });

    test('Parses denied payload correctly', () {
      final json = {
        'status': 'denied',
      };

      final result = ScreenTimeResult.fromJson(json);

      expect(result.status, 'denied');
      expect(result.minutes, null);
    });

    test('Parses failed payload with error message', () {
      final json = {
        'status': 'failed',
        'error': 'Remote exception occurred',
      };

      final result = ScreenTimeResult.fromJson(json);

      expect(result.status, 'failed');
      expect(result.error, 'Remote exception occurred');
    });

    test('Handles completely malformed fallback', () {
      final json = {
        'some_garbage': 0,
      };

      final result = ScreenTimeResult.fromJson(json);
      
      // Defaults to failed if status is missing
      expect(result.status, 'failed');
    });
  });
}
