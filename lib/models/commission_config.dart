import 'package:flutter/foundation.dart';

@immutable
class CommissionConfig {
  final double cashInPerThousand;
  final double cashOutPerThousand;
  final double settlementCharge;

  const CommissionConfig({
    this.cashInPerThousand = 10,
    this.cashOutPerThousand = 10,
    this.settlementCharge = 5,
  });

  CommissionConfig copyWith({
    double? cashInPerThousand,
    double? cashOutPerThousand,
    double? settlementCharge,
  }) {
    return CommissionConfig(
      cashInPerThousand: cashInPerThousand ?? this.cashInPerThousand,
      cashOutPerThousand: cashOutPerThousand ?? this.cashOutPerThousand,
      settlementCharge: settlementCharge ?? this.settlementCharge,
    );
  }

  Map<String, dynamic> toJson() => {
    'cashInPerThousand': cashInPerThousand,
    'cashOutPerThousand': cashOutPerThousand,
    'settlementCharge': settlementCharge,
  };

  factory CommissionConfig.fromJson(Map<String, dynamic> json) {
    return CommissionConfig(
      cashInPerThousand: (json['cashInPerThousand'] as num?)?.toDouble() ?? 10,
      cashOutPerThousand: (json['cashOutPerThousand'] as num?)?.toDouble() ?? 10,
      settlementCharge: (json['settlementCharge'] as num?)?.toDouble() ?? 5,
    );
  }
}

@immutable
class AepsCommissionConfig {
  final double cashWithdrawalPerThousand;
  final double balanceEnquiry;
  final double miniStatement;
  final double aadhaarPayPerThousand;

  const AepsCommissionConfig({
    this.cashWithdrawalPerThousand = 10,
    this.balanceEnquiry = 0,
    this.miniStatement = 0,
    this.aadhaarPayPerThousand = 0,
  });

  AepsCommissionConfig copyWith({
    double? cashWithdrawalPerThousand,
    double? balanceEnquiry,
    double? miniStatement,
    double? aadhaarPayPerThousand,
  }) {
    return AepsCommissionConfig(
      cashWithdrawalPerThousand: cashWithdrawalPerThousand ?? this.cashWithdrawalPerThousand,
      balanceEnquiry: balanceEnquiry ?? this.balanceEnquiry,
      miniStatement: miniStatement ?? this.miniStatement,
      aadhaarPayPerThousand: aadhaarPayPerThousand ?? this.aadhaarPayPerThousand,
    );
  }

  Map<String, dynamic> toJson() => {
    'cashWithdrawalPerThousand': cashWithdrawalPerThousand,
    'balanceEnquiry': balanceEnquiry,
    'miniStatement': miniStatement,
    'aadhaarPayPerThousand': aadhaarPayPerThousand,
  };

  factory AepsCommissionConfig.fromJson(Map<String, dynamic> json) {
    return AepsCommissionConfig(
      cashWithdrawalPerThousand: (json['cashWithdrawalPerThousand'] as num?)?.toDouble() ?? 10,
      balanceEnquiry: (json['balanceEnquiry'] as num?)?.toDouble() ?? 0,
      miniStatement: (json['miniStatement'] as num?)?.toDouble() ?? 0,
      aadhaarPayPerThousand: (json['aadhaarPayPerThousand'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DistributorRange {
  final int min;
  final int max;
  final double commission;

  const DistributorRange({
    required this.min,
    required this.max,
    required this.commission,
  });

  Map<String, dynamic> toJson() => {
    'min': min,
    'max': max,
    'commission': commission,
  };

  factory DistributorRange.fromJson(Map<String, dynamic> json) {
    return DistributorRange(
      min: (json['min'] as num).toInt(),
      max: (json['max'] as num).toInt(),
      commission: (json['commission'] as num).toDouble(),
    );
  }

  DistributorRange copyWith({int? min, int? max, double? commission}) {
    return DistributorRange(
      min: min ?? this.min,
      max: max ?? this.max,
      commission: commission ?? this.commission,
    );
  }

  static const List<DistributorRange> defaults = [
    DistributorRange(min: 200, max: 499, commission: 0.5),
    DistributorRange(min: 500, max: 999, commission: 0.5),
    DistributorRange(min: 1000, max: 1499, commission: 1.25),
    DistributorRange(min: 1500, max: 1999, commission: 2),
    DistributorRange(min: 2000, max: 2499, commission: 3),
    DistributorRange(min: 2500, max: 2999, commission: 3),
    DistributorRange(min: 3000, max: 3499, commission: 10),
    DistributorRange(min: 3500, max: 7999, commission: 10),
    DistributorRange(min: 8000, max: 10000, commission: 10),
  ];
}

class SettlementRange {
  final int min;
  final int max;
  final double charge;

  const SettlementRange({
    required this.min,
    required this.max,
    required this.charge,
  });

  Map<String, dynamic> toJson() => {
    'min': min,
    'max': max,
    'charge': charge,
  };

  factory SettlementRange.fromJson(Map<String, dynamic> json) {
    return SettlementRange(
      min: (json['min'] as num).toInt(),
      max: (json['max'] as num).toInt(),
      charge: (json['charge'] as num).toDouble(),
    );
  }

  SettlementRange copyWith({int? min, int? max, double? charge}) {
    return SettlementRange(
      min: min ?? this.min,
      max: max ?? this.max,
      charge: charge ?? this.charge,
    );
  }

  static const List<SettlementRange> defaults = [
    SettlementRange(min: 0, max: 25000, charge: 5),
    SettlementRange(min: 25001, max: 50000, charge: 10),
    SettlementRange(min: 50001, max: 200000, charge: 10),
  ];
}
