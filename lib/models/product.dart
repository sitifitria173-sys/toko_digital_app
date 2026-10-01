import 'dart:typed_data';

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final Uint8List? imageBytes;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.imageBytes,
  });
}