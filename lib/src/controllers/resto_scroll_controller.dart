import 'package:flutter/widgets.dart';

import '../restoration_host.dart';
import '../size_guardian.dart';

/// A [ScrollController] whose offset survives process death.
///
/// Flutter's built-in scroll "keeping" (via `PageStorage`) only survives
/// within a running session; it is lost when the OS kills the app. This
/// controller persists the offset through the restoration framework instead.
///
/// ```dart
/// final scroll = RestoScrollController(restorationId: 'feed_scroll');
/// // ...inside a RestorationHost:
/// ListView(controller: scroll.controller, ...)
/// ```
class RestoScrollController implements HostedRestorable {
  RestoScrollController({
    required this.restorationId,
    double initialScrollOffset = 0.0,
  }) : _property = _RestorableScrollOffset(initialScrollOffset, restorationId);

  @override
  final String restorationId;

  final _RestorableScrollOffset _property;

  /// The controller to hand to your scrollable. Only valid while this
  /// object is registered with a mounted [RestorationHost].
  ScrollController get controller => _property.controller;

  @override
  RestorableProperty<Object?> get property => _property;

  /// Releases the controller. Call from your `State.dispose`.
  @override
  void dispose() => _property.dispose();
}

/// Wraps a [ScrollController], serializing its offset.
///
/// Restoration flow: `fromPrimitives` recreates the controller with the
/// saved offset as `initialScrollOffset`, which the scroll position picks
/// up when it attaches — no jump, no post-frame hacks.
class _RestorableScrollOffset extends RestorableProperty<ScrollController> {
  _RestorableScrollOffset(this._initialOffset, this._debugId);

  final double _initialOffset;
  final String _debugId;

  ScrollController? _controller;
  double _lastKnownOffset = 0.0;

  ScrollController get controller {
    assert(
      _controller != null,
      'RestoScrollController("$_debugId") was used before its '
      'RestorationHost registered it. Make sure the host is an ancestor of '
      'the scrollable that uses this controller.',
    );
    return _controller!;
  }

  @override
  ScrollController createDefaultValue() =>
      ScrollController(initialScrollOffset: _initialOffset);

  @override
  ScrollController fromPrimitives(Object? data) =>
      ScrollController(initialScrollOffset: (data as num).toDouble());

  @override
  void initWithValue(ScrollController value) {
    _controller?.removeListener(_onScroll);
    _controller?.dispose();
    _controller = value..addListener(_onScroll);
    _lastKnownOffset = value.initialScrollOffset;
  }

  void _onScroll() {
    final ScrollController c = _controller!;
    if (!c.hasClients) return;
    _lastKnownOffset = c.offset;
    // Asks the restoration framework to re-serialize. Serialization is
    // batched per frame by the RestorationManager, so notifying on every
    // scroll tick is cheap.
    notifyListeners();
  }

  @override
  Object? toPrimitives() {
    RestorationSizeGuardian.debugTrack(_debugId, _lastKnownOffset);
    return _lastKnownOffset;
  }

  @override
  void dispose() {
    RestorationSizeGuardian.debugUntrack(_debugId);
    _controller?.removeListener(_onScroll);
    _controller?.dispose();
    super.dispose();
  }
}
