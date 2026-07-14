import 'dart:async';

import '../../internal/transport/transport_response.dart';

final class FfiNexaHttpPendingRequestRegistry {
  FfiNexaHttpPendingRequestRegistry({
    required void Function() onDrainedAfterDispose,
  }) : _onDrainedAfterDispose = onDrainedAfterDispose;

  final void Function() _onDrainedAfterDispose;
  final Map<int, Completer<TransportResponse>> _pendingExecuteRequests =
      <int, Completer<TransportResponse>>{};

  int _requestSequence = 0;
  bool _disposeRequested = false;
  bool _isDisposed = false;

  int nextRequestId() {
    _requestSequence += 1;
    return _requestSequence;
  }

  Completer<TransportResponse> register(int requestId) {
    final completer = Completer<TransportResponse>();
    _pendingExecuteRequests[requestId] = completer;
    return completer;
  }

  Completer<TransportResponse>? take(int requestId) {
    return _pendingExecuteRequests.remove(requestId);
  }

  void dispose() {
    if (_disposeRequested || _isDisposed) {
      return;
    }
    _disposeRequested = true;
    didCompletePendingRequest();
  }

  void didCompletePendingRequest() {
    if (!_disposeRequested ||
        _pendingExecuteRequests.isNotEmpty ||
        _isDisposed) {
      return;
    }

    _isDisposed = true;
    _onDrainedAfterDispose();
  }
}
