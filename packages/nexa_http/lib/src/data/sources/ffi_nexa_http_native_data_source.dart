import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http/nexa_http_bindings_generated.dart';

import '../../api/nexa_http_exception.dart';
import '../../internal/transport/transport_response.dart';
import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_error_dto.dart';
import '../mappers/native_http_error_mapper.dart';
import '../dto/native_http_request_dto.dart';
import 'ffi_nexa_http_client_config_encoder.dart';
import 'ffi_nexa_http_pending_request_registry.dart';
import 'ffi_nexa_http_request_encoder.dart';
import 'ffi_nexa_http_response_decoder.dart';
import 'nexa_http_native_data_source.dart';

typedef BinaryResultFinalizerNative = Void Function(Pointer<Void> token);
typedef StringReleaseNative = Void Function(Pointer<Char> value);

final class FfiNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  factory FfiNexaHttpNativeDataSource({
    required DynamicLibrary library,
    NexaHttpBindings? bindings,
    Pointer<NativeFunction<BinaryResultFinalizerNative>>? binaryResultFinalizer,
    Pointer<NativeFunction<StringReleaseNative>>? stringRelease,
  }) {
    final resolvedBindings = bindings ?? NexaHttpBindings(library);
    final resolvedBinaryResultFinalizer = binaryResultFinalizer ??
        (bindings == null
            ? library.lookup<NativeFunction<BinaryResultFinalizerNative>>(
                'nexa_http_binary_result_free',
              )
            : nullptr);
    final resolvedStringRelease = stringRelease ??
        (bindings == null
            ? library.lookup<NativeFunction<StringReleaseNative>>(
                'nexa_http_string_free',
              )
            : nullptr);

    return FfiNexaHttpNativeDataSource._(
      bindings: resolvedBindings,
      binaryResultFinalizer: resolvedBinaryResultFinalizer,
      releaseNativeString: resolvedStringRelease,
    );
  }

  FfiNexaHttpNativeDataSource._({
    required NexaHttpBindings bindings,
    required Pointer<NativeFunction<BinaryResultFinalizerNative>>
    binaryResultFinalizer,
    required Pointer<NativeFunction<StringReleaseNative>> releaseNativeString,
  }) : _bindings = bindings,
       _releaseNativeString = releaseNativeString == nullptr
           ? null
           : releaseNativeString
                 .asFunction<void Function(Pointer<Char>)>(),
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
  final void Function(Pointer<Char>)? _releaseNativeString;
  final FfiNexaHttpResponseDecoder _responseDecoder;
  late final FfiNexaHttpPendingRequestRegistry _pendingRequests;

  NativeCallable<NexaHttpExecuteCallbackFunction>? _executeCallback;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    final encodedConfig = FfiNexaHttpClientConfigEncoder.encode(config);
    try {
      final clientId = _bindings.nexa_http_client_create(encodedConfig.pointer);
      if (clientId == 0) {
        throw _decodeBootstrapError();
      }
      return clientId;
    } finally {
      encodedConfig.dispose();
    }
  }

  @override
  Future<TransportResponse> execute(int clientId, NativeHttpRequestDto request,
      {RegisterCancelRequest? onCancelReady}) async {
    final requestId = _pendingRequests.nextRequestId();
    final completer = _pendingRequests.register(requestId);
    final requestArgs = FfiNexaHttpRequestEncoder.encode(
      request,
      allocateBody: _bindings.nexa_http_request_body_alloc,
      releaseBody: _bindings.nexa_http_request_body_free,
    );

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
      requestArgs.transferBodyOwnership();
      onCancelReady?.call(() {
        final canceledCompleter = _pendingRequests.cancel(requestId);
        if (canceledCompleter == null || canceledCompleter.isCompleted) {
          return;
        }
        _bindings.nexa_http_client_cancel_request(clientId, requestId);
        canceledCompleter.completeError(
          NexaHttpException(
            code: 'canceled',
            message: 'The request was canceled.',
            uri: Uri.tryParse(request.url),
          ),
        );
        _pendingRequests.didCompletePendingRequest();
      });
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

  NexaHttpException _decodeBootstrapError() {
    final errorPointer = _bindings.nexa_http_take_last_error_json();
    if (errorPointer == nullptr) {
      return const NexaHttpException(
        code: 'native_bootstrap_failed',
        message: 'The nexa_http native library failed to create an HTTP client.',
        details: <String, Object?>{'stage': 'client_create'},
      );
    }

    try {
      final decoded = jsonDecode(errorPointer.cast<Utf8>().toDartString());
      if (decoded is! Map) {
        return const NexaHttpException(
          code: 'native_bootstrap_failed',
          message:
              'The nexa_http native library returned an invalid bootstrap error payload.',
          details: <String, Object?>{'stage': 'client_create'},
        );
      }

      return NativeHttpErrorMapper.toDomain(
        NativeHttpErrorDto.fromJson(
          Map<String, dynamic>.from(decoded.cast<String, Object?>()),
        ),
      );
    } finally {
      _releaseNativeString?.call(errorPointer);
    }
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
