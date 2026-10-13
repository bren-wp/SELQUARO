import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/models.dart';
import 'package:selquaro/vault_store.dart';

void main() {
  final invalid = VaultDocument(
    id: '../external-file',
    name: 'receipt.pdf',
    mimeType: 'application/pdf',
    createdAt: DateTime(2026, 10, 13),
  );
  final vault = VaultStore();

  test('document read refuses path traversal before touching the filesystem', () async {
    await expectLater(vault.readDocument(invalid), throwsFormatException);
  });

  test('document delete refuses path traversal before touching the filesystem', () async {
    await expectLater(vault.deleteDocument(invalid), throwsFormatException);
  });
}
