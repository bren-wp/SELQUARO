import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'models.dart';
import 'theme.dart';
import 'vault_store.dart';

/// Displays decrypted PDF/image bytes in-memory without exporting cleartext.
class SecureDocumentViewer extends StatefulWidget {
  const SecureDocumentViewer({
    super.key,
    required this.document,
    required this.store,
    this.onShare,
  });

  final VaultDocument document;
  final VaultStore store;
  final VoidCallback? onShare;

  @override
  State<SecureDocumentViewer> createState() => _SecureDocumentViewerState();
}

class _SecureDocumentViewerState extends State<SecureDocumentViewer> {
  late final Future<Uint8List> _contents;

  @override
  void initState() {
    super.initState();
    _contents = widget.store.readDocument(widget.document);
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.document.mimeType == 'application/pdf' ||
        widget.document.name.toLowerCase().endsWith('.pdf');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onShare != null)
            IconButton(
              onPressed: widget.onShare,
              tooltip: 'Share a copy',
              icon: const Icon(Icons.ios_share_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Uint8List>(
          future: _contents,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text(
                'Unable to decrypt or open this document.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Sq.red),
              ));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bytes = snapshot.data!;
            if (isPdf) {
              return PdfViewer.data(bytes, sourceName: widget.document.name);
            }
            return Center(child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('Cannot decode this image.'),
              ),
            ));
          },
        ),
      ),
    );
  }
}
