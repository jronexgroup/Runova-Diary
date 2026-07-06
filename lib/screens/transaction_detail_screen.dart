import 'dart:convert';
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
          _detailTile(theme, 'Balance After', '₹${txn.balanceAfterTransaction.toStringAsFixed(2)}', Icons.account_balance_wallet),
          _detailTile(theme, 'Commission', '₹${txn.commission.toStringAsFixed(2)}', Icons.monetization_on),
          _detailTile(theme, 'Date & Time', txn.createdAt.displayDateTime, Icons.schedule),
          if (txn.notes != null && txn.notes!.isNotEmpty)
            _detailTile(theme, 'Notes', txn.notes!, Icons.notes),
          if (txn.signatureData != null)
            _signatureCard(theme, txn.signatureData!),
        ],
      ),
    );
  }

  Widget _signatureCard(ThemeData theme, String signatureData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Signature', style: theme.textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen, size: 20),
                  tooltip: 'View full screen',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openFullSignature(context, signatureData),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  painter: _SignatureDisplayPainter(signatureData),
                  size: const Size(double.infinity, 120),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullSignature(BuildContext context, String signatureData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text('Signature'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LayoutBuilder(
                          builder: (_, constraints) => CustomPaint(
                            painter: _SignatureDisplayPainter(signatureData),
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

class _SignatureDisplayPainter extends CustomPainter {
  final List<List<List<double>>> strokes;

  _SignatureDisplayPainter(String json) : strokes = _parse(json);

  static List<List<List<double>>> _parse(String json) {
    try {
      final data = jsonDecode(json) as List;
      return data.map((s) {
        return (s as List).map((p) => (p as List).cast<double>()).toList();
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          Offset(stroke[0][0], stroke[0][1]),
          paint.strokeWidth / 2,
          paint,
        );
        continue;
      }
      final path = Path();
      path.moveTo(stroke[0][0], stroke[0][1]);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i][0], stroke[i][1]);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
