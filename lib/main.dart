import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cart_provider.dart';
import 'pages/catalog_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key})
      : super(key: key);

  @override
  Widget build(
    BuildContext context,
  ) {
    return ChangeNotifierProvider(
      create: (_) =>
          CartProvider()
            ..fetchAndLoadData(),

      child: MaterialApp(
        title: 'GlowSkin',

        debugShowCheckedModeBanner:
            false,

        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(
            seedColor:
                const Color(
              0xFF8B5CF6,
            ),
          ),

          useMaterial3: true,
        ),

        home:
            const CatalogPage(),
      ),
    );
  }
}