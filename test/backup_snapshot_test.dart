import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/controller.dart';
import 'package:selquaro/models.dart';
import 'package:selquaro/portable_backup.dart';
import 'package:selquaro/vault_store.dart';

class SnapshotStore extends VaultStore {
  final gate = Completer<void>();
  late List<Purchase> records;

  @override
  Future<List<Purchase>> load() async => records;

  @override
  Future<Uint8List> readDocument(VaultDocument document) async {
    await gate.future;
    return Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 55]);
  }

  @override
  Future<void> save(List<Purchase> value) async {
    records = [...value];
  }
}

void main() {
  test('backup locks the vault until all attachments are read', () async {
    final doc = VaultDocument(
      id: '4c6ef9e8-e16a-4568-b46e-c16b9dd7c2c1',
      name: 'receipt.pdf',
      mimeType: 'application/pdf',
      createdAt: DateTime(2026, 10, 13),
    );
    Purchase item(String name) => Purchase(
      id: 'e392d7f8-099c-4e54-9ad1-83125a128329',
      name: name, merchant: '', category: 'Other',
      purchasedAt: DateTime(2026, 10, 13),
      amount: null, currency: 'EUR', warrantyEndsAt: null,
      serialNumber: '', notes: '', documents: [doc],
    );
    final store = SnapshotStore()..records = [item('First name')];
    final controller = VaultController(store);
    await controller.initialize();

    final runningBackup = controller.createBackup('secure-long-backup-passphrase');
    await expectLater(controller.upsert(item('Edited name')), throwsStateError);
    store.gate.complete();
    final ciphertext = await runningBackup;
    final decrypted = await PortableBackup.decrypt(
      ciphertext, 'secure-long-backup-passphrase');
    expect(decrypted.purchases.single.name, 'First name');
    expect(decrypted.files[doc.id]?.length, 8);

    await controller.upsert(item('Edited name'));
    expect(controller.purchases.single.name, 'Edited name');
  });
}
