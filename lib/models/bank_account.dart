import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

@immutable
class BankAccount {
  final String id;
  final String name;
  final String holderName;
  final String bankName;
  final String? upiId;
  final String? accountNumber;
  final bool isActive;

  const BankAccount({
    required this.id,
    required this.name,
    required this.holderName,
    required this.bankName,
    this.upiId,
    this.accountNumber,
    this.isActive = true,
  });

  BankAccount copyWith({
    String? id,
    String? name,
    String? holderName,
    String? bankName,
    String? upiId,
    String? accountNumber,
    bool? isActive,
  }) {
    return BankAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      holderName: holderName ?? this.holderName,
      bankName: bankName ?? this.bankName,
      upiId: upiId ?? this.upiId,
      accountNumber: accountNumber ?? this.accountNumber,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'holderName': holderName,
    'bankName': bankName,
    'upiId': upiId,
    'accountNumber': accountNumber,
    'isActive': isActive,
  };

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String? ?? _uuid.v4(),
      name: json['name'] as String? ?? '',
      holderName: json['holderName'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      upiId: json['upiId'] as String?,
      accountNumber: json['accountNumber'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static BankAccount create({
    required String name,
    required String holderName,
    required String bankName,
    String? upiId,
    String? accountNumber,
    bool isActive = true,
  }) {
    return BankAccount(
      id: _uuid.v4(),
      name: name,
      holderName: holderName,
      bankName: bankName,
      upiId: upiId,
      accountNumber: accountNumber,
      isActive: isActive,
    );
  }
}
