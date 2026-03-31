import 'headers.dart';
import 'request_body.dart';
import 'request_builder.dart';

final class Request {
  Request._({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
    this.timeout,
  });

  factory Request({
    required String method,
    required Uri url,
    Headers? headers,
    RequestBody? body,
    Duration? timeout,
  }) {
    return Request._(
      method: method.trim().toUpperCase(),
      url: url,
      headers: headers ?? Headers.empty,
      body: body,
      timeout: timeout,
    );
  }

  final String method;
  final Uri url;
  final Headers headers;
  final RequestBody? body;
  final Duration? timeout;

  RequestBuilder newBuilder() {
    final builder = RequestBuilder()
      ..url(url)
      ..headers(headers)
      ..method(method, body);
    if (timeout != null) {
      builder.timeout(timeout!);
    }
    return builder;
  }
}
