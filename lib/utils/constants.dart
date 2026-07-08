class AppConstants {
  static const String appName = 'Runova Diary';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String transactionsCollection = 'transactions';
  static const String dailyBalancesCollection = 'daily_balances';
  static const String settingsCollection = 'settings';

  static const String hiveTransactionsBox = 'transactions';
  static const String hiveBalancesBox = 'balances';
  static const String hiveUserBox = 'user';
  static const String hiveSettingsBox = 'settings';

  static const int minPinLength = 4;
  static const int maxPinLength = 6;
}

enum TransactionType {
  aeps,
  cashIn,
  cashOut,
  balanceAdjustment,
  selfTransfer;

  String get displayName {
    switch (this) {
      case TransactionType.aeps:
        return 'AEPS';
      case TransactionType.cashIn:
        return 'Cash In';
      case TransactionType.cashOut:
        return 'Cash Out';
      case TransactionType.balanceAdjustment:
        return 'Balance Adjustment';
      case TransactionType.selfTransfer:
        return 'Self Transfer';
    }
  }
}

enum PhonePeAccount {
  hasibul,
  runaLaila;

  String get displayName {
    switch (this) {
      case PhonePeAccount.hasibul:
        return 'Hasibul';
      case PhonePeAccount.runaLaila:
        return 'Runa Laila';
    }
  }
}
