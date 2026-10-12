import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'models.dart';

/// Password-protected portable backup. No servers and no plaintext temp files.
/// Header SQBK2 + 16-byte salt + 12-byte nonce + ciphertext + 16-byte MAC.
class PortableBackup {
  static final _aes = AesGcm.with256bits();
  static const _signature = 'SQBK2';
  static const maxBytes = 70 * 1024 * 1024;
  static const maxDocuments = 150;
  static const maxEach = 20 * 1024 * 1024;
  static const _saltLength = 16;

  static Future<SecretKey> _derive(String password, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256)
          .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static void _checkPassword(String password) {
    if (password.runes.length < 12 || password.runes.length > 256) {
      throw const FormatException('Backup passphrase must contain 12–256 characters');
    }
  }

  static Future<Uint8List> encrypt({
    required List<Purchase> purchases,
    required Map<String, Uint8List> files,
    required String password,
  }) async {
    _checkPassword(password);
    if (files.length > maxDocuments) {
      throw const FormatException('Too many attachments for one backup');
    }
    final payload = {
      'schema': 1,
      'purchases': purchases.map((item) => item.toJson()).toList(),
      'files': files.map((id, data) => MapEntry(id, base64Encode(data))),
    };
    final plaintext = utf8.encode(jsonEncode(payload));
    if (plaintext.length > maxBytes) {
      throw const FormatException('Backup exceeds the 70 MB limit');
    }
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await _derive(password, salt);
    final box = await _aes.encrypt(plaintext, secretKey: key, nonce: nonce);
    return Uint8List.fromList([
      ...utf8.encode(_signature), ...salt, ...box.nonce, ...box.cipherText, ...box.mac.bytes,
    ]);
  }

  static Future<BackupContents> decrypt(Uint8List encrypted, String password) async {
    _checkPassword(password);
    if (encrypted.length < 5 + _saltLength + 12 + 16 ||
        encrypted.length > (maxBytes * 2) ||
        utf8.decode(encrypted.sublist(0, 5)) != _signature) {
      throw const FormatException('Invalid or oversized SELQUARO backup');
    }
    final salt = encrypted.sublist(5, 5 + _saltLength);
    final packed = encrypted.sublist(5 + _saltLength);
    final box = SecretBox.fromConcatenation(packed, nonceLength: 12, macLength: 16);
    final plain = await _aes.decrypt(box, secretKey: await _derive(password, salt));
    if (plain.length > maxBytes) throw const FormatException('Decrypted backup is oversized');
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    if (json['schema'] != 1) throw const FormatException('Unsupported backup version');
    final records = (json['purchases'] as List<dynamic>)
        .map((entry) => Purchase.fromJson(Map<String, dynamic>.from(entry as Map))).toList();
    final encodedFiles = Map<String, dynamic>.from(json['files'] as Map);
    if (encodedFiles.length > maxDocuments) throw const FormatException('Too many backup files');
    final files = <String, Uint8List>{};
    var total = 0;
    for (final entry in encodedFiles.entries) {
      if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(entry.key)) {
        throw const FormatException('Invalid attachment identifier');
      }
      final bytes = base64Decode(entry.value as String);
      if (bytes.isEmpty || bytes.length > maxEach) {
        throw const FormatException('Invalid attachment size');
      }
      total += bytes.length;
      if (total > maxBytes) throw const FormatException('Too many attachment bytes');
      files[entry.key] = bytes;
    }
    final ids = <String>{};
    for (final purchase in records) {
      for (final document in purchase.documents) {
        if (!ids.add(document.id) || !files.containsKey(document.id)) {
          throw const FormatException('Missing or duplicate backup document');
        }
      }
    }
    if (files.length != ids.length) {
      throw const FormatException('Backup contains unreferenced attachments');
    }
    return BackupContents(records, files);
  }
}

class BackupContents {
  const BackupContents(this.purchases, this.files);
  final List<Purchase> purchases;
  final Map<String, Uint8List> files;
}
