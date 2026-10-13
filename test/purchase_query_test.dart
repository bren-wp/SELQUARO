import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/models.dart';
import 'package:selquaro/purchase_query.dart';

Purchase purchase(
  String id,
  String name, {
  String category = 'Other',
  String merchant = '',
  String serialNumber = '',
  String notes = '',
  int purchasedDay = 1,
  int? warrantyDay,
}) => Purchase(
  id: id,
  name: name,
  merchant: merchant,
  category: category,
  purchasedAt: DateTime(2026, 1, purchasedDay),
  amount: null,
  currency: 'EUR',
  warrantyEndsAt: warrantyDay == null ? null : DateTime(2026, 10, warrantyDay),
  serialNumber: serialNumber,
  notes: notes,
  documents: const [],
);

void main() {
  final now = DateTime(2026, 10, 13);
  final items = [
    purchase('a', 'Camera', category: 'Electronics', merchant: 'Camera shop',
      purchasedDay: 2, warrantyDay: 10),
    purchase('b', 'Laptop', category: 'Computers', notes: 'Travel computer',
      purchasedDay: 3, warrantyDay: 25),
    purchase('c', 'Washing machine', category: 'Appliances',
      serialNumber: 'SER-007', purchasedDay: 1),
    purchase('d', 'Speakers', category: 'Audio', purchasedDay: 4,
      warrantyDay: 30),
  ];

  test('no filters retains all rows without mutation', () {
    final before = items.map((i) => i.id).toList();
    final results = PurchaseQuery.apply(items, today: now);
    expect(results.length, 4);
    expect(results.map((i) => i.id).toList(), ['d', 'b', 'a', 'c']);
    expect(items.map((i) => i.id).toList(), before);
  });

  test('search covers merchant, notes, category and serial number', () {
    expect(PurchaseQuery.apply(items, search: 'camera SHOP', today: now)
      .single.id, 'a');
    expect(PurchaseQuery.apply(items, search: 'travel', today: now)
      .single.id, 'b');
    expect(PurchaseQuery.apply(items, search: 'ser-007', today: now)
      .single.id, 'c');
    expect(PurchaseQuery.apply(items, search: 'audio', today: now)
      .single.id, 'd');
  });

  test('category and search filters compose', () {
    expect(PurchaseQuery.apply(items, category: 'Computers',
      search: 'travel', today: now).single.id, 'b');
    expect(PurchaseQuery.apply(items, category: 'Phones',
      search: 'travel', today: now), isEmpty);
  });

  test('filters expired, upcoming and unspecified warranties', () {
    expect(PurchaseQuery.apply(items, warranty: WarrantyFilter.expired,
      today: now).map((p) => p.id), ['a']);
    expect(PurchaseQuery.apply(items, warranty: WarrantyFilter.expiring,
      today: now).map((p) => p.id).toList(), ['d', 'b']);
    expect(PurchaseQuery.apply(items, warranty: WarrantyFilter.unspecified,
      today: now).single.id, 'c');
    expect(PurchaseQuery.apply(items, warranty: WarrantyFilter.active,
      today: now), isEmpty);
  });

  test('sort by nearest warranty puts missing dates last', () {
    expect(PurchaseQuery.apply(items, sort: PurchaseSort.warranty,
      today: now).map((i) => i.id).toList(), ['a', 'b', 'd', 'c']);
  });

  test('sorts newest, oldest and name deterministically', () {
    expect(PurchaseQuery.apply(items, sort: PurchaseSort.oldest,
      today: now).map((i) => i.id).toList(), ['c', 'a', 'b', 'd']);
    expect(PurchaseQuery.apply(items, sort: PurchaseSort.name,
      today: now).map((i) => i.id).toList(), ['a', 'b', 'd', 'c']);
  });

  test('empty vault and whitespace queries are safe', () {
    expect(PurchaseQuery.apply([], today: now), isEmpty);
    expect(PurchaseQuery.apply(items, search: '   ', today: now), hasLength(4));
  });
}
