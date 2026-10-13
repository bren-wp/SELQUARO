import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'portable_backup.dart';
import 'models.dart';
import 'vault_catalog.dart';
import 'vault_store.dart';

class VaultController extends ChangeNotifier {
  VaultController(this.store);
  final VaultStore store;

  List<Purchase> purchases = const [];
  bool loaded = false;
  String? error;
  bool _mutating = false;

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_mutating) throw StateError('A vault update is already in progress');
    _mutating = true;
    try { return await operation(); } finally { _mutating = false; }
  }

  Future<void> _bestEffortDelete(VaultDocument document) async {
    // Cleanup failures only leave encrypted orphan bytes; saved purchases
    // must not be rolled back or reported as unsaved after the commit.
    try { await store.deleteDocument(document); } catch (_) { /* retry by maintenance */ }
  }

  Future<void> initialize() async {
    try {
      final loadedPurchases = await store.load();
      VaultCatalog.validate(loadedPurchases);
      purchases = loadedPurchases;
    } catch (_) {
      // Never reset or overwrite an encrypted vault after a read failure.
      error = 'The encrypted vault could not be unlocked. No data was deleted.';
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> upsert(Purchase item) => _exclusive(() async {
    if (error != null) throw StateError('Vault is locked');
    final previousDocuments = purchases.where((entry) => entry.id == item.id).expand((entry) => entry.documents).toList();
    final updated = [...purchases.where((entry) => entry.id != item.id), item];
    VaultCatalog.validate(updated);
    await store.save(updated);
    purchases = updated;
    notifyListeners();
    final remainingIds = item.documents.map((d) => d.id).toSet();
    for (final old in previousDocuments) {
      if (!remainingIds.contains(old.id)) {
        await _bestEffortDelete(old);
      }
    }
  });

  Future<void> remove(Purchase item) => _exclusive(() async {
    if (error != null) throw StateError('Vault is locked');
    // Use the current committed record, not a stale details-page snapshot.
    // Otherwise the wrong documents could be deleted after an edit.
    Purchase? current;
    for (final entry in purchases) {
      if (entry.id == item.id) {
        current = entry;
        break;
      }
    }
    if (current == null) {
      throw StateError('This purchase has already been removed');
    }
    final updated = purchases.where((entry) => entry.id != item.id).toList();
    await store.save(updated);
    purchases = updated;
    notifyListeners();
    for (final document in current.documents) {
      await _bestEffortDelete(document);
    }
  });

  /// Keep the metadata/attachment snapshot consistent with concurrent edits.
  /// Encryption runs under the same exclusive lock as imports and restores.
  Future<Uint8List> createBackup(String passphrase) => _exclusive(() async {
    if (error != null) throw StateError('Vault is locked');
    final snapshot = List<Purchase>.of(purchases);
    final files = <String, Uint8List>{};
    for (final purchase in snapshot) {
      for (final document in purchase.documents) {
        files[document.id] = await store.readDocument(document);
      }
    }
    return PortableBackup.encrypt(
      purchases: snapshot, files: files, password: passphrase,
    );
  });

  /// Restore only to an empty vault, ensuring no user records are replaced.
  Future<void> restoreBackup(Uint8List ciphertext, String passphrase) => _exclusive(() async {
    if (error != null) throw StateError('Vault is locked');
    if (purchases.isNotEmpty) {
      throw StateError('For safety, restore is available only when the vault is empty');
    }
    final contents = await PortableBackup.decrypt(ciphertext, passphrase);
    final written = <VaultDocument>[];
    try {
      for (final purchase in contents.purchases) {
        for (final document in purchase.documents) {
          await store.restoreDocumentBytes(document, contents.files[document.id]!);
          written.add(document);
        }
      }
      await store.save(contents.purchases);
      purchases = contents.purchases;
      notifyListeners();
    } catch (_) {
      // A rollback cleanup failure must not hide the original restore error.
      for (final doc in written) {
        await _bestEffortDelete(doc);
      }
      rethrow;
    }
  });

  Future<void> clear() => _exclusive(() async {
    await store.deleteAll();
    purchases = [];
    error = null;
    notifyListeners();
  });

  List<Purchase> get ordered {
    final list = [...purchases];
    list.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return list;
  }

  List<Purchase> get upcoming {
    final now = DateTime.now();
    final list = purchases.where((p) {
      final days = p.daysRemaining(now);
      return days != null && days >= 0 && days <= 90;
    }).toList();
    list.sort((a, b) => a.warrantyEndsAt!.compareTo(b.warrantyEndsAt!));
    return list;
  }
}
