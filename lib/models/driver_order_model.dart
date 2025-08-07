import 'package:flutter/material.dart';

class DriverOrder {
  final int oid;
  final int brojKutija;
  final String broj;

  final String napomena;
  final String napomenaVozac;
  final double iznos;
  final bool trebaVratitiNovac;
  final Kupac kupac;
  final List<Stavka> stavke;

  DriverOrder({
    required this.broj,
    required this.oid,
    required this.brojKutija,
    required this.napomena,
    required this.napomenaVozac,
    required this.iznos,
    required this.trebaVratitiNovac,
    required this.kupac,
    required this.stavke,
  });

  factory DriverOrder.fromJson(Map<String, dynamic> json) {
    // Add debug print to see what's in the JSON
    print('DriverOrder JSON: $json');

    return DriverOrder(
      oid: json['oid'] ?? 0,
      broj: json['broj']?.toString() ?? '',

      brojKutija: json['broj_kutija'] ?? 0,
      napomena: json['napomena'] ?? '',
      // Fix the field name to match API response
      napomenaVozac: json['napomenaVozac'] ?? '',
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0.0,
      // Use the trebaVratitiNovac field from API if available, otherwise calculate it
      trebaVratitiNovac:
          json['trebaVratitiNovac'] ??
          ((json['iznos'] as num?)?.toDouble() ?? 0.0) < 0,
      // Handle potentially null kupac data
      kupac: Kupac.fromJson(json['kupac'] ?? {}),
      // Handle potentially empty or null stavke array
      stavke:
          (json['stavke'] as List<dynamic>?)
              ?.map((stavkaJson) => Stavka.fromJson(stavkaJson))
              .toList() ??
          [],
    );
  }

  // Add a debug helper method
  Map<String, dynamic> toJson() => {
    'oid': oid,
    'broj': broj,
    'broj_kutija': brojKutija,
    'napomena': napomena,
    'napomenaVozac': napomenaVozac,
    'iznos': iznos,
    'trebaVratitiNovac': trebaVratitiNovac,
    'kupac': kupac.toJson(),
    'stavke': stavke.map((item) => item.toJson()).toList(),
  };
}

class PhoneNumber {
  final String number;
  final String type; // 'Mobitel', 'Telefon', etc.
  final String displayText;

  PhoneNumber({
    required this.number,
    required this.type,
    required this.displayText,
  });

  // 🔥 Clean phone number for calling (remove spaces, dashes, etc.)
  String get callableNumber {
    return number.replaceAll(RegExp(r'[^\d+]'), '');
  }

  // 🔥 Check if number looks like a mobile number (starts with 06 in Bosnia)
  bool get isMobile {
    final cleanNum = callableNumber;
    return cleanNum.startsWith('06') ||
        cleanNum.startsWith('+38706') ||
        cleanNum.startsWith('38706') ||
        type.toLowerCase().contains('mobitel');
  }
}

class Kupac {
  final String naziv;
  final String adresa;
  final String opstina;
  final String drzava;
  final String telefon;
  final String email;
  final bool isMaloprodaja;

  // Optional fields for retail stores
  final int? skladisteId;
  final String? skladisteVrsta;
  final int? posId;
  final int? magId;
  final int? mag2Id;

  Kupac({
    required this.naziv,
    required this.adresa,
    required this.opstina,
    required this.drzava,
    required this.telefon,
    required this.email,
    this.isMaloprodaja = false,
    this.skladisteId,
    this.skladisteVrsta,
    this.posId,
    this.magId,
    this.mag2Id,
  });

  factory Kupac.fromJson(Map<String, dynamic> json) {
    return Kupac(
      naziv: json['naziv']?.toString() ?? '',
      adresa: json['adresa']?.toString() ?? '',
      opstina: json['opstina']?.toString() ?? '',
      drzava: json['drzava']?.toString() ?? '',
      telefon: json['telefon']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isMaloprodaja:
          json['isMaloprodaja'] == true || json['isMaloprodaja'] == 1,
      skladisteId: json['skladisteId'] != null
          ? int.parse(json['skladisteId'].toString())
          : 0,
      skladisteVrsta: json['skladisteVrsta']?.toString() ?? '',
      posId: json['posId'] != null ? int.parse(json['posId'].toString()) : 0,
      magId: json['magId'] != null ? int.parse(json['magId'].toString()) : 0,
      mag2Id: json['mag2Id'] != null ? int.parse(json['mag2Id'].toString()) : 0,
    );
  }

  List<PhoneNumber> get phoneNumbers {
    if (telefon.isEmpty) return [];

    // Split by " / " separator and clean up each number
    final phones = telefon
        .split(' / ')
        .map((phone) => phone.trim())
        .where((phone) => phone.isNotEmpty)
        .toList();

    List<PhoneNumber> phoneList = [];

    for (int i = 0; i < phones.length; i++) {
      String cleanPhone = phones[i];
      String type = '';

      // Determine phone type based on position or pattern
      if (phones.length == 1) {
        type = 'Telefon';
      } else if (i == 0) {
        // First number is usually mobile (from Mobitel1)
        type = 'Mobitel';
      } else {
        // Second number is usually landline (from Telefon1)
        type = 'Telefon';
      }

      phoneList.add(
        PhoneNumber(
          number: cleanPhone,
          type: type,
          displayText: '$type: $cleanPhone',
        ),
      );
    }

    return phoneList;
  }

  // 🔥 NEW: Get primary phone (first available)
  String get primaryPhone {
    final phones = phoneNumbers;
    return phones.isNotEmpty ? phones.first.number : '';
  }

  // 🔥 NEW: Check if multiple phones available
  bool get hasMultiplePhones => phoneNumbers.length > 1;

  Map<String, dynamic> toJson() => {
    'naziv': naziv,
    'adresa': adresa,
    'opstina': opstina,
    'drzava': drzava,
    'telefon': telefon,
    'email': email,
    'isMaloprodaja': isMaloprodaja,
    'skladisteId': skladisteId,
    'skladisteVrsta': skladisteVrsta,
    'posId': posId,
    'magId': magId,
    'mag2Id': mag2Id,
  };
}

class Stavka {
  final int aid;
  final String naziv;
  final String ean;
  final double kol;
  final double mpc;
  final double rabat;
  final double cijena;

  Stavka({
    required this.aid,
    required this.naziv,
    required this.ean,
    required this.kol,
    required this.mpc,
    required this.rabat,
    required this.cijena,
  });

  factory Stavka.fromJson(Map<String, dynamic> json) {
    return Stavka(
      aid: json['aid'] ?? 0,
      naziv: json['naziv'] ?? '',
      ean: json['ean'] ?? '',
      kol: (json['kol'] as num?)?.toDouble() ?? 0.0,
      mpc: (json['mpc'] as num?)?.toDouble() ?? 0.0,
      rabat: (json['rabat'] as num?)?.toDouble() ?? 0.0,
      cijena:
          (json['cijena'] as num?)?.toDouble() ?? 0.0, // Parse this from JSON
    );
  }

  Map<String, dynamic> toJson() => {
    'aid': aid,
    'naziv': naziv,
    'ean': ean,
    'kol': kol,
    'mpc': mpc,
    'rabat': rabat,
    'cijena': cijena, // Include in JSON output
  };
}
