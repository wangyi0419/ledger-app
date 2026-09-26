import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/txn.dart';
import 'crypto_service.dart';
import 'github_service.dart';

/// 记账数据仓库：管理本地缓存、与 GitHub 私有仓库的加密同步
///
/// 本地加密缓存使用 shared_preferences（原生与 Web 通用），
/// 不再依赖 path_provider/dart:io，因此同一份代码可编译为安卓/iOS/Web。
class LedgerStore extends ChangeNotifier {
  List<Txn> _txns = [];
  bool _unlocked = false;
  String? _masterPassword;
  bool _syncing = false;
  Timer? _timer;
  String _lastSyncMsg = '';

  List<Txn> get txns => List.unmodifiable(_txns);
  bool get unlocked => _unlocked;
  String get lastSyncMsg => _lastSyncMsg;

  static const _localKey = 'ledger_local_enc';
  static const _storage = FlutterSecureStorage();

  /// 本地是否已存在加密缓存（用于判断首次运行）
  static Future<bool> hasLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_localKey);
    return v != null && v.isNotEmpty;
  }

  /// 解锁：用主密码解密本地缓存（若有），失败说明密码错误
  Future<void> unlock(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_localKey);
    if (cached != null && cached.isNotEmpty) {
      final payload = jsonDecode(cached) as Map<String, dynamic>;
      // 密码错误会抛异常，由调用方捕获提示
      final plain = CryptoService.decryptText(payload, password);
      final list = (jsonDecode(plain) as List)
          .map((e) => Txn.fromJson(e as Map<String, dynamic>))
          .toList();
      _txns = list;
    }
    _masterPassword = password;
    _unlocked = true;
    await _persistLocal(); // 首次也写一份本地加密缓存，供下次识别为"返回用户"
    _startAutoSync();
    notifyListeners();
    // 打开即与远端对账一次
    sync();
  }

  Future<void> lock() async {
    _timer?.cancel();
    _unlocked = false;
    _masterPassword = null;
    _txns = [];
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    if (_masterPassword == null) return;
    final prefs = await SharedPreferences.getInstance();
    final plain = jsonEncode(_txns.map((t) => t.toJson()).toList());
    final payload = CryptoService.encryptText(plain, _masterPassword!);
    await prefs.setString(_localKey, jsonEncode(payload));
  }

  void addTxn(Txn t) {
    _txns.add(t);
    _afterChange();
  }

  void updateTxn(Txn t) {
    final i = _txns.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      _txns[i] = t.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    }
    _afterChange();
  }

  void deleteTxn(String id) {
    _txns.removeWhere((e) => e.id == id);
    _afterChange();
  }

  void _afterChange() {
    _persistLocal();
    notifyListeners();
    sync(); // 触发后台同步
  }

  /// 拉取远端 -> 合并 -> 仅在数据有变化时推送；带并发守卫
  Future<void> sync() async {
    if (!_unlocked || _masterPassword == null || _syncing) return;
    final cfg = await GitHubService.loadConfig();
    final owner = cfg['owner'];
    final repo = cfg['repo'];
    final token = cfg['token'];
    final path = cfg['path'];
    if (owner == null || repo == null || token == null || path == null) {
      _lastSyncMsg = '未配置 GitHub 仓库';
      notifyListeners();
      return;
    }

    _syncing = true;
    _lastSyncMsg = '同步中…';
    notifyListeners();
    try {
      // 1) 拉取远端
      final remote = await GitHubService.fetchFile(owner, repo, path, token);
      String? remotePlain;
      if (remote != null) {
        try {
          final decoded = utf8.decode(base64Decode(remote['content']!));
          final payload = jsonDecode(decoded) as Map<String, dynamic>;
          remotePlain = CryptoService.decryptText(payload, _masterPassword!);
          final remoteList = (jsonDecode(remotePlain!) as List)
              .map((e) => Txn.fromJson(e as Map<String, dynamic>))
              .toList();
          _merge(remoteList);
          await _persistLocal();
          notifyListeners();
        } catch (e) {
          // 主密码与仓库数据不一致：绝不覆盖远端，避免清空白数据
          _lastSyncMsg = '主密码与仓库数据不一致，无法读取远端';
          _syncing = false;
          notifyListeners();
          return;
        }
      }

      // 2) 仅在数据有变化时推送，避免无谓提交
      final localPlain = jsonEncode(_txns.map((t) => t.toJson()).toList());
      final needPush = remote == null || localPlain != remotePlain;
      if (!needPush) {
        _lastSyncMsg = '已是最新 ${_fmtNow()}';
        return;
      }

      // 3) 推送加密后的全量数据
      final encPayload = CryptoService.encryptText(localPlain, _masterPassword!);
      final encText = jsonEncode(encPayload);
      final contentBase64 = base64Encode(utf8.encode(encText));
      await GitHubService.uploadFile(
        owner: owner,
        repo: repo,
        path: path,
        token: token,
        contentBase64: contentBase64,
        message: 'ledger sync ${DateTime.now().toIso8601String()}',
        sha: remote?['sha'],
      );
      _lastSyncMsg = '已同步 ${_fmtNow()}';
    } catch (e) {
      _lastSyncMsg = '同步失败：$e';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// 合并策略：同 id 以 updatedAt 较大者胜；并集其余
  void _merge(List<Txn> remote) {
    final map = <String, Txn>{for (var t in _txns) t.id: t};
    for (var r in remote) {
      final local = map[r.id];
      if (local == null || r.updatedAt > local.updatedAt) {
        map[r.id] = r;
      }
    }
    _txns = map.values.toList();
  }

  void _startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => sync());
  }

  String _fmtNow() {
    final n = DateTime.now();
    return '${n.hour}:${n.minute.toString().padLeft(2, '0')}';
  }
}
