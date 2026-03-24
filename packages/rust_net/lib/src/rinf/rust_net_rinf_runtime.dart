import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../native/rust_net_native_ffi.dart';

final class RustNetRinfSignal {
  const RustNetRinfSignal({
    required this.endpoint,
    required this.messageBytes,
    required this.binary,
  });

  final String endpoint;
  final Uint8List messageBytes;
  final Uint8List binary;

  String get messageUtf8 => utf8.decode(messageBytes);
}

final class RustNetRinfRuntime {
  RustNetRinfRuntime._() {
    _rustSignalPort.listen(_onRustSignal);
    rinfPrepareIsolate(
      NativeApi.postCObject,
      _rustSignalPort.sendPort.nativePort,
    );
    rinfStartRustLogic();
  }

  static RustNetRinfRuntime? _instance;

  static RustNetRinfRuntime shared() {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }

    final runtime = RustNetRinfRuntime._();
    _instance = runtime;
    return runtime;
  }

  final ReceivePort _rustSignalPort = ReceivePort();
  final _signalStreamController =
      StreamController<RustNetRinfSignal>.broadcast();

  Stream<RustNetRinfSignal> signalsFor(String endpoint) {
    return _signalStreamController.stream.where(
      (signal) => signal.endpoint == endpoint,
    );
  }

  void sendSignal({
    required String endpointSymbol,
    required List<int> messageBytes,
    List<int> binary = const <int>[],
  }) {
    final messageMemory = malloc.allocate<Uint8>(messageBytes.length);
    final binaryMemory = malloc.allocate<Uint8>(binary.length);

    try {
      messageMemory.asTypedList(messageBytes.length).setAll(0, messageBytes);
      binaryMemory.asTypedList(binary.length).setAll(0, binary);

      switch (endpointSymbol) {
        case 'rinf_send_dart_signal_rust_net_execute_request':
          rinfSendRustNetExecuteRequest(
            messageMemory,
            messageBytes.length,
            binaryMemory,
            binary.length,
          );
        default:
          throw UnsupportedError(
            'Unsupported Rust signal endpoint: $endpointSymbol',
          );
      }
    } finally {
      malloc.free(messageMemory);
      malloc.free(binaryMemory);
    }
  }

  void dispose() {
    rinfStopRustLogic();
    _rustSignalPort.close();
    _signalStreamController.close();
  }

  void _onRustSignal(dynamic raw) {
    if (raw is! List<dynamic> || raw.length < 3) {
      return;
    }

    final endpoint = raw[0];
    if (endpoint is! String) {
      return;
    }

    final messageBytes = _asBytes(raw[1]);
    final binary = _asBytes(raw[2]);
    _signalStreamController.add(
      RustNetRinfSignal(
        endpoint: endpoint,
        messageBytes: messageBytes,
        binary: binary,
      ),
    );
  }

  static Uint8List _asBytes(dynamic value) {
    if (value == null) {
      return Uint8List(0);
    }
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    return Uint8List(0);
  }
}
