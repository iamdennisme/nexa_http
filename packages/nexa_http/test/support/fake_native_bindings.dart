import 'dart:ffi';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

final class FakeNativeBindings implements NexaHttpBindings {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Pointer<NativeFunction<Void Function(Pointer<NexaHttpBinaryResult>)>>
  get nexaHttpBinaryResultFreeAddress => nullptr;

  @override
  Pointer<NativeFunction<Void Function(Pointer<Char>)>>
  get nexaHttpStringFreeAddress => nullptr;
}
