import 'package:flutter/foundation.dart';
import 'models.dart';
import 'vault_store.dart';

class VaultController extends ChangeNotifier {
  VaultController(this.store);
  final VaultStore store;

  List<Purchase> purchases = const [];
  bool loaded = false;
  String? error;

  Future<void> initialize() async {
    try {
      purchases = await store.load();
    } catch (_) {
      // Never reset or overwrite an encrypted vault after a read failure.
      error = 'The encrypted vault could not be unlocked. No data was deleted.';
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> upsert(Purchase item) async {
    if (error != null) throw StateError('Vault is locked');
    final previousDocuments = purchases.where((entry) => entry.id == item.id).expand((entry) => entry.documents).toList();
    final updated = [...purchases.where((entry) => entry.id != item.id), item];
    await store.save(updated);
    purchases = updated;
    notifyListeners();
    final remainingIds = item.documents.map((d) => d.id).toSet();
    for (final old in previousDocuments) {
      if (!remainingIds.contains(old.id)) {
        await store.deleteDocument(old);
      }
    }
  }

  Future<void> remove(Purchase item) async {
    if (error != null) throw StateError('Vault is locked');
    final updated = purchases.where((entry) => entry.id != item.id).toList();
    await store.save(updated);
    purchases = updated;
    notifyListeners();
    for (final document in item.documents) {
      await store.deleteDocument(document);
    }
  }

  Future<void> clear() async {
    await store.deleteAll();
    purchases = [];
    error = null;
    notifyListeners();
  }

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
