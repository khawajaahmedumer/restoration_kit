import 'package:flutter/widgets.dart';

/// Verifies that a [RestorationScope] with a non-null bucket is available.
///
/// Flutter's restoration framework silently does *nothing* when no
/// restoration scope is configured — the single most common reason devs
/// think restoration "doesn't work". We turn that silence into a loud,
/// copy-pasteable error.
///
/// Call from an `assert(...)` so it costs nothing in release builds.
bool debugCheckHasRestorationScope(BuildContext context, String widgetName) {
  assert(() {
    if (RestorationScope.maybeOf(context) == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('$widgetName requires a RestorationScope, but none was '
            'found in this context.'),
        ErrorDescription(
          'Without a restoration scope, Flutter silently discards all '
          'restoration data, so $widgetName would have no effect.',
        ),
        ErrorHint(
          'Fix: give your app a restorationScopeId:\n\n'
          '  MaterialApp(\n'
          "    restorationScopeId: 'app',  // <-- add this line\n"
          '    ...\n'
          '  )\n\n'
          'CupertinoApp and WidgetsApp accept the same parameter.',
        ),
      ]);
    }
    return true;
  }());
  return true;
}
