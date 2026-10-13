import 'models.dart';

/// Presentation-only searching and sorting. Never changes encrypted records.
enum PurchaseSort { newest, oldest, name, warranty }
enum WarrantyFilter { all, active, expiring, expired, unspecified }

class PurchaseQuery {
  static List<Purchase> apply(
    Iterable<Purchase> purchases, {
    String search = '',
    String category = 'All',
    PurchaseSort sort = PurchaseSort.newest,
    WarrantyFilter warranty = WarrantyFilter.all,
    DateTime? today,
  }) {
    final date = today ?? DateTime.now();
    final needle = search.trim().toLowerCase();
    final result = purchases.where((item) {
      if (category != 'All' && item.category != category) return false;
      if (needle.isNotEmpty) {
        final haystack = [
          item.name, item.merchant, item.serialNumber, item.notes, item.category,
        ].join(' ').toLowerCase();
        if (!haystack.contains(needle)) return false;
      }
      final days = item.daysRemaining(date);
      return switch (warranty) {
        WarrantyFilter.all => true,
        WarrantyFilter.active => days != null && days > 90,
        WarrantyFilter.expiring => days != null && days >= 0 && days <= 90,
        WarrantyFilter.expired => days != null && days < 0,
        WarrantyFilter.unspecified => days == null,
      };
    }).toList();

    result.sort((a, b) {
      switch (sort) {
        case PurchaseSort.newest:
          final cmp = b.purchasedAt.compareTo(a.purchasedAt);
          return cmp != 0 ? cmp : a.id.compareTo(b.id);
        case PurchaseSort.oldest:
          final cmp = a.purchasedAt.compareTo(b.purchasedAt);
          return cmp != 0 ? cmp : a.id.compareTo(b.id);
        case PurchaseSort.name:
          final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return cmp != 0 ? cmp : a.id.compareTo(b.id);
        case PurchaseSort.warranty:
          final x = a.warrantyEndsAt;
          final y = b.warrantyEndsAt;
          if (x == null) return y == null ? a.id.compareTo(b.id) : 1;
          if (y == null) return -1;
          final cmp = x.compareTo(y);
          return cmp != 0 ? cmp : a.id.compareTo(b.id);
      }
    });
    return result;
  }
}
