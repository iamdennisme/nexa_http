import 'package:rust_net_core/rust_net_core.dart';

import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';

abstract interface class RustNetNativeDataSource {
  int createClient(NativeHttpClientConfigDto config);

  Future<RustNetResponse> execute(int clientId, NativeHttpRequestDto request);

  void closeClient(int clientId);
}
