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
  String _selectedRange = 'default';
  DateTime? _customStart;
  DateTime? _customEnd;
  TransactionType? _typeFilter;

  List<Transaction> _filtered(List<Transaction> all) {
    var filtered = all;

    switch (_selectedRange) {
      case 'today':
        filtered = all.where((t) => t.createdAt.isToday).toList();
      case 'yesterday':
        filtered = all.where((t) => t.createdAt.isYesterday).toList();
      case 'custom':
        if (_customStart != null && _customEnd != null) {
          filtered = all.where((t) =>
              t.createdAt.dateKey.compareTo(_customStart!.dateKey) >= 0 &&
              t.createdAt.dateKey.compareTo(_customEnd!.dateKey) <= 0).toList();
        }
      default:
        break;
    }

    if (_typeFilter != null) {
      filtered = filtered.where((t) => t.type == _typeFilter).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionsProvider);
    final balances = ref.watch(balancesProvider);
    final accounts = ref.watch(accountsProvider);

    final filtered = _filtered(allTransactions);

    final totalAmount = filtered.fold(0.0, (s, t) => s + t.amount);
    final aepsTotal = filtered.where((t) => t.type == TransactionType.aeps)
        .fold(0.0, (s, t) => s + t.amount);
    final cashInTotal = filtered.where((t) => t.type == TransactionType.cashIn)
        .fold(0.0, (s, t) => s + t.amount);
    final cashOutTotal = filtered.where((t) => t.type == TransactionType.cashOut)
        .fold(0.0, (s, t) => s + t.amount);
    final ourCommission = filtered.fold(0.0, (s, t) => s + t.commission);
    final distributorCommission = filtered.fold(0.0, (s, t) => s + t.distributorCommission);
    final totalCommission = ourCommission + distributorCommission;

    final dateKey = _customEnd?.dateKey ?? DateTime.now().dateKey;
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
                _rangeChip('default', 'Default', Icons.home),
                const SizedBox(width: 8),
                _rangeChip('today', 'Today', Icons.today),
                const SizedBox(width: 8),
                _rangeChip('yesterday', 'Yesterday', Icons.date_range),
                const SizedBox(width: 8),
                _rangeChip('custom', 'Custom', Icons.calendar_month),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...TransactionType.values.map((type) {
                  final selected = _typeFilter == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type.displayName),
                      selected: selected,
                      onSelected: (v) =>
                          setState(() => _typeFilter = v ? type : null),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (_typeFilter != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.filter_alt, size: 16),
                      label: Text(_typeFilter!.displayName),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _typeFilter = null),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(_selectedRange == 'custom' && _customStart != null && _customEnd != null
              ? '${_customStart!.displayDate} - ${_customEnd!.displayDate}'
              : _selectedRange == 'default' ? 'Showing All' : '${_selectedRange[0].toUpperCase()}${_selectedRange.substring(1)}',
              style: theme.textTheme.titleLarge),
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
                  _reportRow('Our Commission', '₹${ourCommission.toStringAsFixed(2)}'),
                  const Divider(),
                  _reportRow('Distributor Commission', '₹${distributorCommission.toStringAsFixed(2)}'),
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
                  ...accounts.map((acc) {
                    final bal = dayBalance?.getBalance(acc.id) ?? 0;
                    return Column(
                      children: [
                        _reportRow(acc.name, '₹${bal.toStringAsFixed(2)}'),
                        const Divider(),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Transaction Details', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ...filtered.take(50).map((txn) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(txn.type).withValues(alpha: 0.2),
                    child: Text(
                      switch (txn.type) {
                        TransactionType.aeps => 'A',
                        TransactionType.cashIn => 'I',
                        TransactionType.cashOut => 'O',
                        TransactionType.balanceAdjustment => 'ADJ',
                        TransactionType.selfTransfer => 'TRF',
                      },
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
                          'Our: ₹${txn.commission.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (txn.distributorCommission > 0)
                        Text(
                          'Dist: ₹${txn.distributorCommission.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _rangeChip(String value, String label, IconData icon) {
    return FilterChip(
      avatar: Icon(icon, size: 18),
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
      case TransactionType.balanceAdjustment:
        return Colors.purple;
      case TransactionType.selfTransfer:
        return Colors.indigo;
    }
  }
}
