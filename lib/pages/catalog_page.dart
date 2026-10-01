import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../helpers/db_helper.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'cart_page.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final picker = ImagePicker();

  final products = <Product>[
    Product(id: '1', name: 'Serum Vitamin C', category: 'Serum', price: 75000),
    Product(id: '2', name: 'Facial Wash', category: 'Cleanser', price: 55000),
    Product(id: '3', name: 'Toner Hydrating', category: 'Toner', price: 60000),
    Product(id: '4', name: 'Moisturizer Gel', category: 'Moisturizer', price: 70000),
    Product(id: '5', name: 'Moisturizer Skintific', category: 'Moisturizer', price: 80000),
  ];

  final kategori = const [
    'Serum',
    'Cleanser',
    'Toner',
    'Moisturizer',
    'Sunscreen',
    'Mask'
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final data = await DBHelper.instance.getProducts();
    if (!mounted) return;

    if (data.isEmpty) {
      for (final p in products) {
        await _saveProduct(p);
      }
      return;
    }

    setState(() {
      products
        ..clear()
        ..addAll(data.map((e) => Product(
              id: e['id'].toString(),
              name: e['name'].toString(),
              category: e['category'].toString(),
              price: (e['price'] as num).toDouble(),
              imageBytes: _bytes(e['image_bytes']),
            )));
    });
  }

  Uint8List? _bytes(dynamic x) {
    if (x is Uint8List) return x;
    if (x is List<int>) return Uint8List.fromList(x);
    return null;
  }

  Future<void> _saveProduct(Product p) => DBHelper.instance.insertProduct({
        'id': p.id,
        'name': p.name,
        'category': p.category,
        'price': p.price,
        'image_bytes': p.imageBytes,
      });

  Future<Uint8List?> _pick() async =>
      (await picker.pickImage(source: ImageSource.gallery))?.readAsBytes();

  Future<void> _form([Product? old]) async {
    final nama = TextEditingController(text: old?.name);
    final harga = TextEditingController(
      text: old == null ? '' : old.price.toInt().toString(),
    );
    var kat = kategori.contains(old?.category) ? old!.category : 'Serum';
    Uint8List? foto = old?.imageBytes;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            old == null ? 'Tambah Barang' : 'Edit Barang',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final x = await _pick();
                    if (x != null) set(() => foto = x);
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6)),
                    ),
                    child: foto != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(foto!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 36,
                                color: Color(0xFF8B5CF6),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                old == null ? 'Pilih Foto' : 'Tambah Foto',
                                style: const TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _field(nama, 'Nama Produk', Icons.shopping_bag_outlined),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: kat,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: kategori
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) set(() => kat = v);
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  harga,
                  'Harga',
                  Icons.payments_outlined,
                  number: true,
                  hint: 'Contoh: 75000',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final n = nama.text.trim();
                final h = double.tryParse(harga.text.trim());

                if (n.isEmpty || h == null || h <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama dan harga harus diisi dengan benar.'),
                    ),
                  );
                  return;
                }

                final p = Product(
                  id: old?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: n,
                  category: kat,
                  price: h,
                  imageBytes: foto,
                );

                await _saveProduct(p);
                if (!mounted) return;

                setState(() {
                  final i = products.indexWhere((e) => e.id == p.id);
                  i < 0 ? products.add(p) : products[i] = p;
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      old == null
                          ? 'Produk berhasil ditambahkan.'
                          : 'Produk berhasil diperbarui.',
                    ),
                  ),
                );
              },
              child: Text(old == null ? 'Simpan' : 'Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );

    nama.dispose();
    harga.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool number = false,
    String? hint,
  }) =>
      TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      );

  String rupiah(double v) => 'Rp ${v.toInt()}'.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7FF),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFFF1E6FF),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.spa_outlined,
                size: 32,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GlowSkin',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B21B6),
                  ),
                ),
                Text(
                  'Skincare Store',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  iconSize: 32,
                  color: const Color(0xFF5B21B6),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined),
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEC4899),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0E7FF), Color(0xFFFFE8F4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rawat Kulitmu',
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Untuk Versi Terbaik\nDari Dirimu',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.25,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4C1D95),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Temukan produk skincare pilihanmu.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B3FA0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Produk Terlaris',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4C1D95),
                  ),
                ),
                Text(
                  '${products.length} Produk',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF9B7AC8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                mainAxisExtent: 340,
              ),
              itemBuilder: (_, i) {
                final p = products[i];
                return _Card(
                  product: p,
                  price: rupiah(p.price),
                  edit: () => _form(p),
                  cart: () {
                    cart.addToCart(p);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${p.name} ditambahkan ke keranjang'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        onPressed: _form,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text(
          'Tambah Barang',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Product product;
  final String price;
  final VoidCallback edit, cart;

  const _Card({
    required this.product,
    required this.price,
    required this.edit,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _image(
                      product.imageBytes,
                      width: double.infinity,
                      height: 130,
                    ),
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: edit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27272A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: cart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 16,
                        ),
                        label: const Flexible(
                          child: Text(
                            'Tambah ke Keranjang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

Widget _image(
  Uint8List? bytes, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (bytes != null && bytes.isNotEmpty) {
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallback(width, height),
    );
  }
  return _fallback(width, height);
}

Widget _fallback(double? width, double? height) => Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFFBCFE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sanitizer_rounded,
            color: Color(0xFF8B5CF6),
            size: 32,
          ),
          SizedBox(height: 4),
          Text(
            'GlowSkin',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );