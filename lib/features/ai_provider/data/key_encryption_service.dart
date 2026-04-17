import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts and decrypts sensitive strings using AES-256-GCM.
///
/// The encryption key is stored in macOS Keychain via
/// [FlutterSecureStorage].
class KeyEncryptionService {
  /// Creates a [KeyEncryptionService], optionally injecting
  /// a [storage] instance.
  KeyEncryptionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyAlias =
      'com.joaquinmx.preparewithatlas.aeskey';

  final FlutterSecureStorage _storage;
  Key? _cachedKey;

  /// Encrypts [plaintext] and returns a base64-encoded ciphertext.
  ///
  /// The result encodes the random IV prepended to the ciphertext,
  /// separated by a colon: `<ivBase64>:<ciphertextBase64>`.
  Future<String> encrypt(String plaintext) async {
    final key = await _getOrCreateKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  /// Decrypts a [ciphertext] previously produced by [encrypt].
  Future<String> decrypt(String ciphertext) async {
    final key = await _getOrCreateKey();
    final parts = ciphertext.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid ciphertext format');
    }
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Future<Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;
    var keyBase64 = await _storage.read(key: _keyAlias);
    if (keyBase64 == null) {
      final random = Random.secure();
      final keyBytes =
          List<int>.generate(32, (_) => random.nextInt(256));
      keyBase64 = base64Encode(keyBytes);
      await _storage.write(key: _keyAlias, value: keyBase64);
    }
    _cachedKey = Key.fromBase64(keyBase64);
    return _cachedKey!;
  }
}
