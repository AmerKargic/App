import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _userKey = 'user_data';

  // Spremi user podatke kao JSON string
  Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(userData);
    print('Saving user to session: $userData');
    await prefs.setString(_userKey, jsonString);
  }

  // Učitaj user podatke i dekodiraj ih
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userKey);
    print('Loading user from session: $jsonString');
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  // Obriši user podatke (logout)
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    print('Clearing user from session');
    await prefs.remove(_userKey);
  }
}
