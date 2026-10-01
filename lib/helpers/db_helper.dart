import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final instance = DBHelper._init();
  static Database? _database;

  final _webProducts = <Map<String, dynamic>>[];
  final _webCart = <Map<String, dynamic>>[];

  static const _productsKey = 'glowskin_products';
  static const _cartKey = 'glowskin_cart';

  bool _productsLoaded = false, _cartLoaded = false;

  DBHelper._init();

  Future<Database?> get database async =>
      kIsWeb ? null : _database ??= await _initDB();

  Future<Database> _initDB() async => openDatabase(
        join(await getDatabasesPath(), 'skincare_store.db'),
        version: 2,
        onCreate: _createDB,
      );

  Future<void> _createDB(Database db, int _) async {
    await db.execute('''
      CREATE TABLE master_products(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        image_bytes BLOB
      )
    ''');

    await db.execute('''
      CREATE TABLE local_cart(
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        image_bytes BLOB
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> _loadWeb(
    String key,
    List<Map<String, dynamic>> list,
    bool products,
  ) async {
    if (products ? _productsLoaded : _cartLoaded) return list;

    final saved =
        (await SharedPreferences.getInstance()).getString(key);

    list.clear();

    if (saved != null && saved.isNotEmpty) {
      for (final item in jsonDecode(saved)) {
        final data = Map<String, dynamic>.from(item);

        if (data['image_bytes'] is String) {
          data['image_bytes'] = base64Decode(data['image_bytes']);
        }

        list.add(data);
      }
    }

    if (products) {
      _productsLoaded = true;
    } else {
      _cartLoaded = true;
    }

    return list;
  }

  Future<void> _saveWeb(
    String key,
    List<Map<String, dynamic>> list,
  ) async {
    final data = list.map((item) {
      final copy = Map<String, dynamic>.from(item);
      final image = copy['image_bytes'];

      if (image is Uint8List) {
        copy['image_bytes'] = base64Encode(image);
      } else if (image is List<int>) {
        copy['image_bytes'] = base64Encode(Uint8List.fromList(image));
      }

      return copy;
    }).toList();

    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(data));
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    if (kIsWeb) {
      await _loadWeb(_productsKey, _webProducts, true);

      final i = _webProducts.indexWhere((e) => e['id'] == product['id']);
      i < 0
          ? _webProducts.add(Map.from(product))
          : _webProducts[i] = Map.from(product);

      return _saveWeb(_productsKey, _webProducts);
    }

    final db = await database;
    if (db != null) {
      await db.insert(
        'master_products',
        product,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    if (kIsWeb) {
      await _loadWeb(_productsKey, _webProducts, true);
      return _webProducts.map(Map<String, dynamic>.from).toList();
    }

    final db = await database;
    return db == null
        ? []
        : await db.query('master_products', orderBy: 'name ASC');
  }

  Future<void> deleteProduct(String id) async {
    if (kIsWeb) {
      await _loadWeb(_productsKey, _webProducts, true);
      _webProducts.removeWhere((e) => e['id'] == id);
      return _saveWeb(_productsKey, _webProducts);
    }

    final db = await database;
    await db?.delete(
      'master_products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearProducts() async {
    if (kIsWeb) {
      _webProducts.clear();
      await (await SharedPreferences.getInstance()).remove(_productsKey);
      _productsLoaded = true;
      return;
    }

    await (await database)?.delete('master_products');
  }

  Future<void> insertOrUpdateCart(Map<String, dynamic> item) async {
    final productId = item['product_id'];

    if (kIsWeb) {
      await _loadWeb(_cartKey, _webCart, false);

      final i =
          _webCart.indexWhere((e) => e['product_id'] == productId);

      if (i < 0) {
        _webCart.add(Map.from(item));
      } else {
        _webCart[i]['quantity'] =
            (_webCart[i]['quantity'] as int? ?? 0) + 1;
      }

      return _saveWeb(_cartKey, _webCart);
    }

    final db = await database;
    if (db == null) return;

    final result = await db.query(
      'local_cart',
      where: 'product_id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) {
      await db.insert(
        'local_cart',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        'local_cart',
        {'quantity': (result.first['quantity'] as int) + 1},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    if (kIsWeb) {
      await _loadWeb(_cartKey, _webCart, false);
      return _webCart.map(Map<String, dynamic>.from).toList();
    }

    final db = await database;
    return db == null
        ? []
        : await db.query('local_cart', orderBy: 'name ASC');
  }

  Future<void> updateQuantity(String id, int quantity) async {
    if (kIsWeb) {
      await _loadWeb(_cartKey, _webCart, false);

      if (quantity <= 0) {
        _webCart.removeWhere((e) => e['id'] == id);
      } else {
        final i = _webCart.indexWhere((e) => e['id'] == id);
        if (i >= 0) _webCart[i]['quantity'] = quantity;
      }

      return _saveWeb(_cartKey, _webCart);
    }

    final db = await database;
    if (db == null) return;

    if (quantity <= 0) {
      await db.delete('local_cart', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'local_cart',
        {'quantity': quantity},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteCartItem(String id) async {
    if (kIsWeb) {
      await _loadWeb(_cartKey, _webCart, false);
      _webCart.removeWhere((e) => e['id'] == id);
      return _saveWeb(_cartKey, _webCart);
    }

    await (await database)?.delete(
      'local_cart',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearCart() async {
    if (kIsWeb) {
      _webCart.clear();
      await (await SharedPreferences.getInstance()).remove(_cartKey);
      _cartLoaded = true;
      return;
    }

    await (await database)?.delete('local_cart');
  }
}