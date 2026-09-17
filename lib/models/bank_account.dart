import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum AccountType { phonePe, aeps }

@immutable
class BankAccount {
  final String id;
  final String name;
  final String holderName;
  final String bankName;
  final String? upiId;
  final String? accountNumber;
  final String? lastFourDigits;
  final bool isActive;
  final AccountType accountType;

  const BankAccount({
    required this.id,
    required this.name,
    required this.holderName,
    required this.bankName,
    this.upiId,
    this.accountNumber,
    this.lastFourDigits,
    this.isActive = true,
    this.accountType = AccountType.phonePe,
  });

  bool get isAeps => accountType == AccountType.aeps;
  bool get isPhonePe => accountType == AccountType.phonePe;

  BankAccount copyWith({
    String? id,
    String? name,
    String? holderName,
    String? bankName,
    String? upiId,
    String? accountNumber,
    String? lastFourDigits,
    bool? isActive,
    AccountType? accountType,
  }) {
    return BankAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      holderName: holderName ?? this.holderName,
      bankName: bankName ?? this.bankName,
      upiId: upiId ?? this.upiId,
      accountNumber: accountNumber ?? this.accountNumber,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      isActive: isActive ?? this.isActive,
      accountType: accountType ?? this.accountType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'holderName': holderName,
    'bankName': bankName,
    'upiId': upiId,
    'accountNumber': accountNumber,
    'lastFourDigits': lastFourDigits,
    'isActive': isActive,
    'accountType': accountType.name,
  };

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String? ?? _uuid.v4(),
      name: json['name'] as String? ?? '',
      holderName: json['holderName'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      upiId: json['upiId'] as String?,
      accountNumber: json['accountNumber'] as String?,
      lastFourDigits: json['lastFourDigits'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      accountType: json['accountType'] != null
          ? AccountType.values.firstWhere(
              (e) => e.name == json['accountType'],
              orElse: () => AccountType.phonePe,
            )
          : AccountType.phonePe,
    );
  }

  static BankAccount create({
    String? id,
    required String name,
    required String holderName,
    required String bankName,
    String? upiId,
    String? accountNumber,
    String? lastFourDigits,
    bool isActive = true,
    AccountType accountType = AccountType.phonePe,
  }) {
    return BankAccount(
      id: id ?? _uuid.v4(),
      name: name,
      holderName: holderName,
      bankName: bankName,
      upiId: upiId,
      accountNumber: accountNumber,
      lastFourDigits: lastFourDigits,
      isActive: isActive,
      accountType: accountType,
    );
  }
}
