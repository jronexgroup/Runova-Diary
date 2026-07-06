import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/daily_balance.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUser(AppUser user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .set(user.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase saveUser error: $e');
      rethrow;
    }
  }

  Future<AppUser?> getUser(String phoneNumber) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return AppUser.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Firebase getUser error: $e');
      return null;
    }
  }

  Future<void> saveTransaction(Transaction transaction) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(transaction.userId)
          .collection(AppConstants.transactionsCollection)
          .doc(transaction.id)
          .set(transaction.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase saveTransaction error: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String userId, String transactionId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection)
          .doc(transactionId)
          .delete();
    } catch (e) {
      debugPrint('Firebase deleteTransaction error: $e');
      rethrow;
    }
  }

  Future<List<Transaction>> getTransactions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.transactionsCollection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return Transaction.fromJson(
          doc.data(),
          idOverride: doc.id,
        );
      }).toList();
    } catch (e) {
      debugPrint('Firebase getTransactions error: $e');
      return [];
    }
  }

  Future<void> deleteBalance(String userId, String dateKey) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.dailyBalancesCollection)
          .doc(dateKey)
          .delete();
    } catch (e) {
      debugPrint('Firebase deleteBalance error: $e');
    }
  }

  Future<void> saveBalance(DailyBalance balance) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(balance.userId)
          .collection(AppConstants.dailyBalancesCollection)
          .doc(balance.dateKey)
          .set(balance.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase saveBalance error: $e');
      rethrow;
    }
  }

  Future<DailyBalance?> getBalance(String userId, String dateKey) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.dailyBalancesCollection)
          .doc(dateKey)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return DailyBalance.fromJson(
        doc.data()!,
        idOverride: doc.id,
      );
    } catch (e) {
      debugPrint('Firebase getBalance error: $e');
      return null;
    }
  }

  Future<List<DailyBalance>> getAllBalances(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.dailyBalancesCollection)
          .orderBy('dateKey', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return DailyBalance.fromJson(
          doc.data(),
          idOverride: doc.id,
        );
      }).toList();
    } catch (e) {
      debugPrint('Firebase getAllBalances error: $e');
      return [];
    }
  }
}
