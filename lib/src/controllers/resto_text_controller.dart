import 'package:flutter/widgets.dart';

import '../restoration_host.dart';

/// A [TextEditingController] whose text survives process death.
///
/// Flutter already ships [RestorableTextEditingController], but using it
/// still requires the full [RestorationMixin] ceremony. This adapter plugs
/// it into a [RestorationHost] instead:
///
/// ```dart
/// final search = RestoTextController(restorationId: 'search_field');
/// // ...inside a RestorationHost:
/// TextField(controller: search.controller)
/// ```
class RestoTextController implements HostedRestorable {
  RestoTextController({required this.restorationId, String? initialText})
      : _property = RestorableTextEditingController(text: initialText);

  @override
  final String restorationId;

  final RestorableTextEditingController _property;

  /// The controller to hand to your [TextField]/[TextFormField]. Only valid
  /// while this object is registered with a mounted [RestorationHost].
  TextEditingController get controller => _property.value;

  /// Convenience accessor for the current text.
  String get text => _property.value.text;

  @override
  RestorableProperty<Object?> get property => _property;

  /// Releases the controller. Call from your `State.dispose`.
  @override
  void dispose() => _property.dispose();
}
