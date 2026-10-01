import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

enum _Range { today, yesterday, month, year, all, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Range _range = _Range.today;
  DateTime? _customStart;
  DateTime? _customEnd;
  TransactionType? _typeFilter;
  double? _minAmount;
  double? _maxAmount;
  final Set<String> _accountIds = {};

  bool get _hasAdvancedFilters =>
      _typeFilter != null ||
      _customStart != null ||
      _customEnd != null ||
      _minAmount != null ||
      _maxAmount != null ||
      _accountIds.isNotEmpty;

  int get _activeFilterCount =>
      (_typeFilter != null ? 1 : 0) +
      (_customStart != null ? 1 : 0) +
      (_minAmount != null || _maxAmount != null ? 1 : 0) +
      (_accountIds.isNotEmpty ? 1 : 0);

  ({DateTime? start, DateTime? end}) get _dateBounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.today:
        return (start: today, end: today);
      case _Range.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (start: y, end: y);
      case _Range.month:
        return (start: DateTime(now.year, now.month, 1), end: today);
      case _Range.year:
        return (start: DateTime(now.year, 1, 1), end: today);
      case _Range.all:
        return (start: null, end: null);
      case _Range.custom:
        return (start: _customStart, end: _customEnd);
    }
  }

  String get _periodLabel {
    final b = _dateBounds;
    if (b.start == null || b.end == null) return 'All time';
    if (b.start!.isSameDay(b.end!)) return b.start!.displayDate;
    return '${b.start!.displayDate} – ${b.end!.displayDate}';
  }

  List<Transaction> _filtered(List<Transaction> all) {
    var f = all;
    final b = _dateBounds;
    if (b.start != null && b.end != null) {
      final s = b.start!.dateKey;
      final e = b.end!.dateKey;
      f = f
          .where((t) =>
              t.createdAt.dateKey.compareTo(s) >= 0 &&
              t.createdAt.dateKey.compareTo(e) <= 0)
          .toList();
    }
    if (_typeFilter != null) {
      f = f.where((t) => t.type == _typeFilter).toList();
    }
    if (_minAmount != null) {
      f = f.where((t) => t.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      f = f.where((t) => t.amount <= _maxAmount!).toList();
    }
    if (_accountIds.isNotEmpty) {
      f = f
          .where((t) =>
              (t.account != null && _accountIds.contains(t.account)) ||
              (t.fromAccount != null && _accountIds.contains(t.fromAccount)) ||
              (t.toAccount != null && _accountIds.contains(t.toAccount)))
          .toList();
    }
    return f;
  }

  // ---------------------------------------------------------------------
  // Filter sheet
  // ---------------------------------------------------------------------

  Future<void> _openFilterSheet() async {
    var tempType = _typeFilter;
    var tempStart = _customStart;
    var tempEnd = _customEnd;
    final tempAccounts = Set<String>.from(_accountIds);
    final minCtrl = TextEditingController(
        text: _minAmount != null ? _minAmount!.toStringAsFixed(0) : '');
    final maxCtrl = TextEditingController(
        text: _maxAmount != null ? _maxAmount!.toStringAsFixed(0) : '');

    void close() => Navigator.of(context).maybePop();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          final theme = Theme.of(sheetCtx);
          final accounts = ref.watch(accountsProvider);

          Future<void> pickDate({required bool isStart}) async {
            final picked = await showDatePicker(
              context: sheetCtx,
              initialDate: (isStart ? tempStart : tempEnd) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked == null) return;
            setSheet(() {
              if (isStart) {
                tempStart = picked;
                if (tempEnd == null || tempEnd!.isBefore(picked)) {
                  tempEnd = picked;
                }
              } else {
                tempEnd = picked;
                if (tempStart == null || tempStart!.isAfter(picked)) {
                  tempStart = picked;
                }
              }
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filters',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => setSheet(() {
                            tempType = null;
                            tempStart = null;
                            tempEnd = null;
                            tempAccounts.clear();
                            minCtrl.clear();
                            maxCtrl.clear();
                          }),
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ---- Transaction type ----
                    Text('TRANSACTION TYPE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: tempType == null,
                          onSelected: (_) =>
                              setSheet(() => tempType = null),
                        ),
                        ...TransactionType.values.map((type) => ChoiceChip(
                              label: Text(type.displayName),
                              selected: tempType == type,
                              onSelected: (_) => setSheet(
                                  () => tempType = tempType == type ? null : type),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---- Custom date range ----
                    Text('CUSTOM DATE RANGE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickDate(isStart: true),
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(
                              tempStart?.displayDate ?? 'From date',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward,
                              size: 16, color: theme.colorScheme.outline),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickDate(isStart: false),
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(
                              tempEnd?.displayDate ?? 'To date',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (tempStart != null || tempEnd != null)
                          IconButton(
                            tooltip: 'Clear dates',
                            onPressed: () => setSheet(() {
                              tempStart = null;
                              tempEnd = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---- Amount range ----
                    Text('AMOUNT RANGE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min ₹',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.trending_flat,
                              size: 20, color: theme.colorScheme.outline),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Max ₹',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---- Accounts ----
                    Text('ACCOUNTS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 8),
                    if (accounts.isEmpty)
                      Text('No accounts yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: accounts
                            .map((acc) => FilterChip(
                                  label: Text(acc.name),
                                  selected: tempAccounts.contains(acc.id),
                                  onSelected: (sel) => setSheet(() {
                                    if (sel) {
                                      tempAccounts.add(acc.id);
                                    } else {
                                      tempAccounts.remove(acc.id);
                                    }
                                  }),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 24),

                    // ---- Apply ----
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          final invalidDate = (tempStart == null) !=
                              (tempEnd == null);
                          if (invalidDate) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Pick both From and To dates, or clear them')),
                            );
                            return;
                          }
                          final minV = double.tryParse(minCtrl.text.trim());
                          final maxV = double.tryParse(maxCtrl.text.trim());
                          if (minV != null && maxV != null && minV > maxV) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Min amount cannot exceed Max')),
                            );
                            return;
                          }
                          close();
                          setState(() {
                            _typeFilter = tempType;
                            _customStart = tempStart;
                            _customEnd = tempEnd;
                            _minAmount = minV;
                            _maxAmount = maxV;
                            _accountIds
                              ..clear()
                              ..addAll(tempAccounts);
                            if (tempStart != null && tempEnd != null) {
                              _range = _Range.custom;
                            } else if (_range == _Range.custom) {
                              _range = _Range.today;
                            }
                          });
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------
  // Chart data
  // ---------------------------------------------------------------------

  List<({String label, double value})> _buildBuckets(
      List<Transaction> filtered) {
    final b = _dateBounds;

    // Single day -> hourly buckets
    if (b.start != null && b.end != null && b.start!.isSameDay(b.end!)) {
      final sums = List<double>.filled(24, 0);
      for (final t in filtered) {
        sums[t.createdAt.hour] += t.amount;
      }
      return List.generate(24, (i) => (label: '$i', value: sums[i]));
    }

    // Up to ~31 days -> daily buckets
    if (b.start != null &&
        b.end != null &&
        b.end!.difference(b.start!).inDays <= 31) {
      final days = <String, double>{};
      var d = b.start!;
      while (!d.isAfter(b.end!)) {
        days[d.dateKey] = 0;
        d = d.add(const Duration(days: 1));
      }
      for (final t in filtered) {
        days.update(t.createdAt.dateKey, (v) => v + t.amount,
            ifAbsent: () => t.amount);
      }
      return days.entries
          .map((e) => (label: e.key, value: e.value))
          .toList(growable: false);
    }

    // Longer ranges -> monthly buckets grouped from transactions
    final months = <String, double>{};
    for (final t in filtered) {
      final key =
          '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}';
      months.update(key, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final sorted = months.keys.toList()..sort();
    return sorted
        .map((k) => (label: k, value: months[k]!))
        .toList(growable: false);
  }

  Color _typeColor(TransactionType type) {
    switch (type) {
      case TransactionType.aeps:
        return const Color(0xFF3B82F6);
      case TransactionType.cashIn:
        return const Color(0xFF10B981);
      case TransactionType.cashOut:
        return const Color(0xFFF59E0B);
      case TransactionType.aepsCashIn:
        return const Color(0xFF14B8A6);
      case TransactionType.balanceAdjustment:
        return const Color(0xFF8B5CF6);
      case TransactionType.selfTransfer:
        return const Color(0xFF6366F1);
    }
  }

  String _compactAmount(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  // ---------------------------------------------------------------------
  // UI pieces
  // ---------------------------------------------------------------------

  Widget _statCard(
      ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _rangeChip(_Range range, String label) {
    final selected = _range == range;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _range = range;
        if (range != _Range.custom) {
          _customStart = null;
          _customEnd = null;
        }
      }),
    );
  }

  Widget _activeFilterChips() {
    final chips = <Widget>[];
    if (_typeFilter != null) {
      chips.add(Chip(
        avatar: Icon(Icons.label, size: 16, color: _typeColor(_typeFilter!)),
        label: Text(_typeFilter!.displayName),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => setState(() => _typeFilter = null),
      ));
    }
    if (_customStart != null && _customEnd != null) {
      chips.add(Chip(
        avatar: const Icon(Icons.date_range, size: 16),
        label: Text('${_customStart!.displayDate} – ${_customEnd!.displayDate}'),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => setState(() {
          _customStart = null;
          _customEnd = null;
          if (_range == _Range.custom) _range = _Range.today;
        }),
      ));
    }
    if (_minAmount != null || _maxAmount != null) {
      final label = _minAmount != null && _maxAmount != null
          ? '₹${_minAmount!.toStringAsFixed(0)} – ₹${_maxAmount!.toStringAsFixed(0)}'
          : _minAmount != null
              ? 'Min ₹${_minAmount!.toStringAsFixed(0)}'
              : 'Max ₹${_maxAmount!.toStringAsFixed(0)}';
      chips.add(Chip(
        avatar: const Icon(Icons.currency_rupee, size: 16),
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => setState(() {
          _minAmount = null;
          _maxAmount = null;
        }),
      ));
    }
    if (_accountIds.isNotEmpty) {
      chips.add(Chip(
        avatar: const Icon(Icons.account_balance, size: 16),
        label: Text(_accountIds.length == 1
            ? _accountName(_accountIds.first)
            : '${_accountIds.length} accounts'),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () => setState(() => _accountIds.clear()),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  String _accountName(String id) {
    final accounts = ref.watch(accountsProvider);
    final match = accounts.where((a) => a.id == id);
    return match.isNotEmpty ? match.first.name : id;
  }

  Widget _barChart(ThemeData theme, List<Transaction> filtered) {
    final buckets = _buildBuckets(filtered);
    if (buckets.isEmpty) {
      return _chartEmpty(theme);
    }
    final b = _dateBounds;
    final isHourly = b.start != null && b.end != null && b.start!.isSameDay(b.end!);
    final isDaily = !isHourly &&
        b.start != null &&
        b.end != null &&
        b.end!.difference(b.start!).inDays <= 31;

    final maxY = buckets.fold<double>(
            0, (m, e) => e.value > m ? e.value : m) *
        1.2;
    final primary = theme.colorScheme.primary;

    final labelStep = isHourly
        ? 1
        : isDaily
            ? (buckets.length / 8).ceil().clamp(1, 31)
            : (buckets.length / 10).ceil().clamp(1, 12);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY,
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].value,
                  width: isHourly ? 8 : 14,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      primary.withValues(alpha: 0.45),
                      primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = isHourly
                  ? '${buckets[group.x].label}:00'
                  : isDaily
                      ? buckets[group.x].label
                      : buckets[group.x].label;
              return BarTooltipItem(
                '$label\n',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '₹${rod.toY.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: _yTitle,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= buckets.length) {
                  return const SizedBox.shrink();
                }
                if (i % labelStep != 0 && i != buckets.length - 1) {
                  return const SizedBox.shrink();
                }
                String text;
                if (isHourly) {
                  final h = int.parse(buckets[i].label);
                  text = h == 0
                      ? '12a'
                      : h < 12
                          ? '${h}a'
                          : h == 12
                              ? '12p'
                              : h == 24
                                  ? ''
                                  : '${h - 12}p';
                } else if (isDaily) {
                  text = buckets[i].label.substring(8);
                } else {
                  final parts = buckets[i].label.split('-');
                  const mons = [
                    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                  ];
                  final m = int.parse(parts[1]);
                  text = '${mons[m - 1]} ${parts[0].substring(2)}';
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }

  static Widget _yTitle(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text;
    if (value >= 10000000) {
      text = '${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      text = '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(1)}k';
    } else {
      text = value.toStringAsFixed(0);
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: style),
    );
  }

  Widget _donutChart(ThemeData theme, List<Transaction> filtered) {
    final byType = <TransactionType, double>{};
    for (final t in filtered) {
      byType.update(t.type, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    if (entries.isEmpty || total <= 0) {
      return _chartEmpty(theme);
    }

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections: [
                    for (final e in entries)
                      PieChartSectionData(
                        value: e.value,
                        color: _typeColor(e.key),
                        radius: 26,
                        title: (e.value / total * 100) >= 8
                            ? '${(e.value / total * 100).toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 450),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _compactAmount(total),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _typeColor(e.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        _compactAmount(e.value),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartEmpty(ThemeData theme) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'No data for this period',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionsProvider);
    final balances = ref.watch(balancesProvider);
    final accounts = ref.watch(accountsProvider);

    final filtered = _filtered(allTransactions);

    final totalAmount = filtered.fold(0.0, (s, t) => s + t.amount);
    final earningTxns =
        filtered.where((t) => t.type != TransactionType.selfTransfer).toList();
    final ourCommission = earningTxns.fold(0.0, (s, t) => s + t.commission);
    final distributorCommission =
        earningTxns.fold(0.0, (s, t) => s + t.distributorCommission);

    final b = _dateBounds;
    final dateKey = b.end?.dateKey ?? DateTime.now().dateKey;
    final dayBalance = balances[dateKey];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            onPressed: _openFilterSheet,
            tooltip: 'Filters',
            icon: Badge(
              isLabelVisible: _hasAdvancedFilters,
              label: Text('$_activeFilterCount'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---- Quick range chips ----
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _rangeChip(_Range.today, 'Today'),
                const SizedBox(width: 8),
                _rangeChip(_Range.yesterday, 'Yesterday'),
                const SizedBox(width: 8),
                _rangeChip(_Range.month, 'This Month'),
                const SizedBox(width: 8),
                _rangeChip(_Range.year, 'This Year'),
                const SizedBox(width: 8),
                _rangeChip(_Range.all, 'All Time'),
              ],
            ),
          ),
          _activeFilterChips(),
          const SizedBox(height: 14),

          // ---- Period header ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _periodLabel,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${filtered.length} txn${filtered.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ---- KPI cards ----
          SizedBox(
            height: 118,
            child: Row(
              children: [
                Expanded(
                  child: _statCard(theme, 'Transactions',
                      '${filtered.length}', Icons.receipt_long,
                      theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(theme, 'Total Amount',
                      _compactAmount(totalAmount), Icons.currency_rupee,
                      const Color(0xFF10B981)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(theme, 'Our Commission',
                      _compactAmount(ourCommission), Icons.monetization_on,
                      const Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                      theme,
                      'Distributor',
                      _compactAmount(distributorCommission),
                      Icons.people,
                      const Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),

          // ---- Bar chart ----
          _sectionTitle(theme, 'Turnover',
              subtitle: _range == _Range.today ? 'By hour' : 'Per day / month'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
              child: SizedBox(height: 200, child: _barChart(theme, filtered)),
            ),
          ),

          // ---- Donut chart ----
          _sectionTitle(theme, 'By Type'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _donutChart(theme, filtered),
            ),
          ),

          // ---- Balances ----
          _sectionTitle(theme, 'Balances',
              subtitle: b.end?.displayDate ?? DateTime.now().displayDate),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reportRow('AEPS Balance',
                      '₹${(dayBalance?.aepsClosingBalance ?? 0).toStringAsFixed(2)}'),
                  const Divider(),
                  ...accounts.map((acc) {
                    final bal = dayBalance?.getBalance(acc.id) ?? 0;
                    return Column(
                      children: [
                        _reportRow(
                            acc.name, '₹${bal.toStringAsFixed(2)}'),
                        const Divider(),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          // ---- Transaction details ----
          _sectionTitle(theme, 'Transactions',
              subtitle: filtered.length > 50 ? 'Showing 50 of ${filtered.length}' : null),
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox,
                          size: 40, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('No transactions found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ...filtered.take(50).map((txn) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _typeColor(txn.type).withValues(alpha: 0.15),
                    child: Text(
                      switch (txn.type) {
                        TransactionType.aeps => 'A',
                        TransactionType.cashIn => 'I',
                        TransactionType.cashOut => 'O',
                        TransactionType.aepsCashIn => 'ACI',
                        TransactionType.balanceAdjustment => 'ADJ',
                        TransactionType.selfTransfer => 'TRF',
                      },
                      style: TextStyle(
                        color: _typeColor(txn.type),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  title: Text(txn.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    [
                      txn.createdAt.displayDateTime,
                      if (txn.utr != null && txn.utr!.isNotEmpty)
                        'UTR ${txn.utr}',
                    ].join(' • '),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${txn.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (txn.commission > 0)
                        Text(
                          'Our: ₹${txn.commission.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (txn.distributorCommission > 0)
                        Text(
                          'Dist: ₹${txn.distributorCommission.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
