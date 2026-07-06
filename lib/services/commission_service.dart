import '../utils/constants.dart';

class CommissionService {
  double calculateCommission(double amount, TransactionType type) {
    if (amount <= 0) return 0;
    switch (type) {
      case TransactionType.aeps:
        final base = (amount / 1000).ceil() * 10.0;
        final extra = (amount / 10000).ceil() * 13.0;
        return base + extra;
      case TransactionType.cashIn:
      case TransactionType.cashOut:
        return (amount / 1000).ceil() * 10.0;
    }
  }

  (double baseAmount, double commission) smartDetect(double total) {
    final t = total.toInt();
    final maxComm = ((t ~/ 1000) + 1) * 10;
    final start = (t - maxComm < 0) ? 0 : t - maxComm;
    for (int b = start; b <= t; b++) {
      final comm = (b / 1000).ceil() * 10.0;
      if (b + comm == total) return (b.toDouble(), comm);
    }
    return (total, 0);
  }
}
