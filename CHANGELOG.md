## 0.1.0

Initial release.

* `RestorableBuilder<T>` — restore a single primitive value with one widget, no `RestorationMixin` required.
* `RestorationHost` + `HostedRestorable` — host any number of restorable properties without the mixin ceremony.
* Drop-in controllers: `RestoScrollController`, `RestoTextController`, `RestoTabController`.
* Debug-mode size guardian with per-`restorationId` warnings for Android's ~1 MB restoration budget.
* Descriptive error (instead of silent no-op) when no `RestorationScope` is configured.
