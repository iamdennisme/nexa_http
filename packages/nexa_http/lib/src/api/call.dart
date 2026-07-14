import 'request.dart';
import 'response.dart';

abstract interface class Call {
  Request get request;

  bool get isCanceled;

  bool get isExecuted;

  Future<Response> execute();

  void cancel();
}
