import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/txn.dart';
import '../services/ledger_store.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _monthKey = _ym(DateTime.now());

  static String _ym(DateTime d) => DateFormat('yyyy-MM').format(d);

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<LedgerStore>(context);
    final all = store.txns;
    final months = all.map((t) => _ym(DateTime.fromMillisecondsSinceEpoch(t.dateMillis))).toSet().toList()..sort();
    if (!months.contains(_monthKey)) months.insert(0, _monthKey);

    final monthTxns = all
        .where((t) => _ym(DateTime.fromMillisecondsSinceEpoch(t.dateMillis)) == _monthKey)
        .toList()
      ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis));

    final income = monthTxns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final expense = monthTxns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _monthKey,
                items: months
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _monthKey = v!),
              ),
              const Spacer(),
              _SummaryChip(label: '收入', value: income, color: Colors.green),
              const SizedBox(width: 8),
              _SummaryChip(label: '支出', value: expense, color: Colors.red),
            ],
          ),
        ),
        Expanded(
          child: monthTxns.isEmpty
              ? const Center(child: Text('本月暂无记录，点右下角 + 添加'))
              : ListView.separated(
                  itemCount: monthTxns.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = monthTxns[i];
                    return Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (dir) async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('删除该记录？'),
                            content: Text('${t.category} ¥${t.amount.toStringAsFixed(2)}'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('取消')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('删除')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          Provider.of<LedgerStore>(context, listen: false).deleteTxn(t.id);
                        }
                        return ok ?? false;
                      },
                      child: _TxnTile(t: t),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('¥${value.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      );
}

class _TxnTile extends StatelessWidget {
  final Txn t;
  const _TxnTile({required this.t});

  @override
  Widget build(BuildContext context) {
    final isIncome = t.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final date = DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(t.dateMillis));
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color),
      ),
      title: Text('${t.category}${t.note.isNotEmpty ? ' · ${t.note}' : ''}'),
      subtitle: Text(date),
      trailing: Text(
        '${isIncome ? '+' : '-'}¥${t.amount.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddTxnScreen(initial: t)),
      ),
    );
  }
}
