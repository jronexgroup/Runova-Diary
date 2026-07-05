import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  final String id;
  final String phoneNumber;
  final String shopName;
  final String ownerName;
  final String pinHash;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.phoneNumber,
    required this.shopName,
    required this.ownerName,
    required this.pinHash,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? phoneNumber,
    String? shopName,
    String? ownerName,
    String? pinHash,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      pinHash: pinHash ?? this.pinHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phoneNumber': phoneNumber,
    'shopName': shopName,
    'ownerName': ownerName,
    'pinHash': pinHash,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      shopName: json['shopName'] as String,
      ownerName: json['ownerName'] as String,
      pinHash: json['pinHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
