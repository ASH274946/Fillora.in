import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _dbKeyName = 'db_encryption_key';

  /// Get or create a 32-byte key for AES-256 encryption
  Future<encrypt.Key> _getEncryptionKey() async {
    String? storedKey = await _secureStorage.read(key: _dbKeyName);
    
    if (storedKey == null) {
      // Generate a new random key
      final key = encrypt.Key.fromSecureRandom(32);
      await _secureStorage.write(key: _dbKeyName, value: key.base64);
      return key;
    }
    
    return encrypt.Key.fromBase64(storedKey);
  }

  /// Encrypt sensitive string data
  Future<String> encryptData(String data) async {
    if (data.isEmpty) return data;
    
    try {
      final key = await _getEncryptionKey();
      // Use a random IV for every encryption operation (best practice)
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      final encrypted = encrypter.encrypt(data, iv: iv);
      
      // Prepend IV to the encrypted data (base64) so we can use it during decryption
      // Format: base64(iv) + ":" + base64(ciphertext)
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print('Encryption error: $e');
      return data; // Fallback to plain text if encryption fails
    }
  }

  /// Decrypt sensitive string data
  Future<String> decryptData(String encryptedData) async {
    if (encryptedData.isEmpty || !encryptedData.contains(':')) return encryptedData;
    
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return encryptedData;
      
      final iv = encrypt.IV.fromBase64(parts[0]);
      final ciphertext = parts[1];
      
      final key = await _getEncryptionKey();
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      
      return encrypter.decrypt64(ciphertext, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      return encryptedData; // Return as is if decryption fails
    }
  }

  /// Hash sensitive data (one-way)
  String hashData(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }
}
