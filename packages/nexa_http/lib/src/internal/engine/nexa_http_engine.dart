import '../../api/request.dart';
import '../../api/response.dart';
import '../config/client_options.dart';

abstract interface class NexaHttpEngine {
  Future<Response> execute({
    required ClientOptions clientConfig,
    required Request request,
  });
}
