import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WholesaleApp());
}

class WholesaleApp extends StatelessWidget {
  const WholesaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ديون سوريا كاش',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class Customer {
  final int? id;
  final String name;
  final double balance;

  Customer({this.id, required this.name, required this.balance});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      balance: map['balance'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wholesale.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL
      )
    ''');
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    final db = await instance.database;
    final result = await db.query('customers', orderBy: 'name ASC');
    return result.map((json) => Customer.fromMap(json)).toList();
  }

  Future<int> updateCustomerBalance(int id, double newBalance) async {
    final db = await instance.database;
    return await db.update(
      'customers',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Customer> customers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshCustomers();
  }

  Future refreshCustomers() async {
    setState(() => isLoading = true);
    customers = await DatabaseHelper.instance.getCustomers();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    double totalBalance = customers.fold(0, (sum, item) => sum + item.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ديون سوريا كاش'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text('إجمالي الديون:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '$totalBalance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: totalBalance >= 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? const Center(child: Text('لا يوجد زبائن مسجلين حالياً.'))
                    : ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Text('الحساب الحالي: ${customer.balance}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                                onPressed: () => _showAddTransactionDialog(context, customer),
                              ),
                              onLongPress: () => _deleteCustomer(context, customer.id!),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context),
        label: const Text('إضافة زبون جديد'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext dialogContext) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');

    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة زبون جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الزبون')),
            TextField(controller: balanceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرصيد الابتدائي')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                double initialBalance = double.tryParse(balanceController.text) ?? 0;
                await DatabaseHelper.instance.insertCustomer(
                  Customer(name: nameController.text, balance: initialBalance),
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                refreshCustomers();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext dialogContext, Customer customer) {
    final amountController = TextEditingController();
    bool isAddingDebt = true;

    showDialog(
      context: dialogContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) => AlertDialog(
          title: Text('حركة للزبون: ${customer.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'قيمة المبلغ'),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('تحويل رصيد (عليه)'),
                    selected: isAddingDebt,
                    onSelected: (selected) => setStateDialog(() => isAddingDebt = true),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('دفعة واصلة (قبض)'),
                    selected: !isAddingDebt,
                    onSelected: (selected) => setStateDialog(() => isAddingDebt = false),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                double amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  double newBalance = isAddingDebt ? customer.balance + amount : customer.balance - amount;
                  await DatabaseHelper.instance.updateCustomerBalance(customer.id!, newBalance);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  refreshCustomers();
                }
              },
              child: const Text('تحديث الحساب'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCustomer(BuildContext dialogContext, int id) async {
    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الزبون'),
        content: const Text('هل أنت متأكد من حذف هذا الزبون نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.instance.deleteCustomer(id);
              if (!mounted) return;
              Navigator.pop(ctx);
              refreshCustomers();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
