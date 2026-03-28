import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/api.dart';
import '../../nexa_http_client.dart';

class NexaHttpDioAdapter implements HttpClientAdapter {
  static const finalUriHeaderName = 'x-rust-net-final-uri';

  NexaHttpDioAdapter({
    required HttpExecutor executor,
    this.closeExecutor = true,
    this.defaultTimeout,
  }) : _executor = executor;

  factory NexaHttpDioAdapter.client({
    NexaHttpClientConfig config = const NexaHttpClientConfig(),
    bool closeExecutor = true,
  }) {
    return NexaHttpDioAdapter(
      executor: NexaHttpClient(config: config),
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
    final request = NexaHttpRequest(
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
      final responseBody = switch (options.responseType) {
        ResponseType.bytes => ResponseBody.fromBytes(
          await _readResponseBytesWithCancellation(
            response: response,
            options: options,
            cancelFuture: cancelFuture,
          ),
          response.statusCode,
          headers: headers,
          isRedirect: _isRedirectStatus(response.statusCode),
        ),
        _ => ResponseBody(
          _mapResponseBodyStream(
            response: response,
            options: options,
            timeoutResolution: timeoutResolution,
          ),
          response.statusCode,
          headers: headers,
          isRedirect: _isRedirectStatus(response.statusCode),
          onClose: response.close,
        ),
      };

      return responseBody;
    } on DioException {
      rethrow;
    } on NexaHttpException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _mapNexaHttpException(
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

  Future<NexaHttpStreamedResponse> _executeWithCancellation({
    required NexaHttpRequest request,
    required RequestOptions options,
    required Future<void>? cancelFuture,
  }) {
    final requestFuture = _executor.execute(request);
    if (cancelFuture == null) {
      return requestFuture;
    }

    return Future.any(<Future<NexaHttpStreamedResponse>>[
      requestFuture,
      cancelFuture.then<NexaHttpStreamedResponse>((_) {
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: options.cancelToken?.cancelError,
        );
      }),
    ]);
  }

  Future<Uint8List> _readResponseBytesWithCancellation({
    required NexaHttpStreamedResponse response,
    required RequestOptions options,
    required Future<void>? cancelFuture,
  }) {
    final responseBytesFuture = response.readBytes();
    if (cancelFuture == null) {
      return responseBytesFuture;
    }

    return Future.any(<Future<Uint8List>>[
      responseBytesFuture,
      cancelFuture.then<Uint8List>((_) {
        response.close();
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: options.cancelToken?.cancelError,
        );
      }),
    ]);
  }

  Stream<Uint8List> _mapResponseBodyStream({
    required NexaHttpStreamedResponse response,
    required RequestOptions options,
    required _TimeoutResolution? timeoutResolution,
  }) {
    return response.bodyStream.transform(
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is DioException) {
            sink.addError(error, stackTrace);
            return;
          }
          if (error is NexaHttpException) {
            sink.addError(
              _mapNexaHttpException(
                error: error,
                options: options,
                timeoutResolution: timeoutResolution,
              ),
              stackTrace,
            );
            return;
          }
          sink.addError(
            DioException(
              requestOptions: options,
              error: error,
              stackTrace: stackTrace,
              message: error.toString(),
            ),
            stackTrace,
          );
        },
      ),
    );
  }

  void _ensureOpen(RequestOptions options) {
    if (_isClosed) {
      throw DioException(
        requestOptions: options,
        error: StateError('NexaHttpDioAdapter has already been closed.'),
        message: 'NexaHttpDioAdapter has already been closed.',
      );
    }
  }

  static NexaHttpMethod _mapMethod(RequestOptions options) {
    switch (options.method.toUpperCase()) {
      case 'GET':
        return NexaHttpMethod.get;
      case 'POST':
        return NexaHttpMethod.post;
      case 'PUT':
        return NexaHttpMethod.put;
      case 'PATCH':
        return NexaHttpMethod.patch;
      case 'DELETE':
        return NexaHttpMethod.delete;
      case 'HEAD':
        return NexaHttpMethod.head;
      case 'OPTIONS':
        return NexaHttpMethod.options;
      default:
        throw DioException(
          requestOptions: options,
          error: UnsupportedError(
            'NexaHttpDioAdapter does not support ${options.method.toUpperCase()}.',
          ),
          message:
              'NexaHttpDioAdapter does not support ${options.method.toUpperCase()}.',
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

  DioException _mapNexaHttpException({
    required NexaHttpException error,
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

enum _TimeoutKind { connection, send, receive }

final class _TimeoutResolution {
  const _TimeoutResolution({required this.duration, required this.kind});

  final Duration duration;
  final _TimeoutKind kind;
}
