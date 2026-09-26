import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// 主密码派生 + AES-256-CBC 加密（纯 Dart，兼容 Dart 3）
///
/// 加密文件结构（均为 base64 字符串）：
/// { "salt": ..., "iv": ..., "data": ... }
class CryptoService {
  static const int _iterations = 100000;
  static const int _saltLen = 16;
  static const int _ivLen = 16;

  /// 由主密码 + 盐派生 32 字节密钥（PBKDF2-HMAC-SHA256）
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, _iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static PaddedBlockCipherImpl _newCipher() =>
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));

  /// 加密明文，返回可序列化结构
  static Map<String, String> encryptText(String plainText, String password) {
    final salt = _randomBytes(_saltLen);
    final iv = _randomBytes(_ivLen);
    final key = _deriveKey(password, salt);
    final cipher = _newCipher()
      ..init(true, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
    final plain = Uint8List.fromList(utf8.encode(plainText));
    final cipherBytes = cipher.process(plain);
    return {
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'data': base64Encode(cipherBytes),
    };
  }

  /// 解密。密码错误会抛异常（调用方据此判断主密码不正确）
  static String decryptText(Map<String, dynamic> payload, String password) {
    final salt = base64Decode(payload['salt'] as String);
    final iv = base64Decode(payload['iv'] as String);
    final data = base64Decode(payload['data'] as String);
    final key = _deriveKey(password, salt);
    final cipher = _newCipher()
      ..init(false, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
    final plainBytes = cipher.process(data);
    return utf8.decode(plainBytes);
  }

  static Uint8List _randomBytes(int len) {
    final rng = Random.secure();
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) bytes[i] = rng.nextInt(256);
    return bytes;
  }
}
