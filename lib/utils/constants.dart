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

class DistributorCommissionChart {
  static const List<({int min, int max, double commission})> ranges = [
    (min: 200, max: 499, commission: 0.5),
    (min: 500, max: 999, commission: 0.5),
    (min: 1000, max: 1499, commission: 1.25),
    (min: 1500, max: 1999, commission: 2),
    (min: 2000, max: 2499, commission: 3),
    (min: 2500, max: 2999, commission: 3),
    (min: 3000, max: 3499, commission: 10),
    (min: 3500, max: 7999, commission: 10),
    (min: 8000, max: 10000, commission: 10),
  ];

  static double getCommission(double amount) {
    for (final r in ranges) {
      if (amount >= r.min && amount <= r.max) return r.commission;
    }
    return 0;
  }
}

class SettlementChargeChart {
  static const List<({int min, int max, double charge})> ranges = [
    (min: 0, max: 25000, charge: 5),
    (min: 25001, max: 50000, charge: 10),
    (min: 50001, max: 200000, charge: 10),
  ];

  static double getCharge(double amount) {
    for (final r in ranges) {
      if (amount >= r.min && amount <= r.max) return r.charge;
    }
    return 10;
  }
}
