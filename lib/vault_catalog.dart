import 'models.dart';

/// Structural metadata checks, independent of attachment bytes.
/// A corrupt local index must not be re-saved over the original ciphertext.
/// UUID syntax is intentionally not required for legacy purchase identifiers.
class VaultCatalog {
  static void validate(Iterable<Purchase> purchases) {
    final purchaseIds = <String>{};
    final documentIds = <String>{};
    for (final purchase in purchases) {
      if (purchase.id.trim().isEmpty || !purchaseIds.add(purchase.id)) {
        throw const FormatException('Duplicate or missing purchase identifier');
      }
      if (purchase.name.trim().isEmpty) {
        throw const FormatException('Purchase name is missing');
      }
      for (final document in purchase.documents) {
        if (document.id.trim().isEmpty || !documentIds.add(document.id)) {
          throw const FormatException('Duplicate or missing document identifier');
        }
      }
    }
  }
}
