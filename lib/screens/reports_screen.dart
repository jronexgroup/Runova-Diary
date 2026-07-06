import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedRange = 'today';
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionsProvider);
    final balances = ref.watch(balancesProvider);

    List<Transaction> filtered;
    String label;
    DateTime? targetDate;

    final now = DateTime.now();
    switch (_selectedRange) {
      case 'today':
        filtered = allTransactions.where((t) => t.createdAt.isToday).toList();
        label = 'Today';
        targetDate = now;
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        filtered = allTransactions.where((t) => t.createdAt.isYesterday).toList();
        label = 'Yesterday';
        targetDate = yesterday;
        break;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        filtered = allTransactions.where((t) =>
            t.createdAt.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            t.createdAt.isBefore(now.add(const Duration(days: 1)))).toList();
        label = 'This Week';
        targetDate = null;
        break;
      case 'month':
        final monthStart = DateTime(now.year, now.month, 1);
        filtered = allTransactions.where((t) =>
            t.createdAt.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.createdAt.isBefore(now.add(const Duration(days: 1)))).toList();
        label = 'This Month';
        targetDate = null;
        break;
      case 'custom':
        if (_customStart != null && _customEnd != null) {
          filtered = allTransactions.where((t) =>
              t.createdAt.isAfter(_customStart!.subtract(const Duration(days: 1))) &&
              t.createdAt.isBefore(_customEnd!.add(const Duration(days: 1)))).toList();
          label = '${_customStart!.displayDate} - ${_customEnd!.displayDate}';
          targetDate = null;
        } else {
          filtered = allTransactions;
          label = 'Custom Range';
          targetDate = null;
        }
        break;
      default:
        filtered = allTransactions;
        label = 'All Time';
        targetDate = null;
    }

    final totalAmount = filtered.fold(0.0, (s, t) => s + t.amount);
    final aepsTotal = filtered.where((t) => t.type == TransactionType.aeps)
        .fold(0.0, (s, t) => s + t.amount);
    final cashInTotal = filtered.where((t) => t.type == TransactionType.cashIn)
        .fold(0.0, (s, t) => s + t.amount);
    final cashOutTotal = filtered.where((t) => t.type == TransactionType.cashOut)
        .fold(0.0, (s, t) => s + t.amount);
    final totalCommission = filtered.fold(0.0, (s, t) => s + t.commission);

    final dateKey = targetDate?.dateKey ?? (_customEnd?.dateKey ?? now.dateKey);
    final dayBalance = balances[dateKey];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _rangeChip('today', 'Today'),
                const SizedBox(width: 8),
                _rangeChip('yesterday', 'Yesterday'),
                const SizedBox(width: 8),
                _rangeChip('week', 'This Week'),
                const SizedBox(width: 8),
                _rangeChip('month', 'This Month'),
                const SizedBox(width: 8),
                _rangeChip('custom', 'Custom'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(label, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reportRow('Total Transactions', filtered.length.toString()),
                  const Divider(),
                  _reportRow('Total Amount', '₹${totalAmount.toStringAsFixed(2)}',
                      isBold: true),
                  const Divider(),
                  _reportRow('AEPS Total', '₹${aepsTotal.toStringAsFixed(2)}'),
                  const Divider(),
                  _reportRow('Cash In Total', '₹${cashInTotal.toStringAsFixed(2)}'),
                  const Divider(),
                  _reportRow('Cash Out Total', '₹${cashOutTotal.toStringAsFixed(2)}'),
                  const Divider(),
                  _reportRow('Total Commission', '₹${totalCommission.toStringAsFixed(2)}',
                      isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Balances', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reportRow('AEPS Balance',
                      '₹${(dayBalance?.aepsClosingBalance ?? 0).toStringAsFixed(2)}'),
                  const Divider(),
                  _reportRow('Hasibul PhonePe',
                      '₹${(dayBalance?.hasibulClosingBalance ?? 0).toStringAsFixed(2)}'),
                  const Divider(),
                  _reportRow('Runa Laila PhonePe',
                      '₹${(dayBalance?.runaLailaClosingBalance ?? 0).toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Transaction Details', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ...filtered.take(50).map((txn) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(txn.type).withValues(alpha: 0.2),
                    child: Text(
                      txn.type == TransactionType.aeps
                          ? 'A'
                          : txn.type == TransactionType.cashIn ? 'I' : 'O',
                      style: TextStyle(
                        color: _typeColor(txn.type),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(txn.customerName),
                  subtitle: Text(txn.createdAt.displayDateTime),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${txn.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (txn.commission > 0)
                        Text(
                          'Comm: ₹${txn.commission.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _rangeChip(String value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedRange == value,
      onSelected: (v) async {
        if (value == 'custom') {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (range != null) {
            setState(() {
              _selectedRange = value;
              _customStart = range.start;
              _customEnd = range.end;
            });
          }
        } else {
          setState(() => _selectedRange = value);
        }
      },
    );
  }

  Widget _reportRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(TransactionType type) {
    switch (type) {
      case TransactionType.aeps:
        return Colors.blue;
      case TransactionType.cashIn:
        return Colors.green;
      case TransactionType.cashOut:
        return Colors.orange;
    }
  }
}
