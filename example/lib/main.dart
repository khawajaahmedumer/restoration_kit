import 'package:flutter/material.dart';
import 'package:restoration_kit/restoration_kit.dart';

void main() => runApp(const DemoApp());


class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      restorationScopeId: 'app', // Step 1: enable restoration.
      home: DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen>
    with TickerProviderStateMixin {
  final RestoScrollController scroll =
      RestoScrollController(restorationId: 'list');
  final RestoTextController notes =
      RestoTextController(restorationId: 'notes');
  late final RestoTabController tabs = RestoTabController(
    restorationId: 'tabs',
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    scroll.dispose();
    notes.dispose();
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestorationHost(
      restorationId: 'demo',
      properties: [scroll, notes, tabs],
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('restoration_kit demo'),
            bottom: TabBar(
              controller: tabs.controller,
              tabs: const [Tab(text: 'List'), Tab(text: 'Form')],
            ),
          ),
          body: Column(
            children: [
              // Lives ABOVE the TabBarView on purpose: restoration data dies
              // with the widget that owns it, and TabBarView disposes
              // off-screen tabs. Inside a tab, this counter's bucket would be
              // deleted every time its tab went off-screen.
              RestorableBuilder<int>(
                restorationId: 'counter',
                initialValue: 0,
                builder: (context, count) => ListTile(
                  title: Text('Taps: ${count.value}'),
                  trailing: FilledButton(
                    onPressed: () => count.value++,
                    child: const Text('+1'),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabs.controller,
                  children: [
                    // Tab 1: scroll offset restored via the host-level
                    // controller — host-level data survives tab switches.
                    ListView.builder(
                      controller: scroll.controller,
                      itemCount: 200,
                      itemBuilder: (context, i) =>
                          ListTile(title: Text('Item $i')),
                    ),
                    // Tab 2: a text field that survives process death.
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: notes.controller,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText:
                              'Notes (kill the app — they survive)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
