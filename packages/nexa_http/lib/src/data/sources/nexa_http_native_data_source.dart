import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';
import '../../internal/transport/transport_response.dart';

abstract interface class NexaHttpNativeDataSource {
  int createClient(NativeHttpClientConfigDto config);

  Future<TransportResponse> execute(int clientId, NativeHttpRequestDto request);

  void closeClient(int clientId);
}
