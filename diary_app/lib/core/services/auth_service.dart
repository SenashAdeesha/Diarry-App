import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum AuthStatus { unknown, locked, unlocked }

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  static const _pinKey = 'diary_pin_hash';
  static const _encryptionKey = 'diary_encryption_key';
  static const _biometricEnabledKey = 'diary_biometric';

  static const _inactivityTimeout = Duration(minutes: 5);
  static const _pinIterations = 10000;

  AuthStatus _status = AuthStatus.unknown;
  DateTime _lastActive = DateTime.now();
  bool _biometricAvailable = false;

  AuthStatus get status => _status;
  bool get isLocked => _status == AuthStatus.locked;
  bool get hasPin => _status != AuthStatus.unknown;
  bool get biometricAvailable => _biometricAvailable;

  encrypt.Key? _cachedKey;

  Future<void> init() async {
    final hasPin = await _storage.containsKey(key: _pinKey);
    final hasKey = await _storage.containsKey(key: _encryptionKey);

    if (!hasKey) {
      final key = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: _encryptionKey, value: key.base64);
    }

    if (!hasPin) {
      _status = AuthStatus.unknown;
    } else {
      _status = AuthStatus.locked;
    }

    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      _biometricAvailable = false;
    }
  }

  Future<void> touch() async => _lastActive = DateTime.now();

  bool isTimedOut() =>
      DateTime.now().difference(_lastActive) > _inactivityTimeout;

  Future<bool> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    _status = AuthStatus.unlocked;
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return false;
    final match = stored == _hashPin(pin);
    if (match) _status = AuthStatus.unlocked;
    return match;
  }

  Future<void> lock() async {
    _status = AuthStatus.locked;
    _cachedKey = null;
  }

  Future<void> unlock() async => _status = AuthStatus.unlocked;

  Future<bool> authenticateWithBiometrics() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Unlock your diary',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (result) _status = AuthStatus.unlocked;
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) return false;
    await setPin(newPin);
    return true;
  }

  Future<void> resetAll() async {
    await _storage.deleteAll();
    _cachedKey = null;
    _status = AuthStatus.unknown;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    List<int> hash = bytes;
    for (int i = 0; i < _pinIterations; i++) {
      hash = sha256.convert(hash).bytes.toList();
    }
    return base64Encode(hash);
  }

  Future<encrypt.Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final raw = await _storage.read(key: _encryptionKey);
    if (raw == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: _encryptionKey, value: key.base64);
      _cachedKey = key;
      return key;
    }
    _cachedKey = encrypt.Key.fromBase64(raw);
    return _cachedKey!;
  }

  Future<String> encryptContent(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;
    final key = await _getKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  Future<String> decryptContent(String ciphertext) async {
    if (ciphertext.isEmpty || !ciphertext.contains(':')) return ciphertext;
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) return ciphertext;
      final iv = encrypt.IV(base64Decode(parts[0]));
      final key = await _getKey();
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return ciphertext;
    }
  }
}
