class Product {
  final int id;
  final String name;
  final String image;

  Product({required this.id, required this.name, required this.image});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: int.parse(json['id'].toString()),
    name: json['name'],
    image: json['image'] ?? '',
  );
}
