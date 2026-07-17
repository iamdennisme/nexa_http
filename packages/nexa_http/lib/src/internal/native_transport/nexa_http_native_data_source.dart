import 'native_http_client_config_dto.dart';
import 'native_http_request_dto.dart';
import 'transport_response.dart';

typedef CancelNativeRequest = void Function();
typedef RegisterCancelRequest =
    void Function(CancelNativeRequest cancelRequest);

abstract interface class NexaHttpNativeDataSource {
  int createClient(NativeHttpClientConfigDto config);

  Future<TransportResponse> execute(
    int clientId,
    NativeHttpRequestDto request, {
    RegisterCancelRequest? onCancelReady,
  });

  void closeClient(int clientId);

  void dispose();
}
