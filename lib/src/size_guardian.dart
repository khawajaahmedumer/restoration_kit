import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Debug-mode watchdog for Android's restoration data budget.
///
/// Android limits the entire saved-instance-state Bundle to ~1 MB. Exceed it
/// and the app dies in *native* code with a TransactionTooLargeException —
/// no Dart stack trace, no clue which widget was responsible.
///
/// This guardian estimates the serialized size of every value the package
/// persists and prints an actionable warning *naming the restorationId*
/// before you get anywhere near the cliff. It is compiled out of release
/// builds entirely (every entry point is wrapped in `assert`).
abstract final class RestorationSizeGuardian {
  /// Per-property warning threshold. A single property this large is almost
  /// always a sign that something belongs in real storage, not restoration.
  static const int singlePropertyWarnBytes = 100 * 1024; // 100 KB

  /// Cumulative warning threshold, deliberately below the ~1 MB hard limit
  /// to leave headroom for the framework's own restoration data (navigator
  /// stack, text input state, etc.).
  static const int totalWarnBytes = 800 * 1024; // 800 KB

  static final Map<String, int> _sizesById = <String, int>{};

  /// Records the serialized size of [primitives] under [id] and warns when
  /// thresholds are crossed. No-op in release/profile builds.
  static void debugTrack(String id, Object? primitives) {
    assert(() {
      ByteData? encoded;
      try {
        encoded = const StandardMessageCodec().encodeMessage(primitives);
      } catch (_) {
        // Not codec-serializable; the property's own asserts handle that.
        return true;
      }
      final int bytes = encoded?.lengthInBytes ?? 0;
      _sizesById[id] = bytes;

      if (bytes > singlePropertyWarnBytes) {
        debugPrint(
          '[restoration_kit] WARNING: restorationId "$id" is storing '
          '~${_kb(bytes)} of restoration data. Android caps the entire '
          'restoration bundle at ~1 MB and exceeding it crashes natively '
          '(TransactionTooLargeException). Restoration is for ephemeral UI '
          'state — consider moving this data to persistent storage.',
        );
      }

      final int total = _sizesById.values.fold(0, (a, b) => a + b);
      if (total > totalWarnBytes) {
        final String breakdown = (_sizesById.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => '  ${e.key}: ~${_kb(e.value)}')
            .join('\n');
        debugPrint(
          '[restoration_kit] WARNING: total tracked restoration data is '
          '~${_kb(total)}, approaching Android\'s ~1 MB hard limit. '
          'Largest properties:\n$breakdown',
        );
      }
      return true;
    }());
  }

  /// Removes [id] from the ledger when its property is disposed.
  static void debugUntrack(String id) {
    assert(() {
      _sizesById.remove(id);
      return true;
    }());
  }

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';
}
