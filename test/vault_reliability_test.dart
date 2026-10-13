import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/controller.dart';
import 'package:selquaro/document_signatures.dart';
import 'package:selquaro/models.dart';
import 'package:selquaro/vault_store.dart';

class InMemoryStore extends VaultStore {
  List<Purchase> disk = [];
  bool failCleanup = false;
  Completer<void>? saveGate;
  @override
  Future<void> save(List<Purchase> purchases) async {
    if (saveGate != null) await saveGate!.future;
    disk = [...purchases];
  }

  @override
  Future<List<Purchase>> load() async => disk;

  @override
  Future<void> deleteDocument(VaultDocument document) async {
    if (failCleanup) throw const FileSystemExceptionPlaceholder();
  }

  @override
  Future<void> deleteAll() async { disk.clear(); }
}

class FileSystemExceptionPlaceholder implements Exception {
  const FileSystemExceptionPlaceholder();
}

Purchase item(List<VaultDocument> docs) => Purchase(
  id: 'f39125b8-f9e1-41ef-8942-b673557ab2f3',
  name: 'User purchase',
  merchant: '',
  category: 'Other',
  purchasedAt: DateTime(2026, 10, 13),
  amount: null,
  currency: 'EUR',
  warrantyEndsAt: null,
  serialNumber: '',
  notes: '',
  documents: docs,
);

void main() {
  final doc = VaultDocument(
    id: 'da474fed-acb1-41c8-90f7-e98b10d78fda',
    name: 'receipt.pdf',
    mimeType: 'application/pdf',
    createdAt: DateTime(2026, 10, 13),
  );

  test('failed old-file cleanup cannot erase committed purchase metadata', () async {
    final store = InMemoryStore();
    final vault = VaultController(store);
    await vault.initialize();
    await vault.upsert(item([doc]));
    store.failCleanup = true;
    await vault.upsert(item([]));
    expect(vault.purchases.single.documents, isEmpty);
    expect(store.disk.single.documents, isEmpty);
  });

  test('failed attachment cleanup cannot report a successful delete as failed', () async {
    final store = InMemoryStore()..disk = [item([doc])];
    final vault = VaultController(store);
    await vault.initialize();
    store.failCleanup = true;
    await vault.remove(vault.purchases.single);
    expect(vault.purchases, isEmpty);
    expect(store.disk, isEmpty);
  });

  test('overlapping writes fail rather than overwriting newer records', () async {
    final store = InMemoryStore()..saveGate = Completer<void>();
    final vault = VaultController(store);
    await vault.initialize();
    final first = vault.upsert(item([]));
    await expectLater(vault.upsert(item([doc])), throwsStateError);
    store.saveGate!.complete();
    await first;
    expect(vault.purchases.single.documents, isEmpty);
  });

  test('document headers match their declared file type', () {
    DocumentSignatures.validate(
      name: 'invoice.PDF', mimeType: 'application/pdf',
      bytes: Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 55]),
    );
    DocumentSignatures.validate(
      name: 'photo.jpeg', mimeType: 'image/jpeg',
      bytes: Uint8List.fromList([255, 216, 255, 224, 0, 16]),
    );
    DocumentSignatures.validate(
      name: 'logo.png', mimeType: 'image/png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
  });

  test('renamed executable and invalid MIME are rejected', () {
    expect(() => DocumentSignatures.validate(
      name: 'invoice.pdf', mimeType: 'application/pdf',
      bytes: Uint8List.fromList([77, 90, 0, 0, 0]),
    ), throwsFormatException);
    expect(() => DocumentSignatures.validate(
      name: 'image.jpg', mimeType: 'image/png',
      bytes: Uint8List.fromList([255, 216, 255]),
    ), throwsFormatException);
    expect(() => DocumentSignatures.validate(
      name: '../receipt.pdf', mimeType: 'application/pdf',
      bytes: Uint8List.fromList([37, 80, 68, 70, 45]),
    ), throwsFormatException);
  });
}
