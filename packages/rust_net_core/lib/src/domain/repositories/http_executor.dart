import '../entities/rust_net_request.dart';
import '../entities/rust_net_response.dart';

abstract interface class HttpExecutor {
  Future<RustNetResponse> execute(RustNetRequest request);

  Future<void> close();
}
