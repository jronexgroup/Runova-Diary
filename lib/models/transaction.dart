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
  final double distributorCommission;
  final bool commissionOverridden;
  final String? mobileNumber;
  final String? aadhaarNumber;
  final String? transactionId;
  final String? notes;
  final String? bankName;
  final PhonePeAccount? phonePeAccount;
  final double balanceAfterTransaction;
  final DateTime createdAt;
  final String userId;
  final String? account;
  final String? fromAccount;
  final String? toAccount;

  const Transaction({
    required this.id,
    required this.type,
    required this.customerName,
    required this.amount,
    required this.commission,
    this.distributorCommission = 0,
    required this.balanceAfterTransaction,
    required this.createdAt,
    required this.userId,
    this.commissionOverridden = false,
    this.mobileNumber,
    this.aadhaarNumber,
    this.transactionId,
    this.notes,
    this.bankName,
    this.phonePeAccount,
    this.account,
    this.fromAccount,
    this.toAccount,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    String? customerName,
    double? amount,
    double? commission,
    double? distributorCommission,
    bool? commissionOverridden,
    String? mobileNumber,
    String? aadhaarNumber,
    String? transactionId,
    String? notes,
    String? bankName,
    PhonePeAccount? phonePeAccount,
    double? balanceAfterTransaction,
    DateTime? createdAt,
    String? userId,
    String? account,
    String? fromAccount,
    String? toAccount,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      commission: commission ?? this.commission,
      distributorCommission: distributorCommission ?? this.distributorCommission,
      commissionOverridden: commissionOverridden ?? this.commissionOverridden,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      bankName: bankName ?? this.bankName,
      phonePeAccount: phonePeAccount ?? this.phonePeAccount,
      balanceAfterTransaction: balanceAfterTransaction ?? this.balanceAfterTransaction,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      account: account ?? this.account,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'customerName': customerName,
    'amount': amount,
    'commission': commission,
    'distributorCommission': distributorCommission,
    'commissionOverridden': commissionOverridden,
    'mobileNumber': mobileNumber,
    'aadhaarNumber': aadhaarNumber,
    'transactionId': transactionId,
    'notes': notes,
    'bankName': bankName,
    'phonePeAccount': phonePeAccount?.name,
    'balanceAfterTransaction': balanceAfterTransaction,
    'createdAt': createdAt.toIso8601String(),
    'userId': userId,
    'account': account,
    'fromAccount': fromAccount,
    'toAccount': toAccount,
  };

  factory Transaction.fromJson(Map<String, dynamic> json, {String? idOverride}) {
    return Transaction(
      id: idOverride ?? json['id'] as String,
      type: TransactionType.values.firstWhere((e) => e.name == json['type']),
      customerName: json['customerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      commission: (json['commission'] as num).toDouble(),
      distributorCommission: (json['distributorCommission'] as num?)?.toDouble() ?? 0,
      commissionOverridden: json['commissionOverridden'] as bool? ?? false,
      mobileNumber: json['mobileNumber'] as String?,
      aadhaarNumber: json['aadhaarNumber'] as String?,
      transactionId: json['transactionId'] as String?,
      notes: json['notes'] as String?,
      bankName: json['bankName'] as String?,
      phonePeAccount: json['phonePeAccount'] != null
          ? PhonePeAccount.values.firstWhere((e) => e.name == json['phonePeAccount'])
          : null,
      balanceAfterTransaction: (json['balanceAfterTransaction'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String,
      account: json['account'] as String?,
      fromAccount: json['fromAccount'] as String?,
      toAccount: json['toAccount'] as String?,
    );
  }

  static Transaction create({
    required TransactionType type,
    required String customerName,
    required double amount,
    required double balanceAfterTransaction,
    required String userId,
    String? mobileNumber,
    String? aadhaarNumber,
    String? transactionId,
    String? notes,
    String? bankName,
    PhonePeAccount? phonePeAccount,
    double? commission,
    double? distributorCommission,
    bool commissionOverridden = false,
    String? account,
    String? fromAccount,
    String? toAccount,
  }) {
    final now = DateTime.now();
    final commissionValue = commission ?? 0;
    return Transaction(
      id: _uuid.v4(),
      type: type,
      customerName: customerName,
      amount: amount,
      commission: commissionValue,
      distributorCommission: distributorCommission ?? 0,
      commissionOverridden: commissionValue > 0 || commissionOverridden,
      balanceAfterTransaction: balanceAfterTransaction,
      createdAt: now,
      userId: userId,
      mobileNumber: mobileNumber,
      aadhaarNumber: aadhaarNumber,
      transactionId: transactionId,
      notes: notes,
      bankName: bankName,
      phonePeAccount: phonePeAccount,
      account: account,
      fromAccount: fromAccount,
      toAccount: toAccount,
    );
  }
}
