import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'controller.dart';
import 'theme.dart';

/// Explicit, passphrase-protected portable archive. Nothing is sent automatically.
class VaultBackupPage extends StatefulWidget {
  const VaultBackupPage({super.key, required this.vault});
  final VaultController vault;
  @override State<VaultBackupPage> createState() => _VaultBackupPageState();
}

class _VaultBackupPageState extends State<VaultBackupPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;

  @override void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    if (_busy) return;
    if (_password.text.length < 12 || _password.text != _confirm.text) {
      _notice('Use a matching backup passphrase of at least 12 characters.');
      return;
    }
    setState(() => _busy = true);
    File? temporary;
    try {
      final encrypted = await widget.vault.createBackup(_password.text);
      final cache = await getTemporaryDirectory();
      temporary = File('${cache.path}/SELQUARO-backup.sqvault');
      await temporary.writeAsBytes(encrypted, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(temporary.path, mimeType: 'application/octet-stream')],
        text: 'Encrypted SELQUARO backup. Keep the passphrase somewhere safe.',
      );
      _password.clear();
      _confirm.clear();
    } catch (_) {
      _notice('Unable to create the encrypted backup.');
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (widget.vault.purchases.isNotEmpty) {
      _notice('Restore requires an empty vault to protect your existing records.');
      return;
    }
    if (_password.text.length < 12) {
      _notice('Enter the original backup passphrase.');
      return;
    }
    setState(() => _busy = true);
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (selected == null || selected.files.single.path == null) return;
      final selectedPath = selected.files.single.path!;
      if (!selected.files.single.name.toLowerCase().endsWith('.sqvault')) {
        throw const FormatException('Choose a SELQUARO .sqvault file');
      }
      final file = File(selectedPath);
      if (await file.length() > 140 * 1024 * 1024) {
        throw const FormatException('Backup too large');
      }
      await widget.vault.restoreBackup(await file.readAsBytes(), _password.text);
      _password.clear();
      _confirm.clear();
      _notice('Encrypted backup restored successfully.');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _notice('Could not restore. Check your passphrase, file and available storage.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup & restore')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const SqCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline, color: Sq.cyan, size: 40),
        SizedBox(height: 12),
        Text('Your private encrypted backup', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Back up purchases and attached files using AES-256-GCM with a passphrase-derived key. No SELQUARO server, accounts or uploads.',
          style: TextStyle(color: Sq.muted)),
      ])),
      const SizedBox(height: 18),
      TextField(
        controller: _password, obscureText: !_showPassword, autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(labelText: 'Backup passphrase', prefixIcon: const Icon(Icons.password),
          suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _confirm, obscureText: !_showPassword, autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'Confirm passphrase (for export)',
          prefixIcon: Icon(Icons.lock_reset)),
      ),
      const SizedBox(height: 18),
      SqButton(text: _busy ? 'Processing...' : 'Export encrypted backup',
        icon: Icons.ios_share_outlined, onPressed: _busy ? null : _export),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _busy ? null : _restore,
        icon: const Icon(Icons.settings_backup_restore),
        label: const Text('Restore encrypted backup')),
      const SizedBox(height: 18),
      const Text('Keep your passphrase separately. There is no password recovery. Restoring is deliberately blocked when purchases already exist. Only user-selected apps receive the encrypted backup file.',
        style: TextStyle(color: Sq.muted, fontSize: 13)),
    ]),
  );
}
