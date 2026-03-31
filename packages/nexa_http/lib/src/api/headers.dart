import 'dart:collection';

final class Headers {
  const Headers._(this._values);

  static const Headers empty = Headers._(<String, List<String>>{});
  static final Expando<Map<String, String>> _singleValueMapCache =
      Expando<Map<String, String>>();

  final Map<String, List<String>> _values;

  factory Headers.of(Map<String, List<String>> values) {
    if (values.isEmpty) {
      return empty;
    }

    return Headers._(_normalize(values));
  }

  factory Headers.fromMap(Map<String, String> values) {
    if (values.isEmpty) {
      return empty;
    }

    return Headers._(
      Map<String, List<String>>.unmodifiable(
        values.map(
          (key, value) => MapEntry(
            _normalizeName(key),
            List<String>.unmodifiable(<String>[value]),
          ),
        ),
      ),
    );
  }

  String? operator [](String name) {
    final values = _values[_normalizeName(name)];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.last;
  }

  bool contains(String name) => _values.containsKey(_normalizeName(name));

  Iterable<String> get names => _values.keys;

  List<String> values(String name) {
    final resolved = _values[_normalizeName(name)];
    if (resolved == null) {
      return const <String>[];
    }
    return resolved;
  }

  Map<String, List<String>> toMultimap() {
    return _values;
  }

  Map<String, String> toMap() {
    final cached = _singleValueMapCache[this];
    if (cached != null) {
      return cached;
    }

    final projected = UnmodifiableMapView<String, String>(
      _values.map((key, value) => MapEntry(key, value.last)),
    );
    _singleValueMapCache[this] = projected;
    return projected;
  }

  Headers set(String name, String value) {
    final updated = <String, List<String>>{..._values};
    updated[_normalizeName(name)] = <String>[value];
    return Headers._(_normalize(updated));
  }

  Headers add(String name, String value) {
    final normalizedName = _normalizeName(name);
    final updated = <String, List<String>>{
      ..._values.map(
        (key, values) => MapEntry(key, List<String>.from(values)),
      ),
    };
    (updated[normalizedName] ??= <String>[]).add(value);
    return Headers._(_normalize(updated));
  }

  static Map<String, List<String>> _normalize(
      Map<String, List<String>> values) {
    return Map<String, List<String>>.unmodifiable(
      values.map(
        (key, value) => MapEntry(
          _normalizeName(key),
          List<String>.unmodifiable(List<String>.from(value)),
        ),
      ),
    );
  }

  static String _normalizeName(String name) => name.trim().toLowerCase();
}
