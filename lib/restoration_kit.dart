/// Effortless state restoration for Flutter.
///
/// Survive process death without the RestorationMixin ceremony:
///
/// * [RestorableBuilder] — restore a single value with one widget.
/// * [RestorationHost] + drop-in controllers ([RestoScrollController],
///   [RestoTextController], [RestoTabController]) — restore scroll offsets,
///   text fields, and selected tabs.
/// * [RestorationSizeGuardian] — debug-mode warnings before you hit
///   Android's ~1 MB restoration budget and crash natively.
library restoration_kit;

export 'src/controllers/resto_scroll_controller.dart'
    show RestoScrollController;
export 'src/controllers/resto_tab_controller.dart' show RestoTabController;
export 'src/controllers/resto_text_controller.dart' show RestoTextController;
export 'src/restorable_builder.dart'
    show RestorableBuilder, RestorablePrimitive;
export 'src/restoration_host.dart' show HostedRestorable, RestorationHost;
export 'src/size_guardian.dart' show RestorationSizeGuardian;
