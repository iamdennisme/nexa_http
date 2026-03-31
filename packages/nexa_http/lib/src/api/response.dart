import 'headers.dart';
import 'response_body.dart';
import 'request.dart';

final class Response {
  Response({
    required this.request,
    required this.statusCode,
    Headers? headers,
    this.body,
    Uri? finalUrl,
  }) : headers = headers ?? Headers.empty,
       finalUrl = finalUrl ?? request.url;

  final Request request;
  final int statusCode;
  final Headers headers;
  final ResponseBody? body;
  final Uri finalUrl;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;

  String? header(String name) => headers[name];
}
