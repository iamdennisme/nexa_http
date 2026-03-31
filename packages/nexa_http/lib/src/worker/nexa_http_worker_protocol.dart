
sealed class NexaHttpWorkerRequest {
  const NexaHttpWorkerRequest({required this.requestId, required this.type});

  final int requestId;
  final String type;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'requestId': requestId,
      'type': type,
    };
  }

  static NexaHttpWorkerRequest fromMessage(Map<Object?, Object?> message) {
    final normalized = _normalize(message);
    final requestId = normalized['requestId'];
    final type = normalized['type'];
    if (requestId is! int || type is! String) {
      throw StateError('Invalid worker request payload: $message');
    }

    switch (type) {
      case NexaHttpWorkerRequestType.warmUp:
        return NexaHttpWarmUpWorkerRequest(requestId: requestId);
      case NexaHttpWorkerRequestType.openClient:
        return NexaHttpOpenClientWorkerRequest(
          requestId: requestId,
          config: Map<String, Object?>.from(
            (normalized['config'] as Map<Object?, Object?>?) ??
                const <Object?, Object?>{},
          ),
        );
      case NexaHttpWorkerRequestType.execute:
        return NexaHttpExecuteWorkerRequest(
          requestId: requestId,
          leaseId: normalized['leaseId'] as int,
          request: Map<String, Object?>.from(
            (normalized['request'] as Map<Object?, Object?>?) ??
                const <Object?, Object?>{},
          ),
        );
      case NexaHttpWorkerRequestType.closeLease:
        return NexaHttpCloseLeaseWorkerRequest(
          requestId: requestId,
          leaseId: normalized['leaseId'] as int,
        );
      case NexaHttpWorkerRequestType.shutdown:
        return NexaHttpShutdownWorkerRequest(requestId: requestId);
      default:
        throw UnsupportedError('Unsupported worker request type: $type');
    }
  }

  static const NexaHttpWarmUpWorkerRequest Function({required int requestId})
  warmUp = NexaHttpWarmUpWorkerRequest.new;

  static Map<String, Object?> _normalize(Map<Object?, Object?> raw) {
    return Map<String, Object?>.unmodifiable(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is NexaHttpWorkerRequest &&
        requestId == other.requestId &&
        type == other.type &&
        _deepEquals(toMessage(), other.toMessage());
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId, type);
}

final class NexaHttpWarmUpWorkerRequest extends NexaHttpWorkerRequest {
  const NexaHttpWarmUpWorkerRequest({required super.requestId})
    : super(type: NexaHttpWorkerRequestType.warmUp);
}

final class NexaHttpOpenClientWorkerRequest extends NexaHttpWorkerRequest {
  const NexaHttpOpenClientWorkerRequest({
    required super.requestId,
    required this.config,
  }) : super(type: NexaHttpWorkerRequestType.openClient);

  final Map<String, Object?> config;

  @override
  Map<String, Object?> toMessage() {
    return <String, Object?>{...super.toMessage(), 'config': config};
  }
}

final class NexaHttpExecuteWorkerRequest extends NexaHttpWorkerRequest {
  const NexaHttpExecuteWorkerRequest({
    required super.requestId,
    required this.leaseId,
    required this.request,
  }) : super(type: NexaHttpWorkerRequestType.execute);

  final int leaseId;
  final Map<String, Object?> request;

  @override
  Map<String, Object?> toMessage() {
    return <String, Object?>{
      ...super.toMessage(),
      'leaseId': leaseId,
      'request': request,
    };
  }
}

final class NexaHttpCloseLeaseWorkerRequest extends NexaHttpWorkerRequest {
  const NexaHttpCloseLeaseWorkerRequest({
    required super.requestId,
    required this.leaseId,
  }) : super(type: NexaHttpWorkerRequestType.closeLease);

  final int leaseId;

  @override
  Map<String, Object?> toMessage() {
    return <String, Object?>{...super.toMessage(), 'leaseId': leaseId};
  }
}

final class NexaHttpShutdownWorkerRequest extends NexaHttpWorkerRequest {
  const NexaHttpShutdownWorkerRequest({required super.requestId})
    : super(type: NexaHttpWorkerRequestType.shutdown);
}

abstract final class NexaHttpWorkerRequestType {
  static const warmUp = 'warm_up';
  static const openClient = 'open_client';
  static const execute = 'execute';
  static const closeLease = 'close_lease';
  static const shutdown = 'shutdown';
}

sealed class NexaHttpWorkerResponse {
  const NexaHttpWorkerResponse({required this.requestId, required this.ok});

  final int requestId;
  final bool ok;

  Map<String, Object?> toMessage();

  static NexaHttpWorkerResponse fromMessage(Map<Object?, Object?> message) {
    final normalized = Map<String, Object?>.unmodifiable(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );
    final requestId = normalized['requestId'];
    final ok = normalized['ok'];
    if (requestId is! int || ok is! bool) {
      throw StateError('Invalid worker response payload: $message');
    }

    if (ok) {
      return NexaHttpWorkerSuccessResponse(
        requestId: requestId,
        result: Map<String, Object?>.from(
          (normalized['result'] as Map<Object?, Object?>?) ??
              const <Object?, Object?>{},
        ),
      );
    }

    return NexaHttpWorkerErrorResponse(
      requestId: requestId,
      error: Map<String, Object?>.from(
        (normalized['error'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is NexaHttpWorkerResponse &&
        requestId == other.requestId &&
        ok == other.ok &&
        _deepEquals(toMessage(), other.toMessage());
  }

  @override
  int get hashCode => Object.hash(runtimeType, requestId, ok);
}

final class NexaHttpWorkerSuccessResponse extends NexaHttpWorkerResponse {
  const NexaHttpWorkerSuccessResponse({
    required super.requestId,
    this.result = const <String, Object?>{},
  }) : super(ok: true);

  final Map<String, Object?> result;

  @override
  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'requestId': requestId,
      'ok': true,
      'result': result,
    };
  }
}

final class NexaHttpWorkerErrorResponse extends NexaHttpWorkerResponse {
  const NexaHttpWorkerErrorResponse({
    required super.requestId,
    required this.error,
  }) : super(ok: false);

  final Map<String, Object?> error;

  @override
  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'requestId': requestId,
      'ok': false,
      'error': error,
    };
  }
}

bool _deepEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    final leftKeys = left.keys.toSet();
    final rightKeys = right.keys.toSet();
    if (leftKeys.length != rightKeys.length || !leftKeys.containsAll(rightKeys)) {
      return false;
    }
    return leftKeys.every((key) => _deepEquals(left[key], right[key]));
  }

  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_deepEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }

  return left == right;
}
