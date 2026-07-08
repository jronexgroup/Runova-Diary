import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  TransactionType? _typeFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _requirePin() async {
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter PIN'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
            validator: (v) =>
                v?.isEmpty ?? true ? 'Enter your PIN' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || pinCtrl.text.isEmpty) return false;
    return ref.read(authServiceProvider).verifyPin(pinCtrl.text);
  }

  List<Transaction> _filteredTransactions(List<Transaction> all) {
    var filtered = all;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((t) {
        if (t.customerName.toLowerCase().contains(query)) return true;
        if (t.mobileNumber?.toLowerCase().contains(query) == true) return true;
        if (t.transactionId?.toLowerCase().contains(query) == true) return true;
        if (t.bankName?.toLowerCase().contains(query) == true) return true;
        if (t.notes?.toLowerCase().contains(query) == true) return true;
        if (t.aadhaarNumber?.toLowerCase().contains(query) == true) return true;
        if (t.type.displayName.toLowerCase().contains(query)) return true;
        return false;
      }).toList();
    }

    if (_typeFilter != null) {
      filtered = filtered.where((t) => t.type == _typeFilter).toList();
    }

    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((t) =>
          t.createdAt.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
          t.createdAt.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }

    return filtered;
  }

  Future<void> _deleteTransaction(Transaction txn) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Delete transaction for ${txn.customerName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(transactionsProvider.notifier)
          .deleteTransaction(txn.userId, txn.id, txn.createdAt.dateKey);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final pinOk = await _requirePin();
    if (!pinOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text('Delete ${_selectedIds.length} transaction(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final txns = ref.read(transactionsProvider);
    for (final txn in txns.where((t) => _selectedIds.contains(t.id))) {
      await ref.read(transactionsProvider.notifier)
          .deleteTransaction(txn.userId, txn.id, txn.createdAt.dateKey);
    }

    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteTransactionsForDate(DateTime date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Date'),
        content: Text('Delete all transactions for ${date.displayDate}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final pinOk = await _requirePin();
    if (!pinOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN')),
        );
      }
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    final dateKey = date.dateKey;
    await ref.read(transactionsProvider.notifier).deleteTransactionsForDate(user.id, dateKey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transactions deleted for ${date.displayDate}')),
      );
    }
  }

  Future<void> _duplicateTransaction(Transaction txn) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final balance = txn.balanceAfterTransaction;
    await ref.read(transactionsProvider.notifier).addTransaction(
      type: txn.type,
      customerName: txn.customerName,
      amount: txn.amount,
      balanceAfterTransaction: balance,
      userId: user.id,
      mobileNumber: txn.mobileNumber,
      aadhaarNumber: txn.aadhaarNumber,
      transactionId: txn.transactionId,
      notes: txn.notes,
      bankName: txn.bankName,
      phonePeAccount: txn.phonePeAccount,
      commission: txn.commission,
      commissionOverridden: txn.commissionOverridden,
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

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.aeps:
        return 'AEPS';
      case TransactionType.cashIn:
        return 'IN';
      case TransactionType.cashOut:
        return 'OUT';
      case TransactionType.balanceAdjustment:
        return 'ADJ';
      case TransactionType.selfTransfer:
        return 'TRF';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionsProvider);
    final filtered = _filteredTransactions(allTransactions);

    void openDetail(Transaction t) => context.push('/transaction-detail/${t.id}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          if (_multiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _multiSelectMode = false;
                _selectedIds.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _multiSelectMode = true),
              tooltip: 'Select multiple',
            ),
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_showFilters) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(Icons.today, size: 18),
                      label: const Text('Today'),
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = now;
                          _endDate = now;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(Icons.date_range, size: 18),
                      label: const Text('Yesterday'),
                      onPressed: () {
                        final yesterday = DateTime.now().subtract(const Duration(days: 1));
                        setState(() {
                          _startDate = yesterday;
                          _endDate = yesterday;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(Icons.date_range, size: 18),
                      label: const Text('Pick Date'),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = date;
                            _endDate = date;
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(Icons.date_range, size: 18),
                      label: const Text('Custom'),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (range != null) {
                          setState(() {
                            _startDate = range.start;
                            _endDate = range.end;
                          });
                        }
                      },
                    ),
                  ),
                  if (_startDate != null && _endDate != null && _startDate == _endDate)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: Icon(Icons.delete, size: 18, color: Colors.red),
                        label: const Text('Delete Date', style: TextStyle(color: Colors.red)),
                        onPressed: () => _deleteTransactionsForDate(_startDate!),
                      ),
                    ),
                  if (_startDate != null || _typeFilter != null)
                    ActionChip(
                      avatar: Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                      onPressed: () => setState(() {
                        _typeFilter = null;
                        _startDate = null;
                        _endDate = null;
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_multiSelectMode && _selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '${_selectedIds.length} selected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('No transactions found',
                            style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final txn = filtered[i];
                      return Dismissible(
                        key: Key(txn.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          final pinOk = await _requirePin();
                          if (!pinOk) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Incorrect PIN')),
                              );
                            }
                            return;
                          }
                          _deleteTransaction(txn);
                        },
                        child: Card(
                          child: ListTile(
                            onTap: _multiSelectMode
                                ? () {
                                    setState(() {
                                      if (_selectedIds.contains(txn.id)) {
                                        _selectedIds.remove(txn.id);
                                      } else {
                                        _selectedIds.add(txn.id);
                                      }
                                    });
                                  }
                                : () => openDetail(txn),
                            leading: _multiSelectMode
                                ? Checkbox(
                                    value: _selectedIds.contains(txn.id),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedIds.add(txn.id);
                                        } else {
                                          _selectedIds.remove(txn.id);
                                        }
                                      });
                                    },
                                  )
                                : CircleAvatar(
                                    backgroundColor: _typeColor(txn.type).withValues(alpha: 0.2),
                                    child: Text(
                                      _typeLabel(txn.type),
                                      style: TextStyle(
                                        color: _typeColor(txn.type),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                            title: Text(
                              txn.customerName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '₹${txn.amount.toStringAsFixed(0)} • ${txn.createdAt.displayTime}',
                            ),
                            trailing: _multiSelectMode
                                ? null
                                : PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      final pinOk = await _requirePin();
                                      if (!pinOk) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Incorrect PIN')),
                                          );
                                        }
                                        return;
                                      }
                                      switch (v) {
                                        case 'edit':
                                          if (context.mounted) context.push('/edit-transaction/${txn.id}');
                                        case 'duplicate':
                                          _duplicateTransaction(txn);
                                        case 'delete':
                                          _deleteTransaction(txn);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit),
                                          title: Text('Edit'),
                                          dense: true,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'duplicate',
                                        child: ListTile(
                                          leading: Icon(Icons.copy),
                                          title: Text('Duplicate'),
                                          dense: true,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete, color: Colors.red),
                                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                                          dense: true,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
