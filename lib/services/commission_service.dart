import '../utils/constants.dart';

class CommissionService {
  double calculateCommission(double amount, TransactionType type) {
    if (amount <= 0) return 0;
    switch (type) {
      case TransactionType.aeps:
      case TransactionType.cashIn:
      case TransactionType.cashOut:
        return (amount / 1000).ceil() * 10.0;
      case TransactionType.balanceAdjustment:
      case TransactionType.selfTransfer:
        return 0;
    }
  }

  double getDistributorCommission(double amount) {
    if (amount <= 0) return 0;
    return DistributorCommissionChart.getCommission(amount);
  }

  double getSettlementCharge(double amount) {
    if (amount <= 0) return 0;
    return SettlementChargeChart.getCharge(amount);
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
