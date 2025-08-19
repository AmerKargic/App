class Product {
  final String id;
  final String ean;
  final String name;
  final String brand;
  final String mpc;
  final String mpcJednokratno;
  final String description;
  final String image;
  final List<String> images;
  final List<WishStock> wishstock;

  Product({
    required this.id,
    required this.ean,
    required this.name,
    required this.brand,
    required this.mpc,
    required this.mpcJednokratno,
    required this.description,
    required this.image,
    required this.images,
    required this.wishstock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['ID'] ?? "",
      ean: json['EAN'] ?? "",
      name: json['name'] ?? "",
      brand: json['Brand'] ?? "",
      mpc: json['MPC'] ?? "",
      mpcJednokratno: json['MPC_jednokratno'] ?? "",
      description: json['description'] ?? "",
      image: json['image'] ?? "",
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e['small'] as String)
              .toList() ??
          [],
      wishstock:
          (json['wishstock'] as List<dynamic>?)
              ?.map((e) => WishStock.fromJson(e))
              .toList() ??
          [],
    );
  }
  Product copyWith({List<WishStock>? wishstock}) {
    return Product(
      id: id,
      ean: ean,
      name: name,
      brand: brand,
      mpc: mpc,
      mpcJednokratno: mpcJednokratno,
      description: description,
      image: image,
      images: images,
      wishstock: wishstock ?? this.wishstock,
    );
  }
}

class WishStock {
  final String kupId;
  final String posId; // legacy (više se ne koristi za logiku)
  final String magId; // aktivno polje
  final String name;
  final double stock;
  final double stockWish;
  final String stockWishLocked;

  WishStock({
    required this.kupId,
    required this.posId,
    required this.magId,
    required this.name,
    required this.stock,
    required this.stockWish,
    required this.stockWishLocked,
  });

  factory WishStock.fromJson(Map<String, dynamic> json) {
    return WishStock(
      kupId: json['kup_id'] ?? "",
      posId: json['pos_id'] ?? "",
      magId: json['mag_id'] ?? "",
      name: json['name'] ?? "",
      stock: (json['stock'] as num?)?.toDouble() ?? 0,
      stockWish: (json['stock_wish'] as num?)?.toDouble() ?? 0,
      stockWishLocked: json['stock_wish_locked'] ?? "",
    );
  }

  bool get isLocked => stockWishLocked == '1';
}
