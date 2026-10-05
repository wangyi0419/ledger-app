import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ledger_store.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<LedgerStore>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(type: 'expense', title: '支出分类', store: store),
          const SizedBox(height: 16),
          _Section(type: 'income', title: '收入分类', store: store),
          const SizedBox(height: 16),
          const Text(
            '提示：删除分类时，原该分类下的记录会自动归到“其他支出/其他收入”；'
            '重命名会同步更新历史记录。分类随账本加密同步到各端。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String type;
  final String title;
  final LedgerStore store;
  const _Section({required this.type, required this.title, required this.store});

  @override
  Widget build(BuildContext context) {
    final cats = store.categories(type);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAdd(context),
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                ),
              ],
            ),
            const Divider(),
            if (cats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无分类', style: TextStyle(color: Colors.grey)),
              )
            else
              for (final c in cats)
                ListTile(
                  dense: true,
                  title: Text(c),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: '重命名',
                        onPressed: () => _showRename(context, c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: '删除',
                        onPressed: () => _confirmDelete(context, c),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showAdd(BuildContext context) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('添加$title'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分类名称', border: OutlineInputBorder()),
          onSubmitted: (_) => _doAdd(context, ctl.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => _doAdd(context, ctl.text), child: const Text('添加')),
        ],
      ),
    );
  }

  void _doAdd(BuildContext context, String name) {
    if (name.trim().isEmpty) return;
    store.addCategory(type, name);
    Navigator.pop(context);
  }

  void _showRename(BuildContext context, String oldName) {
    final ctl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名分类'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新名称', border: OutlineInputBorder()),
          onSubmitted: (_) => _doRename(context, oldName, ctl.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () => _doRename(context, oldName, ctl.text), child: const Text('保存')),
        ],
      ),
    );
  }

  void _doRename(BuildContext context, String oldName, String newName) {
    if (newName.trim().isEmpty) return;
    store.renameCategory(type, oldName, newName);
    Navigator.pop(context);
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除分类？'),
        content: Text('“${name}”下的记录将改到“${type == 'income' ? '其他收入' : '其他支出'}”。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              store.deleteCategory(type, name);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
