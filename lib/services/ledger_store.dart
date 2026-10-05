import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/txn.dart';
import 'crypto_service.dart';
import 'github_service.dart';

/// 加密文件包装体：记录 + 删除墓碑 + 自定义分类
class _Bundle {
  final List<Txn> txns;
  final Set<String> deleted;
  final Map<String, List<String>> categories;
  final int categoriesUpdatedAt;

  _Bundle({
    required this.txns,
    required this.deleted,
    required this.categories,
    required this.categoriesUpdatedAt,
  });

  String encode() => jsonEncode({
        'txns': txns.map((t) => t.toJson()).toList(),
        'deleted': deleted.toList(),
        'categories': categories,
        'categoriesUpdatedAt': categoriesUpdatedAt,
      });

  /// 解析明文：兼容旧格式（纯 List<Txn>）
  static _Bundle decode(String plain) {
    final d = jsonDecode(plain);
    if (d is List) {
      // 旧版：仅有记录
      final txns = d.map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
      return _Bundle(
        txns: txns,
        deleted: {},
        categories: _defaultCategories(),
        categoriesUpdatedAt: 0,
      );
    }
    final map = d as Map<String, dynamic>;
    final txns =
        (map['txns'] as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
    final deleted = Set<String>.from(map['deleted'] as List? ?? const []);
    final catsRaw = map['categories'] as Map<String, dynamic>? ?? {};
    final categories = <String, List<String>>{
      'expense':
          List<String>.from(catsRaw['expense'] as List? ?? _defaultCategories()['expense']!),
      'income':
          List<String>.from(catsRaw['income'] as List? ?? _defaultCategories()['income']!),
    };
    final categoriesUpdatedAt = (map['categoriesUpdatedAt'] as int?) ?? 0;
    return _Bundle(
      txns: txns,
      deleted: deleted,
      categories: categories,
      categoriesUpdatedAt: categoriesUpdatedAt,
    );
  }
}

/// 记账数据仓库：管理本地缓存、与 GitHub 私有仓库的加密同步
///
/// 本地加密缓存使用 shared_preferences（原生与 Web 通用），
/// 不再依赖 path_provider/dart:io，因此同一份代码可编译为安卓/iOS/Web。
class LedgerStore extends ChangeNotifier {
  List<Txn> _txns = [];
  Set<String> _deleted = {};
  Map<String, List<String>> _categories = _defaultCategories();
  int _categoriesUpdatedAt = 0;

  bool _unlocked = false;
  String? _masterPassword;
  bool _syncing = false;
  Timer? _timer;
  String _lastSyncMsg = '';

  List<Txn> get txns => List.unmodifiable(_txns);
  bool get unlocked => _unlocked;
  String get lastSyncMsg => _lastSyncMsg;
  List<String> categories(String type) =>
      List.unmodifiable(_categories[type] ?? const []);

  static const _localKey = 'ledger_local_enc';
  static const _storage = FlutterSecureStorage();

  static Map<String, List<String>> _defaultCategories() => {
        'expense': List<String>.from(Categories.expense),
        'income': List<String>.from(Categories.income),
      };

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
      final bundle = _Bundle.decode(plain);
      _txns = bundle.txns;
      _deleted = bundle.deleted;
      _categories = bundle.categories;
      _categoriesUpdatedAt = bundle.categoriesUpdatedAt;
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
    _deleted = {};
    _categories = _defaultCategories();
    _categoriesUpdatedAt = 0;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    if (_masterPassword == null) return;
    final prefs = await SharedPreferences.getInstance();
    final plain = _encodeLocal();
    final payload = CryptoService.encryptText(plain, _masterPassword!);
    await prefs.setString(_localKey, jsonEncode(payload));
  }

  String _encodeLocal() => _Bundle(
        txns: _txns,
        deleted: _deleted,
        categories: _categories,
        categoriesUpdatedAt: _categoriesUpdatedAt,
      ).encode();

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
    _deleted.add(id); // 墓碑：同步后远端也会删除，避免被合并回来
    _afterChange();
  }

  /// 新增分类
  void addCategory(String type, String name) {
    name = name.trim();
    if (name.isEmpty) return;
    final list = _categories.putIfAbsent(type, () => []);
    if (list.contains(name)) return;
    list.add(name);
    _bumpCategories();
    _afterChange();
  }

  /// 重命名分类（同步改历史记录的分类名，保持一致）
  void renameCategory(String type, String oldName, String newName) {
    newName = newName.trim();
    if (newName.isEmpty || newName == oldName) return;
    final list = _categories[type];
    if (list == null) return;
    final idx = list.indexOf(oldName);
    if (idx < 0) return;
    if (list.contains(newName)) {
      list.removeAt(idx); // 目标已存在，直接并入
    } else {
      list[idx] = newName;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _txns.length; i++) {
      if (_txns[i].type == type && _txns[i].category == oldName) {
        _txns[i] = _txns[i].copyWith(category: newName, updatedAt: now);
      }
    }
    _bumpCategories();
    _afterChange();
  }

  /// 删除分类：相关记录自动改到“其他支出/其他收入”
  void deleteCategory(String type, String name) {
    final list = _categories[type];
    if (list == null) return;
    list.remove(name);
    final fallback = type == 'income' ? '其他收入' : '其他支出';
    if (!list.contains(fallback)) list.add(fallback);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _txns.length; i++) {
      if (_txns[i].type == type && _txns[i].category == name) {
        _txns[i] = _txns[i].copyWith(category: fallback, updatedAt: now);
      }
    }
    _bumpCategories();
    _afterChange();
  }

  void _bumpCategories() {
    _categoriesUpdatedAt = DateTime.now().millisecondsSinceEpoch;
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
      _Bundle? remoteBundle;
      String? remotePlain;
      if (remote != null) {
        try {
          final decoded = utf8.decode(base64Decode(remote['content']!));
          final payload = jsonDecode(decoded) as Map<String, dynamic>;
          remotePlain = CryptoService.decryptText(payload, _masterPassword!);
          remoteBundle = _Bundle.decode(remotePlain);
        } catch (e) {
          // 主密码与仓库数据不一致：绝不覆盖远端，避免清空白数据
          _lastSyncMsg = '主密码与仓库数据不一致，无法读取远端';
          _syncing = false;
          notifyListeners();
          return;
        }
      }

      if (remoteBundle == null) {
        // 远端无数据：直接推送本地全量
        await _push(owner, repo, path, token, remote?['sha']);
        return;
      }

      // 2) 合并记录（同 id 以 updatedAt 较大者胜）
      _merge(remoteBundle.txns);
      // 合并删除墓碑（并集）
      _deleted.addAll(remoteBundle.deleted);
      // 应用墓碑：移除已被删除的记录
      _txns.removeWhere((t) => _deleted.contains(t.id));
      // 合并分类：整组按时间戳“最后写入胜”
      if (remoteBundle.categoriesUpdatedAt > _categoriesUpdatedAt) {
        _categories = Map<String, List<String>>.from(
            remoteBundle.categories.map((k, v) => MapEntry(k, List<String>.from(v))));
        _categoriesUpdatedAt = remoteBundle.categoriesUpdatedAt;
      }

      await _persistLocal();
      notifyListeners();

      // 3) 本地与远端不一致才推送；删除墓碑使本地与远端不同 -> 必推；
      //    空本地拉到远端数据时，合并后与远端一致 -> 不推（避免清空云端）
      final localPlain = _encodeLocal();
      final needPush = remote == null || localPlain != remotePlain;
      if (!needPush) {
        _lastSyncMsg = '已是最新 ${_fmtNow()}';
        return;
      }
      await _push(owner, repo, path, token, remote?['sha']);
    } catch (e) {
      _lastSyncMsg = '同步失败：$e';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _push(String owner, String repo, String path, String token, String? sha) async {
    final encPayload = CryptoService.encryptText(_encodeLocal(), _masterPassword!);
    final encText = jsonEncode(encPayload);
    final contentBase64 = base64Encode(utf8.encode(encText));
    await GitHubService.uploadFile(
      owner: owner,
      repo: repo,
      path: path,
      token: token,
      contentBase64: contentBase64,
      message: 'ledger sync ${DateTime.now().toIso8601String()}',
      sha: sha,
    );
    _lastSyncMsg = '已同步 ${_fmtNow()}';
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
