import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/services/diagnostic_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DiagnosticLogger tests', () {
    late DiagnosticLogger logger;
    
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Redacts Secrets natively across layers', () async {
      final prefs = await SharedPreferences.getInstance();
      logger = DiagnosticLogger(prefs);

      logger.info('Testing ?token=SUPERSECRETVALUE123');
      logger.error('Error fetching data', 'AIzaSDFGHRTYUIOOPASDFGHJKLZXCVBNMQWERTYU');
      
      final logs = logger.getLogs();
      expect(logs.length, 2);
      
      expect(
          logs[1].message.contains('[REDACTED_PARAM]'), 
          true,
          reason: "URL params containing tokens should redact",
      );
      
      expect(
          logs[0].error?.contains('[REDACTED_API_KEY]'), 
          true,
          reason: "API Keys should sanitize pre-persistence!",
      );
    });

    test('Loads corrupted blocks reliably dropping only malformed elements', () async {
      SharedPreferences.setMockInitialValues({
        'diagnostic_ring_buffer': '[{"ts":"2023-11-20T10:00:00Z","lvl":"INFO","msg":"Good" }, "CRASH", {"msg":"Bad"}]'
      });
      final prefs = await SharedPreferences.getInstance();
      logger = DiagnosticLogger(prefs);
      
      // Should recover the "Good" element securely bypassing the raw "CRASH" string and malformed "Bad" object
      final logs = logger.getLogs();
      // "Bad" missing timestamp throws exception inside DiagnosticLog.fromJson which is safely caught!
      expect(logs.length, 1);
      expect(logs[0].message, 'Good');
    });

    test('Truncates payload sizing', () async {
      final prefs = await SharedPreferences.getInstance();
      logger = DiagnosticLogger(prefs);

      final massiveString = "A" * 5000;
      logger.info(massiveString);
      
      final logs = logger.getLogs();
      expect(logs[0].message.length, lessThan(4200));
      expect(logs[0].message.endsWith('[TRUNCATED]'), true);
    });
  });
}
