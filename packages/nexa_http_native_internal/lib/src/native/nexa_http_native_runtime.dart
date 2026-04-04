import 'dart:ffi';

abstract interface class NexaHttpNativeRuntime {
  DynamicLibrary open();
}
