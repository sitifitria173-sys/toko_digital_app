import 'dart:typed_data';

class CartItem {
  final String id;
  final String productId;
  final String name;
  final String category;
  final double price;
  int quantity;
  final Uint8List? imageBytes;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    this.imageBytes,
  });
}