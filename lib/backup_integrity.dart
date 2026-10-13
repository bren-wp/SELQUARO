import 'dart:typed_data';

import 'models.dart';

/// Validate the whole archive before any restored attachment reaches storage.
class BackupIntegrity {
  static const maxDocuments = 150;
  static const maxEach = 20 * 1024 * 1024;
  static const maxTotal = 70 * 1024 * 1024;

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static final _cleanName = RegExp(r'[\x00-\x1f\x7f/\\]');

  static void validate(List<Purchase> purchases, Map<String, Uint8List> files) {
    if (purchases.length > 10000 || files.length > maxDocuments) {
      throw const FormatException('Backup exceeds the supported record limits');
    }
    var total = 0;
    for (final bytes in files.values) {
      if (bytes.isEmpty || bytes.length > maxEach) {
        throw const FormatException('An attachment has an invalid size');
      }
      total += bytes.length;
      if (total > maxTotal) {
        throw const FormatException('Backup attachments exceed the size limit');
      }
    }
    final purchaseIds = <String>{};
    final documentIds = <String>{};
    for (final p in purchases) {
      if (!_uuid.hasMatch(p.id) || !purchaseIds.add(p.id)) {
        throw const FormatException('Duplicate or invalid purchase identifier');
      }
      if (p.name.trim().isEmpty || p.name.length > 120 ||
          p.merchant.length > 120 || p.serialNumber.length > 150 ||
          p.notes.length > 2000) {
        throw const FormatException('Invalid purchase metadata');
      }
      if (p.amount != null &&
          (!p.amount!.isFinite || p.amount! < 0 || p.amount! > 1e12)) {
        throw const FormatException('Invalid purchase price');
      }
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(p.currency)) {
        throw const FormatException('Invalid currency code');
      }
      if (p.purchasedAt.year < 1990 || p.purchasedAt.year > 2100 ||
          (p.warrantyEndsAt != null &&
              (p.warrantyEndsAt!.year < 1990 || p.warrantyEndsAt!.year > 2100))) {
        throw const FormatException('Invalid purchase or warranty date');
      }
      if (p.coverDocumentId != null &&
          !p.documents.any((d) => d.id == p.coverDocumentId && d.mimeType.startsWith('image/'))) {
        throw const FormatException('Invalid product photograph reference');
      }
      for (final d in p.documents) {
        if (!_uuid.hasMatch(d.id) || !documentIds.add(d.id) ||
            d.name.trim().isEmpty || d.name.length > 255 ||
            _cleanName.hasMatch(d.name) || !files.containsKey(d.id)) {
          throw const FormatException('Invalid, duplicate or missing attachment');
        }
        final extension = d.name.split('.').last.toLowerCase();
        final expected = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          'pdf' => 'application/pdf',
          _ => null,
        };
        if (expected == null || d.mimeType != expected) {
          throw const FormatException('Unsupported attachment type');
        }
      }
    }
    if (files.length != documentIds.length ||
        !files.keys.toSet().containsAll(documentIds)) {
      throw const FormatException('Archive contains unreferenced attachments');
    }
  }
}
