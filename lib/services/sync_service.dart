import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/bank_account.dart';
import '../models/daily_balance.dart';
import '../models/transaction.dart';
import 'hive_service.dart';
import 'firebase_service.dart';

class SyncService {
  final HiveService _hiveService;
  final FirebaseService _firebaseService;
  StreamSubscription? _connectivitySubscription;

  SyncService(this._hiveService, this._firebaseService);

  Future<void> init() async {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncToFirebase();
      }
    });
  }

  Future<void> syncFromFirebase() async {
    final user = _hiveService.getUser();
    if (user == null) return;

    try {
      final fbTransactions = await _firebaseService.getTransactions(user.id);
      for (final txn in fbTransactions) {
        await _hiveService.saveTransaction(txn);
      }

      final fbBalances = await _firebaseService.getAllBalances(user.id);
      for (final bal in fbBalances) {
        await _hiveService.saveBalance(bal);
      }

      final accounts = await pullAccounts(user.id);
      if (accounts.isNotEmpty) {
        await _hiveService.saveAccountsJson(
          user.id,
          jsonEncode(accounts.map((a) => a.toJson()).toList()),
        );
      }

      final configs = await pullCommissionConfigs(user.id);
      if (configs.isNotEmpty) {
        await _hiveService.saveCommissionConfigsJson(
          user.id,
          jsonEncode(configs),
        );
      }

      final aiSettings = await pullAiSettings(user.id);
      if (aiSettings.isNotEmpty) {
        await _hiveService.saveAiSettingsJson(
          user.id,
          jsonEncode(aiSettings),
        );
      }
    } catch (e) {
      debugPrint('Sync from Firebase failed: $e');
    }
  }

  Future<void> syncToFirebase() async {
    final user = _hiveService.getUser();
    if (user == null) return;

    try {
      final transactions = _hiveService.getTransactions(user.id);
      for (final txn in transactions) {
        await _firebaseService.saveTransaction(txn);
      }

      final balances = _hiveService.getAllBalances(user.id);
      for (final bal in balances) {
        await _firebaseService.saveBalance(bal);
      }

      final accountsJson = _hiveService.getAccountsJson(user.id);
      if (accountsJson != null) {
        final accounts = (jsonDecode(accountsJson) as List)
            .map((j) => BankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        await pushAccounts(user.id, accounts);
      }

      final configsJson = _hiveService.getCommissionConfigsJson(user.id);
      if (configsJson != null) {
        await pushCommissionConfigs(user.id, jsonDecode(configsJson) as Map<String, dynamic>);
      }

      final aiJson = _hiveService.getAiSettingsJson(user.id);
      if (aiJson != null) {
        await pushAiSettings(user.id, jsonDecode(aiJson) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Sync to Firebase failed: $e');
    }
  }

  Future<void> pushTransaction(Transaction txn) async {
    try {
      await _firebaseService.saveTransaction(txn);
    } catch (e) {
      debugPrint('Push transaction failed: $e');
    }
  }

  Future<void> pushDeleteTransaction(String userId, String txnId) async {
    try {
      await _firebaseService.deleteTransaction(userId, txnId);
    } catch (e) {
      debugPrint('Push delete transaction failed: $e');
    }
  }

  Future<void> pushBalance(DailyBalance balance) async {
    try {
      await _firebaseService.saveBalance(balance);
    } catch (e) {
      debugPrint('Push balance failed: $e');
    }
  }

  Future<void> pushDeleteBalance(String userId, String dateKey) async {
    try {
      await _firebaseService.deleteBalance(userId, dateKey);
    } catch (e) {
      debugPrint('Push delete balance failed: $e');
    }
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<void> pushAccounts(String userId, List<BankAccount> accounts) async {
    try {
      final data = {'accounts': accounts.map((a) => a.toJson()).toList()};
      await _firebaseService.saveSettings(userId, 'accounts', data);
    } catch (e) {
      debugPrint('Push accounts failed: $e');
    }
  }

  Future<List<BankAccount>> pullAccounts(String userId) async {
    try {
      final data = await _firebaseService.getSettings(userId, 'accounts');
      if (data == null || data['accounts'] == null) return [];
      return (data['accounts'] as List)
          .map((j) => BankAccount.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Pull accounts failed: $e');
      return [];
    }
  }

  Future<void> pushCommissionConfigs(String userId, Map<String, dynamic> configs) async {
    try {
      await _firebaseService.saveSettings(userId, 'commissions', configs);
    } catch (e) {
      debugPrint('Push commission configs failed: $e');
    }
  }

  Future<Map<String, dynamic>> pullCommissionConfigs(String userId) async {
    try {
      final data = await _firebaseService.getSettings(userId, 'commissions');
      return data ?? {};
    } catch (e) {
      debugPrint('Pull commission configs failed: $e');
      return {};
    }
  }

  Future<void> pushAiSettings(String userId, Map<String, dynamic> settings) async {
    try {
      await _firebaseService.saveSettings(userId, 'ai_settings', settings);
    } catch (e) {
      debugPrint('Push AI settings failed: $e');
    }
  }

  Future<Map<String, dynamic>> pullAiSettings(String userId) async {
    try {
      final data = await _firebaseService.getSettings(userId, 'ai_settings');
      return data ?? {};
    } catch (e) {
      debugPrint('Pull AI settings failed: $e');
      return {};
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
