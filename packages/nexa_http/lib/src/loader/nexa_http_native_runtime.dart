import 'dart:ffi';

abstract interface class NexaHttpNativeRuntime {
  String? get binaryExecutionLibraryPath;

  DynamicLibrary open();
}
