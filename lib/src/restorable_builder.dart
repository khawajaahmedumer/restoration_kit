import 'package:flutter/services.dart' show debugIsSerializableForRestoration;
import 'package:flutter/widgets.dart';

import 'errors.dart';
import 'size_guardian.dart';

/// A restorable wrapper around a single codec-serializable value.
///
/// v1 is deliberately **strict**: `T` must be a type that Flutter's
/// [StandardMessageCodec] can serialize — `null`, `bool`, `int`, `double`,
/// `String`, or `List`/`Map` compositions of those. Anything else fails
/// fast with a clear error instead of failing silently at restore time.
class RestorablePrimitive<T> extends RestorableValue<T> {
  RestorablePrimitive(this._defaultValue) {
    assert(
      debugIsSerializableForRestoration(_defaultValue),
      'RestorablePrimitive<$T>: "$_defaultValue" cannot be serialized for '
      'restoration. v1 supports primitives (bool, int, double, String) and '
      'Lists/Maps of primitives. Custom-type converters are planned for a '
      'future release.',
    );
  }

  final T _defaultValue;

  @override
  T createDefaultValue() => _defaultValue;

  @override
  void didUpdateValue(T? oldValue) {
    assert(
      debugIsSerializableForRestoration(value),
      'RestorablePrimitive<$T>: the new value "$value" cannot be serialized '
      'for restoration.',
    );
    // Tells the RestorationMixin that owns this property to re-serialize.
    notifyListeners();
  }

  @override
  T fromPrimitives(Object? data) {
    // The codec round-trips int-valued doubles as ints on some platforms;
    // coerce so `RestorablePrimitive<double>` restored from `2.0` works.
    if (data is num && T == double) {
      return data.toDouble() as T;
    }
    return data as T;
  }

  @override
  Object? toPrimitives() {
    RestorationSizeGuardian.debugTrack(debugLabel, value);
    return value;
  }

  /// Best-effort identifier for guardian warnings; falls back to the type.
  String get debugLabel => _debugLabel ?? 'RestorablePrimitive<$T>';
  String? _debugLabel;
  set debugLabel(String label) => _debugLabel = label;

  @override
  void dispose() {
    RestorationSizeGuardian.debugUntrack(debugLabel);
    super.dispose();
  }
}

/// Restores a single value across process death — no [RestorationMixin],
/// no `restoreState` override, no manual registration or disposal.
///
/// ```dart
/// RestorableBuilder<int>(
///   restorationId: 'counter',
///   initialValue: 0,
///   builder: (context, count) => FilledButton(
///     onPressed: () => count.value++, // rebuilds AND persists
///     child: Text('${count.value}'),
///   ),
/// )
/// ```
///
/// Requires an ancestor restoration scope; in practice that means setting
/// `restorationScopeId` on your `MaterialApp`/`CupertinoApp`/`WidgetsApp`.
/// If none is found, this widget throws a descriptive [FlutterError] in
/// debug mode instead of silently doing nothing.
class RestorableBuilder<T> extends StatefulWidget {
  const RestorableBuilder({
    super.key,
    required this.restorationId,
    required this.initialValue,
    required this.builder,
  });

  /// Uniquely identifies this widget's data within the surrounding
  /// restoration scope. Two [RestorableBuilder]s under the same scope must
  /// not share an id.
  final String restorationId;

  /// The value used when there is nothing to restore (first launch, or
  /// restoration data was cleared).
  final T initialValue;

  /// Rebuilds whenever `state.value` changes. Read and write the value via
  /// the provided [RestorablePrimitive].
  final Widget Function(BuildContext context, RestorablePrimitive<T> state)
      builder;

  @override
  State<RestorableBuilder<T>> createState() => _RestorableBuilderState<T>();
}

class _RestorableBuilderState<T> extends State<RestorableBuilder<T>>
    with RestorationMixin {
  late final RestorablePrimitive<T> _value =
      RestorablePrimitive<T>(widget.initialValue)
        ..debugLabel = widget.restorationId;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_value, 'v');
  }

  @override
  void initState() {
    super.initState();
    _value.addListener(_onValueChanged);
  }

  void _onValueChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    assert(debugCheckHasRestorationScope(context, 'RestorableBuilder'));
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _value
      ..removeListener(_onValueChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
