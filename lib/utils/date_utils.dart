import 'package:intl/intl.dart';

extension DateFormatting on DateTime {
  String get dateKey => DateFormat('yyyy-MM-dd').format(this);

  String get displayDate => DateFormat('dd MMM yyyy').format(this);

  String get displayDateTime => DateFormat('dd MMM yyyy, hh:mm a').format(this);

  String get displayTime => DateFormat('hh:mm a').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
