import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/github_service.dart';
import '../services/ledger_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ownerCtl = TextEditingController();
  final _repoCtl = TextEditingController();
  final _tokenCtl = TextEditingController();
  final _pathCtl = TextEditingController(text: 'data/ledger.enc');
  final _apiCtl = TextEditingController(text: 'https://api.github.com');
  bool _loading = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await GitHubService.loadConfig();
    _ownerCtl.text = cfg['owner'] ?? '';
    _repoCtl.text = cfg['repo'] ?? '';
    _tokenCtl.text = cfg['token'] ?? '';
    _pathCtl.text = cfg['path'] ?? 'data/ledger.enc';
    _apiCtl.text = cfg['apiBase'] ?? 'https://api.github.com';
  }

  Future<void> _test() async {
    setState(() => _msg = '测试中…');
    try {
      final login = await GitHubService.testConnection(
          _tokenCtl.text.trim(), _apiCtl.text.trim());
      setState(() => _msg = '连接成功，账号：$login');
    } catch (e) {
      setState(() => _msg = '连接失败：$e');
    }
  }

  Future<void> _save() async {
    if (_ownerCtl.text.isEmpty || _repoCtl.text.isEmpty || _tokenCtl.text.isEmpty) {
      setState(() => _msg = '请填齐 用户名 / 仓库 / Token');
      return;
    }
    setState(() => _loading = true);
    await GitHubService.saveConfig(
      owner: _ownerCtl.text.trim(),
      repo: _repoCtl.text.trim(),
      token: _tokenCtl.text.trim(),
      path: _pathCtl.text.trim(),
      apiBase: _apiCtl.text.trim(),
    );
    await Provider.of<LedgerStore>(context, listen: false).sync();
    setState(() => _loading = false);
  }

  Future<void> _lock() async {
    await Provider.of<LedgerStore>(context, listen: false).lock();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('GitHub 私有仓库同步', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('数据以 AES-256 加密后存入你的私有仓库，仅你账号可见。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        TextField(
          controller: _ownerCtl,
          decoration: const InputDecoration(labelText: 'GitHub 用户名', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repoCtl,
          decoration: const InputDecoration(labelText: '数据仓库名（私有）', border: OutlineInputBorder(), hintText: '例如 ledger-data'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tokenCtl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Personal Access Token', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pathCtl,
          decoration: const InputDecoration(labelText: '仓库内文件路径', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiCtl,
          decoration: const InputDecoration(
              labelText: 'API 基地址',
              border: OutlineInputBorder(),
              hintText: '默认官方；国内不可达时填中转地址'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton.icon(onPressed: _loading ? null : _test, icon: const Icon(Icons.cable), label: const Text('测试连接')),
            FilledButton.icon(onPressed: _loading ? null : _save, icon: const Icon(Icons.save), label: const Text('保存并同步')),
          ],
        ),
        const SizedBox(height: 12),
        if (_msg.isNotEmpty)
          Text(_msg, style: TextStyle(color: _msg.contains('失败') ? Colors.red : Colors.green)),
        const Divider(height: 32),
        const Text('安全说明', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          '· 主密码仅存于内存，用于加解密，不会上传。\n'
          '· Token 存于系统安全存储（Keychain / Keystore）。\n'
          '· 忘记主密码将无法解密数据，请务必牢记。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _lock,
          icon: const Icon(Icons.logout),
          label: const Text('锁定并退出（清除内存主密码）'),
        ),
      ],
    );
  }
}
