import 'headers.dart';
import 'request.dart';
import 'request_body.dart';

final class RequestBuilder {
  Uri? _url;
  String _method = 'GET';
  RequestBody? _body;
  Duration? _timeout;
  final Map<String, List<String>> _headers = <String, List<String>>{};

  RequestBuilder url(Uri value) {
    _url = value;
    return this;
  }

  RequestBuilder headers(Headers value) {
    _headers
      ..clear()
      ..addAll(
        value.toMultimap().map(
          (key, values) => MapEntry(key, List<String>.from(values)),
        ),
      );
    return this;
  }

  RequestBuilder header(String name, String value) {
    _headers[_normalizeName(name)] = <String>[value];
    return this;
  }

  RequestBuilder addHeader(String name, String value) {
    (_headers[_normalizeName(name)] ??= <String>[]).add(value);
    return this;
  }

  RequestBuilder timeout(Duration value) {
    _timeout = value;
    return this;
  }

  RequestBuilder get() => method('GET');

  RequestBuilder head() => method('HEAD');

  RequestBuilder post(RequestBody body) => method('POST', body);

  RequestBuilder put(RequestBody body) => method('PUT', body);

  RequestBuilder patch(RequestBody body) => method('PATCH', body);

  RequestBuilder delete([RequestBody? body]) => method('DELETE', body);

  RequestBuilder method(String value, [RequestBody? body]) {
    _method = value.trim().toUpperCase();
    _body = body;
    return this;
  }

  Request build() {
    final url = _url;
    if (url == null) {
      throw StateError('RequestBuilder requires a URL before build().');
    }

    return Request(
      method: _method,
      url: url,
      headers: Headers.of(_headers),
      body: _body,
      timeout: _timeout,
    );
  }

  static String _normalizeName(String name) => name.trim().toLowerCase();
}
