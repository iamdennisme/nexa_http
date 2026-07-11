import 'dart:ffi';
import 'dart:typed_data';

abstract interface class ResponseBodyOwner {
  Uint8List get view;

  bool get isNative;

  void release();
}

final class DartResponseBodyOwner implements ResponseBodyOwner {
  DartResponseBodyOwner(this._view);

  Uint8List? _view;

  @override
  bool get isNative => false;

  @override
  Uint8List get view {
    final view = _view;
    if (view == null) {
      throw StateError('Response body ownership has already been released.');
    }
    return view;
  }

  @override
  void release() {
    _view = null;
  }
}

final class NativeResponseBodyOwner
    implements ResponseBodyOwner, Finalizable {
  NativeResponseBodyOwner(
    this._view, {
    required void Function() release,
    NativeFinalizer? finalizer,
    Pointer<Void>? finalizerToken,
    int externalSize = 0,
  }) : _release = release,
       _finalizer = finalizer {
    if (finalizer != null && finalizerToken != null) {
      finalizer.attach(
        this,
        finalizerToken,
        detach: _detachToken,
        externalSize: externalSize,
      );
    }
  }

  Uint8List? _view;
  final void Function() _release;
  final NativeFinalizer? _finalizer;
  final Object _detachToken = Object();

  @override
  bool get isNative => true;

  @override
  Uint8List get view {
    final view = _view;
    if (view == null) {
      throw StateError('Response body ownership has already been released.');
    }
    return view;
  }

  @override
  void release() {
    if (_view == null) {
      return;
    }
    _view = null;
    _finalizer?.detach(_detachToken);
    _release();
  }
}
