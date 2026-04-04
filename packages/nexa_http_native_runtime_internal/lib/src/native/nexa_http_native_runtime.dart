import 'dart:ffi';

abstract interface class NexaHttpNativeLibraryStrategy {
  DynamicLibrary open();
}

typedef NexaHttpNativeRuntime = NexaHttpNativeLibraryStrategy;
