import 'package:rust_net/rust_net.dart' as rust_net;
import 'package:rust_net_core/rust_net_core.dart' as rust_net_core;
import 'package:test/test.dart';

void main() {
  test('re-exports the same RustNetRequest type as package:rust_net', () {
    expect(rust_net_core.RustNetRequest, same(rust_net.RustNetRequest));
  });

  test('re-exports the same RustNetResponse type as package:rust_net', () {
    expect(rust_net_core.RustNetResponse, same(rust_net.RustNetResponse));
  });

  test('re-exports the same HttpExecutor type as package:rust_net', () {
    expect(rust_net_core.HttpExecutor, same(rust_net.HttpExecutor));
  });
}
