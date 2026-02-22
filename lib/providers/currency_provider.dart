import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/currency_service.dart';
import 'database_provider.dart';

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService(ref.watch(databaseProvider));
});

final usdToRubRateProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(currencyServiceProvider);
  return service.getUsdToRubRate();
});

final rubToUsdRateProvider = FutureProvider<double>((ref) async {
  final rate = await ref.watch(usdToRubRateProvider.future);
  return 1.0 / rate;
});

/// Convert amount from one currency to another
final convertedAmountProvider =
    FutureProvider.family<double, ({double amount, String from, String to})>(
        (ref, params) async {
  if (params.from == params.to) return params.amount;

  final service = ref.watch(currencyServiceProvider);
  return service.convert(params.amount, params.from, params.to);
});

/// Custom rate override provider (user can set their own rate)
final customRateProvider = StateProvider<double?>((ref) => null);
