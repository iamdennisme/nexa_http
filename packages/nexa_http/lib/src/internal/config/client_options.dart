final class ClientOptions {
  const ClientOptions({
    this.baseUrl,
    this.defaultHeaders = const <String, String>{},
    this.timeout,
    this.userAgent,
  });

  final Uri? baseUrl;
  final Map<String, String> defaultHeaders;
  final Duration? timeout;
  final String? userAgent;

  static final Expando<List<MapEntry<String, String>>> _defaultHeaderEntries =
      Expando<List<MapEntry<String, String>>>();

  List<MapEntry<String, String>> get defaultHeaderEntries {
    final cached = _defaultHeaderEntries[this];
    if (cached != null) {
      return cached;
    }

    final entries = List<MapEntry<String, String>>.unmodifiable(
      defaultHeaders.entries.map(
        (entry) => MapEntry<String, String>(entry.key, entry.value),
      ),
    );
    _defaultHeaderEntries[this] = entries;
    return entries;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ClientOptions &&
        baseUrl == other.baseUrl &&
        timeout == other.timeout &&
        userAgent == other.userAgent &&
        _sameHeaders(defaultHeaders, other.defaultHeaders);
  }

  @override
  int get hashCode => Object.hash(
    baseUrl,
    timeout,
    userAgent,
    Object.hashAllUnordered(
      defaultHeaders.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );

  static bool _sameHeaders(
    Map<String, String> left,
    Map<String, String> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
