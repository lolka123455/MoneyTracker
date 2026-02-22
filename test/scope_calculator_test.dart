import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/providers/scope_provider.dart';

void main() {
  group('ScopeCalculator', () {
    late ScopeCalculator calculator;

    setUp(() {
      calculator = ScopeCalculator(day1: 13, day2: 27);
    });

    test('getCurrentScopeDates returns correct scope boundaries', () {
      final dates = calculator.getCurrentScopeDates();
      expect(dates.start.isBefore(dates.end), isTrue);
      expect(dates.end.difference(dates.start).inDays, lessThanOrEqualTo(16));
      expect(dates.end.difference(dates.start).inDays, greaterThanOrEqualTo(12));
    });

    test('getCurrentScopeLabel returns Advance or Salary', () {
      final label = calculator.getCurrentScopeLabel();
      expect(['Advance', 'Salary'], contains(label));
    });

    test('generateScopes generates correct periods', () {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 2, 1);
      final scopes = calculator.generateScopes(from, to);

      expect(scopes.length, greaterThanOrEqualTo(2));
      for (final scope in scopes) {
        expect(scope.start.isBefore(scope.end), isTrue);
        expect(['Advance', 'Salary'], contains(scope.label));
      }
    });

    test('custom scope days work correctly', () {
      final customCalc = ScopeCalculator(day1: 1, day2: 15);
      final dates = customCalc.getCurrentScopeDates();
      expect(dates.start.isBefore(dates.end), isTrue);
    });
  });
}
