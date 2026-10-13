import 'package:flutter/material.dart';

import 'theme.dart';

/// Prevents input and screen-reader access to all routes after device lock.
/// Keep the Navigator mounted so in-progress forms survive authentication.
class PrivacyCurtain extends StatelessWidget {
  const PrivacyCurtain({
    super.key,
    required this.child,
    required this.locked,
    required this.onUnlock,
  });

  final Widget child;
  final bool locked;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) => Stack(children: [
    ExcludeSemantics(
      excluding: locked,
      child: IgnorePointer(ignoring: locked, child: child),
    ),
    if (locked)
      Positioned.fill(
        child: Material(
          color: Sq.bg,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shield_outlined, color: Sq.cyan, size: 68),
                    const SizedBox(height: 18),
                    const Text(
                      'SELQUARO is locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Use device authentication to view your private documents.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Sq.muted),
                    ),
                    const SizedBox(height: 22),
                    SqButton(
                      text: 'Unlock vault',
                      icon: Icons.lock_open,
                      onPressed: onUnlock,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
  ]);
}
