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
// 1. DATABASE HELPER
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
        stock_quantity INTEGER DEFAULT 0,
        min_stock_warning INTEGER DEFAULT 5
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

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
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
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var item in cartItems) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['price'],
          'subtotal': item['price'] * item['quantity'],
        });

        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item['quantity'], item['product_id']],
        );
      }
    });

    return saleId;
  }
}

// ==========================================
// 2. ACTIVATION GATE (نظام التفعيل)
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
      return const CashierScreen();
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
              'التطبيق غير مفعل. للحصول على كود التفعيل يرجى الاتصال بـ:\n01115197980',
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
// 3. CASHIER SCREEN (شاشة الكاشير والمبيعات)
// ==========================================
class CashierScreen extends StatefulWidget {
  const CashierScreen({Key? key}) : super(key: key);

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final List<Map<String, dynamic>> _cart = [];
  final TextEditingController _paidController = TextEditingController();

  double get _totalAmount => _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

  void _addToCart(String name, double price, int productId) {
    setState(() {
      int index = _cart.indexWhere((element) => element['product_id'] == productId);
      if (index != -1) {
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
    double paid = double.tryParse(_paidController.text) ?? _totalAmount;

    await DatabaseHelper.instance.processSale(
      cartItems: _cart,
      totalAmount: _totalAmount,
      paidAmount: paid,
    );

    setState(() {
      _cart.clear();
      _paidController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت عملية البيع بنجاح وحفظ الفاتورة!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كاشير - أولاد علي الصعيدي'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('السلة فارغة، اضغط على إضافات سريعة للتجربة'))
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
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => _addToCart('منتج تجريبي 1', 10.0, 1),
                      child: const Text('+ منتج 10ج'),
                    ),
                    ElevatedButton(
                      onPressed: () => _addToCart('منتج تجريبي 2', 25.0, 2),
                      child: const Text('+ منتج 25ج'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('$_totalAmount ج.م', style: const TextStyle(fontSize: 20, color: Colors.teal, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _checkout,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.teal,
                  ),
                  child: const Text('إتمام البيع وطباعة', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
