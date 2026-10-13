import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/backup_integrity.dart';
import 'package:selquaro/models.dart';

const purchaseId = 'c104ea8f-6d6a-4e65-8c58-1c178e54d111';
const documentId = '17cb69aa-2edc-4dd8-b8a6-87ad1b3dfac2';

Purchase purchase({
  String id = purchaseId,
  String name = 'Purchased item',
  String? cover,
  List<VaultDocument>? docs,
  double? amount = 12.5,
}) => Purchase(
      id: id,
      name: name,
      merchant: 'Store',
      category: 'Electronics',
      purchasedAt: DateTime(2026, 10, 13),
      amount: amount,
      currency: 'EUR',
      warrantyEndsAt: DateTime(2028, 10, 13),
      serialNumber: '',
      notes: '',
      documents: docs ?? [],
      coverDocumentId: cover,
    );

VaultDocument image(String id, {String name = 'device.jpg'}) => VaultDocument(
      id: id,
      name: name,
      mimeType: 'image/jpeg',
      createdAt: DateTime(2026, 10, 13),
    );

void main() {
  test('valid empty vault and valid image attachment are accepted', () {
    BackupIntegrity.validate([], {});
    BackupIntegrity.validate([
      purchase(cover: documentId, docs: [image(documentId)]),
    ], {
      documentId: Uint8List.fromList([1, 2, 3]),
    });
  });

  test('duplicate purchase identifiers fail before any restore', () {
    expect(() => BackupIntegrity.validate([
      purchase(), purchase(),
    ], {}), throwsFormatException);
  });

  test('orphaned encrypted attachment fails', () {
    expect(() => BackupIntegrity.validate(
      [purchase()],
      {documentId: Uint8List.fromList([1])},
    ), throwsFormatException);
  });

  test('missing original attachment fails', () {
    expect(() => BackupIntegrity.validate(
      [purchase(docs: [image(documentId)])], {},
    ), throwsFormatException);
  });

  test('stale product photograph reference fails', () {
    expect(() => BackupIntegrity.validate(
      [purchase(cover: documentId)], {},
    ), throwsFormatException);
  });

  test('invalid purchase metadata fails', () {
    expect(() => BackupIntegrity.validate(
      [purchase(name: '  ')], {},
    ), throwsFormatException);
    expect(() => BackupIntegrity.validate(
      [purchase(amount: double.nan)], {},
    ), throwsFormatException);
  });

  test('unsupported file names and MIME pairs fail', () {
    expect(() => BackupIntegrity.validate(
      [purchase(docs: [image(documentId, name: 'invoice.exe')])],
      {documentId: Uint8List.fromList([1])},
    ), throwsFormatException);
  });
}
