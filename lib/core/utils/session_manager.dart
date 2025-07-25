import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SessionManager {
  static const _userKey = 'user_data';

  // ✅ Save user data
  Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(userData);
    print('Saving user to session: $userData');
    await prefs.setString(_userKey, jsonString);
  }

  // ✅ Load user data
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userKey);
    print('Loading user from session: $jsonString');
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  // ✅ Clear user data (logout)
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    print('Clearing user from session');
    await prefs.remove(_userKey);
  }
}

// ✅ Check if user session is still valid
Future<bool> isLoggedIn() async {
  final user = await SessionManager().getUser();
  if (user == null) return false;

  try {
    final response = await http.post(
      Uri.parse(
        "https://10.0.2.2/appinternal/api/check_session.php",
      ), // <-- update to real URL
      body: {
        "kup_id": user["kup_id"].toString(),
        "pos_id": user["pos_id"].toString(),
        "hash1": user["hash1"],
        "hash2": user["hash2"],
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["success"] == 1;
    }
  } catch (e) {
    print('Session check failed: $e');
  }

  return false;
}

// ✅ Call this to log out and redirect to login
void logoutAndRedirect(BuildContext context) async {
  await SessionManager().clearUser();
  Navigator.pushReplacementNamed(context, "/login");
}
