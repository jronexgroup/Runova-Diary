import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_account.dart';
import '../models/ai_settings.dart';
import '../models/commission_config.dart';
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
    if (state != null) {
      final sync = _ref.read(syncServiceProvider);
      await sync.syncFromFirebase();
      _ref.read(transactionsProvider.notifier).loadTransactions(state!.id);
      _ref.read(balancesProvider.notifier).loadBalances(state!.id);
      await       _ref.read(accountsProvider.notifier).load(state!.id);
      _ref.read(commissionConfigsProvider.notifier).load(state!.id);
      _ref.read(aiSettingsProvider.notifier).load(state!.id);
    }
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
      await       _ref.read(accountsProvider.notifier).load(user.id);
      _ref.read(commissionConfigsProvider.notifier).load(user.id);
      _ref.read(aiSettingsProvider.notifier).load(user.id);
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
    String? account,
    String? fromAccount,
    String? toAccount,
    double? distributorCommission,
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
      account: account,
      fromAccount: fromAccount,
      toAccount: toAccount,
      distributorCommission: distributorCommission,
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
    final toDelete = state.where((t) => t.createdAt.dateKey == dateKey).toList();
    final count = await hive.deleteTransactionsForDate(userId, dateKey);
    state = state.where((t) => t.createdAt.dateKey != dateKey).toList();
    final sync = _ref.read(syncServiceProvider);
    for (final txn in toDelete) {
      await sync.pushDeleteTransaction(userId, txn.id);
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
    final yesterdayCustom = yesterday?.customClosingBalances ?? yesterday?.customOpeningBalances ?? {};

    final balance = DailyBalance.create(
      dateKey: dateKey,
      userId: userId,
      aepsOpeningBalance: yesterday?.aepsClosingBalance ?? aepsOpening,
      hasibulOpeningBalance: yesterday?.hasibulClosingBalance ?? hasibulOpening,
      runaLailaOpeningBalance: yesterday?.runaLailaClosingBalance ?? runaLailaOpening,
      customOpening: yesterdayCustom,
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

    final customBal = Map<String, double>.from(balance.customOpeningBalances);

    String resolveAccountId(Transaction txn) {
      return txn.account ?? txn.phonePeAccount?.name ?? '';
    }

    void adjustBalance(String acctId, double amount) {
      switch (acctId) {
        case 'aeps':
          aepsClosing += amount;
        case 'hasibul':
          hasibulClosing += amount;
        case 'runaLaila':
          runaLailaClosing += amount;
        default:
          customBal[acctId] = (customBal[acctId] ?? 0) + amount;
      }
    }

    for (final txn in dayTxns) {
      switch (txn.type) {
        case TransactionType.aeps:
          aepsClosing += txn.amount + txn.distributorCommission;
        case TransactionType.cashIn:
          adjustBalance(resolveAccountId(txn), txn.amount);
        case TransactionType.cashOut:
          adjustBalance(resolveAccountId(txn), -txn.amount);
        case TransactionType.balanceAdjustment:
          adjustBalance(txn.account ?? '', txn.amount);
        case TransactionType.selfTransfer:
          adjustBalance(txn.fromAccount ?? '', -(txn.amount + txn.commission));
          adjustBalance(txn.toAccount ?? '', txn.amount);
      }
    }

    final updated = balance.copyWith(
      aepsClosingBalance: aepsClosing,
      hasibulClosingBalance: hasibulClosing,
      runaLailaClosingBalance: runaLailaClosing,
      customClosingBalances: customBal,
    );
    await hive.saveBalance(updated);
    _ref.read(syncServiceProvider).pushBalance(updated);
    state = {...state, dateKey: updated};
  }

  Future<void> recalculateDayBalances(String userId, String dateKey) async {
    await recalculateBalance(userId, dateKey);
  }
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, List<BankAccount>>((ref) {
  return AccountsNotifier(ref);
});

class AccountsNotifier extends StateNotifier<List<BankAccount>> {
  final Ref _ref;

  AccountsNotifier(this._ref) : super([]);

  Future<void> load(String userId) async {
    final json = _ref.read(hiveServiceProvider).getAccountsJson(userId);
    if (json != null) {
      try {
        final list = (jsonDecode(json) as List)
            .map((j) => BankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        state = list;
        return;
      } catch (_) {}
    }
    state = _defaultAccounts();
    await save(userId);
  }

  List<BankAccount> _defaultAccounts() => [
    BankAccount.create(id: 'hasibul', name: 'Hasibul', holderName: '', bankName: 'PhonePe'),
    BankAccount.create(id: 'runaLaila', name: 'Runa Laila', holderName: '', bankName: 'PhonePe'),
  ];

  Future<void> save(String userId) async {
    final jsonStr = jsonEncode(state.map((a) => a.toJson()).toList());
    await _ref.read(hiveServiceProvider).saveAccountsJson(userId, jsonStr);
    _ref.read(syncServiceProvider).pushAccounts(userId, state);
  }

  Future<void> addAccount(BankAccount account, String userId) async {
    if (state.length >= 5) return;
    state = [...state, account];
    await save(userId);
  }

  Future<void> updateAccount(int index, BankAccount account, String userId) async {
    final list = [...state];
    list[index] = account;
    state = list;
    await save(userId);
  }

  Future<void> deleteAccount(int index, String userId) async {
    final list = [...state];
    list.removeAt(index);
    state = list;
    await save(userId);
  }
}

final commissionConfigsProvider = StateNotifierProvider<CommissionConfigsNotifier, Map<String, dynamic>>((ref) {
  return CommissionConfigsNotifier(ref);
});

class CommissionConfigsNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref _ref;

  CommissionConfigsNotifier(this._ref) : super({});

  void load(String userId) {
    final json = _ref.read(hiveServiceProvider).getCommissionConfigsJson(userId);
    if (json != null) {
      try {
        state = jsonDecode(json) as Map<String, dynamic>;
        return;
      } catch (_) {}
    }
    state = _defaults();
  }

  Map<String, dynamic> _defaults() => {
    'aeps': const AepsCommissionConfig().toJson(),
    'distributor': DistributorRange.defaults.map((r) => r.toJson()).toList(),
    'settlement': SettlementRange.defaults.map((r) => r.toJson()).toList(),
  };

  Future<void> save(String userId) async {
    final jsonStr = jsonEncode(state);
    await _ref.read(hiveServiceProvider).saveCommissionConfigsJson(userId, jsonStr);
    _ref.read(syncServiceProvider).pushCommissionConfigs(userId, state);
  }

  CommissionConfig getAccountConfig(String accountId) {
    final data = state[accountId];
    if (data != null) {
      return CommissionConfig.fromJson(data as Map<String, dynamic>);
    }
    return const CommissionConfig();
  }

  AepsCommissionConfig getAepsConfig() {
    final data = state['aeps'];
    if (data != null) {
      return AepsCommissionConfig.fromJson(data as Map<String, dynamic>);
    }
    return const AepsCommissionConfig();
  }

  List<DistributorRange> getDistributorRanges() {
    final data = state['distributor'];
    if (data != null) {
      try {
        return (data as List).map((j) => DistributorRange.fromJson(j as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return List.from(DistributorRange.defaults);
  }

  Future<void> setDistributorRanges(List<DistributorRange> ranges, String userId) async {
    state = {...state, 'distributor': ranges.map((r) => r.toJson()).toList()};
    await save(userId);
  }

  List<SettlementRange> getSettlementRanges() {
    final data = state['settlement'];
    if (data != null) {
      try {
        return (data as List).map((j) => SettlementRange.fromJson(j as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return List.from(SettlementRange.defaults);
  }

  Future<void> setSettlementRanges(List<SettlementRange> ranges, String userId) async {
    state = {...state, 'settlement': ranges.map((r) => r.toJson()).toList()};
    await save(userId);
  }

  Future<void> setAccountConfig(String accountId, CommissionConfig config, String userId) async {
    state = {...state, accountId: config.toJson()};
    await save(userId);
  }

  Future<void> setAepsConfig(AepsCommissionConfig config, String userId) async {
    state = {...state, 'aeps': config.toJson()};
    await save(userId);
  }
}

final aiSettingsProvider = StateNotifierProvider<AiSettingsNotifier, AiSettings>((ref) {
  return AiSettingsNotifier(ref);
});

class AiSettingsNotifier extends StateNotifier<AiSettings> {
  final Ref _ref;

  AiSettingsNotifier(this._ref) : super(const AiSettings());

  void load(String userId) {
    final json = _ref.read(hiveServiceProvider).getAiSettingsJson(userId);
    if (json != null) {
      try {
        final parsed = AiSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
        state = parsed.copyWith(enabled: parsed.apiKey.isNotEmpty);
        return;
      } catch (_) {}
    }
    state = const AiSettings();
  }

  Future<void> save(String userId) async {
    await _ref.read(hiveServiceProvider).saveAiSettingsJson(userId, jsonEncode(state.toJson()));
    _ref.read(syncServiceProvider).pushAiSettings(userId, state.toJson());
  }

  Future<void> setApiKey(String key, String userId) async {
    state = state.copyWith(apiKey: key, enabled: key.isNotEmpty);
    await save(userId);
  }

  Future<void> setEnabled(bool enabled, String userId) async {
    state = state.copyWith(enabled: enabled);
    await save(userId);
  }

  Future<void> update(AiSettings updated, String userId) async {
    state = updated.copyWith(enabled: updated.apiKey.isNotEmpty);
    await save(userId);
  }
}
