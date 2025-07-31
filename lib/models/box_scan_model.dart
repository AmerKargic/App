import 'dart:convert';

class BoxScan {
  final int oid;
  final int boxNumber;
  final String boxBarcode;
  final String timestamp;
  final List<String> products;

  BoxScan({
    required this.oid,
    required this.boxNumber,
    required this.boxBarcode,
    required this.timestamp,
    this.products = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'oid': oid,
      'box_number': boxNumber,
      'box_barcode': boxBarcode,
      'timestamp': timestamp,
      'products': products,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'oid': oid,
      'box_number': boxNumber,
      'box_barcode': boxBarcode,
      'timestamp': timestamp,
      'synced': 0,
    };
  }

  factory BoxScan.fromJson(Map<String, dynamic> json) {
    return BoxScan(
      oid: json['oid'],
      boxNumber: json['box_number'],
      boxBarcode: json['box_barcode'],
      timestamp: json['timestamp'],
      products: List<String>.from(json['products'] ?? []),
    );
  }

  factory BoxScan.fromDbMap(Map<String, dynamic> map, List<String> products) {
    return BoxScan(
      oid: map['oid'],
      boxNumber: map['box_number'],
      boxBarcode: map['box_barcode'],
      timestamp: map['timestamp'],
      products: products,
    );
  }

  @override
  String toString() {
    return 'BoxScan: OID=$oid, Box #$boxNumber, Barcode=$boxBarcode, Products=${products.length}';
  }
}
