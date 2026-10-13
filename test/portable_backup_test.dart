import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/models.dart';
import 'package:selquaro/portable_backup.dart';

void main() {
  final receipt = VaultDocument(
    id: 'de56e8b1-19ae-4ee5-91b3-a369b9d1b734',
    name: 'receipt.pdf',
    mimeType: 'application/pdf',
    createdAt: DateTime(2026, 10, 13),
  );
  final purchase = Purchase(
    id: '535ab64f-e470-476f-8337-233933fc168c',
    name: 'Private purchase',
    merchant: 'Store',
    category: 'Computers',
    purchasedAt: DateTime(2026, 10, 13),
    amount: 250,
    currency: 'EUR',
    warrantyEndsAt: DateTime(2028, 10, 13),
    serialNumber: 'serial',
    notes: '',
    documents: [receipt],
  );

  test('backup roundtrip restores all fields and original document bytes', () async {
    final original = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 55]);
    final encrypted = await PortableBackup.encrypt(
      purchases: [purchase], files: {receipt.id: original},
      password: 'very-long-unique-passphrase',
    );
    expect(String.fromCharCodes(encrypted.take(5)), 'SQBK2');
    final data = await PortableBackup.decrypt(encrypted, 'very-long-unique-passphrase');
    expect(data.purchases.single.documents.single.name, 'receipt.pdf');
    expect(data.purchases.single.warrantyEndsAt, DateTime(2028, 10, 13));
    expect(data.files[receipt.id], original);
  });

  test('wrong backup password fails authentication', () async {
    final ciphertext = await PortableBackup.encrypt(
      purchases: [], files: {}, password: 'correct-unique-passphrase',
    );
    await expectLater(
      PortableBackup.decrypt(ciphertext, 'incorrect-long-passphrase'),
      throwsA(anything),
    );
  });

  test('tampered encrypted backup is rejected', () async {
    final ciphertext = await PortableBackup.encrypt(
      purchases: [], files: {}, password: 'correct-unique-passphrase',
    );
    ciphertext[ciphertext.length - 19] ^= 0x40;
    await expectLater(
      PortableBackup.decrypt(ciphertext, 'correct-unique-passphrase'),
      throwsA(isA<Exception>()),
    );
  });

  test('refuses short passphrases', () async {
    await expectLater(
      PortableBackup.encrypt(purchases: [], files: {}, password: 'short'),
      throwsFormatException,
    );
  });
}
