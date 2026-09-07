import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OuladAliPOSApp());
}

class OuladAliPOSApp extends StatelessWidget {
  const OuladAliPOSApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سوبر ماركت أولاد علي الصعيدي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Roboto',
      ),
      home: const ActivationGate(),
    );
  }
}

// ==========================================
// DATABASE HELPER
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('oulad_ali_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        cost_price REAL DEFAULT 0.0,
        selling_price REAL NOT NULL,
        stock_quantity INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        remaining_amount REAL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await instance.database;
    return await db.query('sales', orderBy: 'id DESC');
  }

  Future<int> processSale({
    required List<Map<String, dynamic>> cartItems,
    required double totalAmount,
    required double paidAmount,
  }) async {
    final db = await instance.database;
    int saleId = -1;

    await db.transaction((txn) async {
      double remaining = paidAmount - totalAmount;
      saleId = await txn.insert('sales', {
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'remaining_amount': remaining,
        'created_at': DateTime.now().toString().split('.')[0],
      });

      for (var item in cartItems) {
        if (item['product_id'] != null && item['product_id'] > 0) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item['quantity'], item['product_id']],
          );
        }
      }
    });

    return saleId;
  }
}

// ==========================================
// ACTIVATION GATE
// ==========================================
class ActivationGate extends StatefulWidget {
  const ActivationGate({Key? key}) : super(key: key);

  @override
  State<ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<ActivationGate> {
  final TextEditingController _keyController = TextEditingController();
  bool _isActivated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isActivated = prefs.getBool('is_activated') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _activate() async {
    if (_keyController.text.trim() == 'OULAD-ALI-2026') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_activated', true);
      setState(() {
        _isActivated = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز التفعيل غير صحيح، تواصل مع الدعم')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isActivated) {
      return const MainHomeScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل النظام')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              'سوبر ماركت أولاد علي الصعيدي',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'التطبيق غير مفعل. للدعم اتصل بـ: 01115197980',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'أدخل كود التفعيل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _activate,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.teal,
              ),
              child: const Text('تفعيل الآن', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MAIN HOME SCREEN WITH BOTTOM NAVIGATION
// ==========================================
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const CashierScreen(),
    const ProductsScreen(),
    const SalesHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'الكاشير'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'المنتجات والمخزون'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'سجل المبيعات'),
        ],
      ),
    );
  }
}

// ==========================================
// 1. CASHIER SCREEN
// ==========================================
class CashierScreen extends StatefulWidget {
  const CashierScreen({Key? key}) : super(key: key);

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final List<Map<String, dynamic>> _cart = [];
  List<Map<String, dynamic>> _dbProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _dbProducts = products;
    });
  }

  double get _totalAmount => _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

  void _addToCart(String name, double price, int productId) {
    setState(() {
      int index = _cart.indexWhere((element) => element['product_id'] == productId && productId != 0);
      if (index != -1 && productId != 0) {
        _cart[index]['quantity']++;
      } else {
        _cart.add({
          'product_id': productId,
          'name': name,
          'price': price,
          'quantity': 1,
        });
      }
    });
  }

  void _checkout() async {
    if (_cart.isEmpty) return;

    await DatabaseHelper.instance.processSale(
      cartItems: _cart,
      totalAmount: _totalAmount,
      paidAmount: _totalAmount,
    );

    setState(() {
      _cart.clear();
    });

    _loadProducts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إتمام البيع وتسجيل الفاتورة بنجاح!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الكاشير - أولاد علي الصعيدي'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('السلة فارغة، اختر منتجات من الأسفل'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text('${item['price']} ج.م × ${item['quantity']}'),
                        trailing: Text('${item['price'] * item['quantity']} ج.م'),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                  child: _dbProducts.isEmpty
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _addToCart('منتج سريع 10ج', 10.0, 0),
                                child: const Text('+ 10ج'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _addToCart('منتج سريع 25ج', 25.0, 0),
                                child: const Text('+ 25ج'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _dbProducts.length,
                          itemBuilder: (context, index) {
                            final p = _dbProducts[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ElevatedButton(
                                onPressed: () => _addToCart(p['name'], p['selling_price'], p['id']),
                                child: Text('${p['name']} (${p['selling_price']}ج)'),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('$_totalAmount ج.م', style: const TextStyle(fontSize: 20, color: Colors.teal, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _checkout,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: Colors.teal,
                  ),
                  child: const Text('إتمام البيع', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 2. PRODUCTS MANAGEMENT SCREEN
// ==========================================
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  void _refreshProducts() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = data;
    });
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة منتج جديد'),
        content: Column(
          mainAxisSize: ViewAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المنتج')),
            TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع')),
            TextField(controller: _stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية بالمخزن')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty && _priceController.text.isNotEmpty) {
                await DatabaseHelper.instance.insertProduct({
                  'name': _nameController.text,
                  'selling_price': double.parse(_priceController.text),
                  'stock_quantity': int.tryParse(_stockController.text) ?? 0,
                });
                _nameController.clear();
                _priceController.clear();
                _stockController.clear();
                Navigator.pop(context);
                _refreshProducts();
              }
            },
            child: const Text('حفظ'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات والمخزون'),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      body: _products.isEmpty
          ? const Center(child: Text('لا توجد منتجات مضافة بعد. اضغط + لإضافة منتج'))
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final p = _products[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.shopping_bag)),
                  title: Text(p['name']),
                  subtitle: Text('السعر: ${p['selling_price']} ج.م'),
                  trailing: Text('المخزون: ${p['stock_quantity']}'),
                );
              },
            ),
    );
  }
}

// ==========================================
// 3. SALES HISTORY SCREEN
// ==========================================
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Map<String, dynamic>> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() async {
    final data = await DatabaseHelper.instance.getAllSales();
    setState(() {
      _sales = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المبيعات والفواتير'),
        backgroundColor: Colors.teal,
      ),
      body: _sales.isEmpty
          ? const Center(child: Text('لا توجد فواتير مبيعات مسجلة'))
          : ListView.builder(
              itemCount: _sales.length,
              itemBuilder: (context, index) {
                final s = _sales[index];
                return ListTile(
                  leading: const Icon(Icons.receipt, color: Colors.teal),
                  title: Text('فاتورة #${s['id']} - ${s['total_amount']} ج.م'),
                  subtitle: Text('التاريخ: ${s['created_at']}'),
                );
              },
            ),
    );
  }
}
