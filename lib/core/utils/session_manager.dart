import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';

class SessionManager {
  static const _userKey = 'user_data';

  // ✅ Save user data
  Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(userData);
    print('Saving user to session: $userData');
    await prefs.setString(_userKey, jsonString);
  }

  Future<Map<String, dynamic>?> getRealtimeStats() async {
    final user = await getUser();
    if (user == null) return null;

    try {
      final requestData = {
        'kup_id': user['kup_id'].toString(),
        'hash1': user['hash1'],
        'hash2': user['hash2'],
      };

      final response = await http.post(
        Uri.parse(
          //'https://www.digitalis.ba/webshop/appinternal/api/analytics/realtime_stats.php',
          'http://10.0.2.2/webshop/appinternal/api/analytics/realtime_stats.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('Analytics response: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == 1) {
          return result;
        }
      }
    } catch (e) {
      print('Error getting analytics: $e');
    }
    return null;
  }

  // ✅ Load user data
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userKey);
    print('Loading user from session: $jsonString');

    if (jsonString == null) return null;

    try {
      // 🔥 PRVO UČITAJ LOKALNE PODATKE
      final localUser = jsonDecode(jsonString);

      // 🔥 ZATIM PROVJERI NA SERVERU
      final response = await http.post(
        Uri.parse("http://10.0.2.2/webshop/appinternal/api/check_sesion.php"),
        // Uri.parse(
        //   "https://www.digitalis.ba/webshop/appinternal/api/check_sesion.php",
        // ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "kup_id": localUser["kup_id"].toString(),
          "pos_id": localUser["pos_id"].toString(),
          "hash1": localUser["hash1"],
          "hash2": localUser["hash2"],
        }),
      );

      print('🔍 getUser server check: ${response.body}');

      if (response.statusCode == 200) {
        final serverResponse = jsonDecode(response.body);

        // 🔥 AKO SERVER KAŽE force_logout
        if (serverResponse["force_logout"] == true) {
          print(
            '🔥 getUser: Server requested logout - ${serverResponse["message"]}',
          );
          Restart.restartApp(); // Restart app to clear session
          await clearUser(); // Očisti lokalne podatke
          return null; // Vrati null = user nije logiran
        }

        // 🔥 AKO JE SUCCESS = 0 (nevalidna sesija)
        if (serverResponse["success"] != 1) {
          print('🔥 getUser: Invalid session - ${serverResponse["message"]}');
          await clearUser();
          return null;
        }

        // 🔥 AKO JE SVE OK, VRATI LOKALNE PODATKE
        print('✅ getUser: Session valid, returning user data');
        return localUser;
      } else {
        // Server error - za sada vrati lokalne podatke
        print(
          '⚠️ getUser: Server error ${response.statusCode}, using local data',
        );
        return localUser;
      }
    } catch (e) {
      print('🔥 Error in getUser: $e');
      return null;
    }
  }

  // ✅ Clear user data (logout)
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    print('Clearing user from session');
    await prefs.remove(_userKey);
  }

  void logoutAndRedirect(BuildContext context) async {
    await SessionManager().clearUser();
    Navigator.pushReplacementNamed(context, "/login");
  }
}

// ✅ Check if user session is still valid
Future<bool> isLoggedIn() async {
  final user = await SessionManager().getUser();
  if (user == null) return false;

  try {
    final response = await http.post(
      Uri.parse("http://10.0.2.2/webshop/appinternal/api/check_sesion.php"),

      // Uri.parse(
      //   "https://www.digitalis.ba/webshop/appinternal/api/check_sesion.php",
      // ),
      headers: {'Content-Type': 'application/json'}, // 🔥 DODAJ OVO
      body: jsonEncode({
        // 🔥 PROMIJENI U jsonEncode
        "kup_id": user["kup_id"].toString(),
        "pos_id": user["pos_id"].toString(),
        "hash1": user["hash1"],
        "hash2": user["hash2"],
      }),
    );

    print('🔍 isLoggedIn response: ${response.body}'); // DEBUG

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // 🔥 PROVJERI force_logout
      if (json["force_logout"] == true) {
        print('🔥 Server requested force logout during session check');
        await SessionManager().clearUser();

        // 🔥 DODAJ NAVIGACIJU
        // import 'package:get/get.dart';
        // Get.offAllNamed('/');

        return false;
      }

      return json["success"] == 1;
    }
  } catch (e) {
    print('Session check failed: $e');
  }

  return false;
}

Future<void> forceLogout() async {
  print('🔥 Executing force logout...');
  await SessionManager().clearUser();

  // Ako koristiš GetX:
  // Get.offAllNamed('/login');

  // Ili ako koristiš običnu navigaciju, trebat ćeš context
  // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
}

// ✅ Call this to log out and redirect to login
