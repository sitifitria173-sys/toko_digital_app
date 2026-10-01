import 'package:flutter/foundation.dart';
import '../helpers/db_helper.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider with ChangeNotifier {
  final _items = <String, CartItem>{};

  Map<String, CartItem> get items => {..._items};
  List<CartItem> get cartItems => _items.values.toList();
  int get itemCount => _items.length;
  double get totalAmount =>
      _items.values.fold(0, (t, e) => t + e.price * e.quantity);

  Future<void> fetchAndLoadData() async {
    final data = await DBHelper.instance.getCartItems();

    _items
      ..clear()
      ..addEntries(data.map((e) {
        final item = CartItem(
          id: e['id'].toString(),
          productId: e['product_id'].toString(),
          name: e['name'].toString(),
          category: e['category'].toString(),
          price: (e['price'] as num).toDouble(),
          quantity: (e['quantity'] as num).toInt(),
        );
        return MapEntry(item.productId, item);
      }));

    notifyListeners();
  }

  Future<void> addToCart(Product p) async {
    final old = _items[p.id];

    final item = CartItem(
      id: old?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      productId: p.id,
      name: p.name,
      category: p.category,
      price: p.price,
      quantity: (old?.quantity ?? 0) + 1,
      imageBytes: p.imageBytes,
    );

    _items[p.id] = item;
    notifyListeners();

    await DBHelper.instance.insertOrUpdateCart({
      'id': item.id,
      'product_id': item.productId,
      'name': item.name,
      'category': item.category,
      'price': item.price,
      'quantity': item.quantity,
      'image_bytes': item.imageBytes,
    });
  }

  Future<void> incrementQuantity(String id) async {
    final item = _items[id];
    if (item == null) return;

    final updated = CartItem(
      id: item.id,
      productId: item.productId,
      name: item.name,
      category: item.category,
      price: item.price,
      quantity: item.quantity + 1,
      imageBytes: item.imageBytes,
    );

    _items[id] = updated;
    notifyListeners();

    await DBHelper.instance.updateQuantity(
      item.id,
      updated.quantity,
    );
  }

  Future<void> decrementQuantity(String id) async {
    final item = _items[id];
    if (item == null) return;

    if (item.quantity > 1) {
      final updated = CartItem(
        id: item.id,
        productId: item.productId,
        name: item.name,
        category: item.category,
        price: item.price,
        quantity: item.quantity - 1,
        imageBytes: item.imageBytes,
      );

      _items[id] = updated;
      notifyListeners();

      await DBHelper.instance.updateQuantity(
        item.id,
        updated.quantity,
      );
    } else {
      _items.remove(id);
      notifyListeners();
      await DBHelper.instance.deleteCartItem(item.id);
    }
  }

  Future<void> removeItem(String id) async {
    final item = _items.remove(id);
    notifyListeners();

    if (item != null) {
      await DBHelper.instance.deleteCartItem(item.id);
    }
  }

  Future<void> clearCart() async {
    _items.clear();
    notifyListeners();
    await DBHelper.instance.clearCart();
  }

  Future<void> clear() => clearCart();
}