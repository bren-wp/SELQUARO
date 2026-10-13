import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';
import 'vault_store.dart';

/// Shows user-imported encrypted product photographs, never stock/mock items.
class ProductPhoto extends StatefulWidget {
  const ProductPhoto({
    super.key,
    required this.item,
    required this.store,
    required this.fallbackIcon,
    this.width = 56,
    this.height = 56,
  });

  final Purchase item;
  final VaultStore store;
  final IconData fallbackIcon;
  final double width;
  final double height;

  @override State<ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<ProductPhoto> {
  Future<Uint8List>? _photo;

  @override void initState() {
    super.initState();
    _load();
  }

  @override void didUpdateWidget(covariant ProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.coverDocumentId != widget.item.coverDocumentId) _load();
  }

  void _load() {
    _photo = null;
    final cover = widget.item.coverDocumentId;
    if (cover == null) return;
    for (final document in widget.item.documents) {
      if (document.id == cover && document.mimeType.startsWith('image/')) {
        _photo = widget.store.readDocument(document);
        break;
      }
    }
  }

  @override Widget build(BuildContext context) {
    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: Sq.elevated,
      alignment: Alignment.center,
      child: Icon(widget.fallbackIcon, color: Sq.cyan,
        size: widget.height > 75 ? 48 : 27),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: _photo == null
          ? placeholder
          : FutureBuilder<Uint8List>(
              future: _photo,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return placeholder;
                return Image.memory(
                  snapshot.data!,
                  width: widget.width, height: widget.height,
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                );
              },
            ),
    );
  }
}
