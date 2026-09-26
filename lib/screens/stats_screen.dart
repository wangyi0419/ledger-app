import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/txn.dart';
import '../services/ledger_store.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static final _palette = [
    Colors.teal, Colors.orange, Colors.blue, Colors.purple,
    Colors.amber, Colors.pink, Colors.cyan, Colors.lime,
    Colors.indigo, Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    final txns = Provider.of<LedgerStore>(context).txns;

    // 近 6 个月
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      return DateFormat('yyyy-MM').format(d);
    });
    final incomeByM = <String, double>{for (var m in months) m: 0};
    final expenseByM = <String, double>{for (var m in months) m: 0};
    for (final t in txns) {
      final m = DateFormat('yyyy-MM').format(DateTime.fromMillisecondsSinceEpoch(t.dateMillis));
      if (incomeByM.containsKey(m)) {
        if (t.type == 'income') incomeByM[m] = incomeByM[m]! + t.amount;
        else expenseByM[m] = expenseByM[m]! + t.amount;
      }
    }

    // 当月分类支出
    final curMonth = DateFormat('yyyy-MM').format(now);
    final byCat = <String, double>{};
    for (final t in txns) {
      if (t.type != 'expense') continue;
      final m = DateFormat('yyyy-MM').format(DateTime.fromMillisecondsSinceEpoch(t.dateMillis));
      if (m == curMonth) byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final catEntries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = catEntries.fold(0.0, (s, e) => s + e.value);

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < months.length; i++) {
      barGroups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(toY: incomeByM[months[i]]!, color: Colors.green, width: 10, borderRadius: BorderRadius.circular(2)),
          BarChartRodData(toY: expenseByM[months[i]]!, color: Colors.red, width: 10, borderRadius: BorderRadius.circular(2)),
        ],
      ));
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < catEntries.length; i++) {
      final e = catEntries[i];
      sections.add(PieChartSectionData(
        value: e.value,
        title: '${(e.value / (totalExpense == 0 ? 1 : totalExpense) * 100).toStringAsFixed(0)}%',
        color: _palette[i % _palette.length],
        radius: 70,
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('近 6 个月收支（绿=收入 红=支出）', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: _maxY(incomeByM, expenseByM),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= months.length) return const Text('');
                  return Text(months[i].substring(5));
                },
              )),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: barGroups,
          )),
        ),
        const SizedBox(height: 24),
        Text('$curMonth 支出分类占比', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (catEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('本月暂无支出记录')),
          )
        else
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            )),
          ),
        if (catEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (var i = 0; i < catEntries.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, color: _palette[i % _palette.length]),
                    const SizedBox(width: 4),
                    Text('${catEntries[i].key} ¥${catEntries[i].value.toStringAsFixed(0)}'),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  double _maxY(Map<String, double> a, Map<String, double> b) {
    var m = 0.0;
    for (final v in [...a.values, ...b.values]) if (v > m) m = v;
    return (m * 1.2).ceilToDouble().clamp(10, double.infinity);
  }
}
