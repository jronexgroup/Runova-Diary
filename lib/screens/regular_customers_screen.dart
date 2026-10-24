import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

/// Customers with 2+ matching transactions, clustered per the form's type rules.
class RegularCustomersScreen extends ConsumerWidget {
  final TransactionType type;

  const RegularCustomersScreen({super.key, required this.type});

  static const _supportedTypes = {
    TransactionType.aeps,
    TransactionType.aepsCashIn,
    TransactionType.cashIn,
    TransactionType.cashOut,
  };

  static String _normName(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _normDigits(String? s) =>
      (s ?? '').replaceAll(RegExp(r'\D'), '');

  static bool _fieldEq(String a, String b) =>
      a.isNotEmpty && b.isNotEmpty && a == b;

  /// Match rules:
  /// - AEPS: name + mobile + aadhaar → any 2 of 3 match
  /// - AEPS Cash In: name + village + phone → any 2 of 3 match
  /// - Cash In/Out: name + mobile; if either mobile missing → name alone
  bool _matches(Transaction a, Transaction b) {
    switch (type) {
      case TransactionType.aeps:
        var m = 0;
        if (_fieldEq(_normName(a.customerName), _normName(b.customerName))) m++;
        if (_fieldEq(_normDigits(a.mobileNumber), _normDigits(b.mobileNumber))) m++;
        if (_fieldEq(_normDigits(a.aadhaarNumber), _normDigits(b.aadhaarNumber))) m++;
        return m >= 2;
      case TransactionType.aepsCashIn:
        var m = 0;
        if (_fieldEq(_normName(a.customerName), _normName(b.customerName))) m++;
        if (_fieldEq(_normName(a.village), _normName(b.village))) m++;
        if (_fieldEq(_normDigits(a.mobileNumber), _normDigits(b.mobileNumber))) m++;
        return m >= 2;
      case TransactionType.cashIn:
      case TransactionType.cashOut:
        final nameA = _normName(a.customerName);
        if (nameA.isEmpty || nameA != _normName(b.customerName)) return false;
        final mobA = _normDigits(a.mobileNumber);
        final mobB = _normDigits(b.mobileNumber);
        if (mobA.isEmpty || mobB.isEmpty) return true;
        return mobA == mobB;
      default:
        return false;
    }
  }

  List<_RegularCustomer> _buildCustomers(List<Transaction> all) {
    final txns = all.where((t) => _supportedTypes.contains(type)).toList();
    if (txns.length < 2) return const [];

    // Union-find clustering over pairwise matches.
    final parent = List<int>.generate(txns.length, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      parent[find(a)] = find(b);
    }

    for (var i = 0; i < txns.length; i++) {
      for (var j = i + 1; j < txns.length; j++) {
        if (_matches(txns[i], txns[j])) union(i, j);
      }
    }

    final groups = <int, List<Transaction>>{};
    for (var i = 0; i < txns.length; i++) {
      groups.putIfAbsent(find(i), () => []).add(txns[i]);
    }

    final customers = <_RegularCustomer>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      final sorted = [...group]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      customers.add(_RegularCustomer(
        representative: sorted.first,
        count: group.length,
        lastAt: sorted.first.createdAt,
      ));
    }
    customers.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return b.lastAt.compareTo(a.lastAt);
    });
    return customers;
  }

  String _identityLine(Transaction t) {
    final parts = <String>[];
    switch (type) {
      case TransactionType.aeps:
        if ((t.mobileNumber ?? '').isNotEmpty) parts.add(t.mobileNumber!);
        if ((t.aadhaarNumber ?? '').isNotEmpty) {
          final a = t.aadhaarNumber!;
          parts.add(a.length > 4 ? '****$a' : a);
        }
      case TransactionType.aepsCashIn:
        if ((t.mobileNumber ?? '').isNotEmpty) parts.add(t.mobileNumber!);
        if ((t.village ?? '').isNotEmpty) parts.add(t.village!);
      case TransactionType.cashIn:
      case TransactionType.cashOut:
        if ((t.mobileNumber ?? '').isNotEmpty) parts.add(t.mobileNumber!);
      default:
        break;
    }
    return parts.join(' • ');
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(transactionsProvider);
    final customers = _buildCustomers(all);

    return Scaffold(
      appBar: AppBar(title: const Text('Regular Customers')),
      body: customers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'No regular customers yet.\nCustomers with 2+ matching transactions appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: customers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = customers[i];
                final rep = c.representative;
                return Card(
                  child: ListTile(
                    onTap: () => context.pop(rep),
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        _initials(rep.customerName),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      rep.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if (_identityLine(rep).isNotEmpty) _identityLine(rep),
                        'Last: ${c.lastAt.displayDate}',
                      ].join('\n'),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${c.count} txns',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(Icons.chevron_right,
                            size: 18, color: theme.colorScheme.outline),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _RegularCustomer {
  final Transaction representative;
  final int count;
  final DateTime lastAt;

  const _RegularCustomer({
    required this.representative,
    required this.count,
    required this.lastAt,
  });
}
