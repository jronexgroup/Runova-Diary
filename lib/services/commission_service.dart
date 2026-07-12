import '../models/commission_config.dart';
import '../utils/constants.dart';

class CommissionService {
  double _rateFromRanges(double amount, List<CommissionRange> ranges) {
    for (final r in ranges) {
      if (amount >= r.min && amount <= r.max) return r.rate;
    }
    return 0;
  }

  double calculateCommission(double amount, TransactionType type,
      {double? cashInPerThousand,
      double? cashOutPerThousand,
      double? aepsPerThousand,
      List<CommissionRange>? cashInRanges,
      List<CommissionRange>? cashOutRanges}) {
    if (amount <= 0) return 0;

    double perThousand;
    if (type == TransactionType.cashIn && cashInRanges != null && cashInRanges.isNotEmpty) {
      perThousand = _rateFromRanges(amount, cashInRanges);
      if (perThousand <= 0) perThousand = cashInPerThousand ?? 10;
    } else if (type == TransactionType.cashOut && cashOutRanges != null && cashOutRanges.isNotEmpty) {
      perThousand = _rateFromRanges(amount, cashOutRanges);
      if (perThousand <= 0) perThousand = cashOutPerThousand ?? 10;
    } else {
      perThousand = switch (type) {
        TransactionType.aeps => aepsPerThousand ?? 10.0,
        TransactionType.cashIn => cashInPerThousand ?? 10.0,
        TransactionType.cashOut => cashOutPerThousand ?? 10.0,
        _ => 0.0,
      };
    }

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

  (double baseAmount, double commission) smartDetect(double total,
      {List<CommissionRange>? cashInRanges, List<CommissionRange>? cashOutRanges}) {
    final t = total.toInt();
    final tD = total.toDouble();

    double rateFor(double amt) {
      final ranges = cashInRanges ?? cashOutRanges;
      if (ranges != null && ranges.isNotEmpty) {
        final match = ranges.where((r) => amt >= r.min && amt <= r.max);
        if (match.isNotEmpty) return match.first.rate;
      }
      return 10;
    }

    final maxComm = ((t ~/ 1000) + 1) * rateFor(total);
    int start = t - maxComm.toInt();
    if (start < 0) start = 0;
    for (int b = start; b <= t; b++) {
      final comm = (b / 1000).ceil() * rateFor(b.toDouble());
      if (b + comm == total) return (b.toDouble(), comm);
    }
    return (tD, 0);
  }
}
