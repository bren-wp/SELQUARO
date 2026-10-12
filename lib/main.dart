import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'controller.dart';
import 'editor.dart';
import 'models.dart';
import 'theme.dart';
import 'vault_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Selquaro());
}

class Selquaro extends StatefulWidget {
  const Selquaro({super.key});
  @override State<Selquaro> createState() => _SelquaroState();
}

class _SelquaroState extends State<Selquaro> with WidgetsBindingObserver {
  late final VaultController vault;
  final _securePrefs = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  int currentTab = 0;
  bool locked = false;
  bool biometric = false;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vault = VaultController(VaultStore())..addListener(_rebuild);
    _boot();
  }

  Future<void> _boot() async {
    biometric = await _securePrefs.read(key: 'selquaro.lock.enabled') == 'true';
    if (biometric) {
      locked = true;
      if (mounted) setState(() {});
      await _unlock();
    }
    await vault.initialize();
    if (mounted) setState(() {});
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && biometric && !_authInProgress) {
      setState(() => locked = true);
    }
  }

  Future<void> _unlock() async {
    if (_authInProgress) return;
    _authInProgress = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your private SELQUARO vault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok && mounted) setState(() => locked = false);
    } catch (_) {
      // Stay locked. Never bypass a failed device authentication.
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    if (enabled) {
      try {
        final available = await _auth.isDeviceSupported();
        if (!available || !await _auth.authenticate(localizedReason: 'Enable device unlock for SELQUARO')) {
          _notice('Device authentication is not available');
          return;
        }
      } catch (_) {
        _notice('Device authentication is not available');
        return;
      }
    }
    await _securePrefs.write(key: 'selquaro.lock.enabled', value: enabled.toString());
    if (mounted) setState(() => biometric = enabled);
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vault.removeListener(_rebuild);
    vault.dispose();
    super.dispose();
  }

  Future<void> _create({bool camera = false}) async {
    if (vault.error != null) return;
    String? file;
    if (camera) {
      try {
        final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 2400);
        file = shot?.path;
        if (file == null) return;
      } catch (_) {
        _notice('Camera unavailable. Check camera permissions.');
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
      PurchaseEditor(controller: vault, initialFile: file),
    ));
  }

  Future<void> _edit(Purchase? item) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) =>
      PurchaseEditor(controller: vault, existing: item),
    ));
  }

  Future<void> _details(Purchase item) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProductDetails(
      item: item, controller: vault, onEdit: () async {
        Navigator.pop(context);
        await _edit(item);
      }, onShare: _shareDocument,
    )));
  }

  Future<void> _shareDocument(VaultDocument item) async {
    File? exported;
    try {
      final content = await vault.store.readDocument(item);
      final directory = await getTemporaryDirectory();
      final safeName = item.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      exported = File('${directory.path}/${item.id}_${safeName}');
      await exported.writeAsBytes(content, flush: true);
      await Share.shareXFiles([XFile(exported.path)], text: 'Document shared from SELQUARO');
    } catch (_) {
      _notice('Unable to share this document');
    } finally {
      if (exported != null && await exported.exists()) {
        await exported.delete();
      }
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(title: const Text('Erase local vault?'), content: const Text(
        'Permanently delete every purchase and encrypted document on this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Erase everything', style: TextStyle(color: Sq.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await vault.clear();
      if (mounted) setState(() => currentTab = 0);
    } catch (_) { _notice('Could not erase the vault'); }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SELQUARO', theme: Sq.theme, debugShowCheckedModeBanner: false,
    home: locked
      ? Scaffold(body: SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shield_outlined, color: Sq.cyan, size: 72),
            const SizedBox(height: 20),
            const Text('SELQUARO is locked', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            const Text('Use your device authentication to open the local encrypted vault.',
              textAlign: TextAlign.center, style: TextStyle(color: Sq.muted)),
            const SizedBox(height: 20),
            SqButton(text: 'Unlock', icon: Icons.lock_open, onPressed: _unlock),
          ]),
        ))))
      : Scaffold(
          body: SafeArea(child: !vault.loaded
            ? const Center(child: CircularProgressIndicator())
            : vault.error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24),
                child: Text(vault.error!, textAlign: TextAlign.center, style: const TextStyle(color: Sq.red))))
              : IndexedStack(index: currentTab, children: [
                  HomePage(controller: vault, onNew: () => _create(), onOpen: _details),
                  VaultPage(controller: vault, onNew: () => _create(), onOpen: _details),
                  AlertsPage(controller: vault, onOpen: _details),
                  SettingsPage(controller: vault, biometricEnabled: biometric,
                    onBiometricChange: _setBiometric, onClear: _deleteAll),
                ])),
          bottomNavigationBar: vault.loaded && vault.error == null ? SafeArea(top: false,
            child: Container(
              height: 79,
              decoration: const BoxDecoration(color: Color(0xFF061522),
                border: Border(top: BorderSide(color: Sq.outline, width: .6))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _navIcon(0, Icons.home_outlined, 'Home'),
                _navIcon(1, Icons.inventory_2_outlined, 'Vault'),
                Semantics(label: 'Scan receipt', button: true, child: InkResponse(
                  onTap: () => _create(camera: true),
                  child: Container(width: 59, height: 59,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF067D95), Color(0xFF03D6E0)]),
                      border: Border.all(color: Sq.cyan, width: 2),
                      boxShadow: [BoxShadow(color: Sq.cyan.withValues(alpha: .23), blurRadius: 15)]),
                    child: const Icon(Icons.document_scanner_outlined, size: 28, color: Sq.white),
                  ),
                )),
                _navIcon(2, Icons.notifications_none, 'Alerts'),
                _navIcon(3, Icons.settings_outlined, 'Settings'),
              ]),
            ),
          ) : null,
        ),
  );

  Widget _navIcon(int index, IconData icon, String label) => InkWell(
    onTap: () => setState(() => currentTab = index),
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(width: 67, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: currentTab == index ? Sq.cyan : Sq.muted, size: 25),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: currentTab == index ? Sq.cyan : Sq.muted)),
    ])),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.onNew, required this.onOpen});
  final VaultController controller;
  final VoidCallback onNew;
  final ValueChanged<Purchase> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = controller.purchases.where((p) => (p.daysRemaining(now) ?? -1) >= 0).length;
    final totalFiles = controller.purchases.fold<int>(0, (n, p) => n + p.documents.length);
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), children: [
      const BrandHeader(title: 'Your purchases.\nProtected for tomorrow.', subtitle: 'Every receipt and warranty, always at hand.'),
      SqCard(padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12), child: Row(children: [
        _stat(totalFiles, 'Documents', Icons.description_outlined, Sq.cyan),
        _stat(active, 'Active', Icons.shield_outlined, Sq.green),
        _stat(controller.upcoming.length, 'Expiring', Icons.schedule_outlined, Sq.gold),
      ])),
      const SizedBox(height: 15),
      SqButton(text: 'Add Receipt or Purchase', icon: Icons.document_scanner_outlined, onPressed: onNew),
      const SizedBox(height: 28),
      _section('Recent Items'),
      const SizedBox(height: 12),
      if (controller.ordered.isEmpty)
        const EmptyView(icon: Icons.inventory_2_outlined, title: 'Your vault is empty',
          message: 'Add your first purchase or scan a receipt. No account is required.')
      else
        ...controller.ordered.take(5).map((p) => Padding(padding: const EdgeInsets.only(bottom: 10),
          child: PurchaseTile(item: p, onTap: () => onOpen(p)))),
      const SizedBox(height: 26),
      _section('Upcoming Warranty Expirations'),
      const SizedBox(height: 12),
      if (controller.upcoming.isEmpty)
        const EmptyView(icon: Icons.event_available_outlined, title: 'Nothing expiring soon',
          message: 'Warranty expiry reminders appear here when you add dates.')
      else
        ...controller.upcoming.take(4).map((p) => Padding(padding: const EdgeInsets.only(bottom: 10),
          child: PurchaseTile(item: p, onTap: () => onOpen(p)))),
      const SizedBox(height: 20),
    ]);
  }

  Widget _stat(int count, String text, IconData icon, Color color) => Expanded(child: Column(children: [
    Icon(icon, color: color, size: 25), const SizedBox(height: 8),
    Text('$count', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
    const SizedBox(height: 3),
    Text(text, style: const TextStyle(fontSize: 12, color: Sq.muted)),
  ]));

  Widget _section(String title) => Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800));
}

class PurchaseTile extends StatelessWidget {
  const PurchaseTile({super.key, required this.item, required this.onTap});
  final Purchase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = item.daysRemaining(DateTime.now());
    final color = days == null ? Sq.muted : days < 0 ? Sq.red : days <= 90 ? Sq.gold : Sq.green;
    final status = days == null ? 'No expiry date' : days < 0 ? 'Expired' : days == 0 ? 'Expires today' : '$days days left';
    return SqCard(onTap: onTap, padding: const EdgeInsets.all(12), child: Row(children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(
        color: Sq.elevated, borderRadius: BorderRadius.circular(12)),
        child: Icon(categoryIcon(item.category), color: Sq.cyan, size: 28)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text(item.merchant.isEmpty ? item.category : '${item.merchant} • ${item.category}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Sq.muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(DateFormat.yMMMd().format(item.purchasedAt), style: const TextStyle(color: Sq.muted, fontSize: 12)),
      ])),
      const SizedBox(width: 5),
      Flexible(child: Text(status, textAlign: TextAlign.right, maxLines: 2,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
      const Icon(Icons.chevron_right, color: Sq.muted, size: 20),
    ]));
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'Phones': return Icons.smartphone;
    case 'Computers': return Icons.laptop_mac_outlined;
    case 'Audio': return Icons.headphones_outlined;
    case 'Appliances': return Icons.kitchen_outlined;
    case 'Home': return Icons.home_outlined;
    case 'Tools': return Icons.handyman_outlined;
    case 'Vehicles': return Icons.directions_car_outlined;
    default: return Icons.inventory_2_outlined;
  }
}

class VaultPage extends StatefulWidget {
  const VaultPage({super.key, required this.controller, required this.onNew, required this.onOpen});
  final VaultController controller;
  final VoidCallback onNew;
  final ValueChanged<Purchase> onOpen;
  @override State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  String query = '';
  String category = 'All';

  @override
  Widget build(BuildContext context) {
    final matched = widget.controller.ordered.where((p) =>
      (category == 'All' || p.category == category) &&
      ('${p.name} ${p.merchant} ${p.serialNumber} ${p.notes}').toLowerCase().contains(query.toLowerCase()),
    ).toList();
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), children: [
      const BrandHeader(title: 'Always at hand.', subtitle: 'Your private, searchable purchase vault.'),
      TextField(onChanged: (value) => setState(() => query = value),
        decoration: const InputDecoration(hintText: 'Search your vault...', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 13),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final label in const ['All', 'Electronics', 'Computers', 'Phones', 'Audio', 'Appliances', 'Home', 'Tools', 'Vehicles', 'Other'])
          Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
            label: Text(label), selected: category == label,
            onSelected: (_) => setState(() => category = label),
          )),
      ])),
      const SizedBox(height: 19),
      Row(children: [
        Expanded(child: Text('${matched.length} Items', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
        IconButton(onPressed: widget.onNew, tooltip: 'Add purchase', icon: const Icon(Icons.add_circle, color: Sq.cyan, size: 29)),
      ]),
      const SizedBox(height: 8),
      if (matched.isEmpty)
        EmptyView(icon: Icons.folder_open_outlined,
          title: widget.controller.purchases.isEmpty ? 'No purchases yet' : 'No matching purchases',
          message: widget.controller.purchases.isEmpty ? 'Tap + to add your first receipt or product.' : 'Try a different filter or search term.')
      else
        ...matched.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: PurchaseTile(item: p, onTap: () => widget.onOpen(p)))),
    ]);
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key, required this.controller, required this.onOpen});
  final VaultController controller;
  final ValueChanged<Purchase> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dated = controller.purchases.where((p) => p.warrantyEndsAt != null).toList()
      ..sort((a, b) => a.warrantyEndsAt!.compareTo(b.warrantyEndsAt!));
    final past = dated.where((p) => (p.daysRemaining(now) ?? 0) < 0).length;
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), children: [
      const BrandHeader(title: 'Never miss an expiry.', subtitle: 'Keep track of coverage deadlines.'),
      SqCard(child: Row(children: [
        Expanded(child: _metric('${controller.upcoming.length}', 'Next 90 days', Sq.gold)),
        Expanded(child: _metric('$past', 'Expired', Sq.red)),
        Expanded(child: _metric('${dated.length}', 'Tracked', Sq.cyan)),
      ])),
      const SizedBox(height: 25),
      const Text('Warranty timeline', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (dated.isEmpty)
        const EmptyView(icon: Icons.notifications_none, title: 'No alerts yet',
          message: 'Add actual warranty expiry dates to see your timeline here.')
      else
        ...dated.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10),
          child: PurchaseTile(item: p, onTap: () => onOpen(p)))),
      const SizedBox(height: 15),
      const Text('Dates are stored on your device. Automatic system notifications will be added in a future release.',
        style: TextStyle(color: Sq.muted, fontSize: 12)),
    ]);
  }

  Widget _metric(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: color)),
    const SizedBox(height: 5),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Sq.muted)),
  ]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller, required this.biometricEnabled,
    required this.onBiometricChange, required this.onClear});
  final VaultController controller;
  final bool biometricEnabled;
  final ValueChanged<bool> onBiometricChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    children: [
      const BrandHeader(title: 'Settings', subtitle: 'Security, privacy and preferences.'),
      const SqCard(child: Row(children: [
        Icon(Icons.verified_user_outlined, color: Sq.green, size: 36),
        SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Encrypted local vault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          SizedBox(height: 5),
          Text('Documents stay on this device. No login, cloud sync or tracking.',
            style: TextStyle(color: Sq.muted, fontSize: 12)),
        ])),
      ])),
      const SizedBox(height: 26),
      const Text('SECURITY', style: TextStyle(color: Sq.cyan, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SqCard(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.fingerprint, color: Sq.cyan),
        title: const Text('Device authentication'),
        subtitle: const Text('Require biometrics or device passcode when reopening.', style: TextStyle(fontSize: 12, color: Sq.muted)),
        value: biometricEnabled, onChanged: onBiometricChange,
      )),
      const SizedBox(height: 12),
      SqCard(child: const ListTile(
        contentPadding: EdgeInsets.zero, leading: Icon(Icons.cloud_off_outlined, color: Sq.green),
        title: Text('Offline by design'),
        subtitle: Text('No account, remote backup or network API.', style: TextStyle(fontSize: 12, color: Sq.muted)),
      )),
      const SizedBox(height: 12),
      SqCard(child: ListTile(
        contentPadding: EdgeInsets.zero, leading: const Icon(Icons.delete_forever_outlined, color: Sq.red),
        title: const Text('Erase all local data'),
        subtitle: const Text('Permanently remove the encrypted vault.', style: TextStyle(fontSize: 12, color: Sq.muted)),
        trailing: const Icon(Icons.chevron_right), onTap: onClear,
      )),
      const SizedBox(height: 26),
      const Text('ABOUT', style: TextStyle(color: Sq.cyan, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const SqCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SELQUARO 0.1.0', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Your purchases. Safely kept.', style: TextStyle(color: Sq.muted)),
        SizedBox(height: 8),
        Text('A private receipt, document and warranty manager. Warranty dates must be verified against the applicable purchase terms.',
          style: TextStyle(color: Sq.muted, fontSize: 12)),
      ])),
      const SizedBox(height: 25),
    ],
  );
}

class ProductDetails extends StatelessWidget {
  const ProductDetails({super.key, required this.item, required this.controller,
    required this.onEdit, required this.onShare});
  final Purchase item;
  final VaultController controller;
  final VoidCallback onEdit;
  final ValueChanged<VaultDocument> onShare;

  Future<void> _remove(BuildContext context) async {
    final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete purchase?'),
      content: const Text('This also deletes its encrypted attachments from the vault.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Sq.red))),
      ],
    ));
    if (approved == true) {
      try {
        await controller.remove(item);
        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = item.daysRemaining(DateTime.now());
    final date = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(title: const Text('Product details'), actions: [
        IconButton(onPressed: onEdit, tooltip: 'Edit purchase', icon: const Icon(Icons.edit_outlined)),
        IconButton(onPressed: () => _remove(context), tooltip: 'Delete purchase',
          icon: const Icon(Icons.delete_outline, color: Sq.red)),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Container(
          width: 115, height: 115,
          decoration: BoxDecoration(color: Sq.surface, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Sq.outline)),
          child: Icon(categoryIcon(item.category), color: Sq.cyan, size: 64),
        )),
        const SizedBox(height: 18),
        Center(child: Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        Center(child: Text(item.category, style: const TextStyle(color: Sq.muted))),
        const SizedBox(height: 22),
        SqCard(child: Row(children: [
          Icon(Icons.shield_outlined, color: remaining == null ? Sq.muted : remaining < 0 ? Sq.red : Sq.green, size: 30),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(remaining == null ? 'Warranty not specified' : remaining < 0 ? 'Warranty expired' : '$remaining days of coverage left',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(item.warrantyEndsAt == null ? 'Enter the verified expiry date in Edit.' : 'Expires ${date.format(item.warrantyEndsAt!)}',
              style: const TextStyle(color: Sq.muted, fontSize: 12)),
          ])),
        ])),
        const SizedBox(height: 13),
        _info('Merchant', item.merchant.isEmpty ? 'Not specified' : item.merchant, Icons.store_outlined),
        _info('Purchased', date.format(item.purchasedAt), Icons.event_outlined),
        _info('Amount', item.amount == null ? 'Not specified' : '${item.currency} ${item.amount!.toStringAsFixed(2)}', Icons.payments_outlined),
        _info('Serial number', item.serialNumber.isEmpty ? 'Not specified' : item.serialNumber, Icons.qr_code_2),
        if (item.notes.isNotEmpty) _info('Notes', item.notes, Icons.notes_outlined),
        const SizedBox(height: 20),
        Text('Encrypted documents (${item.documents.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (item.documents.isEmpty)
          const EmptyView(icon: Icons.description_outlined, title: 'No attachments',
            message: 'Edit the purchase to attach receipts or warranty PDFs.')
        else
          ...item.documents.map((d) => Padding(padding: const EdgeInsets.only(bottom: 10),
            child: SqCard(onTap: () => onShare(d), child: Row(children: [
              const Icon(Icons.description_outlined, color: Sq.cyan), const SizedBox(width: 12),
              Expanded(child: Text(d.name, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.share_outlined, color: Sq.muted),
            ])))),
        const SizedBox(height: 24),
        SqButton(text: 'Edit purchase', icon: Icons.edit_outlined, onPressed: onEdit),
      ]),
    );
  }

  Widget _info(String heading, String content, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: SqCard(child: Row(children: [
      Icon(icon, color: Sq.cyan), const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(heading, style: const TextStyle(fontSize: 12, color: Sq.muted)),
        const SizedBox(height: 5),
        Text(content, style: const TextStyle(fontWeight: FontWeight.w600)),
      ])),
    ])),
  );
}
