import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

const _uuid = Uuid();

@immutable
class Transaction {
  final String id;
  final TransactionType type;
  final String customerName;
  final double amount;
  final double commission;
  final bool commissionOverridden;
  final String? mobileNumber;
  final String? transactionId;
  final String? notes;
  final String? bankName;
  final PhonePeAccount? phonePeAccount;
  final double balanceAfterTransaction;
  final DateTime createdAt;
  final String userId;

  const Transaction({
    required this.id,
    required this.type,
    required this.customerName,
    required this.amount,
    required this.commission,
    required this.balanceAfterTransaction,
    required this.createdAt,
    required this.userId,
    this.commissionOverridden = false,
    this.mobileNumber,
    this.transactionId,
    this.notes,
    this.bankName,
    this.phonePeAccount,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    String? customerName,
    double? amount,
    double? commission,
    bool? commissionOverridden,
    String? mobileNumber,
    String? transactionId,
    String? notes,
    String? bankName,
    PhonePeAccount? phonePeAccount,
    double? balanceAfterTransaction,
    DateTime? createdAt,
    String? userId,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      commission: commission ?? this.commission,
      commissionOverridden: commissionOverridden ?? this.commissionOverridden,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      bankName: bankName ?? this.bankName,
      phonePeAccount: phonePeAccount ?? this.phonePeAccount,
      balanceAfterTransaction: balanceAfterTransaction ?? this.balanceAfterTransaction,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'customerName': customerName,
    'amount': amount,
    'commission': commission,
    'commissionOverridden': commissionOverridden,
    'mobileNumber': mobileNumber,
    'transactionId': transactionId,
    'notes': notes,
    'bankName': bankName,
    'phonePeAccount': phonePeAccount?.name,
    'balanceAfterTransaction': balanceAfterTransaction,
    'createdAt': createdAt.toIso8601String(),
    'userId': userId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json, {String? idOverride}) {
    return Transaction(
      id: idOverride ?? json['id'] as String,
      type: TransactionType.values.firstWhere((e) => e.name == json['type']),
      customerName: json['customerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      commission: (json['commission'] as num).toDouble(),
      commissionOverridden: json['commissionOverridden'] as bool? ?? false,
      mobileNumber: json['mobileNumber'] as String?,
      transactionId: json['transactionId'] as String?,
      notes: json['notes'] as String?,
      bankName: json['bankName'] as String?,
      phonePeAccount: json['phonePeAccount'] != null
          ? PhonePeAccount.values.firstWhere((e) => e.name == json['phonePeAccount'])
          : null,
      balanceAfterTransaction: (json['balanceAfterTransaction'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String,
    );
  }

  static Transaction create({
    required TransactionType type,
    required String customerName,
    required double amount,
    required double balanceAfterTransaction,
    required String userId,
    String? mobileNumber,
    String? transactionId,
    String? notes,
    String? bankName,
    PhonePeAccount? phonePeAccount,
    double? commission,
    bool commissionOverridden = false,
  }) {
    final now = DateTime.now();
    final commissionValue = commission ?? _calculateCommission(amount, type);
    return Transaction(
      id: _uuid.v4(),
      type: type,
      customerName: customerName,
      amount: amount,
      commission: commissionValue,
      commissionOverridden: commission != null || commissionOverridden,
      balanceAfterTransaction: balanceAfterTransaction,
      createdAt: now,
      userId: userId,
      mobileNumber: mobileNumber,
      transactionId: transactionId,
      notes: notes,
      bankName: bankName,
      phonePeAccount: phonePeAccount,
    );
  }

  static double _calculateCommission(double amount, TransactionType type) {
    if (type != TransactionType.aeps) return 0;
    return (amount / 1000).ceil() * 10.0;
  }
}
