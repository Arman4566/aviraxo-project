import 'dart:async';

import '../../core/messenger.dart';

/// Keeps the latest server list in memory and exposes it as a stream, so screens that used
/// `watchAll()` keep working. Call [refresh] after any change (repos do this for you).
class CachedList<T> {
  CachedList(this._load);

  final Future<List<T>> Function() _load;
  final StreamController<List<T>> _bus = StreamController<List<T>>.broadcast();
  List<T>? _latest;
  Future<void>? _inFlight;

  List<T>? get latest => _latest;

  Future<void> refresh({bool quiet = false}) {
    return _inFlight ??= () async {
      try {
        _latest = await _load();
        _bus.add(_latest!);
      } catch (e) {
        if (!quiet) AppMessenger.error(e);
      } finally {
        _inFlight = null;
      }
    }();
  }

  /// Emits the cached list straight away (if any), then every refresh.
  Stream<List<T>> watch() {
    late StreamController<List<T>> c;
    StreamSubscription<List<T>>? sub;
    c = StreamController<List<T>>(
      onListen: () {
        if (_latest != null) c.add(_latest!);
        sub = _bus.stream.listen(c.add);
        refresh();
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  void clear() {
    _latest = null;
  }
}
