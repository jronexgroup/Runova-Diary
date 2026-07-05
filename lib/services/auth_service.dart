import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'firebase_service.dart';
import 'hive_service.dart';

const _uuid = Uuid();

class AuthService {
  final HiveService _hiveService;
  final FirebaseService _firebaseService;

  AuthService(this._hiveService, this._firebaseService);

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<AppUser> register({
    required String phoneNumber,
    required String shopName,
    required String ownerName,
    required String pin,
  }) async {
    final user = AppUser(
      id: _uuid.v4(),
      phoneNumber: phoneNumber,
      shopName: shopName,
      ownerName: ownerName,
      pinHash: _hashPin(pin),
      createdAt: DateTime.now(),
    );
    await _hiveService.saveUser(user);
    await _firebaseService.saveUser(user);
    return user;
  }

  Future<AppUser?> login({
    required String phoneNumber,
    required String pin,
  }) async {
    final localUser = _hiveService.getUser();
    if (localUser != null &&
        localUser.phoneNumber == phoneNumber &&
        localUser.pinHash == _hashPin(pin)) {
      return localUser;
    }

    final fbUser = await _firebaseService.getUser(phoneNumber);
    if (fbUser != null && fbUser.pinHash == _hashPin(pin)) {
      await _hiveService.saveUser(fbUser);
      return fbUser;
    }

    return null;
  }

  Future<void> logout() async {
    await _hiveService.clearUser();
  }

  AppUser? getCurrentUser() {
    return _hiveService.getUser();
  }

  Future<void> changePin(String oldPin, String newPin) async {
    final user = _hiveService.getUser();
    if (user == null) throw Exception('No user logged in');
    if (user.pinHash != _hashPin(oldPin)) throw Exception('Incorrect current PIN');
    final updated = user.copyWith(pinHash: _hashPin(newPin));
    await _hiveService.saveUser(updated);
    await _firebaseService.saveUser(updated);
  }
}
