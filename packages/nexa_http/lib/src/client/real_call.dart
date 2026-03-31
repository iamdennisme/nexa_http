import '../api/call.dart';
import '../api/callback.dart';
import '../api/request.dart';
import '../api/response.dart';

final class RealCall implements Call {
  RealCall({
    required Request request,
    required Future<Response> Function(Request request) executeRequest,
  }) : _request = request,
       _executeRequest = executeRequest;

  final Request _request;
  final Future<Response> Function(Request request) _executeRequest;

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
    return _executeRequest(_request);
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
    return RealCall(request: _request, executeRequest: _executeRequest);
  }
}
