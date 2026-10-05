import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/txn.dart';
import '../services/ledger_store.dart';

class AddTxnScreen extends StatefulWidget {
  const AddTxnScreen({super.key});

  @override
  State<AddTxnScreen> createState() => _AddTxnScreenState();
}

class _AddTxnScreenState extends State<AddTxnScreen> {
  String _type = 'expense';
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  late LedgerStore _store;
  late String _category;
  DateTime _date = DateTime.now();

  List<String> get _cats => _store.categories(_type);

  @override
  void initState() {
    super.initState();
    _store = Provider.of<LedgerStore>(context, listen: false);
    _category = _cats.first;
  }

  void _onTypeChanged(String? v) {
    if (v == null) return;
    setState(() {
      _type = v;
      _category = _cats.first;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amount = double.tryParse(_amountCtl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    Provider.of<LedgerStore>(context, listen: false).addTxn(Txn(
      type: _type,
      amount: amount,
      category: _category,
      note: _noteCtl.text.trim(),
      dateMillis: _date.millisecondsSinceEpoch,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增记录')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('支出')),
                ButtonSegment(value: 'income', label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _onTypeChanged(s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: '分类', border: OutlineInputBorder()),
              items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtl,
              decoration: const InputDecoration(labelText: '备注（可选）', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_date)),
              onTap: _pickDate,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('保存并同步')),
            ),
          ],
        ),
      ),
    );
  }
}
