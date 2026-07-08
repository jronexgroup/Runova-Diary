import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_balance.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/commission_service.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

final hiveServiceProvider = Provider<HiveService>((ref) => HiveService());

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(hiveServiceProvider),
    ref.watch(firebaseServiceProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final firebase = ref.watch(firebaseServiceProvider);
  return AuthService(hive, firebase);
});

final commissionServiceProvider = Provider<CommissionService>((ref) => CommissionService());

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AppUser?> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(null);

  Future<void> register({
    required String phoneNumber,
    required String shopName,
    required String ownerName,
    required String pin,
  }) async {
    final user = await _ref.read(authServiceProvider).register(
      phoneNumber: phoneNumber,
      shopName: shopName,
      ownerName: ownerName,
      pin: pin,
    );
    state = user;
  }

  Future<bool> login({
    required String phoneNumber,
    required String pin,
  }) async {
    final user = await _ref.read(authServiceProvider).login(
      phoneNumber: phoneNumber,
      pin: pin,
    );
    state = user;
    if (user != null) {
      final sync = _ref.read(syncServiceProvider);
      await sync.syncFromFirebase();
      _ref.read(transactionsProvider.notifier).loadTransactions(user.id);
      _ref.read(balancesProvider.notifier).loadBalances(user.id);
    }
    return user != null;
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    state = null;
  }

  Future<void> changePin(String oldPin, String newPin) async {
    await _ref.read(authServiceProvider).changePin(oldPin, newPin);
  }

  void setUser(AppUser user) {
    state = user;
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, List<Transaction>>((ref) {
  return TransactionsNotifier(ref);
});

class TransactionsNotifier extends StateNotifier<List<Transaction>> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super([]);

  void loadTransactions(String userId) {
    final hive = _ref.read(hiveServiceProvider);
    state = hive.getTransactions(userId);
  }

  Future<void> addTransaction({
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
    bool commissionOverridden = false,
    String? signatureData,
    String? account,
    String? fromAccount,
    String? toAccount,
  }) async {
    final txn = Transaction.create(
      type: type,
      customerName: customerName,
      amount: amount,
      balanceAfterTransaction: balanceAfterTransaction,
      userId: userId,
      mobileNumber: mobileNumber,
      aadhaarNumber: aadhaarNumber,
      transactionId: transactionId,
      notes: notes,
      bankName: bankName,
      phonePeAccount: phonePeAccount,
      commission: commission,
      commissionOverridden: commissionOverridden,
      signatureData: signatureData,
      account: account,
      fromAccount: fromAccount,
      toAccount: toAccount,
    );
    final hive = _ref.read(hiveServiceProvider);
    await hive.saveTransaction(txn);
    state = [...state, txn];
    _ref.read(syncServiceProvider).pushTransaction(txn);
    await _ref.read(balancesProvider.notifier).recalculateBalance(userId, txn.createdAt.dateKey);
  }

  Future<void> updateTransaction(Transaction oldTxn, Transaction newTxn) async {
    final hive = _ref.read(hiveServiceProvider);
    await hive.deleteTransaction(oldTxn.userId, oldTxn.id);
    await hive.saveTransaction(newTxn);
    state = state.map((t) => t.id == oldTxn.id ? newTxn : t).toList();
    await _ref.read(balancesProvider.notifier).recalculateDayBalances(newTxn.userId, newTxn.createdAt.dateKey);
  }

  Future<void> deleteTransaction(String userId, String txnId, String dateKey) async {
    final hive = _ref.read(hiveServiceProvider);
    await hive.deleteTransaction(userId, txnId);
    state = state.where((t) => t.id != txnId).toList();
    _ref.read(syncServiceProvider).pushDeleteTransaction(userId, txnId);
    await _ref.read(balancesProvider.notifier).recalculateDayBalances(userId, dateKey);
  }

  Future<int> deleteTransactionsForDate(String userId, String dateKey) async {
    final hive = _ref.read(hiveServiceProvider);
    final count = await hive.deleteTransactionsForDate(userId, dateKey);
    state = state.where((t) => t.createdAt.dateKey != dateKey).toList();
    final sync = _ref.read(syncServiceProvider);
    for (final txn in state) {
      if (txn.createdAt.dateKey == dateKey) {
        await sync.pushDeleteTransaction(userId, txn.id);
      }
    }
    await _ref.read(balancesProvider.notifier).recalculateDayBalances(userId, dateKey);
    return count;
  }

  List<Transaction> searchTransactions(String query) {
    final q = query.toLowerCase();
    return state.where((t) {
      if (t.customerName.toLowerCase().contains(q)) return true;
      if (t.mobileNumber?.toLowerCase().contains(q) == true) return true;
      if (t.transactionId?.toLowerCase().contains(q) == true) return true;
      if (t.bankName?.toLowerCase().contains(q) == true) return true;
      if (t.notes?.toLowerCase().contains(q) == true) return true;
      if (t.account?.toLowerCase().contains(q) == true) return true;
      if (t.fromAccount?.toLowerCase().contains(q) == true) return true;
      if (t.toAccount?.toLowerCase().contains(q) == true) return true;
      if (t.aadhaarNumber?.toLowerCase().contains(q) == true) return true;
      if (t.type.displayName.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  List<Transaction> filterByDate(DateTime date) {
    return state.where((t) => t.createdAt.isSameDay(date)).toList();
  }

  List<Transaction> filterByType(TransactionType type) {
    return state.where((t) => t.type == type).toList();
  }

  List<Transaction> filterByDateRange(DateTime start, DateTime end) {
    return state.where((t) =>
        t.createdAt.isAfter(start.subtract(const Duration(days: 1))) &&
        t.createdAt.isBefore(end.add(const Duration(days: 1)))).toList();
  }
}

final balancesProvider = StateNotifierProvider<BalancesNotifier, Map<String, DailyBalance>>((ref) {
  return BalancesNotifier(ref);
});

class BalancesNotifier extends StateNotifier<Map<String, DailyBalance>> {
  final Ref _ref;

  BalancesNotifier(this._ref) : super({});

  DailyBalance? getBalance(String dateKey) => state[dateKey];

  void loadBalances(String userId) {
    final hive = _ref.read(hiveServiceProvider);
    final all = hive.getAllBalances(userId);
    final map = <String, DailyBalance>{};
    for (final b in all) {
      map[b.dateKey] = b;
    }
    state = map;
  }

  Future<DailyBalance> ensureBalance(String userId, String dateKey,
      {double aepsOpening = 0, double hasibulOpening = 0, double runaLailaOpening = 0}) async {
    final hive = _ref.read(hiveServiceProvider);
    final existing = state[dateKey] ?? hive.getBalance(userId, dateKey);
    if (existing != null) return existing;

    final yesterdayKey = DateTime.parse(dateKey)
        .subtract(const Duration(days: 1))
        .dateKey;
    final yesterday = state[yesterdayKey] ?? hive.getBalance(userId, yesterdayKey);

    final balance = DailyBalance.create(
      dateKey: dateKey,
      userId: userId,
      aepsOpeningBalance: yesterday?.aepsClosingBalance ?? aepsOpening,
      hasibulOpeningBalance: yesterday?.hasibulClosingBalance ?? hasibulOpening,
      runaLailaOpeningBalance: yesterday?.runaLailaClosingBalance ?? runaLailaOpening,
    );
    await hive.saveBalance(balance);
    _ref.read(syncServiceProvider).pushBalance(balance);
    state = {...state, dateKey: balance};
    return balance;
  }

  Future<void> updateOpeningBalances({
    required String userId,
    required String dateKey,
    double? aepsOpening,
    double? hasibulOpening,
    double? runaLailaOpening,
  }) async {
    final hive = _ref.read(hiveServiceProvider);
    final balance = state[dateKey];
    if (balance == null) return;

    final updated = balance.copyWith(
      aepsOpeningBalance: aepsOpening ?? balance.aepsOpeningBalance,
      hasibulOpeningBalance: hasibulOpening ?? balance.hasibulOpeningBalance,
      runaLailaOpeningBalance: runaLailaOpening ?? balance.runaLailaOpeningBalance,
    );
    await hive.saveBalance(updated);
    _ref.read(syncServiceProvider).pushBalance(updated);
    state = {...state, dateKey: updated};
  }

  Future<void> recalculateBalance(String userId, String dateKey) async {
    final hive = _ref.read(hiveServiceProvider);
    final existing = state[dateKey];
    final balance = existing ?? await ensureBalance(userId, dateKey);

    final transactions = _ref.read(transactionsProvider);
    final dayTxns = transactions.where((t) => t.createdAt.dateKey == dateKey).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    double aepsClosing = balance.aepsOpeningBalance;
    double hasibulClosing = balance.hasibulOpeningBalance;
    double runaLailaClosing = balance.runaLailaOpeningBalance;

    for (final txn in dayTxns) {
      switch (txn.type) {
        case TransactionType.aeps:
          aepsClosing += txn.amount;
        case TransactionType.cashIn:
          if (txn.phonePeAccount == PhonePeAccount.hasibul) {
            hasibulClosing += txn.amount;
          } else {
            runaLailaClosing += txn.amount;
          }
        case TransactionType.cashOut:
          if (txn.phonePeAccount == PhonePeAccount.hasibul) {
            hasibulClosing -= txn.amount;
          } else {
            runaLailaClosing -= txn.amount;
          }
        case TransactionType.balanceAdjustment:
          switch (txn.account) {
            case 'aeps':
              aepsClosing += txn.amount;
            case 'hasibul':
              hasibulClosing += txn.amount;
            case 'runaLaila':
              runaLailaClosing += txn.amount;
          }
        case TransactionType.selfTransfer:
          switch (txn.fromAccount) {
            case 'aeps':
              aepsClosing -= txn.amount;
            case 'hasibul':
              hasibulClosing -= txn.amount;
            case 'runaLaila':
              runaLailaClosing -= txn.amount;
          }
          switch (txn.toAccount) {
            case 'aeps':
              aepsClosing += txn.amount;
            case 'hasibul':
              hasibulClosing += txn.amount;
            case 'runaLaila':
              runaLailaClosing += txn.amount;
          }
      }
    }

    final updated = balance.copyWith(
      aepsClosingBalance: aepsClosing,
      hasibulClosingBalance: hasibulClosing,
      runaLailaClosingBalance: runaLailaClosing,
    );
    await hive.saveBalance(updated);
    _ref.read(syncServiceProvider).pushBalance(updated);
    state = {...state, dateKey: updated};
  }

  Future<void> recalculateDayBalances(String userId, String dateKey) async {
    await recalculateBalance(userId, dateKey);
  }
}
