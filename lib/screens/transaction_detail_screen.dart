import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionsProvider);
    final txn = transactions.where((t) => t.id == transactionId).firstOrNull;

    if (txn == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Detail')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    final typeColor = switch (txn.type) {
      TransactionType.aeps => Colors.blue,
      TransactionType.cashIn => Colors.green,
      TransactionType.cashOut => Colors.orange,
      TransactionType.balanceAdjustment => Colors.purple,
      TransactionType.selfTransfer => Colors.indigo,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/edit-transaction/${txn.id}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: typeColor.withValues(alpha: 0.2),
                      child: Icon(Icons.swap_horiz, color: typeColor, size: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      txn.type.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _detailTile(theme, 'Customer Name', txn.customerName, Icons.person),
          _detailTile(theme, 'Amount', '₹${txn.amount.toStringAsFixed(2)}', Icons.currency_rupee),
          if (txn.bankName != null)
            _detailTile(theme, 'Bank Name', txn.bankName!, Icons.account_balance),
          if (txn.aadhaarNumber != null)
            _detailTile(theme, 'Aadhaar Number', txn.aadhaarNumber!, Icons.credit_card),
          if (txn.mobileNumber != null)
            _detailTile(theme, 'Mobile Number', txn.mobileNumber!, Icons.phone),
          if (txn.transactionId != null)
            _detailTile(theme, 'Transaction ID', txn.transactionId!, Icons.receipt),
          if (txn.phonePeAccount != null)
            _detailTile(theme, 'PhonePe Account', txn.phonePeAccount!.displayName, Icons.phone_android),
          if (txn.account != null) ...[
            _detailTile(theme, 'Account', _accountLabel(ref, txn.account!), Icons.account_balance),
          ],
          if (txn.fromAccount != null && txn.toAccount != null) ...[
            _detailTile(theme, 'From', _accountLabel(ref, txn.fromAccount!), Icons.arrow_forward),
            _detailTile(theme, 'To', _accountLabel(ref, txn.toAccount!), Icons.arrow_back),
          ],
          _detailTile(theme, 'Balance After', '₹${txn.balanceAfterTransaction.toStringAsFixed(2)}', Icons.account_balance_wallet),
          _detailTile(theme, 'Our Commission', '₹${txn.commission.toStringAsFixed(2)}', Icons.monetization_on),
          if (txn.distributorCommission > 0)
            _detailTile(theme, 'Distributor Comm.', '₹${txn.distributorCommission.toStringAsFixed(2)}', Icons.people),
          _detailTile(theme, 'Date & Time', txn.createdAt.displayDateTime, Icons.schedule),
          if (txn.notes != null && txn.notes!.isNotEmpty)
            _detailTile(theme, 'Notes', txn.notes!, Icons.notes),
        ],
      ),
    );
  }

  String _accountLabel(WidgetRef ref, String acct) {
    if (acct == 'aeps') return 'AEPS';
    final accounts = ref.read(accountsProvider);
    final match = accounts.where((a) => a.id == acct);
    if (match.isNotEmpty) return match.first.name;
    return acct;
  }

  Widget _detailTile(ThemeData theme, String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: theme.textTheme.bodySmall),
        subtitle: Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      ),
    );
  }
}
