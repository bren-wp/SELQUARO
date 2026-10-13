import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selquaro/privacy_curtain.dart';

void main() {
  testWidgets('locking masks nested UI while preserving unfinished text input', (tester) async {
    bool locked = false;
    late StateSetter update;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return PrivacyCurtain(
            locked: locked,
            onUnlock: () => setState(() => locked = false),
            child: Scaffold(body: Center(child: TextField(
              key: const Key('unfinished-purchase'),
              controller: controller,
            ))),
          );
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('unfinished-purchase')), 'Private draft');
    update(() => locked = true);
    await tester.pump();
    expect(find.text('SELQUARO is locked'), findsOneWidget);
    expect(find.text('Unlock vault'), findsOneWidget);
    await tester.tap(find.text('Unlock vault'));
    await tester.pump();
    expect(controller.text, 'Private draft');
    expect(find.text('SELQUARO is locked'), findsNothing);
  });

  testWidgets('unlock screen fits small displays without an overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home: PrivacyCurtain(
      locked: true, onUnlock: () {},
      child: const Scaffold(body: Text('Sensitive receipt')),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Unlock vault'), findsOneWidget);
  });
}
