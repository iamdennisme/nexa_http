@DefaultAsset('package:rust_net/src/native/rust_net_native_ffi.dart')
library;

import 'dart:ffi';

typedef PostCObjectNative = Int8 Function(Int64, Pointer<Dart_CObject>);

@Native<Uint64 Function(Pointer<Char>)>(symbol: 'rust_net_client_create')
external int rustNetClientCreate(Pointer<Char> configJson);

@Native<Void Function(Uint64)>(symbol: 'rust_net_client_close')
external void rustNetClientClose(int clientId);

@Native<
    Void Function(
      Pointer<NativeFunction<PostCObjectNative>>,
      Int64,
    )>(symbol: 'rinf_prepare_isolate_extern')
external void rinfPrepareIsolate(
  Pointer<NativeFunction<PostCObjectNative>> postCObject,
  int nativePort,
);

@Native<Void Function()>(symbol: 'rinf_start_rust_logic_extern')
external void rinfStartRustLogic();

@Native<Void Function()>(symbol: 'rinf_stop_rust_logic_extern')
external void rinfStopRustLogic();

@Native<
    Void Function(
      Pointer<Uint8>,
      UintPtr,
      Pointer<Uint8>,
      UintPtr,
    )>(symbol: 'rinf_send_dart_signal_rust_net_execute_request')
external void rinfSendRustNetExecuteRequest(
  Pointer<Uint8> messageBytes,
  int messageLength,
  Pointer<Uint8> binaryBytes,
  int binaryLength,
);
