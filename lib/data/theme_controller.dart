import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    try {
      final v = await _storage.read(key: _key);
      mode = ThemeMode.values.firstWhere(
        (m) => m.name == v,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: m.name);
    } catch (_) {}
  }
}

final ThemeController themeController = ThemeController();
