import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/daily_balance.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(AppConstants.hiveTransactionsBox);
    await Hive.openBox(AppConstants.hiveBalancesBox);
    await Hive.openBox(AppConstants.hiveUserBox);
    await Hive.openBox(AppConstants.hiveSettingsBox);
  }

  Box get _txBox => Hive.box(AppConstants.hiveTransactionsBox);
  Box get _balBox => Hive.box(AppConstants.hiveBalancesBox);
  Box get _userBox => Hive.box(AppConstants.hiveUserBox);
  Box get _settingsBox => Hive.box(AppConstants.hiveSettingsBox);

  Future<void> saveUser(AppUser user) async {
    await _userBox.put('current', jsonEncode(user.toJson()));
  }

  AppUser? getUser() {
    final data = _userBox.get('current') as String?;
    if (data == null) return null;
    return AppUser.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> clearUser() async {
    await _userBox.delete('current');
  }

  Future<void> saveTransaction(Transaction transaction) async {
    final key = '${transaction.userId}_${transaction.id}';
    await _txBox.put(key, jsonEncode(transaction.toJson()));
  }

  Future<void> deleteTransaction(String userId, String transactionId) async {
    final key = '${userId}_$transactionId';
    await _txBox.delete(key);
  }

  List<Transaction> getTransactions(String userId) {
    final transactions = <Transaction>[];
    for (final key in _txBox.keys) {
      if (key.toString().startsWith('${userId}_')) {
        final data = _txBox.get(key) as String;
        final txn = Transaction.fromJson(
          jsonDecode(data) as Map<String, dynamic>,
        );
        transactions.add(txn);
      }
    }
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  Future<void> deleteBalance(String userId, String dateKey) async {
    final key = '${userId}_$dateKey';
    await _balBox.delete(key);
  }

  Future<int> deleteTransactionsForDate(String userId, String dateKey) async {
    final toDelete = <dynamic>[];
    for (final key in _txBox.keys) {
      if (key.toString().startsWith('${userId}_')) {
        final data = _txBox.get(key) as String;
        final txn = Transaction.fromJson(jsonDecode(data) as Map<String, dynamic>);
        if (txn.createdAt.dateKey == dateKey) {
          toDelete.add(key);
        }
      }
    }
    for (final key in toDelete) {
      await _txBox.delete(key);
    }
    return toDelete.length;
  }

  Future<void> saveBalance(DailyBalance balance) async {
    final key = '${balance.userId}_${balance.dateKey}';
    await _balBox.put(key, jsonEncode(balance.toJson()));
  }

  DailyBalance? getBalance(String userId, String dateKey) {
    final key = '${userId}_$dateKey';
    final data = _balBox.get(key) as String?;
    if (data == null) return null;
    return DailyBalance.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  List<DailyBalance> getAllBalances(String userId) {
    final balances = <DailyBalance>[];
    for (final key in _balBox.keys) {
      if (key.toString().startsWith('${userId}_')) {
        final data = _balBox.get(key) as String;
        balances.add(DailyBalance.fromJson(jsonDecode(data) as Map<String, dynamic>));
      }
    }
    balances.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return balances;
  }

  Future<void> saveAccountsJson(String userId, String jsonStr) async {
    await _settingsBox.put('${userId}_accounts', jsonStr);
  }

  String? getAccountsJson(String userId) {
    return _settingsBox.get('${userId}_accounts') as String?;
  }

  Future<void> saveCommissionConfigsJson(String userId, String jsonStr) async {
    await _settingsBox.put('${userId}_commissions', jsonStr);
  }

  String? getCommissionConfigsJson(String userId) {
    return _settingsBox.get('${userId}_commissions') as String?;
  }

  Future<void> saveAiSettingsJson(String userId, String jsonStr) async {
    await _settingsBox.put('${userId}_ai', jsonStr);
  }

  String? getAiSettingsJson(String userId) {
    return _settingsBox.get('${userId}_ai') as String?;
  }
}
