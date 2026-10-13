import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/models.dart';

Purchase coverage(DateTime expiry) => Purchase(
  id: '99ba2571-730e-4a3d-bcc8-1bbd6995e5aa',
  name: 'Verified purchase',
  merchant: '',
  category: 'Other',
  purchasedAt: DateTime(2026, 1, 1),
  amount: null,
  currency: 'EUR',
  warrantyEndsAt: expiry,
  serialNumber: '',
  notes: '',
  documents: const [],
);

void main() {
  test('warranty calendar dates ignore time-of-day', () {
    expect(coverage(DateTime(2026, 10, 13, 23, 59))
        .daysRemaining(DateTime(2026, 10, 13, 0, 1)), 0);
    expect(coverage(DateTime(2026, 10, 14))
        .daysRemaining(DateTime(2026, 10, 13, 23)), 1);
  });

  test('calendar day differences remain exact over spring DST', () {
    // Europe's spring-forward change occurs 29 March 2026.
    expect(coverage(DateTime(2026, 3, 30))
        .daysRemaining(DateTime(2026, 3, 28)), 2);
  });

  test('calendar day differences remain exact over autumn DST', () {
    // Europe's clocks change 25 October 2026.
    expect(coverage(DateTime(2026, 10, 26))
        .daysRemaining(DateTime(2026, 10, 24)), 2);
  });

  test('expired warranties are negative and open coverage is null', () {
    expect(coverage(DateTime(2026, 10, 12))
        .daysRemaining(DateTime(2026, 10, 13)), -1);
    final without = Purchase(
      id: '5baa8800-131d-43a7-96df-617ef049fe3b',
      name: 'No warranty',
      merchant: '',
      category: 'Other',
      purchasedAt: DateTime(2026, 1, 1),
      amount: null,
      currency: 'EUR',
      warrantyEndsAt: null,
      serialNumber: '',
      notes: '',
      documents: const [],
    );
    expect(without.daysRemaining(DateTime(2026, 10, 13)), isNull);
  });
}
