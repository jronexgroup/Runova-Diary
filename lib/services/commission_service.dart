import '../utils/constants.dart';

class CommissionService {
  double calculateCommission(double amount, TransactionType type) {
    if (type != TransactionType.aeps) return 0;
    if (amount <= 0) return 0;
    return (amount / 1000).ceil() * 10.0;
  }
}
