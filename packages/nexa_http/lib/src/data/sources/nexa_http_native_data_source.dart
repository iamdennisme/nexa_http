import '../../api/api.dart';

import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';

abstract interface class NexaHttpNativeDataSource {
  int createClient(NativeHttpClientConfigDto config);

  Future<NexaHttpResponse> execute(int clientId, NativeHttpRequestDto request);

  void closeClient(int clientId);
}
