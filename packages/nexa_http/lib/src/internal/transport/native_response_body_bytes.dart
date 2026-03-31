import 'dart:collection';
import 'dart:ffi';

abstract interface class ClosableBodyBytes implements List<int> {
  void release();
}

List<int> adoptNativeResponseBodyBytes(
  List<int> bytes, {
  required void Function() release,
  NativeFinalizer? finalizer,
  Pointer<Void>? finalizerToken,
  int externalSize = 0,
}) {
  return _NativeResponseBodyBytes(
    bytes,
    release: release,
    finalizer: finalizer,
    finalizerToken: finalizerToken,
    externalSize: externalSize,
  );
}

final class _NativeResponseBodyBytes extends ListBase<int>
    implements ClosableBodyBytes, Finalizable {
  _NativeResponseBodyBytes(
    this._delegate, {
    required void Function() release,
    NativeFinalizer? finalizer,
    Pointer<Void>? finalizerToken,
    required int externalSize,
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

  final List<int> _delegate;
  final void Function() _release;
  final NativeFinalizer? _finalizer;
  final Object _detachToken = Object();
  bool _isReleased = false;

  @override
  int get length {
    _ensureOpen();
    return _delegate.length;
  }

  @override
  set length(int value) {
    throw UnsupportedError('Response body bytes are read-only.');
  }

  @override
  int operator [](int index) {
    _ensureOpen();
    return _delegate[index];
  }

  @override
  void operator []=(int index, int value) {
    throw UnsupportedError('Response body bytes are read-only.');
  }

  @override
  void release() {
    if (_isReleased) {
      return;
    }

    _isReleased = true;
    _finalizer?.detach(_detachToken);
    _release();
  }

  void _ensureOpen() {
    if (_isReleased) {
      throw StateError('Response body bytes have already been released.');
    }
  }
}
