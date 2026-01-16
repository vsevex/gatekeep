# Gatekeep Flutter SDK

[![pub package](https://img.shields.io/pub/v/gatekeep.svg)](https://pub.dev/packages/gatekeep)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready Flutter SDK for integrating with the Gatekeep virtual waiting room system. Manage user queues, track positions, and handle admission tokens seamlessly in your Flutter applications.

## Overview

Gatekeep is a distributed admission control system designed for managing access to limited resources under extreme load. This Flutter SDK provides a simple, robust interface for:

- **Queue Management**: Join queues, track positions, and monitor wait times
- **Token Handling**: Secure admission token management with automatic persistence
- **State Management**: Built-in state machine for queue lifecycle
- **Resilience**: Automatic retries, exponential backoff, and network failure handling
- **UI Components**: Pre-built waiting room screens and widgets

### Use Cases

- **Ticket Sales**: High-demand event ticket releases
- **Product Launches**: Limited edition product drops
- **Beta Access**: Controlled rollout of new features
- **API Throttling**: Fair access to rate-limited APIs
- **Resource Protection**: Any scenario with limited capacity and high demand

## Features

- ✅ **Idempotent Operations**: Safe retries without duplicate queue entries
- ✅ **Automatic Heartbeats**: Keep your position alive with configurable heartbeat intervals
- ✅ **Token Persistence**: Secure storage of admission tokens for app resume scenarios
- ✅ **Position Polling**: Real-time queue position updates with exponential backoff
- ✅ **State Management**: Built-in state machine (Joining → Waiting → Admitted → Expired/Error)
- ✅ **Network Resilience**: Automatic retry logic with exponential backoff
- ✅ **UI Components**: Pre-built waiting room screens and widgets
- ✅ **Offline Support**: Cache queue status and restore tokens on app restart
- ✅ **Priority Buckets**: Support for presale, partner, and general access tiers

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  gatekeep: ^0.1.0
```

**Note:** If using this package locally or with a different name, update the import statements accordingly. The package name in `pubspec.yaml` should match your package identifier.

Then run:

```bash
flutter pub get
```

### Additional Dependencies

For secure token storage, you'll need:

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

For HTTP requests (if not using the built-in client):

```yaml
dependencies:
  http: ^1.1.0
```

## Quick Start

### 1. Initialize the Client

```dart
import 'package:gatekeep_flutter/gatekeep.dart';
import 'package:device_info_plus/device_info_plus.dart';

Future<void> initializeGatekeep() async {
  final deviceInfo = DeviceInfoPlugin();
  final deviceId = await _getDeviceId(deviceInfo);

  await QueueClient.initialize(
    baseUrl: 'https://gatekeep.example.com/v1',
    deviceId: deviceId,
    userId: currentUser?.id, // Optional
    headers: {
      'X-Custom-Header': 'value',
    },
  );
}

Future<String> _getDeviceId(DeviceInfoPlugin deviceInfo) async {
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id;
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.identifierForVendor ?? 'unknown';
  }
  return 'unknown';
}
```

### 2. Join a Queue

```dart
try {
  final status = await QueueClient.instance.joinEvent(
    eventId: 'evt_123',
    priorityBucket: 'general', // Optional: 'presale', 'partner', 'general'
  );

  print('Joined queue: ${status.queueId}');
  print('Position: ${status.position}');
  print('Estimated wait: ${status.estimatedWaitSeconds} seconds');
} on QueueException catch (e) {
  if (e.statusCode == 409) {
    // Already in queue, get current position
    print('Already in queue: ${e.message}');
  } else {
    print('Error joining queue: ${e.message}');
  }
}
```

### 3. Monitor Queue Status

```dart
// Listen for status updates
final subscription = QueueClient.instance.listenStatus(
  queueId: status.queueId,
  pollInterval: const Duration(seconds: 5),
).listen(
  (status) {
    switch (status.state) {
      case QueueState.waiting:
        updateUI(status.position, status.estimatedWaitSeconds);
      case QueueState.admitted:
        handleAdmission(status.admissionToken!);
      case QueueState.expired:
        showExpiredMessage();
      case QueueState.error:
        showErrorMessage(status.error);
      default:
        break;
    }
  },
  onError: (error) {
    print('Status stream error: $error');
  },
);

// Don't forget to cancel the subscription
subscription.cancel();
```

### 4. Send Heartbeats

```dart
// Keep your position alive
Timer.periodic(const Duration(seconds: 30), (timer) async {
  try {
    await QueueClient.instance.sendHeartbeat(
      queueId: status.queueId,
    );
  } catch (e) {
    print('Heartbeat failed: $e');
    // Consider retrying or handling the error
  }
});
```

### 5. Handle Admission

```dart
void handleAdmission(AdmissionToken token) async {
  // Save token securely
  await token.save();

  // Verify token is valid
  if (!token.isValid()) {
    print('Token expired');
    return;
  }

  // Navigate to protected resource
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ProtectedResourceScreen(token: token),
    ),
  );
}
```

### 6. Restore Token on App Resume

```dart
Future<void> restoreAdmissionToken(String eventId) async {
  final token = await GatekeepClient.instance.restoreToken(
    eventId: eventId,
  );

  if (token != null && token.isValid()) {
    // User was previously admitted, navigate directly
    navigateToProtectedResource(token);
  } else {
    // User needs to join queue again
    joinQueue(eventId);
  }
}
```

## API Reference

### QueueClient

The main client for interacting with the Gatekeep service.

#### Methods

##### `initialize`

Initialize the queue client with configuration.

```dart
static Future<void> initialize({
  required String baseUrl,
  required String deviceId,
  String? userId,
  Map<String, String>? headers,
  Duration? timeout,
  int? maxRetries,
})
```

**Parameters:**

- `baseUrl` (required): The base URL of the Gatekeep API (e.g., `https://gatekeep.example.com/v1`)
- `deviceId` (required): Unique device identifier (UUID recommended)
- `userId` (optional): User identifier if available
- `headers` (optional): Additional HTTP headers to include in requests
- `timeout` (optional): Request timeout duration (default: 30 seconds)
- `maxRetries` (optional): Maximum number of retry attempts (default: 3)

**Throws:**

- `QueueException`: If initialization fails

##### `joinEvent`

Join the queue for a specific event.

```dart
Future<QueueStatus> joinEvent({
  required String eventId,
  String? priorityBucket,
  Map<String, dynamic>? metadata,
})
```

**Parameters:**

- `eventId` (required): The event identifier
- `priorityBucket` (optional): Priority tier (`'presale'`, `'partner'`, `'general'`)
- `metadata` (optional): Custom key-value pairs for analytics

**Returns:**

- `QueueStatus`: Initial queue status with position and estimated wait time

**Throws:**

- `QueueException`: If join fails (check `statusCode` for specific errors)
  - `400`: Invalid event_id or missing device_id
  - `409`: Already in queue (returns current position)
  - `429`: Rate limit exceeded
  - `503`: Service unavailable

**Idempotency:**

- Same `device_id` + `event_id` returns existing position
- Safe to retry on network failures

##### `listenStatus`

Listen to queue status updates with automatic polling.

```dart
Stream<QueueStatus> listenStatus({
  required String queueId,
  Duration pollInterval = const Duration(seconds: 5),
  bool autoHeartbeat = true,
  Duration heartbeatInterval = const Duration(seconds: 30),
})
```

**Parameters:**

- `queueId` (required): The queue identifier from `joinEvent`
- `pollInterval` (optional): How often to poll for updates (default: 5 seconds)
- `autoHeartbeat` (optional): Automatically send heartbeats (default: true)
- `heartbeatInterval` (optional): Heartbeat interval (default: 30 seconds)

**Returns:**

- `Stream<QueueStatus>`: Stream of queue status updates

**Behavior:**

- Uses exponential backoff on errors
- Automatically sends heartbeats if `autoHeartbeat` is true
- Stops polling when admitted or expired
- Handles network failures gracefully

##### `sendHeartbeat`

Keep your queue position alive.

```dart
Future<QueueStatus> sendHeartbeat({
  required String queueId,
})
```

**Parameters:**

- `queueId` (required): The queue identifier

**Returns:**

- `QueueStatus`: Updated queue status

**Throws:**

- `QueueException`: If heartbeat fails
  - `404`: Queue ID not found (expired or invalid)
  - `410`: Already admitted or expired

**Behavior:**

- Extends TTL on queue entry
- Returns updated position
- If admitted, returns admission token

##### `restoreToken`

Restore a previously saved admission token.

```dart
Future<AdmissionToken?> restoreToken({
  required String eventId,
})
```

**Parameters:**

- `eventId` (required): The event identifier

**Returns:**

- `AdmissionToken?`: The saved token if found and valid, `null` otherwise

**Behavior:**

- Checks secure storage for saved token
- Validates token expiry
- Returns `null` if token not found or expired

### QueueStatus

Represents the current state of a queue entry.

```dart
class QueueStatus {
  final String queueId;
  final int position;
  final int estimatedWaitSeconds;
  final QueueState state;
  final DateTime? enqueuedAt;
  final DateTime? lastHeartbeat;
  final AdmissionToken? admissionToken;
  final String? error;
}
```

**Properties:**

- `queueId`: Unique identifier for this queue entry
- `position`: Current position in queue (0 = front of queue)
- `estimatedWaitSeconds`: Estimated wait time in seconds
- `state`: Current state (see `QueueState` enum)
- `enqueuedAt`: When the user joined the queue
- `lastHeartbeat`: Last successful heartbeat timestamp
- `admissionToken`: Admission token (null until admitted)
- `error`: Error message if state is `error`

### QueueState

Enum representing the possible states of a queue entry.

```dart
enum QueueState {
  joining,    // Initial join request in progress
  waiting,    // In queue, waiting for admission
  admitted,   // Admitted, token available
  expired,    // Token expired or queue entry expired
  error,      // Error occurred
}
```

### AdmissionToken

Represents an admission token for accessing protected resources.

```dart
class AdmissionToken {
  final String token;
  final String eventId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  // Persist token to secure storage
  Future<void> save();

  // Check if token is still valid
  bool isValid();

  // Get remaining validity duration
  Duration remainingValidity();
}
```

**Methods:**

- `save()`: Persists token to secure storage (flutter_secure_storage)
- `isValid()`: Checks if token is still valid (not expired)
- `remainingValidity()`: Returns remaining time until expiry

**Usage:**

```dart
final token = status.admissionToken!;

// Save for app resume
await token.save();

// Check validity
if (token.isValid()) {
  // Use token
  makeAuthenticatedRequest(token.token);
} else {
  // Token expired, rejoin queue
  rejoinQueue();
}

// Show countdown
final remaining = token.remainingValidity();
print('Token expires in: ${remaining.inMinutes} minutes');
```

### QueueException

Exception thrown by queue operations.

```dart
class QueueException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? details;
}
```

**Properties:**

- `message`: Human-readable error message
- `statusCode`: HTTP status code (if applicable)
- `errorCode`: Machine-readable error code
- `details`: Additional error details

**Common Status Codes:**

- `400`: Bad Request (invalid parameters)
- `404`: Not Found (queue ID not found)
- `409`: Conflict (already in queue)
- `410`: Gone (admitted but expired)
- `429`: Too Many Requests (rate limited)
- `503`: Service Unavailable (service down)

## UI Components

### WaitingRoomScreen

A pre-built screen for displaying queue status.

```dart
WaitingRoomScreen(
  queueId: status.queueId,
  eventId: 'evt_123',
  onAdmitted: (token) =>
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProtectedResourceScreen(token: token),
      ),
    ),
  onError: (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${error.message}')),
    );
  },
)
```

### QueuePositionWidget

A widget for displaying queue position.

```dart
QueuePositionWidget(
  position: status.position,
  estimatedWaitSeconds: status.estimatedWaitSeconds,
  showProgress: true,
)
```

### AdmissionTokenWidget

A widget for displaying admission token status.

```dart
AdmissionTokenWidget(
  token: token,
  onExpired: () {
    // Handle token expiry
  },
)
```

## Advanced Usage

### Custom Retry Logic

```dart
Future<QueueStatus> joinWithCustomRetry(String eventId) async {
  int attempts = 0;
  const maxAttempts = 5;

  while (attempts < maxAttempts) {
    try {
      return await QueueClient.instance.joinEvent(eventId: eventId);
    } on QueueException catch (e) {
      if (e.statusCode == 503) {
        // Service unavailable, retry with exponential backoff
        attempts++;
        if (attempts >= maxAttempts) rethrow;

        final delay = Duration(seconds: pow(2, attempts).toInt());
        await Future.delayed(delay);
        continue;
      }
      rethrow;
    }
  }

  throw Exception('Max retry attempts reached');
}
```

### Manual Polling

```dart
Future<void> pollManually(String queueId) async {
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      final status = await QueueClient.instance.getStatus(queueId: queueId);

      if (status.state == QueueState.admitted) {
        timer.cancel();
        handleAdmission(status.admissionToken!);
      } else if (status.state == QueueState.expired) {
        timer.cancel();
        handleExpired();
      }
    } catch (e) {
      print('Poll error: $e');
      // Continue polling on error
    }
  });
}
```

### Multiple Events

```dart
Future<Map<String, QueueStatus>> joinMultipleEvents(
  List<String> eventIds,
) async {
  final results = <String, QueueStatus>{};

  await Future.wait(
    eventIds.map((eventId) async {
      try {
        final status = await QueueClient.instance.joinEvent(
          eventId: eventId,
        );
        results[eventId] = status;
      } catch (e) {
        print('Failed to join $eventId: $e');
      }
    }),
  );

  return results;
}
```

## Error Handling

### Network Errors

```dart
try {
  final status = await QueueClient.instance.joinEvent(eventId: eventId);
} on SocketException catch (e) {
  // Network connectivity issue
  showOfflineMessage();
} on TimeoutException catch (e) {
  // Request timeout
  showTimeoutMessage();
} on QueueException catch (e) {
  // API error
  handleApiError(e);
}
```

### Rate Limiting

```dart
try {
  final status = await QueueClient.instance.joinEvent(eventId: eventId);
} on QueueException catch (e) {
  if (e.statusCode == 429) {
    // Rate limited
    final retryAfter = e.details?['retry_after'] as int?;
    if (retryAfter != null) {
      await Future.delayed(Duration(seconds: retryAfter));
      // Retry join
    }
  }
}
```

### Token Expiry

```dart
void checkTokenValidity(AdmissionToken token) {
  if (!token.isValid()) {
    // Token expired
    showExpiredMessage();
    // Optionally rejoin queue
    rejoinQueue();
  } else {
    final remaining = token.remainingValidity();
    if (remaining.inMinutes < 2) {
      // Token expiring soon, warn user
      showExpiringSoonWarning();
    }
  }
}
```

## Best Practices

### 1. Device ID Generation

Use a stable, unique device identifier:

```dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_id');

  if (deviceId == null) {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? Uuid().v4();
    } else {
      deviceId = Uuid().v4();
    }

    await prefs.setString('device_id', deviceId);
  }

  return deviceId;
}
```

### 2. Token Storage

Always save admission tokens securely:

```dart
Future<void> handleAdmission(AdmissionToken token) async {
  // Save immediately
  await token.save();

  // Also save to app state for quick access
  await saveTokenToAppState(token);

  // Navigate to protected resource
  navigateToProtectedResource(token);
}
```

### 3. App Resume Handling

Restore queue state or token on app resume:

```dart
class MyApp extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _restoreQueueState();
  }

  Future<void> _restoreQueueState() async {
    // Check for saved token first
    final token = await QueueClient.instance.restoreToken(
      eventId: currentEventId,
    );

    if (token != null && token.isValid()) {
      // User was admitted, navigate directly
      navigateToProtectedResource(token);
    } else {
      // Check for saved queue ID
      final queueId = await getSavedQueueId();
      if (queueId != null) {
        // Resume queue monitoring
        resumeQueueMonitoring(queueId);
      }
    }
  }
}
```

### 4. Heartbeat Management

Send heartbeats regularly but not too frequently:

```dart
class QueueManager {
  Timer? _heartbeatTimer;

  void startHeartbeat(String queueId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          await GatekeepClient.instance.sendHeartbeat(queueId: queueId);
        } catch (e) {
          print('Heartbeat failed: $e');
          // Consider exponential backoff for heartbeat failures
        }
      },
    );
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
```

### 5. Error Recovery

Implement robust error recovery:

```dart
Future<QueueStatus> joinWithRecovery(String eventId) async {
  try {
    return await GatekeepClient.instance.joinEvent(eventId: eventId);
  } catch (e) {
    if (e is QueueException && e.statusCode == 409) {
      // Already in queue, get status
      final queueId = await getSavedQueueId();
      if (queueId != null) {
        return await GatekeepClient.instance.getStatus(queueId: queueId);
      }
    }
    rethrow;
  }
}
```

## Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gatekeep_flutter/gatekeep_flutter.dart';

void main() {
  group('GatekeepClient', () {
    test('initializes correctly', () async {
      await GatekeepClient.initialize(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      expect(GatekeepClient.instance, isNotNull);
    });

    test('handles join errors', () async {
      // Mock network error
      // Test error handling
    });
  });
}
```

### Integration Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('queue flow', (WidgetTester tester) async {
    // Test full queue flow
    // Join → Wait → Admitted
  });
}
```

## Troubleshooting

### Common Issues

#### "Queue ID not found" (404)

**Cause:** Queue entry expired or invalid queue ID.

**Solution:**

- Check if queue entry TTL expired (default: 1 hour)
- Ensure heartbeats are being sent regularly
- Rejoin queue if entry expired

#### "Token expired" (410)

**Cause:** Admission token expired before use.

**Solution:**

- Tokens have short TTL (default: 5 minutes)
- Use token immediately after admission
- Check token validity before making requests

#### "Rate limit exceeded" (429)

**Cause:** Too many requests in short time.

**Solution:**

- Respect `Retry-After` header
- Implement exponential backoff
- Reduce polling frequency

#### Network connectivity issues

**Cause:** Device offline or service unavailable.

**Solution:**

- Implement offline detection
- Cache last known status
- Retry with exponential backoff
- Show appropriate UI feedback

## Platform Support

- ✅ iOS 12.0+
- ✅ Android API 21+
- ✅ Web (with limitations)
- ✅ macOS 10.14+
- ✅ Windows 10+
- ✅ Linux

## Dependencies

- `flutter_secure_storage`: Secure token storage
- `http`: HTTP client (optional, can use custom client)
- `device_info_plus`: Device ID generation (recommended)

## Contributing

Contributions are welcome! Please read our contributing guidelines first.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or contributions:

- **GitHub Issues**: [Create an issue](https://github.com/your-org/gatekeep-flutter/issues)
- **Documentation**: [Full Documentation](https://gatekeep.example.com/docs)
- **Email**: support@gatekeep.example.com

## Related Packages

- [gatekeep-backend](https://github.com/your-org/gatekeep-backend): Go backend service
- [gatekeep-web](https://github.com/your-org/gatekeep-web): Web SDK

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.

---

**Made with ❤️ for managing high-demand resources**
