import '../models/commission_config.dart';
import '../utils/constants.dart';

class CommissionService {
  double calculateCommission(double amount, TransactionType type,
      {double? cashInPerThousand, double? cashOutPerThousand, double? aepsPerThousand}) {
    if (amount <= 0) return 0;
    final perThousand = switch (type) {
      TransactionType.aeps => aepsPerThousand ?? 10.0,
      TransactionType.cashIn => cashInPerThousand ?? 10.0,
      TransactionType.cashOut => cashOutPerThousand ?? 10.0,
      _ => 0.0,
    };
    if (perThousand <= 0) return 0;
    return (amount / 1000).ceil() * perThousand;
  }

  double calculateAepsWithdrawalCommission(double amount, AepsCommissionConfig config) {
    if (amount <= 0) return 0;
    return (amount / 1000).ceil() * config.cashWithdrawalPerThousand;
  }

  double getDistributorCommission(double amount, {List<DistributorRange>? ranges}) {
    if (amount <= 0) return 0;
    final list = ranges ?? DistributorRange.defaults;
    for (final r in list) {
      if (amount >= r.min && amount <= r.max) return r.commission;
    }
    return 0;
  }

  double getSettlementCharge(double amount, {List<SettlementRange>? ranges}) {
    if (amount <= 0) return 0;
    final list = ranges ?? SettlementRange.defaults;
    for (final r in list) {
      if (amount >= r.min && amount <= r.max) return r.charge;
    }
    return 10;
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
