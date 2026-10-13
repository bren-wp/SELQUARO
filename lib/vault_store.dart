import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'document_signatures.dart';
import 'models.dart';

/// No networking or accounts. Keys live in Android Keystore / Apple Keychain.
class VaultStore {
  VaultStore({FlutterSecureStorage? keyStorage})
      : _keys = keyStorage ?? const FlutterSecureStorage();

  static const _keyName = 'selquaro.vault.key.v1';
  static const _maxFileBytes = 20 * 1024 * 1024;
  static const _uuid = Uuid();

  final FlutterSecureStorage _keys;
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _vaultKey;

  Future<Directory> get _directory async {
    final base = await getApplicationSupportDirectory();
    final path = Directory('${base.path}/selquaro_v1');
    if (!await path.exists()) await path.create(recursive: true);
    if (Platform.isIOS) {
      // Prevent iCloud device backup from copying the private vault.
      await const MethodChannel('com.selquaro/security').invokeMethod<void>('excludeFromBackup');
    }
    return path;
  }

  Future<SecretKey> get _key async {
    if (_vaultKey != null) return _vaultKey!;
    final existing = await _keys.read(key: _keyName);
    if (existing == null) {
      // Never silently create a new key over an existing encrypted vault.
      // Keystore/keychain loss is unrecoverable without a portable backup.
      final directory = await _directory;
      final entries = await directory.list(followLinks: false).toList();
      if (entries.any((entity) =>
          entity is File &&
          (entity.path.endsWith('.bin') || entity.path.endsWith('.pending')))) {
        throw StateError('Encrypted data exists but its decryption key is missing');
      }
    }
    if (existing != null) {
      final bytes = base64Decode(existing);
      if (bytes.length != 32) throw const FormatException('Invalid vault encryption key');
      return _vaultKey = SecretKey(bytes);
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _keys.write(key: _keyName, value: base64Encode(bytes));
    return _vaultKey = SecretKey(bytes);
  }

  Future<Uint8List> _seal(List<int> plain) async {
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final box = await _cipher.encrypt(plain, secretKey: await _key, nonce: nonce);
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> _unseal(List<int> encrypted) async {
    if (encrypted.length < 29) throw const FormatException('Invalid encrypted document');
    final box = SecretBox.fromConcatenation(encrypted, nonceLength: 12, macLength: 16);
    return Uint8List.fromList(await _cipher.decrypt(box, secretKey: await _key));
  }

  Future<List<Purchase>> load() async {
    final base = await _directory;
    final file = File('${base.path}/vault.bin');
    if (await file.exists()) {
      final plain = await _unseal(await file.readAsBytes());
      return decodePurchases(utf8.decode(plain));
    }
    // Interrupted first save: recover a fully authenticated pending write.
    // Never treat an undecryptable pending file as an empty, new vault.
    final pending = File('${file.path}.pending');
    if (await pending.exists()) {
      final plain = await _unseal(await pending.readAsBytes());
      final recovered = decodePurchases(utf8.decode(plain));
      await pending.rename(file.path);
      return recovered;
    }
    return [];
  }

  Future<void> save(List<Purchase> purchases) async {
    final base = await _directory;
    final file = File('${base.path}/vault.bin');
    final temporary = File('${file.path}.pending');
    await temporary.writeAsBytes(await _seal(utf8.encode(encodePurchases(purchases))), flush: true);
    // Rename within the same private directory to avoid partial writes.
    await temporary.rename(file.path);
  }

  Future<void> _writeNewEncrypted(File target, Uint8List bytes) async {
    if (await target.exists()) throw StateError('Encrypted document already exists');
    try {
      await target.writeAsBytes(await _seal(bytes), flush: true);
    } catch (_) {
      // A failed write can leave a truncated encrypted file. Never leave
      // a partial attachment behind if it was not committed to metadata.
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<VaultDocument> importDocument({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final source = File(sourcePath);
    final size = await source.length();
    if (size <= 0 || size > _maxFileBytes) {
      throw const FormatException('Document must be between 1 byte and 20 MB');
    }
    final extension = fileName.split('.').last.toLowerCase();
    if (!['pdf', 'jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      throw const FormatException('Only PDF and image documents are supported');
    }
    final directory = await _directory;
    final document = VaultDocument(
      id: _uuid.v4(),
      name: fileName.split(RegExp(r'[/\\]')).last,
      mimeType: mimeType,
      createdAt: DateTime.now(),
    );
    final target = File('${directory.path}/${document.id}.bin');
    final bytes = await source.readAsBytes();
    DocumentSignatures.validate(
      name: document.name, mimeType: document.mimeType, bytes: bytes);
    await _writeNewEncrypted(target, bytes);
    return document;
  }

  Future<Uint8List> readDocument(VaultDocument document) async {
    final directory = await _directory;
    return _unseal(await File('${directory.path}/${document.id}.bin').readAsBytes());
  }

  /// Import validated backup bytes without writing plaintext to disk.
  Future<void> restoreDocumentBytes(VaultDocument document, Uint8List contents) async {
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(document.id)) {
      throw const FormatException('Invalid restored attachment identifier');
    }
    if (contents.isEmpty || contents.length > _maxFileBytes) {
      throw const FormatException('Invalid restored attachment size');
    }
    DocumentSignatures.validate(
      name: document.name, mimeType: document.mimeType, bytes: contents);
    final directory = await _directory;
    final target = File(directory.path + '/' + document.id + '.bin');
    await _writeNewEncrypted(target, contents);
  }

  Future<void> deleteDocument(VaultDocument document) async {
    final directory = await _directory;
    final file = File('${directory.path}/${document.id}.bin');
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    final directory = await _directory;
    if (await directory.exists()) await directory.delete(recursive: true);
    await _keys.delete(key: _keyName);
    _vaultKey = null;
  }
}
