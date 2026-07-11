import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

@immutable
class DailyBalance {
  final String id;
  final String dateKey;
  final String userId;
  final double aepsOpeningBalance;
  final double aepsClosingBalance;
  final double hasibulOpeningBalance;
  final double hasibulClosingBalance;
  final double runaLailaOpeningBalance;
  final double runaLailaClosingBalance;
  final Map<String, double> customBalances;
  final bool openingBalancesEditable;

  const DailyBalance({
    required this.id,
    required this.dateKey,
    required this.userId,
    required this.aepsOpeningBalance,
    required this.aepsClosingBalance,
    required this.hasibulOpeningBalance,
    required this.hasibulClosingBalance,
    required this.runaLailaOpeningBalance,
    required this.runaLailaClosingBalance,
    this.customBalances = const {},
    this.openingBalancesEditable = true,
  });

  double getBalance(String accountId, {bool closing = true}) {
    switch (accountId) {
      case 'aeps':
        return closing ? aepsClosingBalance : aepsOpeningBalance;
      case 'hasibul':
        return closing ? hasibulClosingBalance : hasibulOpeningBalance;
      case 'runaLaila':
        return closing ? runaLailaClosingBalance : runaLailaOpeningBalance;
      default:
        return customBalances[accountId] ?? 0;
    }
  }

  DailyBalance setBalance(String accountId, double amount) {
    switch (accountId) {
      case 'aeps':
        return copyWith(aepsClosingBalance: amount);
      case 'hasibul':
        return copyWith(hasibulClosingBalance: amount);
      case 'runaLaila':
        return copyWith(runaLailaClosingBalance: amount);
      default:
        final newMap = Map<String, double>.from(customBalances);
        newMap[accountId] = amount;
        return copyWith(customBalances: newMap);
    }
  }

  double get totalClosingBalance {
    var total = aepsClosingBalance + hasibulClosingBalance + runaLailaClosingBalance;
    for (final v in customBalances.values) {
      total += v;
    }
    return total;
  }

  double get totalOpeningBalance {
    var total = aepsOpeningBalance + hasibulOpeningBalance + runaLailaOpeningBalance;
    for (final v in customBalances.values) {
      total += v;
    }
    return total;
  }

  DailyBalance copyWith({
    String? id,
    String? dateKey,
    String? userId,
    double? aepsOpeningBalance,
    double? aepsClosingBalance,
    double? hasibulOpeningBalance,
    double? hasibulClosingBalance,
    double? runaLailaOpeningBalance,
    double? runaLailaClosingBalance,
    Map<String, double>? customBalances,
    bool? openingBalancesEditable,
  }) {
    return DailyBalance(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      userId: userId ?? this.userId,
      aepsOpeningBalance: aepsOpeningBalance ?? this.aepsOpeningBalance,
      aepsClosingBalance: aepsClosingBalance ?? this.aepsClosingBalance,
      hasibulOpeningBalance: hasibulOpeningBalance ?? this.hasibulOpeningBalance,
      hasibulClosingBalance: hasibulClosingBalance ?? this.hasibulClosingBalance,
      runaLailaOpeningBalance: runaLailaOpeningBalance ?? this.runaLailaOpeningBalance,
      runaLailaClosingBalance: runaLailaClosingBalance ?? this.runaLailaClosingBalance,
      customBalances: customBalances ?? this.customBalances,
      openingBalancesEditable: openingBalancesEditable ?? this.openingBalancesEditable,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dateKey': dateKey,
    'userId': userId,
    'aepsOpeningBalance': aepsOpeningBalance,
    'aepsClosingBalance': aepsClosingBalance,
    'hasibulOpeningBalance': hasibulOpeningBalance,
    'hasibulClosingBalance': hasibulClosingBalance,
    'runaLailaOpeningBalance': runaLailaOpeningBalance,
    'runaLailaClosingBalance': runaLailaClosingBalance,
    if (customBalances.isNotEmpty) 'customBalances': customBalances,
    'openingBalancesEditable': openingBalancesEditable,
  };

  factory DailyBalance.fromJson(Map<String, dynamic> json, {String? idOverride}) {
    return DailyBalance(
      id: idOverride ?? json['id'] as String,
      dateKey: json['dateKey'] as String,
      userId: json['userId'] as String,
      aepsOpeningBalance: (json['aepsOpeningBalance'] as num).toDouble(),
      aepsClosingBalance: (json['aepsClosingBalance'] as num).toDouble(),
      hasibulOpeningBalance: (json['hasibulOpeningBalance'] as num).toDouble(),
      hasibulClosingBalance: (json['hasibulClosingBalance'] as num).toDouble(),
      runaLailaOpeningBalance: (json['runaLailaOpeningBalance'] as num).toDouble(),
      runaLailaClosingBalance: (json['runaLailaClosingBalance'] as num).toDouble(),
      customBalances: json['customBalances'] != null
          ? (json['customBalances'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as num).toDouble()))
          : {},
      openingBalancesEditable: json['openingBalancesEditable'] as bool? ?? true,
    );
  }

  factory DailyBalance.create({
    required String dateKey,
    required String userId,
    double aepsOpeningBalance = 0,
    double hasibulOpeningBalance = 0,
    double runaLailaOpeningBalance = 0,
    Map<String, double> customOpening = const {},
  }) {
    return DailyBalance(
      id: _uuid.v4(),
      dateKey: dateKey,
      userId: userId,
      aepsOpeningBalance: aepsOpeningBalance,
      aepsClosingBalance: aepsOpeningBalance,
      hasibulOpeningBalance: hasibulOpeningBalance,
      hasibulClosingBalance: hasibulOpeningBalance,
      runaLailaOpeningBalance: runaLailaOpeningBalance,
      runaLailaClosingBalance: runaLailaOpeningBalance,
      customBalances: Map.from(customOpening),
    );
  }
}
