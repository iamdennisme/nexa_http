import '../api/call.dart';
import '../api/callback.dart';
import '../api/request.dart';
import '../api/response.dart';
import '../internal/config/client_options.dart';
import '../internal/engine/nexa_http_engine_manager.dart';

final class RealCall implements Call {
  RealCall({
    required ClientOptions clientOptions,
    required Request request,
  }) : _clientOptions = clientOptions,
       _request = request;

  final ClientOptions _clientOptions;
  final Request _request;

  bool _isCanceled = false;
  bool _isExecuted = false;

  @override
  Request get request => _request;

  @override
  bool get isCanceled => _isCanceled;

  @override
  bool get isExecuted => _isExecuted;

  @override
  Future<Response> execute() async {
    if (_isExecuted) {
      throw StateError('This call has already been executed.');
    }
    if (_isCanceled) {
      throw StateError('This call was canceled before execution.');
    }

    _isExecuted = true;
    return NexaHttpEngineManager.instance.execute(
      clientConfig: _clientOptions,
      request: _request,
    );
  }

  @override
  void enqueue(Callback callback) {
    execute().then(
      (response) => callback.onResponse(this, response),
      onError: (Object error, StackTrace stackTrace) {
        callback.onFailure(this, error, stackTrace);
      },
    );
  }

  @override
  void cancel() {
    _isCanceled = true;
  }

  @override
  Call clone() {
    return RealCall(clientOptions: _clientOptions, request: _request);
  }
}
