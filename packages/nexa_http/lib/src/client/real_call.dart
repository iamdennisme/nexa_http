import '../api/call.dart';
import '../api/request.dart';
import '../api/response.dart';
import '../internal/errors/nexa_http_failures.dart';

typedef ExecuteRequest =
    Future<Response> Function(
      Request request, {
      void Function(void Function() cancelRequest)? onCancelReady,
      bool Function()? isCanceled,
    });

final class RealCall implements Call {
  RealCall({required Request request, required ExecuteRequest executeRequest})
    : _request = request,
      _executeRequest = executeRequest;

  final Request _request;
  final ExecuteRequest _executeRequest;

  bool _isCanceled = false;
  bool _isExecuted = false;
  bool _hasForwardedCancellation = false;
  void Function()? _cancelRequest;

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

    _isExecuted = true;
    if (_isCanceled) {
      throw NexaHttpFailures.canceled(
        stage: 'call_pre_execute',
        uri: _request.url,
      );
    }

    try {
      return await _executeRequest(
        _request,
        onCancelReady: _installCancelRequest,
        isCanceled: () => _isCanceled,
      );
    } finally {
      _cancelRequest = null;
    }
  }

  @override
  void cancel() {
    _isCanceled = true;
    _forwardCancellation();
  }

  void _installCancelRequest(void Function() cancelRequest) {
    _cancelRequest = cancelRequest;
    _forwardCancellation();
  }

  void _forwardCancellation() {
    final cancelRequest = _cancelRequest;
    if (!_isExecuted ||
        !_isCanceled ||
        _hasForwardedCancellation ||
        cancelRequest == null) {
      return;
    }

    _hasForwardedCancellation = true;
    cancelRequest();
  }
}
