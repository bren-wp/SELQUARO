import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/controller.dart';
import 'package:selquaro/main.dart';
import 'package:selquaro/theme.dart';
import 'package:selquaro/vault_store.dart';

void main() {
  testWidgets('new installation shows empty state without fake purchases', (tester) async {
    final vault = VaultController(VaultStore());
    await tester.pumpWidget(MaterialApp(
      theme: Sq.theme,
      home: Scaffold(body: HomePage(
        controller: vault, onNew: () {}, onOpen: (_) {},
      )),
    ));
    expect(find.text('Your vault is empty'), findsOneWidget);
    expect(find.text('Add Receipt or Purchase'), findsOneWidget);
    expect(find.text('MacBook Air'), findsNothing);
  });
}
