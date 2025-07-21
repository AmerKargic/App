// models/shelf.dart

class Shelf {
  final int id;
  final String name;
  final String barcode;

  Shelf({required this.id, required this.name, required this.barcode});

  factory Shelf.fromJson(Map<String, dynamic> json) {
    return Shelf(
      id: int.parse(json['id'].toString()),
      name: json['name'],
      barcode: json['barcode'],
    );
  }
}

class ShelfProduct {
  final int shelfId;
  final int productId;
  final String productName;
  final String image;

  ShelfProduct({
    required this.shelfId,
    required this.productId,
    required this.productName,
    required this.image,
  });

  factory ShelfProduct.fromJson(Map<String, dynamic> json) {
    return ShelfProduct(
      shelfId: int.parse(json['shelf_id'].toString()),
      productId: int.parse(json['product_id'].toString()),
      productName: json['product_name'],
      image: json['image'] ?? '',
    );
  }
}
