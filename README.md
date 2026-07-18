# restoration_kit

**Effortless state restoration for Flutter.** Survive process death — no `RestorationMixin` ceremony, no `restoreState` overrides, no manual registration.

When Android or iOS kills your backgrounded app to reclaim memory, users come back to find their scroll position gone, their half-typed form erased, and their selected tab reset. Flutter ships a full framework to fix this, but the API is verbose enough that almost nobody uses it. This package removes the ceremony.

## Before / after

**Vanilla Flutter** — restoring one counter:

```dart
class _CounterState extends State<Counter> with RestorationMixin {
  final RestorableInt _count = RestorableInt(0);

  @override
  String? get restorationId => 'counter';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_count, 'count');
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { /* ... */ }
}
```

**With restoration_kit:**

```dart
RestorableBuilder<int>(
  restorationId: 'counter',
  initialValue: 0,
  builder: (context, count) => FilledButton(
    onPressed: () => count.value++, // rebuilds AND persists
    child: Text('${count.value}'),
  ),
)
```

## Setup (one line)

Restoration is off until you give your app a restoration scope:

```dart
MaterialApp(
  restorationScopeId: 'app', // <-- this line
  ...
)
```

Forget it, and vanilla Flutter fails *silently*. This package instead throws a descriptive error in debug mode telling you exactly what to add.

## Drop-in controllers

Scroll offsets, text fields, and selected tabs are the state users most notice losing. One `RestorationHost` + drop-in controllers:

```dart
class _FeedScreenState extends State<FeedScreen> {
  final scroll = RestoScrollController(restorationId: 'scroll');
  final search = RestoTextController(restorationId: 'search');

  @override
  void dispose() {
    scroll.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RestorationHost(
      restorationId: 'feed',
      properties: [scroll, search], // registered, restored, disposed for you
      child: Column(children: [
        TextField(controller: search.controller),
        Expanded(
          child: ListView.builder(
            controller: scroll.controller,
            ...
          ),
        ),
      ]),
    );
  }
}
```

`RestoTabController` works the same way (it additionally needs your State's `TickerProviderStateMixin` as `vsync`, because animations need one).

Ownership follows standard Flutter convention: **you** create the controllers, **you** dispose them in your `State.dispose` — exactly like a `TextEditingController`. The host only registers them. Keep the list stable (make them `final` fields, as above) and don't share one controller across two hosts.

## The 1 MB guardian

Android caps the entire restoration bundle at ~1 MB. Exceed it and your app dies in **native** code with a `TransactionTooLargeException` — no Dart stack trace, no hint of which widget did it.

restoration_kit tracks the serialized size of everything it persists and, in debug mode, prints a warning **naming the offending `restorationId`** long before you hit the cliff — including a per-property breakdown when the total approaches the limit. Compiled out of release builds entirely.

## What restoration is (and isn't) for

Restoration is for **ephemeral UI state**: scroll positions, unsubmitted form input, selected tabs, expanded/collapsed sections. It is *not* a database — it survives process death but not necessarily a user swiping the app away or a device restart. Anything that must truly persist belongs in real storage.

## v1 type support

`RestorableBuilder<T>` is deliberately strict: `T` must be serializable by Flutter's `StandardMessageCodec` — `bool`, `int`, `double`, `String`, or `List`/`Map` compositions of those. Unsupported types fail fast with a clear error instead of failing silently at restore time. Custom-type converters are on the roadmap.

## Testing your app's restoration

Flutter's test framework can simulate process death:

```dart
await tester.restartAndRestore();
```

See this package's own [test suite](test/restoration_kit_test.dart) for complete examples. To test on a real Android device: enable **Don't keep activities** in developer options, background your app, and reopen it.

## API at a glance

| Symbol | Purpose |
|---|---|
| `RestorableBuilder<T>` | Restore a single value with one widget |
| `RestorationHost` | Hosts any number of restorable properties, mixin-free |
| `RestoScrollController` | `ScrollController` that restores its offset |
| `RestoTextController` | `TextEditingController` that restores its text |
| `RestoTabController` | `TabController` that restores its index |
| `HostedRestorable` | Implement to plug your own restorables into a host |

Pure Dart. Zero dependencies beyond Flutter. Works on all six platforms.

## Gotcha: restoration data lives with its widget

A restorable's saved data is stored in a *bucket* owned by the widget that
registered it. When that widget's State is disposed, its bucket — and the
data in it — is deleted. The classic trap: a `RestorableBuilder` inside a
`TabBarView` or `PageView` loses its data every time its page goes
off-screen, because those widgets dispose off-screen children.

Fixes, pick one:

1. **Lift it** — move the restorable above the `TabBarView`/`PageView`.
2. **Keep the page alive** — `AutomaticKeepAliveClientMixin` on the page.
3. **Store at screen level** — hold the state in a `RestorationHost` that
   never unmounts (this is why the drop-in controllers live on your State,
   not inside the page).

Related: swiping the app away from the recents screen is a *user-initiated*
kill — the OS deliberately discards restoration data, by design, on both
Android and iOS. Restoration only fires after *system-initiated* kills
(memory pressure). To test the real thing:

```bash
# Background the app with the HOME button first (do not swipe it away), then:
adb shell am kill your.package.name
# Reopen from the launcher.
```

Or toggle Developer options → "Don't keep activities" while testing.
