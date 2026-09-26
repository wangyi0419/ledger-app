import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ledger_store.dart';

/// 解锁页：首次运行设置主密码，之后输入主密码解密本地数据
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _pwdCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _firstRun = false;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    setState(() => _firstRun = !(await LedgerStore.hasLocalCache()));
  }

  Future<void> _submit() async {
    final pwd = _pwdCtl.text;
    if (pwd.length < 6) {
      setState(() => _error = '主密码至少 6 位');
      return;
    }
    if (_firstRun && _confirmCtl.text != pwd) {
      setState(() => _error = '两次输入不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      // 解锁成功后 RootGate 会自动切换到主页
      await Provider.of<LedgerStore>(context, listen: false).unlock(pwd);
    } catch (e) {
      setState(() => _error = '主密码错误，无法解密本地数据');
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.teal),
                const SizedBox(height: 16),
                Text(_firstRun ? '设置主密码' : '输入主密码',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _firstRun
                      ? '此密码用于加密你的记账数据，\n忘记将无法恢复数据，请牢记。'
                      : '用于解密本地与仓库中的加密数据。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pwdCtl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '主密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_firstRun) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '确认主密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('进入'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
