import 'dart:ffi';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

void main() {
  setUp(resetNexaHttpNativeBindingsForTesting);

  test('same asset identity registration is idempotent and lazy once', () {
    var createCount = 0;
    final factory = NexaHttpNativeBindingsFactory(
      assetId: 'package:carrier/src/native/nexa_http_native_ffi.dart',
      create: () {
        createCount += 1;
        return _FakeBindings();
      },
    );

    registerNexaHttpNativeBindings(factory);
    registerNexaHttpNativeBindings(factory);

    expect(
      resolveNexaHttpNativeBindings(),
      same(resolveNexaHttpNativeBindings()),
    );
    expect(createCount, 1);
  });

  test('different asset identity registration fails immediately', () {
    registerNexaHttpNativeBindings(
      NexaHttpNativeBindingsFactory(
        assetId: 'package:first/src/native/nexa_http_native_ffi.dart',
        create: _FakeBindings.new,
      ),
    );

    expect(
      () => registerNexaHttpNativeBindings(
        NexaHttpNativeBindingsFactory(
          assetId: 'package:second/src/native/nexa_http_native_ffi.dart',
          create: _FakeBindings.new,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('package:first'), contains('package:second')),
        ),
      ),
    );
  });
}

final class _FakeBindings implements NexaHttpBindings {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Pointer<NativeFunction<Void Function(Pointer<NexaHttpBinaryResult>)>>
  get nexaHttpBinaryResultFreeAddress => nullptr;

  @override
  Pointer<NativeFunction<Void Function(Pointer<Char>)>>
  get nexaHttpStringFreeAddress => nullptr;
}
