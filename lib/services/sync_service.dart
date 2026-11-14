import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/bank_account.dart';
import '../models/daily_balance.dart';
import '../models/transaction.dart';
import 'hive_service.dart';
import 'firebase_service.dart';

/// Syncs local Hive data to Firebase.
///
/// Push strategy:
/// - The first successful sync of a session performs a **full baseline push**
///   (reconciles the entire local dataset, as before).
/// - Afterwards, connectivity-triggered syncs are **delta pushes**: only items
///   that changed since the last successful push are sent, and offline
///   deletions are replayed.
/// - Manual "Sync Now" forces a full push via [syncToFirebase] with `full: true`.
class SyncService {
  final HiveService _hiveService;
  final FirebaseService _firebaseService;
  StreamSubscription? _connectivitySubscription;

  /// Unpushed local changes, keyed by transaction id / balance dateKey.
  final Map<String, Transaction> _dirtyTransactions = {};
  final Map<String, DailyBalance> _dirtyBalances = {};

  /// Offline deletions waiting to be replayed on Firebase.
  final Set<String> _pendingTxnDeletes = {};
  final Set<String> _pendingBalanceDeletes = {};

  bool _dirtyAccounts = false;
  bool _dirtyCommissionConfigs = false;
  bool _dirtyAiSettings = false;

  /// Whether the baseline (full) push has completed this session.
  bool _needsBaselinePush = true;

  /// Guards against concurrent sync runs.
  Future<void>? _ongoingSync;

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

  /// Pushes local changes to Firebase.
  ///
  /// [full] forces pushing the entire local dataset (used by manual sync).
  /// Concurrent calls are coalesced into a single run.
  Future<void> syncToFirebase({bool full = false}) {
    return _ongoingSync ??= _syncToFirebase(full: full)
        .whenComplete(() => _ongoingSync = null);
  }

  Future<void> _syncToFirebase({bool full = false}) async {
    final user = _hiveService.getUser();
    if (user == null) return;

    if (full || _needsBaselinePush) {
      await _fullPush(user.id);
    } else {
      await _flushDirty(user.id);
    }
  }

  Future<void> _fullPush(String userId) async {
    try {
      final transactions = _hiveService.getTransactions(userId);
      for (final txn in transactions) {
        await _firebaseService.saveTransaction(txn);
      }

      final balances = _hiveService.getAllBalances(userId);
      for (final bal in balances) {
        await _firebaseService.saveBalance(bal);
      }

      final accountsJson = _hiveService.getAccountsJson(userId);
      if (accountsJson != null) {
        final accounts = (jsonDecode(accountsJson) as List)
            .map((j) => BankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        await pushAccounts(userId, accounts);
      }

      final configsJson = _hiveService.getCommissionConfigsJson(userId);
      if (configsJson != null) {
        await pushCommissionConfigs(userId, jsonDecode(configsJson) as Map<String, dynamic>);
      }

      final aiJson = _hiveService.getAiSettingsJson(userId);
      if (aiJson != null) {
        await pushAiSettings(userId, jsonDecode(aiJson) as Map<String, dynamic>);
      }

      _needsBaselinePush = false;
      _dirtyTransactions.clear();
      _dirtyBalances.clear();
      _pendingTxnDeletes.clear();
      _pendingBalanceDeletes.clear();
      _dirtyAccounts = false;
      _dirtyCommissionConfigs = false;
      _dirtyAiSettings = false;
    } catch (e) {
      debugPrint('Sync to Firebase failed: $e');
    }
  }

  /// Pushes only the changes recorded since the last successful push.
  Future<void> _flushDirty(String userId) async {
    final hasDirty = _dirtyTransactions.isNotEmpty ||
        _dirtyBalances.isNotEmpty ||
        _pendingTxnDeletes.isNotEmpty ||
        _pendingBalanceDeletes.isNotEmpty ||
        _dirtyAccounts ||
        _dirtyCommissionConfigs ||
        _dirtyAiSettings;
    if (!hasDirty) return;

    debugPrint(
      'Delta sync: ${_dirtyTransactions.length} transactions, '
      '${_dirtyBalances.length} balances, '
      '${_pendingTxnDeletes.length} txn deletes, '
      '${_pendingBalanceDeletes.length} balance deletes, '
      'accounts=$_dirtyAccounts commissions=$_dirtyCommissionConfigs ai=$_dirtyAiSettings',
    );

    for (final txn in List.of(_dirtyTransactions.values)) {
      await _pushTransactionNow(txn);
    }

    for (final balance in List.of(_dirtyBalances.values)) {
      await _pushBalanceNow(balance);
    }

    for (final txnId in Set.of(_pendingTxnDeletes)) {
      await pushDeleteTransaction(userId, txnId);
    }

    for (final dateKey in Set.of(_pendingBalanceDeletes)) {
      await pushDeleteBalance(userId, dateKey);
    }

    if (_dirtyAccounts) {
      final accountsJson = _hiveService.getAccountsJson(userId);
      if (accountsJson != null) {
        final accounts = (jsonDecode(accountsJson) as List)
            .map((j) => BankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        await pushAccounts(userId, accounts);
      }
    }

    if (_dirtyCommissionConfigs) {
      final configsJson = _hiveService.getCommissionConfigsJson(userId);
      if (configsJson != null) {
        await pushCommissionConfigs(userId, jsonDecode(configsJson) as Map<String, dynamic>);
      }
    }

    if (_dirtyAiSettings) {
      final aiJson = _hiveService.getAiSettingsJson(userId);
      if (aiJson != null) {
        await pushAiSettings(userId, jsonDecode(aiJson) as Map<String, dynamic>);
      }
    }
  }

  Future<void> pushTransaction(Transaction txn) async {
    _dirtyTransactions[txn.id] = txn;
    await _pushTransactionNow(txn);
  }

  Future<void> _pushTransactionNow(Transaction txn) async {
    try {
      await _firebaseService.saveTransaction(txn);
      _dirtyTransactions.remove(txn.id);
    } catch (e) {
      debugPrint('Push transaction failed: $e');
    }
  }

  Future<void> pushDeleteTransaction(String userId, String txnId) async {
    _dirtyTransactions.remove(txnId);
    try {
      await _firebaseService.deleteTransaction(userId, txnId);
      _pendingTxnDeletes.remove(txnId);
    } catch (e) {
      _pendingTxnDeletes.add(txnId);
      debugPrint('Push delete transaction failed: $e');
    }
  }

  Future<void> pushBalance(DailyBalance balance) async {
    _dirtyBalances[balance.dateKey] = balance;
    await _pushBalanceNow(balance);
  }

  Future<void> _pushBalanceNow(DailyBalance balance) async {
    try {
      await _firebaseService.saveBalance(balance);
      _dirtyBalances.remove(balance.dateKey);
    } catch (e) {
      debugPrint('Push balance failed: $e');
    }
  }

  Future<void> pushDeleteBalance(String userId, String dateKey) async {
    _dirtyBalances.remove(dateKey);
    try {
      await _firebaseService.deleteBalance(userId, dateKey);
      _pendingBalanceDeletes.remove(dateKey);
    } catch (e) {
      _pendingBalanceDeletes.add(dateKey);
      debugPrint('Push delete balance failed: $e');
    }
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<void> pushAccounts(String userId, List<BankAccount> accounts) async {
    _dirtyAccounts = true;
    try {
      final data = {'accounts': accounts.map((a) => a.toJson()).toList()};
      await _firebaseService.saveSettings(userId, 'accounts', data);
      _dirtyAccounts = false;
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
    _dirtyCommissionConfigs = true;
    try {
      await _firebaseService.saveSettings(userId, 'commissions', configs);
      _dirtyCommissionConfigs = false;
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
    _dirtyAiSettings = true;
    try {
      await _firebaseService.saveSettings(userId, 'ai_settings', settings);
      _dirtyAiSettings = false;
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
