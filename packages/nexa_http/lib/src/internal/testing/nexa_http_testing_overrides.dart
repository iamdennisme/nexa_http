import '../../native_bridge/nexa_http_native_data_source_factory.dart';

final class NexaHttpTestingOverrides {
  NexaHttpTestingOverrides._();

  static NexaHttpNativeDataSourceFactory? _nativeDataSourceFactory;

  static NexaHttpNativeDataSourceFactory? get nativeDataSourceFactory =>
      _nativeDataSourceFactory;

  static void installNativeDataSourceFactory(
    NexaHttpNativeDataSourceFactory factory,
  ) {
    _nativeDataSourceFactory = factory;
  }

  static void reset() {
    _nativeDataSourceFactory = null;
  }
}
