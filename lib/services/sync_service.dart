import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
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
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
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
    } catch (e) {
      debugPrint('Sync from Firebase failed: $e');
    }
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
