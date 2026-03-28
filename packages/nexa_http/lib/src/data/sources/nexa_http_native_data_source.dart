import '../../api/api.dart';

import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';

abstract interface class NexaHttpNativeDataSource {
  int createClient(NativeHttpClientConfigDto config);

  /// Buffers the native streamed head/chunk response protocol into a single
  /// [NexaHttpResponse] until Task 3 switches the public contract to streaming.
  Future<NexaHttpResponse> execute(int clientId, NativeHttpRequestDto request);

  void closeClient(int clientId);
}
