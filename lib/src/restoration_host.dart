import 'package:flutter/widgets.dart';

import 'errors.dart';

/// The contract that lets an object plug into a [RestorationHost].
///
/// Implemented by the package's drop-in controllers ([RestoScrollController],
/// [RestoTextController], [RestoTabController]) and open for your own
/// restorable objects.
abstract interface class HostedRestorable {
  /// The underlying property that [RestorationHost] registers and restores.
  RestorableProperty<Object?> get property;

  /// Identifies this object's data within its host. Must be unique among
  /// the host's [RestorationHost.properties].
  String get restorationId;

  /// Releases the underlying property's resources.
  ///
  /// You own what you create: call this from your `State.dispose`, exactly
  /// as you would for a [TextEditingController].
  void dispose();
}

/// Hosts any number of [HostedRestorable]s — the only widget in this package
/// that touches [RestorationMixin], so you never have to.
///
/// ```dart
/// class _FeedScreenState extends State<FeedScreen> {
///   final scroll = RestoScrollController(restorationId: 'scroll');
///   final search = RestoTextController(restorationId: 'search');
///
///   @override
///   void dispose() {
///     scroll.dispose();
///     search.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return RestorationHost(
///       restorationId: 'feed',
///       properties: [scroll, search],
///       child: ListView(controller: scroll.controller, ...),
///     );
///   }
/// }
/// ```
///
/// Lifecycle contract — standard Flutter ownership: **you** create the
/// controllers, so **you** dispose them (in your `State.dispose`, exactly
/// like a [TextEditingController]). The host only registers them for
/// restoration; it must *not* dispose them, because the host's State can
/// die and be recreated (process restoration, conditional subtrees) while
/// your State — the controllers' true owner — lives on. The [properties]
/// list must be stable for the lifetime of the host (create controllers as
/// `final` fields on your State, as above), and a controller instance must
/// not be shared across two hosts.
class RestorationHost extends StatefulWidget {
  /// Creates a host that registers and restores [properties].
  const RestorationHost({
    super.key,
    required this.restorationId,
    required this.properties,
    required this.child,
  });

  /// Uniquely identifies this host within the surrounding restoration scope.
  final String restorationId;

  /// The restorable objects this host manages. See the class docs for the
  /// ownership contract.
  final List<HostedRestorable> properties;

  /// The widget below this host in the tree.
  final Widget child;

  @override
  State<RestorationHost> createState() => _RestorationHostState();
}

class _RestorationHostState extends State<RestorationHost>
    with RestorationMixin {
  /// Properties THIS host has registered. Kept explicitly (rather than
  /// asking `property.isRegistered`, which is @protected framework
  /// internals) so dispose unregisters exactly what restoreState
  /// registered — no more, no less.
  final Set<HostedRestorable> _registeredByThisHost = <HostedRestorable>{};

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    assert(_debugCheckUniqueIds());
    for (final HostedRestorable hosted in widget.properties) {
      registerForRestoration(hosted.property, hosted.restorationId);
      _registeredByThisHost.add(hosted);
    }
  }

  bool _debugCheckUniqueIds() {
    final Set<String> seen = <String>{};
    for (final HostedRestorable hosted in widget.properties) {
      assert(
        seen.add(hosted.restorationId),
        'RestorationHost("${widget.restorationId}") received two properties '
        'with the same restorationId "${hosted.restorationId}". Each '
        'property needs a unique id within its host.',
      );
    }
    return true;
  }

  @override
  void didChangeDependencies() {
    assert(debugCheckHasRestorationScope(context, 'RestorationHost'));
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(RestorationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(oldWidget.properties, widget.properties) ||
          _sameProperties(oldWidget.properties, widget.properties),
      'RestorationHost("${widget.restorationId}") was rebuilt with a '
      'different properties list. The list must be stable for the lifetime '
      'of the host — store your controllers as final fields on your State '
      'and pass the same instances on every build.',
    );
  }

  static bool _sameProperties(
      List<HostedRestorable> a, List<HostedRestorable> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  void dispose() {
    // Unregister — do NOT dispose. Disposal belongs to whoever created the
    // properties (the user's State). But unregistration is OUR job: the
    // framework's mixin does not clear a property's registration bookkeeping
    // when the mixin's State dies, because in the standard pattern property
    // and State share a lifetime. Ours don't — the host can die and be
    // recreated (process restoration, conditional subtrees) while the
    // properties live on in the user's State. Without this, re-registering
    // with the next host trips the framework's "already registered" assert.
    for (final HostedRestorable hosted in _registeredByThisHost) {
      unregisterFromRestoration(hosted.property);
    }
    _registeredByThisHost.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
