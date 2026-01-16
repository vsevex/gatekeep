import '../config/gatekeep_config.dart';
import '../config/gatekeep_initializer.dart';
import 'queue_client.dart';
import 'queue_client_interface.dart';

class QueueClientFactory {
  QueueClientFactory._();

  static QueueClientInterface create({
    required String baseUrl,
    required String deviceId,
    String? userId,
    Map<String, String>? headers,
    bool debug = false,
  }) {
    final config = GatekeepInitializer.initialize(
      baseUrl: baseUrl,
      deviceId: deviceId,
      userId: userId,
      headers: headers,
      debug: debug,
    );

    return QueueClient(config);
  }

  /// Create a QueueClient with full customization
  QueueClientInterface createWith(GatekeepConfig config) => QueueClient(config);
}
