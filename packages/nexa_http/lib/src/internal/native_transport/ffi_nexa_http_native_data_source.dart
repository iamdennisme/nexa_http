import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import '../../api/nexa_http_exception.dart';
import '../errors/nexa_http_failures.dart';
import 'ffi_nexa_http_client_config_encoder.dart';
import 'ffi_nexa_http_pending_request_registry.dart';
import 'ffi_nexa_http_request_encoder.dart';
import 'ffi_nexa_http_response_decoder.dart';
import 'native_http_client_config_dto.dart';
import 'native_http_error_dto.dart';
import 'native_http_error_mapper.dart';
import 'native_http_request_dto.dart';
import 'nexa_http_native_data_source.dart';
import 'transport_response.dart';

typedef BinaryResultFinalizerNative =
    Void Function(Pointer<NexaHttpBinaryResult> token);
typedef StringReleaseNative = Void Function(Pointer<Char> value);

final class FfiNexaHttpNativeDataSource implements NexaHttpNativeDataSource {
  factory FfiNexaHttpNativeDataSource({required NexaHttpBindings bindings}) {
    return FfiNexaHttpNativeDataSource._(
      bindings: bindings,
      binaryResultFinalizer: bindings.nexaHttpBinaryResultFreeAddress,
      releaseNativeString: bindings.nexaHttpStringFreeAddress,
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
           : releaseNativeString.asFunction<void Function(Pointer<Char>)>(),
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
  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  }) async {
    final requestId = _pendingRequests.nextRequestId();
    final requestArgs = FfiNexaHttpRequestEncoder.encode(
      request,
      allocateBody: _bindings.nexa_http_request_body_alloc,
      releaseBody: _bindings.nexa_http_request_body_free,
    );
    final completer = _pendingRequests.register(requestId);

    try {
      final dispatched = _bindings.nexa_http_client_execute_async(
        clientId,
        requestId,
        requestArgs.pointer,
        _executeCallback!.nativeFunction,
      );

      if (dispatched == 0) {
        throw const NexaHttpException(
          kind: NexaHttpFailureKind.unavailable,
          message:
              'The nexa_http native library failed to dispatch the request.',
          diagnostics: <String, Object?>{
            'stage': 'request_dispatch',
            'native_code': 'ffi_dispatch_failed',
          },
        );
      }
      requestArgs.transferBodyOwnership();
      onCancelReady?.call(() {
        if (completer.isCompleted) {
          return;
        }
        final cancelAccepted =
            _bindings.nexa_http_client_cancel_request(clientId, requestId) == 1;
        if (!cancelAccepted) {
          return;
        }
        final canceledCompleter = _pendingRequests.take(requestId);
        if (canceledCompleter == null || canceledCompleter.isCompleted) {
          return;
        }
        canceledCompleter.completeError(
          NexaHttpFailures.canceled(
            stage: 'request_cancel',
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
        kind: NexaHttpFailureKind.unavailable,
        message:
            'The nexa_http native library failed to create an HTTP client.',
        diagnostics: <String, Object?>{
          'stage': 'client_create',
          'native_code': 'native_bootstrap_failed',
        },
      );
    }

    try {
      final decoded = jsonDecode(errorPointer.cast<Utf8>().toDartString());
      if (decoded is! Map) {
        return const NexaHttpException(
          kind: NexaHttpFailureKind.internal,
          message:
              'The nexa_http native library returned an invalid bootstrap error payload.',
          diagnostics: <String, Object?>{
            'stage': 'client_create',
            'native_code': 'native_bootstrap_failed',
          },
        );
      }

      return NativeHttpErrorMapper.toDomain(
        NativeHttpErrorDto.fromJson(
          Map<String, dynamic>.from(decoded.cast<String, Object?>()),
        ),
      );
    } on Object catch (error) {
      return NexaHttpFailures.internal(
        message:
            'The nexa_http native library returned malformed bootstrap diagnostics.',
        stage: 'client_create',
        error: error,
        diagnostics: const <String, Object?>{
          'native_code': 'native_bootstrap_failed',
        },
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

    try {
      final response = _responseDecoder.decode(resultPointer);
      completer.complete(response);
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _pendingRequests.didCompletePendingRequest();
    }
  }
}
