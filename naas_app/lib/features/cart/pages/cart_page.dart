import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final ApiClient _api = ApiClient();
  List<dynamic> _items = [];
  double _total = 0;
  bool _loading = true;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/cart');
      if (res.data['success'] == true && mounted) {
        setState(() {
          _items = res.data['data']['items'] ?? [];
          _total = (res.data['data']['total'] ?? 0).toDouble();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkout() async {
    setState(() => _checkingOut = true);
    try {
      final res = await _api.post('/cart/checkout');
      if (mounted) {
        if (res.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'تم الشراء بنجاح'), backgroundColor: Colors.green),
          );
          _loadCart();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'فشلت عملية الشراء'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشلت عملية الشراء'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
    if (mounted) setState(() => _checkingOut = false);
  }

  Future<void> _removeItem(String courseId) async {
    try {
      await _api.delete('/cart/$courseId');
      _loadCart();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلة المشتريات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('السلة فارغة', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }, child: const Text('تصفح الكورسات')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 60, height: 60,
                                  color: Colors.grey.shade200,
                                  child: item['thumbnail_url'] != null
                                      ? Image.network(item['thumbnail_url'], fit: BoxFit.cover)
                                      : const Icon(Icons.school),
                                ),
                              ),
                              title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(item['teacher_name'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${item['price']} د.ل',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () => _removeItem(item['course_id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المجموع', style: TextStyle(fontSize: 16)),
                                Text('${_total.toStringAsFixed(2)} د.ل',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _checkingOut ? null : _checkout,
                                child: _checkingOut
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text('شراء (${_items.length})'),
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
}
