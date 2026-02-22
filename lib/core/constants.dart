class AppConstants {
  AppConstants._();

  static const String appName = 'MoneyTracker';

  // CBR (Central Bank of Russia) API
  static const String cbrDailyUrl =
      'https://www.cbr.ru/scripts/XML_daily.asp';

  // T-Bank Open Banking API
  static const String tBankBaseUrl = 'https://business.tbank.ru/openapi';
  static const String tBankAuthUrl =
      'https://id.tbank.ru/auth/authorize';
  static const String tBankTokenUrl =
      'https://id.tbank.ru/auth/token';

  // Default scope dates (Russian payroll: advance on 25th, salary on 10th)
  static const int defaultScopeDay1 = 13;
  static const int defaultScopeDay2 = 27;

  // Notification channel
  static const String notificationChannelId = 'money_tracker_reminders';
  static const String notificationChannelName = 'Payment Reminders';
}

enum AppCurrency {
  rub('RUB', '\u20BD', 'Russian Ruble'),
  usd('USD', '\$', 'US Dollar');

  final String code;
  final String symbol;
  final String name;
  const AppCurrency(this.code, this.symbol, this.name);
}

enum PaymentFrequency {
  daily('Daily', 1),
  weekly('Weekly', 7),
  monthly('Monthly', 30);

  final String label;
  final int approximateDays;
  const PaymentFrequency(this.label, this.approximateDays);
}

enum TransactionType {
  income,
  expense,
}
