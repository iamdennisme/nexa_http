import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/api.dart';
import '../../rust_net_client.dart';

class RustNetDioAdapter implements HttpClientAdapter {
  static const finalUriHeaderName = 'x-rust-net-final-uri';

  RustNetDioAdapter({
    required HttpExecutor executor,
    this.closeExecutor = true,
    this.defaultTimeout,
  }) : _executor = executor;

  factory RustNetDioAdapter.client({
    RustNetClientConfig config = const RustNetClientConfig(),
    bool closeExecutor = true,
  }) {
    return RustNetDioAdapter(
      executor: RustNetClient(config: config),
      closeExecutor: closeExecutor,
      defaultTimeout: config.timeout,
    );
  }

  final HttpExecutor _executor;
  final bool closeExecutor;
  final Duration? defaultTimeout;

  bool _isClosed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _ensureOpen(options);

    final timeoutResolution = _resolveTimeout(options);
    final request = RustNetRequest(
      method: _mapMethod(options),
      uri: options.uri,
      headers: _mapHeaders(options.headers),
      bodyBytes: await _readRequestBody(requestStream),
      timeout: timeoutResolution?.duration ?? defaultTimeout,
    );

    try {
      final response = await _executeWithCancellation(
        request: request,
        options: options,
        cancelFuture: cancelFuture,
      );
      final headers = <String, List<String>>{
        ...response.headers,
        if (response.finalUri != null)
          finalUriHeaderName: <String>[response.finalUri.toString()],
      };

      return ResponseBody(
        Stream<Uint8List>.value(Uint8List.fromList(response.bodyBytes)),
        response.statusCode,
        headers: headers,
        isRedirect: _isRedirectStatus(response.statusCode),
      );
    } on DioException {
      rethrow;
    } on RustNetException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _mapRustNetException(
          error: error,
          options: options,
          timeoutResolution: timeoutResolution,
        ),
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: error.toString(),
        ),
        stackTrace,
      );
    }
  }

  @override
  void close({bool force = false}) {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    if (closeExecutor) {
      unawaited(_executor.close());
    }
  }

  Future<RustNetResponse> _executeWithCancellation({
    required RustNetRequest request,
    required RequestOptions options,
    required Future<void>? cancelFuture,
  }) {
    final requestFuture = _executor.execute(request);
    if (cancelFuture == null) {
      return requestFuture;
    }

    return Future.any(<Future<RustNetResponse>>[
      requestFuture,
      cancelFuture.then<RustNetResponse>((_) {
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: options.cancelToken?.cancelError,
        );
      }),
    ]);
  }

  void _ensureOpen(RequestOptions options) {
    if (_isClosed) {
      throw DioException(
        requestOptions: options,
        error: StateError('RustNetDioAdapter has already been closed.'),
        message: 'RustNetDioAdapter has already been closed.',
      );
    }
  }

  static RustNetMethod _mapMethod(RequestOptions options) {
    switch (options.method.toUpperCase()) {
      case 'GET':
        return RustNetMethod.get;
      case 'POST':
        return RustNetMethod.post;
      case 'PUT':
        return RustNetMethod.put;
      case 'PATCH':
        return RustNetMethod.patch;
      case 'DELETE':
        return RustNetMethod.delete;
      case 'HEAD':
        return RustNetMethod.head;
      case 'OPTIONS':
        return RustNetMethod.options;
      default:
        throw DioException(
          requestOptions: options,
          error: UnsupportedError(
            'RustNetDioAdapter does not support ${options.method.toUpperCase()}.',
          ),
          message:
              'RustNetDioAdapter does not support ${options.method.toUpperCase()}.',
        );
    }
  }

  static Map<String, String> _mapHeaders(Map<String, dynamic> headers) {
    final mapped = <String, String>{};
    headers.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is Iterable<Object?>) {
        mapped[key] = value.map((item) => '$item').join(', ');
        return;
      }
      mapped[key] = '$value';
    });
    return mapped;
  }

  static Future<List<int>?> _readRequestBody(
    Stream<Uint8List>? requestStream,
  ) async {
    if (requestStream == null) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in requestStream) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  }

  static _TimeoutResolution? _resolveTimeout(RequestOptions options) {
    final candidates = <_TimeoutResolution>[
      if (_isPositiveTimeout(options.connectTimeout))
        _TimeoutResolution(
          duration: options.connectTimeout!,
          kind: _TimeoutKind.connection,
        ),
      if (_isPositiveTimeout(options.sendTimeout))
        _TimeoutResolution(
          duration: options.sendTimeout!,
          kind: _TimeoutKind.send,
        ),
      if (_isPositiveTimeout(options.receiveTimeout))
        _TimeoutResolution(
          duration: options.receiveTimeout!,
          kind: _TimeoutKind.receive,
        ),
    ];

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((left, right) {
      final durationCompare = left.duration.compareTo(right.duration);
      if (durationCompare != 0) {
        return durationCompare;
      }
      return left.kind.index.compareTo(right.kind.index);
    });
    return candidates.first;
  }

  static bool _isPositiveTimeout(Duration? timeout) {
    return timeout != null && timeout > Duration.zero;
  }

  DioException _mapRustNetException({
    required RustNetException error,
    required RequestOptions options,
    required _TimeoutResolution? timeoutResolution,
  }) {
    if (error.isTimeout) {
      final effectiveTimeout = timeoutResolution?.duration ?? defaultTimeout;
      final timeoutKind = timeoutResolution?.kind ?? _TimeoutKind.receive;
      if (effectiveTimeout != null) {
        switch (timeoutKind) {
          case _TimeoutKind.connection:
            return DioException.connectionTimeout(
              timeout: effectiveTimeout,
              requestOptions: options,
              error: error,
            );
          case _TimeoutKind.send:
            return DioException.sendTimeout(
              timeout: effectiveTimeout,
              requestOptions: options,
            );
          case _TimeoutKind.receive:
            return DioException.receiveTimeout(
              timeout: effectiveTimeout,
              requestOptions: options,
              error: error,
            );
        }
      }
    }

    if (error.code == 'network') {
      return DioException.connectionError(
        requestOptions: options,
        reason: error.message,
        error: error,
      );
    }

    return DioException(
      requestOptions: options,
      error: error,
      message: error.message,
    );
  }

  static bool _isRedirectStatus(int statusCode) {
    return statusCode >= 300 && statusCode < 400;
  }
}

enum _TimeoutKind {
  connection,
  send,
  receive,
}

final class _TimeoutResolution {
  const _TimeoutResolution({
    required this.duration,
    required this.kind,
  });

  final Duration duration;
  final _TimeoutKind kind;
}
