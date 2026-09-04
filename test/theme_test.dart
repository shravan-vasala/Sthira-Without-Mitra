import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/theme/app_theme.dart';

void main() {
  test('AppTheme.light initializes without crashing', () {
    final theme = AppTheme.light;
    expect(theme, isNotNull);
  });
  test('AppTheme.dark initializes without crashing', () {
    final theme = AppTheme.dark;
    expect(theme, isNotNull);
  });
}
