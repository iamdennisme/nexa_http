import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _PostCObjectInner = Int8 Function(Int64, Pointer<Dart_CObject>);
typedef _PostCObjectPtr = Pointer<NativeFunction<_PostCObjectInner>>;
typedef _PrepareIsolateNative = Void Function(_PostCObjectPtr, Int64);
typedef _PrepareIsolateDart = void Function(_PostCObjectPtr, int);
typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();
typedef _SendSignalNative = Void Function(
  Pointer<Uint8>,
  UintPtr,
  Pointer<Uint8>,
  UintPtr,
);
typedef _SendSignalDart = void Function(
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
);

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
  RustNetRinfRuntime._({
    required this.libraryPath,
    required DynamicLibrary library,
  }) : _library = library {
    _prepareIsolate =
        _library.lookupFunction<_PrepareIsolateNative, _PrepareIsolateDart>(
      'rinf_prepare_isolate_extern',
    );
    _startRustLogic = _library.lookupFunction<_VoidNative, _VoidDart>(
      'rinf_start_rust_logic_extern',
    );
    _stopRustLogic = _library.lookupFunction<_VoidNative, _VoidDart>(
      'rinf_stop_rust_logic_extern',
    );

    _rustSignalPort.listen(_onRustSignal);
    _prepareIsolate(NativeApi.postCObject, _rustSignalPort.sendPort.nativePort);
    _startRustLogic();
  }

  static RustNetRinfRuntime? _instance;

  static RustNetRinfRuntime shared({required String libraryPath}) {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }

    final runtime = RustNetRinfRuntime._(
      libraryPath: libraryPath,
      library: DynamicLibrary.open(libraryPath),
    );
    _instance = runtime;
    return runtime;
  }

  final String libraryPath;
  final DynamicLibrary _library;
  final ReceivePort _rustSignalPort = ReceivePort();
  final _signalStreamController =
      StreamController<RustNetRinfSignal>.broadcast();
  final _sendSignalFunctions = <String, _SendSignalDart>{};

  late final _PrepareIsolateDart _prepareIsolate;
  late final _VoidDart _startRustLogic;
  late final _VoidDart _stopRustLogic;

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

      final sender = _sendSignalFunctions.putIfAbsent(
        endpointSymbol,
        () => _library.lookupFunction<_SendSignalNative, _SendSignalDart>(
          endpointSymbol,
        ),
      );
      sender(
        messageMemory,
        messageBytes.length,
        binaryMemory,
        binary.length,
      );
    } finally {
      malloc.free(messageMemory);
      malloc.free(binaryMemory);
    }
  }

  void dispose() {
    _stopRustLogic();
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
