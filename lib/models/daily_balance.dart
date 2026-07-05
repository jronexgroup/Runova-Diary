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
    this.openingBalancesEditable = true,
  });

  double get totalClosingBalance =>
      aepsClosingBalance + hasibulClosingBalance + runaLailaClosingBalance;

  double get totalOpeningBalance =>
      aepsOpeningBalance + hasibulOpeningBalance + runaLailaOpeningBalance;

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
      openingBalancesEditable: json['openingBalancesEditable'] as bool? ?? true,
    );
  }

  factory DailyBalance.create({
    required String dateKey,
    required String userId,
    double aepsOpeningBalance = 0,
    double hasibulOpeningBalance = 0,
    double runaLailaOpeningBalance = 0,
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
    );
  }
}
