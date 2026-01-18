import 'dart:io';

import 'package:flutter/material.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  runApp(const GatekeepExampleApp());
}

class GatekeepExampleApp extends StatelessWidget {
  const GatekeepExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gatekeep Example',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    home: const GatekeepHomePage(),
  );
}

class GatekeepHomePage extends StatefulWidget {
  const GatekeepHomePage({super.key});

  @override
  State<GatekeepHomePage> createState() => _GatekeepHomePageState();
}

class _GatekeepHomePageState extends State<GatekeepHomePage> {
  // Get the correct base URL based on platform
  // Android emulator uses 10.0.2.2 to access host machine's localhost
  static String _getDefaultBaseUrl() {
    if (Platform.isAndroid) {
      // Check if running in emulator (you can enhance this check)
      return 'http://10.0.2.2:8080';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'http://localhost:8080';
    } else {
      // Desktop/web
      return 'http://localhost:8080';
    }
  }

  final _baseUrlController = TextEditingController(
    text: _getDefaultBaseUrl(), // Default backend URL (platform-aware)
  );

  final _eventIdController = TextEditingController(
    text: 'test-event', // Default event ID
  );

  final _userIdController = TextEditingController();

  QueueClientInterface? _queueClient;
  bool _isInitialized = false;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _eventIdController.dispose();
    _userIdController.dispose();
    _queueClient?.dispose();
    super.dispose();
  }

  void _initializeClient() {
    if (_baseUrlController.text.isEmpty || _eventIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter base URL and event ID')),
      );
      return;
    }

    // Generate a device ID (in production, use a persistent device identifier)
    final deviceId = Platform.isAndroid
        ? 'android-device-${DateTime.now().millisecondsSinceEpoch}'
        : 'ios-device-${DateTime.now().millisecondsSinceEpoch}';

    // Dispose previous client if exists
    _queueClient?.dispose();

    // Create new queue client
    _queueClient = QueueClientFactory.create(
      baseUrl: _baseUrlController.text.trim(),
      deviceId: deviceId,
      userId: _userIdController.text.trim().isEmpty
          ? null
          : _userIdController.text.trim(),
      debug: true, // Enable debug logging
    );

    setState(() => _isInitialized = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gatekeep client initialized successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _joinQueue() {
    if (!_isInitialized || _queueClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please initialize the client first')),
      );
      return;
    }

    if (_eventIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an event ID')));
      return;
    }

    // Navigate to waiting room screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WaitingRoomScreen(
          queueClient: _queueClient!,
          eventId: _eventIdController.text.trim(),
          onAdmitted: (token) {
            // Handle admission
            Navigator.of(context).pop();
            _showAdmissionDialog(token);
          },
          onError: (error) {
            // Handle error
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${error.message}'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onCancel: Navigator.of(context).pop,
        ),
      ),
    );
  }

  void _showAdmissionDialog(AdmissionToken token) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Admitted!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event ID: ${token.eventId}'),
          const SizedBox(height: 8),
          Text('Token: ${token.token.substring(0, 20)}...'),
          const SizedBox(height: 8),
          Text('Expires: ${token.expiresAt}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: FocusScope.of(context).unfocus,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Gatekeep Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: Platform.isAndroid
                    ? 'http://10.0.2.2:8080 (Android emulator)'
                    : 'http://localhost:8080',
                helperText: Platform.isAndroid
                    ? 'Use 10.0.2.2 for Android emulator, or your machine\'s IP for physical device'
                    : null,
                border: const OutlineInputBorder(),
              ),
              enabled: !_isInitialized,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventIdController,
              decoration: const InputDecoration(
                labelText: 'Event ID',
                hintText: 'test-event',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID (Optional)',
                hintText: 'user-123',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isInitialized ? null : _initializeClient,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Initialize Client'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isInitialized ? _joinQueue : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Join Queue'),
            ),
            if (_isInitialized) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Client initialized and ready',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              Platform.isAndroid
                  ? '1. Enter your backend base URL (use http://10.0.2.2:8080 for emulator)\n'
                        '2. Enter an event ID to join\n'
                        '3. Optionally enter a user ID\n'
                        '4. Click "Initialize Client" to set up the Gatekeep SDK\n'
                        '5. Click "Join Queue" to enter the waiting room'
                  : '1. Enter your backend base URL (e.g., http://localhost:8080)\n'
                        '2. Enter an event ID to join\n'
                        '3. Optionally enter a user ID\n'
                        '4. Click "Initialize Client" to set up the Gatekeep SDK\n'
                        '5. Click "Join Queue" to enter the waiting room',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
}
