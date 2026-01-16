import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'storage_interface.dart';

/// Secure storage implementation using flutter_secure_storage
class SecureStorage implements StorageInterface {
  SecureStorage({FlutterSecureStorage? storage, String prefix = 'gatekeep_'})
    : _storage = storage ?? const FlutterSecureStorage(),
      _prefix = prefix;

  final FlutterSecureStorage _storage;
  final String _prefix;

  String _getKey(String key) => '$_prefix$key';

  @override
  Future<String?> read(String key) => _storage.read(key: _getKey(key));

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: _getKey(key), value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: _getKey(key));

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<bool> containsKey(String key) =>
      _storage.containsKey(key: _getKey(key));

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}
