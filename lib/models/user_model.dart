//pulling data from api :D

class UserModel {
  final int kupId;
  final int posId;
  final String name;
  final String email;
  final String level;
  final String hash1;
  final String hash2;
  final Map<String, dynamic>? magaciniIdArray; // DODAJ OVO

  UserModel({
    required this.kupId,
    required this.posId,
    required this.name,
    required this.email,
    required this.level,
    required this.hash1,
    required this.hash2,
    this.magaciniIdArray, // DODAJ OVO
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    int kupId = 0;
    int posId = 0;

    if (json['kup_id'] != null) {
      kupId = int.tryParse(json['kup_id'].toString()) ?? 0;
    }

    if (json['pos_id'] != null) {
      posId = int.tryParse(json['pos_id'].toString()) ?? 0;
    }

    String level = '';
    if (json['options'] != null && json['options']['level'] != null) {
      level = json['options']['level'].toString();
    } else if (json['level'] != null) {
      level = json['level'].toString();
    }

    // DODAJ OVO
    Map<String, dynamic>? magaciniIdArray;
    if (json['options'] != null &&
        json['options']['Magacini_ID_array'] != null) {
      magaciniIdArray = Map<String, dynamic>.from(
        json['options']['Magacini_ID_array'],
      );
    } else if (json['Magacini_ID_array'] != null) {
      magaciniIdArray = Map<String, dynamic>.from(json['Magacini_ID_array']);
    }

    return UserModel(
      kupId: kupId,
      posId: posId,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      level: level,
      hash1: json['hash1'] ?? '',
      hash2: json['hash2'] ?? '',
      magaciniIdArray: magaciniIdArray, // DODAJ OVO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kup_id': kupId,
      'pos_id': posId,
      'name': name,
      'email': email,
      'level': level,
      'hash1': hash1,
      'hash2': hash2,
      'Magacini_ID_array': magaciniIdArray, // DODAJ OVO
    };
  }
}
