import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'controller.dart';
import 'document_signatures.dart';
import 'models.dart';
import 'theme.dart';

class PurchaseEditor extends StatefulWidget {
  const PurchaseEditor({super.key, required this.controller, this.existing, this.initialFile});
  final VaultController controller;
  final Purchase? existing;
  final String? initialFile;
  @override State<PurchaseEditor> createState() => _PurchaseEditorState();
}

class _PurchaseEditorState extends State<PurchaseEditor> {
  static const _uuid = Uuid();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _serial = TextEditingController();
  final _notes = TextEditingController();
  DateTime _purchaseDate = DateTime.now();
  DateTime? _warrantyEnd;
  String _category = 'Electronics';
  String _currency = 'EUR';
  final List<_PendingFile> _files = [];
  late List<VaultDocument> _saved;
  String? _coverId;
  _PendingFile? _pendingCover;
  bool _saving = false;
  bool _scanning = false;
  String? _ocrHint;

  static const categories = ['Electronics', 'Appliances', 'Computers', 'Phones', 'Audio', 'Home', 'Tools', 'Vehicles', 'Other'];

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _saved = [...?item?.documents];
    _coverId = item?.coverDocumentId;
    if (item != null) {
      _name.text = item.name;
      _merchant.text = item.merchant;
      _amount.text = item.amount?.toStringAsFixed(2) ?? '';
      _serial.text = item.serialNumber;
      _notes.text = item.notes;
      _purchaseDate = item.purchasedAt;
      _warrantyEnd = item.warrantyEndsAt;
      _category = categories.contains(item.category) ? item.category : 'Other';
      _currency = item.currency;
    }
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addSource(widget.initialFile!, widget.initialFile!.split('/').last, temporary: true);
      });
    }
  }

  @override
  void dispose() {
    for (final file in _files) { _cleanTemporary(file); }
    _name.dispose(); _merchant.dispose(); _amount.dispose();
    _serial.dispose(); _notes.dispose();
    super.dispose();
  }

  void _cleanTemporary(_PendingFile file) {
    if (!file.temporary) return;
    unawaited(File(file.path).delete().then<void>((_) {}).catchError((Object _) {}));
  }

  Future<void> _addSource(String path, String fileName, {bool temporary = false, bool productPhoto = false}) async {
    final extension = fileName.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'pdf'].contains(extension)) {
      _message('Only images and PDF files are supported');
      return;
    }
    final source = File(path);
    if (!await source.exists() ||
        await source.length() == 0 ||
        await source.length() > DocumentSignatures.maxBytes) {
      _message('The selected document must be between 1 byte and 20 MB.');
      return;
    }
    try {
      DocumentSignatures.validate(
        name: fileName,
        mimeType: DocumentSignatures.mimeTypeForName(fileName),
        bytes: await source.readAsBytes(),
      );
    } on FormatException {
      _message('The selected document is invalid or its extension is incorrect.');
      return;
    } catch (_) {
      _message('Cannot read the selected document.');
      return;
    }
    if (!mounted) return;
    final pending = _PendingFile(path, fileName, temporary: temporary);
    setState(() {
      _files.add(pending);
      if (productPhoto) _pendingCover = pending;
    });
    if (!productPhoto && ['jpg', 'jpeg', 'png'].contains(extension)) await _extract(path);
  }

  Future<void> _camera() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 2400);
      if (image != null) await _addSource(image.path, image.name, temporary: true);
    } catch (_) { _message('Camera unavailable. Check camera permissions.'); }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (result != null && result.files.single.path != null) {
        await _addSource(result.files.single.path!, result.files.single.name);
      }
    } catch (_) { _message('Could not import the selected file'); }
  }

  Future<void> _pickProductPhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600,
      );
      if (photo != null) {
        await _addSource(photo.path, photo.name, temporary: true, productPhoto: true);
      }
    } catch (_) {
      _message('Unable to choose a product photo.');
    }
  }

  Future<void> _extract(String path) async {
    setState(() => _scanning = true);
    final scanner = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await scanner.processImage(InputImage.fromFilePath(path));
      final lines = result.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (lines.isNotEmpty && _merchant.text.isEmpty) _merchant.text = lines.first;
      final amountPattern = RegExp(r'(?:EUR|USD|GBP|€|\$|£)?\s*(\d{1,5}[.,]\d{2})\b');
      if (_amount.text.isEmpty) {
        for (final line in lines.reversed) {
          final match = amountPattern.firstMatch(line);
          if (match != null) {
            _amount.text = match.group(1)!.replaceAll(',', '.');
            break;
          }
        }
      }
      setState(() => _ocrHint = 'Text recognized on your device. Verify every suggested value before saving.');
    } catch (_) {
      setState(() => _ocrHint = 'Automatic text recognition unavailable; enter details manually.');
    } finally {
      await scanner.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _chooseDate({required bool warranty}) async {
    final result = await showDatePicker(
      context: context,
      initialDate: warranty ? (_warrantyEnd ?? _purchaseDate.add(const Duration(days: 365))) : _purchaseDate,
      firstDate: DateTime(1990), lastDate: DateTime(2100),
    );
    if (result != null) setState(() {
      if (warranty) { _warrantyEnd = result; } else { _purchaseDate = result; }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final imported = <VaultDocument>[];
    String? savedCover = _coverId;
    try {
      for (final pending in _files) {
        final extension = pending.name.split('.').last.toLowerCase();
        final mime = extension == 'pdf' ? 'application/pdf' : 'image/${extension == 'jpg' ? 'jpeg' : extension}';
        final file = await widget.controller.store.importDocument(
          sourcePath: pending.path, fileName: pending.name, mimeType: mime,
        );
        imported.add(file);
        if (identical(pending, _pendingCover)) savedCover = file.id;
      }
      final purchase = Purchase(
        id: widget.existing?.id ?? _uuid.v4(),
        name: _name.text.trim(), merchant: _merchant.text.trim(), category: _category,
        purchasedAt: _purchaseDate,
        amount: _amount.text.trim().isEmpty ? null : double.parse(_amount.text.trim().replaceAll(',', '.')),
        currency: _currency, warrantyEndsAt: _warrantyEnd,
        serialNumber: _serial.text.trim(), notes: _notes.text.trim(),
        documents: [..._saved, ...imported],
        coverDocumentId: savedCover,
      );
      await widget.controller.upsert(purchase);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      for (final doc in imported) {
        await widget.controller.store.deleteDocument(doc);
      }
      _message('Unable to save securely. Your previous data was not replaced.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Add purchase' : 'Edit purchase')),
      body: SafeArea(child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('PURCHASE DETAILS', style: TextStyle(color: Sq.cyan, letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        TextFormField(controller: _name, maxLength: 120,
          decoration: const InputDecoration(labelText: 'Product name *', prefixIcon: Icon(Icons.inventory_2_outlined)),
          validator: (value) => value == null || value.trim().isEmpty ? 'Enter a product name' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _merchant, maxLength: 120,
          decoration: const InputDecoration(labelText: 'Store / merchant', prefixIcon: Icon(Icons.store_outlined))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category'),
          items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) => setState(() => _category = value ?? _category)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.payments_outlined)),
            validator: (text) {
              if (text == null || text.trim().isEmpty) return null;
              final amount = double.tryParse(text.replaceAll(',', '.'));
              return amount == null || !amount.isFinite || amount < 0 ? 'Invalid amount' : null;
            })),
          const SizedBox(width: 10),
          SizedBox(width: 104, child: DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: ['EUR', 'USD', 'GBP', 'CHF'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => _currency = value ?? 'EUR'),
          )),
        ]),
        const SizedBox(height: 20),
        SqCard(onTap: () => _chooseDate(warranty: false), child: Row(children: [
          const Icon(Icons.calendar_today_outlined, color: Sq.cyan), const SizedBox(width: 12),
          Expanded(child: Text('Purchased on: ${date.format(_purchaseDate)}')),
          const Icon(Icons.chevron_right),
        ])),
        const SizedBox(height: 10),
        SqCard(onTap: () => _chooseDate(warranty: true), child: Row(children: [
          const Icon(Icons.shield_outlined, color: Sq.green), const SizedBox(width: 12),
          Expanded(child: Text(_warrantyEnd == null ? 'Set warranty expiry (optional)' : 'Warranty ends: ${date.format(_warrantyEnd!)}')),
          if (_warrantyEnd != null) IconButton(onPressed: () => setState(() => _warrantyEnd = null), icon: const Icon(Icons.close)) else const Icon(Icons.chevron_right),
        ])),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(
          'Enter the actual warranty expiration from your purchase terms. SELQUARO does not assume legal coverage.',
          style: TextStyle(color: Sq.muted, fontSize: 12),
        )),
        TextFormField(controller: _serial, maxLength: 150, decoration: const InputDecoration(labelText: 'Serial number')),
        const SizedBox(height: 12),
        TextFormField(controller: _notes, maxLines: 3, maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Notes')),
        const SizedBox(height: 16),
        const Text('DOCUMENTS', style: TextStyle(color: Sq.cyan, letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _pickProductPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_pendingCover == null && _coverId == null ? 'Add product photo' : 'Change product photo')),
        if (_pendingCover != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(14),
            child: Image.file(File(_pendingCover!.path),
              height: 148, width: double.infinity, fit: BoxFit.contain)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _camera, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Scan receipt')),
          OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file), label: const Text('Import image / PDF')),
        ]),
        if (_scanning) const LinearProgressIndicator(),
        if (_ocrHint != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_ocrHint!, style: const TextStyle(color: Sq.gold))),
        ..._saved.map((file) => ListTile(
          leading: const Icon(Icons.lock_outline, color: Sq.green), title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(tooltip: 'Remove from this purchase', onPressed: () => setState(() { _saved.remove(file); if (_coverId == file.id) _coverId = null; }), icon: const Icon(Icons.close)),
        )),
        ..._files.map((file) => ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined, color: Sq.cyan),
          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(onPressed: () { _cleanTemporary(file); setState(() { _files.remove(file); if (identical(_pendingCover, file)) _pendingCover = null; }); }, icon: const Icon(Icons.close)),
        )),
        const SizedBox(height: 24),
        SqButton(text: _saving ? 'Saving securely...' : 'Save purchase', icon: Icons.lock_outline, onPressed: _saving ? null : _save),
        const SizedBox(height: 24),
      ]))),
    );
  }
}

class _PendingFile {
  const _PendingFile(this.path, this.name, {required this.temporary});
  final String path;
  final String name;
  final bool temporary;
}
