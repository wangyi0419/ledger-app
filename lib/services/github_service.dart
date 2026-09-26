import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 与 GitHub Contents API 交互
class GitHubService {
  static const _storage = FlutterSecureStorage();
  static const _api = 'https://api.github.com';

  /// 保存并持久化连接配置（token 存于系统安全存储）
  static Future<void> saveConfig({
    required String owner,
    required String repo,
    required String token,
    required String path,
  }) async {
    await _storage.write(key: 'gh_owner', value: owner);
    await _storage.write(key: 'gh_repo', value: repo);
    await _storage.write(key: 'gh_token', value: token);
    await _storage.write(key: 'gh_path', value: path);
  }

  static Future<Map<String, String?>> loadConfig() async {
    return {
      'owner': await _storage.read(key: 'gh_owner'),
      'repo': await _storage.read(key: 'gh_repo'),
      'token': await _storage.read(key: 'gh_token'),
      'path': await _storage.read(key: 'gh_path'),
    };
  }

  static Future<void> clearToken() => _storage.delete(key: 'gh_token');

  /// 读取文件：返回 {content(base64), sha}；不存在返回 null
  static Future<Map<String, String>?> fetchFile(
      String owner, String repo, String path, String token) async {
    final url = Uri.parse('$_api/repos/$owner/$repo/contents/$path');
    final res = await http.get(url, headers: _headers(token));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('GitHub 读取失败 (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return {
      'content': (json['content'] as String).replaceAll('\n', ''),
      'sha': json['sha'] as String,
    };
  }

  /// 创建或更新文件，返回新的 sha
  static Future<String> uploadFile({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String contentBase64,
    required String message,
    String? sha,
  }) async {
    final url = Uri.parse('$_api/repos/$owner/$repo/contents/$path');
    final body = <String, dynamic>{
      'message': message,
      'content': contentBase64,
    };
    if (sha != null) body['sha'] = sha;
    final res = await http.put(url,
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('GitHub 写入失败 (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['content'] as Map<String, dynamic>)['sha'] as String;
  }

  /// 测试连接：读取用户基本信息
  static Future<String> testConnection(String token) async {
    final res = await http.get(Uri.parse('$_api/user'),
        headers: _headers(token));
    if (res.statusCode != 200) {
      throw Exception('Token 无效或权限不足 (${res.statusCode})');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['login'] as String;
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
      };
}
