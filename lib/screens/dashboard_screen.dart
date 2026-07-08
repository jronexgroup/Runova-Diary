import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';
import '../widgets/summary_card.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_action_button.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final user = ref.read(authProvider);
    if (user == null) return;

    ref.read(transactionsProvider.notifier).loadTransactions(user.id);
    ref.read(balancesProvider.notifier).loadBalances(user.id);
    _ensureTodayBalance(user.id);
  }

  Future<void> _ensureTodayBalance(String userId) async {
    final todayKey = DateTime.now().dateKey;
    await ref.read(balancesProvider.notifier).ensureBalance(userId, todayKey);
    await ref.read(balancesProvider.notifier).recalculateBalance(userId, todayKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final transactions = ref.watch(transactionsProvider);
    final balances = ref.watch(balancesProvider);

    final todayKey = DateTime.now().dateKey;
    final todayBalance = balances[todayKey];
    final todayTxns = transactions.where((t) => t.createdAt.isToday).toList();

    final aepsTxns = todayTxns.where((t) => t.type == TransactionType.aeps).toList();
    final cashInTxns = todayTxns.where((t) => t.type == TransactionType.cashIn).toList();
    final cashOutTxns = todayTxns.where((t) => t.type == TransactionType.cashOut).toList();
    final todayCommission = todayTxns.fold(0.0, (sum, t) => sum + t.commission);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.shopName ?? 'Runova Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Summary", style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'AEPS',
                      count: aepsTxns.length,
                      amount: aepsTxns.fold(0.0, (s, t) => s + t.amount),
                      icon: Icons.account_balance,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryCard(
                      title: 'Cash In',
                      count: cashInTxns.length,
                      amount: cashInTxns.fold(0.0, (s, t) => s + t.amount),
                      icon: Icons.arrow_downward,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryCard(
                      title: 'Cash Out',
                      count: cashOutTxns.length,
                      amount: cashOutTxns.fold(0.0, (s, t) => s + t.amount),
                      icon: Icons.arrow_upward,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(Icons.monetization_on, color: theme.colorScheme.primary),
                  title: const Text("Today's Commission"),
                  trailing: Text(
                    '₹${todayCommission.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Current Balances', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              BalanceCard(
                label: 'AEPS Balance',
                opening: todayBalance?.aepsOpeningBalance ?? 0,
                closing: todayBalance?.aepsClosingBalance ?? 0,
                icon: Icons.account_balance,
                color: theme.colorScheme.primary,
              ),
              BalanceCard(
                label: 'Hasibul PhonePe',
                opening: todayBalance?.hasibulOpeningBalance ?? 0,
                closing: todayBalance?.hasibulClosingBalance ?? 0,
                icon: Icons.phone_android,
                color: Colors.blue,
              ),
              BalanceCard(
                label: 'Runa Laila PhonePe',
                opening: todayBalance?.runaLailaOpeningBalance ?? 0,
                closing: todayBalance?.runaLailaClosingBalance ?? 0,
                icon: Icons.phone_android,
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
              Text('Quick Actions', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: QuickActionButton(
                      label: 'New AEPS',
                      icon: Icons.account_balance,
                      color: theme.colorScheme.primary,
                      onTap: () => context.push('/new-transaction/aeps'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuickActionButton(
                      label: 'Cash In',
                      icon: Icons.arrow_downward,
                      color: Colors.green,
                      onTap: () => context.push('/new-transaction/${TransactionType.cashIn.name}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuickActionButton(
                      label: 'Cash Out',
                      icon: Icons.arrow_upward,
                      color: Colors.orange,
                      onTap: () => context.push('/new-transaction/${TransactionType.cashOut.name}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/history'),
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/reports'),
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Reports'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
