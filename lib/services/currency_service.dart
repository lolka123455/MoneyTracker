import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../database/database.dart';
import '../core/constants.dart';

class CurrencyService {
  final AppDatabase _db;

  CurrencyService(this._db);

  /// Fetch USD/RUB rate from Central Bank of Russia (CBR)
  Future<double> fetchCbrRate() async {
    try {
      final response = await http.get(Uri.parse(AppConstants.cbrDailyUrl));
      if (response.statusCode != 200) {
        throw Exception('CBR API returned ${response.statusCode}');
      }

      final document = xml.XmlDocument.parse(
        utf8.decode(response.bodyBytes),
      );

      final valutes = document.findAllElements('Valute');
      for (final valute in valutes) {
        final charCode =
            valute.findElements('CharCode').first.innerText;
        if (charCode == 'USD') {
          final valueStr = valute
              .findElements('Value')
              .first
              .innerText
              .replaceAll(',', '.');
          final nominal = int.parse(
              valute.findElements('Nominal').first.innerText);
          return double.parse(valueStr) / nominal;
        }
      }
      throw Exception('USD not found in CBR response');
    } catch (e) {
      rethrow;
    }
  }

  /// Get the USD to RUB exchange rate (with caching)
  Future<double> getUsdToRubRate() async {
    // Check if we have a cached rate from today
    final cached = await _db.getLatestRate('USD', 'RUB');
    if (cached != null) {
      final age = DateTime.now().difference(cached.fetchedAt);
      if (age.inHours < 24) {
        return cached.rate;
      }
    }

    // Fetch fresh rate
    try {
      final rate = await fetchCbrRate();
      await _db.insertCurrencyRate(CurrencyRatesCompanion(
        fromCurrency: const Value('USD'),
        toCurrency: const Value('RUB'),
        rate: Value(rate),
        source: const Value('CBR'),
      ));
      return rate;
    } catch (e) {
      // If fetching fails and we have a cached rate, use it
      if (cached != null) return cached.rate;
      // Default fallback rate
      return 90.0;
    }
  }

  /// Convert an amount from one currency to another
  Future<double> convert(
      double amount, String from, String to) async {
    if (from == to) return amount;

    final usdToRub = await getUsdToRubRate();

    if (from == 'USD' && to == 'RUB') {
      return amount * usdToRub;
    } else if (from == 'RUB' && to == 'USD') {
      return amount / usdToRub;
    }

    return amount; // Same currency
  }
}
