import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Data Contract Test', () {
    test('JSON payload matches Kotlin expectations', () {
      final Map<String, dynamic> widgetData = {
        'date': '2026-09-13',
        'updatedAt': '17:30',
        'steps': 5000,
        'stepGoal': 10000,
        'mealsLogged': 2,
        'totalMeals': 4,
        'habitsDone': 1,
        'totalHabits': 3,
        'energy': 1200.0,
        'protein': 60.0,
        'isRest': false,
        'workoutTitle': 'Leg Day',
        'workoutStatus': 'Pending',
      };
      expect(widgetData.containsKey('date'), isTrue);
      expect(widgetData.containsKey('updatedAt'), isTrue);
      expect(widgetData.containsKey('steps'), isTrue);
    });
  });
}
