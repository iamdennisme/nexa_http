import 'request.dart';
import 'response.dart';

import 'callback.dart';

abstract interface class Call {
  Request get request;

  bool get isCanceled;

  bool get isExecuted;

  Future<Response> execute();

  void enqueue(Callback callback);

  void cancel();

  Call clone();
}
