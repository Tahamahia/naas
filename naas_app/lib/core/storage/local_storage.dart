import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> setThemeMode(String mode) =>
      _storage.write(key: 'theme_mode', value: mode);

  Future<String?> getThemeMode() =>
      _storage.read(key: 'theme_mode');

  Future<void> setLocale(String locale) =>
      _storage.write(key: 'locale', value: locale);

  Future<String?> getLocale() =>
      _storage.read(key: 'locale');

  Future<void> setUserRole(String role) =>
      _storage.write(key: 'user_role', value: role);

  Future<String?> getUserRole() =>
      _storage.read(key: 'user_role');

  Future<void> clearAll() => _storage.deleteAll();
}
