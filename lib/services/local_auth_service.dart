import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальное хранилище зарегистрированных пользователей (SharedPreferences, не сервер).
class LocalAuthService {
  LocalAuthService._();
  static const _prefsKey = 'chess_app_local_users_v1';
  static const _pepper = 'chess_app_auth_v1';

  static String _hashPassword(String username, String password) {
    final bytes = utf8.encode('$_pepper|${username.trim().toLowerCase()}|$password');
    return sha256.convert(bytes).toString();
  }

  static Future<Map<String, String>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveUsers(Map<String, String> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(users));
  }

  /// Регистрация: логин не должен быть занят.
  static Future<String?> register(String username, String password) async {
    final name = username.trim();
    if (name.isEmpty) return 'Введите логин';
    final users = await _loadUsers();
    final key = name.toLowerCase();
    if (users.containsKey(key)) return 'Такой пользователь уже зарегистрирован';
    users[key] = _hashPassword(name, password);
    await _saveUsers(users);
    return null;
  }

  /// Вход: проверка логина и пароля.
  static Future<String?> login(String username, String password) async {
    final name = username.trim();
    if (name.isEmpty) return 'Введите логин';
    final users = await _loadUsers();
    final key = name.toLowerCase();
    final stored = users[key];
    if (stored == null) {
      return 'Пользователь не найден. Сначала зарегистрируйтесь.';
    }
    if (stored != _hashPassword(name, password)) {
      return 'Неверный пароль';
    }
    return null;
  }
}
