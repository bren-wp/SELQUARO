import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/models.dart';

void main() {
  test('empty vault is supported without seeded accounts or products', () {
    expect(decodePurchases(encodePurchases([])), isEmpty);
  });

  test('purchase retains receipt references and expiry', () {
    final purchase = Purchase(
      id: 'real-user-item',
      name: 'User entered product',
      merchant: 'Merchant',
      category: 'Electronics',
      purchasedAt: DateTime(2026, 1, 1),
      amount: 99.90,
      currency: 'EUR',
      warrantyEndsAt: DateTime(2028, 1, 1),
      serialNumber: '',
      notes: '',
      coverDocumentId: 'doc1',
      documents: [VaultDocument(id: 'doc1', name: 'receipt.pdf', mimeType: 'application/pdf', createdAt: DateTime(2026, 1, 1))],
    );
    final restored = decodePurchases(encodePurchases([purchase])).single;
    expect(restored.documents.single.name, 'receipt.pdf');
    expect(restored.coverDocumentId, 'doc1');
    expect(restored.daysRemaining(DateTime(2027, 1, 1)), 365);
    expect(restored.amount, 99.9);
  });

  test('unrecognized schema cannot silently discard data', () {
    expect(() => decodePurchases('{"schema":999,"purchases":[]}'), throwsFormatException);
  });
}
