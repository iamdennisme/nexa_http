import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../../api/nexa_http_exception.dart';
import '../../internal/transport/transport_response.dart';
import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';
import 'ffi_nexa_http_pending_request_registry.dart';
import 'ffi_nexa_http_request_encoder.dart';
import 'ffi_nexa_http_response_decoder.dart';
import 'nexa_http_native_data_source.dart';

typedef BinaryResultFinalizerNative = Void Function(Pointer<Void> token);

final class FfiNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  factory FfiNexaHttpNativeDataSource({
    required DynamicLibrary library,
    NexaHttpBindings? bindings,
    Pointer<NativeFunction<BinaryResultFinalizerNative>>? binaryResultFinalizer,
  }) {
    final resolvedBindings = bindings ?? NexaHttpBindings(library);

    return FfiNexaHttpNativeDataSource._(
      bindings: resolvedBindings,
      binaryResultFinalizer:
          binaryResultFinalizer ??
          library.lookup<NativeFunction<BinaryResultFinalizerNative>>(
            'nexa_http_binary_result_free',
          ),
    );
  }

  FfiNexaHttpNativeDataSource._({
    required NexaHttpBindings bindings,
    required Pointer<NativeFunction<BinaryResultFinalizerNative>>
    binaryResultFinalizer,
  }) : _bindings = bindings,
       _responseDecoder = FfiNexaHttpResponseDecoder(
         releaseBinaryResult: bindings.nexa_http_binary_result_free,
         binaryResultNativeFinalizer: binaryResultFinalizer == nullptr
             ? null
             : NativeFinalizer(binaryResultFinalizer.cast()),
       ) {
    _executeCallback = NativeCallable<NexaHttpExecuteCallbackFunction>.listener(
      _handleExecuteCallback,
    );
    _pendingRequests = FfiNexaHttpPendingRequestRegistry(
      onDrainedAfterDispose: () {
        final callback = _executeCallback;
        _executeCallback = null;
        callback?.close();
      },
    );
  }

  final NexaHttpBindings _bindings;
  final FfiNexaHttpResponseDecoder _responseDecoder;
  late final FfiNexaHttpPendingRequestRegistry _pendingRequests;

  NativeCallable<NexaHttpExecuteCallbackFunction>? _executeCallback;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    final configPointer = jsonEncode(config.toJson()).toNativeUtf8();
    try {
      final clientId = _bindings.nexa_http_client_create(configPointer.cast());
      if (clientId == 0) {
        throw StateError(
          'The nexa_http native library failed to create an HTTP client.',
        );
      }
      return clientId;
    } finally {
      calloc.free(configPointer);
    }
  }

  @override
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    final requestId = _pendingRequests.nextRequestId();
    final completer = _pendingRequests.register(requestId);
    final requestArgs = FfiNexaHttpRequestEncoder.encode(request);

    try {
      final dispatched = _bindings.nexa_http_client_execute_async(
        clientId,
        requestId,
        requestArgs.pointer,
        _executeCallback!.nativeFunction,
      );

      if (dispatched == 0) {
        throw const NexaHttpException(
          code: 'ffi_dispatch_failed',
          message:
              'The nexa_http native library failed to dispatch the request.',
        );
      }
    } catch (error, stackTrace) {
      _pendingRequests.take(requestId);
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      requestArgs.dispose();
    }

    return completer.future;
  }

  @override
  void closeClient(int clientId) {
    _bindings.nexa_http_client_close(clientId);
  }

  @override
  void dispose() {
    _pendingRequests.dispose();
  }

  void _handleExecuteCallback(
    int requestId,
    Pointer<NexaHttpBinaryResult> resultPointer,
  ) {
    final completer = _pendingRequests.take(requestId);
    if (completer == null || completer.isCompleted) {
      _bindings.nexa_http_binary_result_free(resultPointer);
      _pendingRequests.didCompletePendingRequest();
      return;
    }

    var releaseResultPointer = true;
    try {
      final response = _responseDecoder.decode(resultPointer);
      releaseResultPointer = !_responseDecoder.adoptsBodyOwnership(
        resultPointer.ref,
      );
      completer.complete(response);
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      if (releaseResultPointer) {
        _bindings.nexa_http_binary_result_free(resultPointer);
      }
      _pendingRequests.didCompletePendingRequest();
    }
  }
}
