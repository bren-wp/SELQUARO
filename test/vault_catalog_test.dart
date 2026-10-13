import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/controller.dart';
import 'package:selquaro/models.dart';
import 'package:selquaro/vault_catalog.dart';
import 'package:selquaro/vault_store.dart';

Purchase record(String id, {String name = 'Real product',
  List<VaultDocument> documents = const []}) => Purchase(
    id: id, name: name, merchant: '', category: 'Other',
    purchasedAt: DateTime(2026, 10, 13), amount: null, currency: 'EUR',
    warrantyEndsAt: null, serialNumber: '', notes: '', documents: documents,
  );

VaultDocument attachment(String id) => VaultDocument(
  id: id, name: 'receipt.pdf', mimeType: 'application/pdf',
  createdAt: DateTime(2026, 10, 13),
);

class CatalogStore extends VaultStore {
  List<Purchase> disk = [];
  final deleted = <String>[];

  @override
  Future<List<Purchase>> load() async => disk;

  @override
  Future<void> save(List<Purchase> values) async {
    disk = [...values];
  }

  @override
  Future<void> deleteDocument(VaultDocument document) async {
    deleted.add(document.id);
  }
}

void main() {
  test('rejects duplicate purchases and document references', () {
    expect(() => VaultCatalog.validate([
      record('p1'), record('p1'),
    ]), throwsFormatException);
    expect(() => VaultCatalog.validate([
      record('p1', documents: [attachment('shared')]),
      record('p2', documents: [attachment('shared')]),
    ]), throwsFormatException);
    expect(() => VaultCatalog.validate([
      record('p1', name: '   '),
    ]), throwsFormatException);
    // Legacy non-UUID identifiers are still readable for data compatibility.
    VaultCatalog.validate([record('legacy-id', documents: [attachment('old-doc')])]);
  });

  test('corrupt local index is not treated as empty and no write is made', () async {
    final store = CatalogStore()..disk = [record('p1'), record('p1')];
    final controller = VaultController(store);
    await controller.initialize();
    expect(controller.loaded, isTrue);
    expect(controller.error, isNotNull);
    expect(controller.purchases, isEmpty);
    await expectLater(controller.upsert(record('replacement')), throwsStateError);
    expect(store.disk.length, 2);
  });

  test('upsert rejects duplicate document IDs before committing', () async {
    final store = CatalogStore();
    final controller = VaultController(store);
    await controller.initialize();
    await expectLater(controller.upsert(record('p1', documents: [
      attachment('d1'), attachment('d1'),
    ])), throwsFormatException);
    expect(store.disk, isEmpty);
  });

  test('deletion uses latest committed attachments, not a stale page object', () async {
    final oldDocument = attachment('old-doc');
    final updatedDocument = attachment('new-doc');
    final stale = record('p1', documents: [oldDocument]);
    final current = record('p1', documents: [updatedDocument]);
    final store = CatalogStore()..disk = [current];
    final controller = VaultController(store);
    await controller.initialize();
    await controller.remove(stale);
    expect(store.disk, isEmpty);
    expect(store.deleted, ['new-doc']);
    await expectLater(controller.remove(stale), throwsStateError);
    expect(store.deleted, ['new-doc']);
  });
}
