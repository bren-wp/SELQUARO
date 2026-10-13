import 'dart:convert';

class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String mimeType;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mimeType': mimeType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VaultDocument.fromJson(Map<String, dynamic> json) => VaultDocument(
        id: json['id'] as String,
        name: json['name'] as String,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Purchase {
  const Purchase({
    required this.id,
    required this.name,
    required this.merchant,
    required this.category,
    required this.purchasedAt,
    required this.amount,
    required this.currency,
    required this.warrantyEndsAt,
    required this.serialNumber,
    required this.notes,
    required this.documents,
    this.coverDocumentId,
  });

  final String id;
  final String name;
  final String merchant;
  final String category;
  final DateTime purchasedAt;
  final double? amount;
  final String currency;
  final DateTime? warrantyEndsAt;
  final String serialNumber;
  final String notes;
  final List<VaultDocument> documents;
  final String? coverDocumentId;

  /// Calendar-day arithmetic: local UTC-offset and DST shifts must not
  /// shorten a warranty by one day near daylight-saving transitions.
  int? daysRemaining(DateTime now) {
    final expiry = warrantyEndsAt;
    if (expiry == null) return null;
    return DateTime.utc(expiry.year, expiry.month, expiry.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'merchant': merchant,
        'category': category,
        'purchasedAt': purchasedAt.toIso8601String(),
        'amount': amount,
        'currency': currency,
        'warrantyEndsAt': warrantyEndsAt?.toIso8601String(),
        'serialNumber': serialNumber,
        'notes': notes,
        'documents': documents.map((e) => e.toJson()).toList(),
        'coverDocumentId': coverDocumentId,
      };

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as String,
        name: json['name'] as String,
        merchant: json['merchant'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        purchasedAt: DateTime.parse(json['purchasedAt'] as String),
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
        warrantyEndsAt: json['warrantyEndsAt'] == null ? null : DateTime.parse(json['warrantyEndsAt'] as String),
        serialNumber: json['serialNumber'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        documents: (json['documents'] as List<dynamic>? ?? []).map((e) => VaultDocument.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        coverDocumentId: json['coverDocumentId'] as String?,
      );
}

String encodePurchases(List<Purchase> purchases) =>
    jsonEncode({'schema': 1, 'purchases': purchases.map((e) => e.toJson()).toList()});

List<Purchase> decodePurchases(String source) {
  final payload = jsonDecode(source) as Map<String, dynamic>;
  if (payload['schema'] != 1) throw const FormatException('Unsupported vault version');
  return (payload['purchases'] as List<dynamic>).map((e) => Purchase.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}
