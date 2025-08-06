import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String baseUrl =
      //'https://www.digitalis.ba/webshop/appinternal/api/';
      'http://10.0.2.2/appinternal/api/';

  /// Fetch combined data for the admin dashboard
  Future<List<Map<String, dynamic>>> fetchAdminDashboardData() async {
    final url = '${baseUrl}admin_dashboard.php';
    print('Fetching admin dashboard data from: $url');

    final response = await http.get(Uri.parse(url));

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Parsed data: $data');

      if (data['success'] == 1) {
        return List<Map<String, dynamic>>.from(data['drivers']);
      } else {
        throw Exception(
          'Failed to fetch admin dashboard data: ${data['message']}',
        );
      }
    } else {
      throw Exception(
        'Failed to fetch admin dashboard data: ${response.statusCode}',
      );
    }
  }
}
