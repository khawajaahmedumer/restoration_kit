import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restoration_kit/restoration_kit.dart';

/// Wraps [child] in an app with restoration enabled — the setup every
/// consumer of this package needs.
Widget appWithRestoration(Widget child) {
  return MaterialApp(
    restorationScopeId: 'app',
    home: Scaffold(body: child),
  );
}

void main() {
  group('RestorableBuilder', () {
    testWidgets('value survives simulated process death', (tester) async {
      Widget buildApp() => appWithRestoration(
            RestorableBuilder<int>(
              restorationId: 'counter',
              initialValue: 0,
              builder: (context, count) => TextButton(
                onPressed: () => count.value++,
                child: Text('count: ${count.value}'),
              ),
            ),
          );

      await tester.pumpWidget(buildApp());
      expect(find.text('count: 0'), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.text('count: 2'), findsOneWidget);

      // Simulates the OS killing and relaunching the app.
      await tester.restartAndRestore();

      expect(find.text('count: 2'), findsOneWidget);
    });

    testWidgets('uses initialValue on first launch', (tester) async {
      await tester.pumpWidget(appWithRestoration(
        RestorableBuilder<String>(
          restorationId: 'greeting',
          initialValue: 'hello',
          builder: (context, s) => Text(s.value),
        ),
      ));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('throws a helpful error when no restoration scope exists',
        (tester) async {
      // Deliberately NO restorationScopeId.
      await tester.pumpWidget(
        MaterialApp(
          home: RestorableBuilder<int>(
            restorationId: 'x',
            initialValue: 0,
            builder: (context, v) => Text('${v.value}'),
          ),
        ),
      );

      final dynamic error = tester.takeException();
      expect(error, isFlutterError);
      expect(
        (error as FlutterError).toString(),
        contains('restorationScopeId'),
      );
    });
  });

  group('RestorationHost + RestoTextController', () {
    testWidgets('text survives simulated process death', (tester) async {
      final search = RestoTextController(restorationId: 'search');

      await tester.pumpWidget(appWithRestoration(
        RestorationHost(
          restorationId: 'screen',
          properties: [search],
          child: Builder(
            builder: (context) =>
                TextField(controller: search.controller),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'flutter rocks');
      await tester.pump();

      await tester.restartAndRestore();

      expect(find.text('flutter rocks'), findsOneWidget);

      // Ownership contract: the creator disposes. Unmount first so the
      // host's RestorationMixin unregisters cleanly.
      await tester.pumpWidget(const SizedBox());
      search.dispose();
    });

    testWidgets('duplicate restorationIds are caught in debug mode',
        (tester) async {
      final a = RestoTextController(restorationId: 'same');
      final b = RestoTextController(restorationId: 'same');

      await tester.pumpWidget(appWithRestoration(
        RestorationHost(
          restorationId: 'screen',
          properties: [a, b],
          child: const SizedBox(),
        ),
      ));

      expect(tester.takeException(), isAssertionError);

      await tester.pumpWidget(const SizedBox());
      a.dispose();
      b.dispose();
    });
  });

  group('RestorationHost + RestoScrollController', () {
    testWidgets('scroll offset survives simulated process death',
        (tester) async {
      final scroll = RestoScrollController(restorationId: 'list');

      Widget buildList() => appWithRestoration(
            RestorationHost(
              restorationId: 'screen',
              properties: [scroll],
              child: Builder(
                builder: (context) => ListView.builder(
                  controller: scroll.controller,
                  itemExtent: 100,
                  itemCount: 100,
                  itemBuilder: (context, i) => Text('item $i'),
                ),
              ),
            ),
          );

      await tester.pumpWidget(buildList());

      scroll.controller.jumpTo(500);
      await tester.pump();
      expect(scroll.controller.offset, 500);

      await tester.restartAndRestore();

      expect(scroll.controller.offset, 500);

      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    });
  });

  group('RestorationHost lifecycle', () {
    testWidgets(
        'host State can die and be recreated while controllers live on '
        '(regression: host must not dispose user-owned properties)',
        (tester) async {
      final notes = RestoTextController(restorationId: 'notes');

      Widget buildHost({required bool visible}) => appWithRestoration(
            visible
                ? RestorationHost(
                    restorationId: 'screen',
                    properties: [notes],
                    child: Builder(
                      builder: (context) =>
                          TextField(controller: notes.controller),
                    ),
                  )
                : const SizedBox(),
          );

      // Mount, type, then remove the host's subtree entirely...
      await tester.pumpWidget(buildHost(visible: true));
      await tester.enterText(find.byType(TextField), 'still here');
      await tester.pump();
      await tester.pumpWidget(buildHost(visible: false));

      // ...and bring it back with the SAME controller instance. Before the
      // fix, the dying host disposed the property and this re-registration
      // crashed with "used after being disposed".
      await tester.pumpWidget(buildHost(visible: true));
      expect(tester.takeException(), isNull);

      // Note: the text does NOT survive this — a dying host disposes its
      // restoration bucket, deleting its saved data. That's framework
      // semantics (within-session subtree survival is PageStorage's job).
      // What matters here is that the controller is alive and usable:
      await tester.enterText(find.byType(TextField), 'reborn');
      await tester.pump();
      expect(find.text('reborn'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      notes.dispose();
    });
  });

  group('RestorationHost + RestoTabController', () {
    testWidgets('selected tab survives simulated process death',
        (tester) async {
      await tester.pumpWidget(appWithRestoration(const _TabHarness()));

      await tester.tap(find.text('Tab C'));
      await tester.pumpAndSettle();
      expect(find.text('Body C'), findsOneWidget);

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      expect(find.text('Body C'), findsOneWidget);
    });
  });
}

class _TabHarness extends StatefulWidget {
  const _TabHarness();

  @override
  State<_TabHarness> createState() => _TabHarnessState();
}

class _TabHarnessState extends State<_TabHarness>
    with TickerProviderStateMixin {
  late final RestoTabController tabs = RestoTabController(
    restorationId: 'tabs',
    length: 3,
    vsync: this,
  );

  @override
  Widget build(BuildContext context) {
    return RestorationHost(
      restorationId: 'tab_screen',
      properties: [tabs],
      child: Builder(
        builder: (context) => Column(
          children: [
            TabBar(
              controller: tabs.controller,
              labelColor: Colors.black,
              tabs: const [
                Tab(text: 'Tab A'),
                Tab(text: 'Tab B'),
                Tab(text: 'Tab C'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabs.controller,
                children: const [
                  Text('Body A'),
                  Text('Body B'),
                  Text('Body C'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
