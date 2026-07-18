import 'package:flutter/material.dart';

import '../restoration_host.dart';
import '../size_guardian.dart';

/// A [TabController] whose selected index survives process death.
///
/// Needs a [TickerProvider], so your State keeps its
/// `TickerProviderStateMixin` — that's the one piece of ceremony we can't
/// remove, because animations need a vsync.
///
/// ```dart
/// class _HomeState extends State<Home> with TickerProviderStateMixin {
///   late final tabs = RestoTabController(
///     restorationId: 'home_tabs',
///     length: 3,
///     vsync: this,
///   );
///   // ...inside a RestorationHost:
///   TabBarView(controller: tabs.controller, ...)
/// }
/// ```
class RestoTabController implements HostedRestorable {
  /// Creates a tab controller whose selected index is restored under
  /// [restorationId].
  RestoTabController({
    required this.restorationId,
    required int length,
    required TickerProvider vsync,
    int initialIndex = 0,
  }) : _property =
            _RestorableTab(length, vsync, initialIndex, restorationId);

  @override
  final String restorationId;

  final _RestorableTab _property;

  /// The controller to hand to your [TabBar]/[TabBarView]. Only valid while
  /// this object is registered with a mounted [RestorationHost].
  TabController get controller => _property.controller;

  @override
  RestorableProperty<Object?> get property => _property;

  /// Releases the controller. Call from your `State.dispose`.
  @override
  void dispose() => _property.dispose();
}

/// Wraps a [TabController], serializing only its [TabController.index].
class _RestorableTab extends RestorableProperty<TabController> {
  _RestorableTab(this._length, this._vsync, this._initialIndex, this._debugId);

  final int _length;
  final TickerProvider _vsync;
  final int _initialIndex;
  final String _debugId;

  TabController? _controller;

  TabController get controller {
    assert(
      _controller != null,
      'RestoTabController("$_debugId") was used before its RestorationHost '
      'registered it. Make sure the host is an ancestor of the widget that '
      'uses this controller.',
    );
    return _controller!;
  }

  @override
  TabController createDefaultValue() => TabController(
        length: _length,
        vsync: _vsync,
        initialIndex: _initialIndex,
      );

  @override
  TabController fromPrimitives(Object? data) => TabController(
        length: _length,
        vsync: _vsync,
        // Clamp defensively: the app may ship an update with fewer tabs
        // than the restored index remembers.
        initialIndex: (data as int).clamp(0, _length - 1),
      );

  @override
  void initWithValue(TabController value) {
    _controller?.removeListener(_onTabChanged);
    _controller?.dispose();
    _controller = value..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Serialize only once the change settles (skip mid-swipe frames).
    if (!_controller!.indexIsChanging) notifyListeners();
  }

  @override
  Object? toPrimitives() {
    final int index = _controller!.index;
    RestorationSizeGuardian.debugTrack(_debugId, index);
    return index;
  }

  @override
  void dispose() {
    RestorationSizeGuardian.debugUntrack(_debugId);
    _controller?.removeListener(_onTabChanged);
    _controller?.dispose();
    super.dispose();
  }
}
